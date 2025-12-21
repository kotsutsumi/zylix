// ZylixHotReload.kt - Android Hot Reload for Zylix v0.5.0
//
// Provides hot reload functionality for Android development.
// Features:
// - Emulator integration
// - State preservation
// - Error overlay
// - WebSocket communication

package com.zylix

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

// ============================================================================
// Hot Reload State
// ============================================================================

enum class HotReloadState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    RELOADING,
    ERROR
}

// ============================================================================
// Build Error
// ============================================================================

data class BuildError(
    val file: String,
    val line: Int,
    val column: Int,
    val message: String,
    val severity: String = "error"
)

// ============================================================================
// Hot Reload Client
// ============================================================================

class ZylixHotReloadClient private constructor(context: Context) {
    private val appContext = context.applicationContext
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    private val _state = MutableStateFlow(HotReloadState.DISCONNECTED)
    val state: StateFlow<HotReloadState> = _state

    private val _lastError = MutableStateFlow<BuildError?>(null)
    val lastError: StateFlow<BuildError?> = _lastError

    private val stateManager = StatePreservationManager(appContext)
    private var errorOverlay: ErrorOverlayView? = null
    private val handlers = mutableMapOf<String, (JSONObject) -> Unit>()

    var serverUrl: String = "ws://10.0.2.2:3001" // Android emulator localhost
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 10

    private var reconnectJob: Job? = null

    init {
        registerActivityLifecycle()
    }

    /**
     * Shuts down the client, releasing all resources.
     * Call this when the application is terminating.
     */
    fun shutdown() {
        disconnect()
        scope.cancel()
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }

    companion object {
        private const val TAG = "ZylixHMR"

        @Volatile
        private var instance: ZylixHotReloadClient? = null

        fun getInstance(context: Context): ZylixHotReloadClient {
            return instance ?: synchronized(this) {
                instance ?: ZylixHotReloadClient(context).also { instance = it }
            }
        }
    }

    // MARK: - Connection

    fun connect() {
        if (_state.value == HotReloadState.CONNECTED ||
            _state.value == HotReloadState.CONNECTING) return

        _state.value = HotReloadState.CONNECTING

        val request = Request.Builder()
            .url(serverUrl)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "Connected to $serverUrl")
                mainHandler.post {
                    _state.value = HotReloadState.CONNECTED
                    reconnectAttempts = 0
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                mainHandler.post {
                    handleMessage(text)
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Connection failed: ${t.message}")
                mainHandler.post {
                    _state.value = HotReloadState.ERROR
                    scheduleReconnect()
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Connection closed: $reason")
                mainHandler.post {
                    _state.value = HotReloadState.DISCONNECTED
                    scheduleReconnect()
                }
            }
        })
    }

    fun disconnect() {
        reconnectJob?.cancel()
        reconnectJob = null
        webSocket?.close(1000, "Client closing")
        webSocket = null
        reconnectAttempts = 0
        _state.value = HotReloadState.DISCONNECTED
    }

    private fun scheduleReconnect() {
        if (reconnectAttempts >= maxReconnectAttempts) {
            Log.d(TAG, "Max reconnect attempts reached")
            return
        }

        // Cancel any existing reconnect job to prevent concurrent reconnects
        reconnectJob?.cancel()

        reconnectAttempts++
        val baseDelay = minOf(30000L, (1L shl (reconnectAttempts - 1)) * 1000)
        // Add jitter to prevent thundering herd
        val jitter = (Math.random() * 1000).toLong()
        val delay = baseDelay + jitter

        Log.d(TAG, "Reconnecting in ${delay}ms (attempt $reconnectAttempts)")

        reconnectJob = scope.launch {
            delay(delay)
            connect()
        }
    }

    // MARK: - Message Handling

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")

            when (type) {
                "reload" -> handleReload()
                "hot_update" -> handleHotUpdate(json.optJSONObject("payload"))
                "error_overlay" -> handleErrorOverlay(json.opt("payload"))
                "state_sync" -> handleStateSync(json.optJSONObject("payload"))
                "ping" -> send(JSONObject().put("type", "pong"))
                else -> handlers[type]?.invoke(json.optJSONObject("payload") ?: JSONObject())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Message handling error: ${e.message}")
        }
    }

    private fun handleReload() {
        Log.d(TAG, "Full reload triggered")
        _state.value = HotReloadState.RELOADING

        // Save state before reload
        stateManager.saveState()

        // Trigger activity recreation
        scope.launch {
            currentActivity?.recreate()
        }
    }

    private fun handleHotUpdate(payload: JSONObject?) {
        val module = payload?.optString("module") ?: return
        Log.d(TAG, "Hot update for: $module")

        hideErrorOverlay()

        // Notify observers (use toList() to prevent ConcurrentModificationException)
        hotUpdateListeners.toList().forEach { it(module) }
    }

    private fun handleErrorOverlay(payload: Any?) {
        if (payload is JSONObject) {
            val error = BuildError(
                file = payload.optString("file", "unknown"),
                line = payload.optInt("line", 1),
                column = payload.optInt("column", 1),
                message = payload.optString("message", "Unknown error"),
                severity = payload.optString("severity", "error")
            )
            _lastError.value = error
            showErrorOverlay(error)
        }
    }

    private fun handleStateSync(state: JSONObject?) {
        state?.let { stateManager.mergeState(it) }
    }

    // MARK: - Error Overlay

    private fun showErrorOverlay(error: BuildError) {
        currentActivity?.let { activity ->
            hideErrorOverlay()
            errorOverlay = ErrorOverlayView(activity, error) {
                hideErrorOverlay()
            }
            errorOverlay?.show()
        }
    }

    fun hideErrorOverlay() {
        errorOverlay?.dismiss()
        errorOverlay = null
        _lastError.value = null
    }

    // MARK: - Send

    private fun send(data: JSONObject) {
        webSocket?.send(data.toString())
    }

    // MARK: - State Preservation

    fun saveState(key: String, value: Any) {
        stateManager.set(key, value)
    }

    fun loadState(key: String): Any? {
        return stateManager.get(key)
    }

    fun restoreState() {
        stateManager.restoreState()
    }

    // MARK: - Handlers

    fun on(event: String, handler: (JSONObject) -> Unit) {
        handlers[event] = handler
    }

    fun off(event: String) {
        handlers.remove(event)
    }

    // MARK: - Activity Lifecycle

    private var currentActivity: Activity? = null
    private val hotUpdateListeners = mutableListOf<(String) -> Unit>()

    private fun registerActivityLifecycle() {
        (appContext as? Application)?.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
                override fun onActivityStarted(activity: Activity) {}
                override fun onActivityResumed(activity: Activity) {
                    currentActivity = activity
                    if (_state.value == HotReloadState.RELOADING) {
                        restoreState()
                        _state.value = HotReloadState.CONNECTED
                    }
                }
                override fun onActivityPaused(activity: Activity) {}
                override fun onActivityStopped(activity: Activity) {}
                override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
                override fun onActivityDestroyed(activity: Activity) {
                    if (currentActivity == activity) {
                        currentActivity = null
                    }
                }
            }
        )
    }

    fun addHotUpdateListener(listener: (String) -> Unit) {
        hotUpdateListeners.add(listener)
    }

    fun removeHotUpdateListener(listener: (String) -> Unit) {
        hotUpdateListeners.remove(listener)
    }
}

// ============================================================================
// State Preservation Manager
// ============================================================================

class StatePreservationManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "__ZYLIX_HOT_RELOAD_STATE__",
        Context.MODE_PRIVATE
    )
    private val state = mutableMapOf<String, Any>()

    fun set(key: String, value: Any) {
        state[key] = value
    }

    fun get(key: String): Any? {
        return state[key]
    }

    fun mergeState(newState: JSONObject) {
        val keys = newState.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            state[key] = newState.get(key)
        }
    }

    fun saveState() {
        val editor = prefs.edit()
        val json = JSONObject(state.mapValues { it.value.toString() })
        editor.putString("state", json.toString())
        editor.apply()
    }

    fun restoreState() {
        prefs.getString("state", null)?.let { stateStr ->
            try {
                val json = JSONObject(stateStr)
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    state[key] = json.get(key)
                }
            } catch (e: Exception) {
                Log.e("StateManager", "Failed to restore state: ${e.message}")
            }
        }

        // Clear stored state
        prefs.edit().remove("state").apply()
    }
}

// ============================================================================
// Error Overlay View
// ============================================================================

class ErrorOverlayView(
    private val activity: Activity,
    private val error: BuildError,
    private val onDismiss: () -> Unit
) {
    private var overlayView: View? = null

    fun show() {
        val container = FrameLayout(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#E6000000"))
        }

        val content = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 40, 40, 40)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        // Title
        content.addView(TextView(activity).apply {
            text = "⚠️ Build Error"
            setTextColor(Color.parseColor("#FF6B6B"))
            textSize = 24f
            setPadding(0, 0, 0, 20)
        })

        // Location
        content.addView(TextView(activity).apply {
            text = "${error.file}:${error.line}:${error.column}"
            setTextColor(Color.GRAY)
            textSize = 14f
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(0, 0, 0, 10)
        })

        // Message
        content.addView(ScrollView(activity).apply {
            addView(TextView(activity).apply {
                text = error.message
                setTextColor(Color.WHITE)
                textSize = 16f
                typeface = android.graphics.Typeface.MONOSPACE
                setBackgroundColor(Color.parseColor("#333333"))
                setPadding(20, 20, 20, 20)
            })
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 20)
            }
        })

        // Dismiss button
        content.addView(Button(activity).apply {
            text = "Dismiss"
            setBackgroundColor(Color.parseColor("#4A90D9"))
            setTextColor(Color.WHITE)
            setOnClickListener { onDismiss() }
        })

        container.addView(content)

        (activity.window.decorView as? ViewGroup)?.addView(container)
        overlayView = container
    }

    fun dismiss() {
        overlayView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
        }
        overlayView = null
    }
}

// ============================================================================
// Compose Integration
// ============================================================================

@Composable
fun rememberHotReloadState(): State<HotReloadState> {
    val context = androidx.compose.ui.platform.LocalContext.current
    val client = remember { ZylixHotReloadClient.getInstance(context) }
    return client.state.collectAsState()
}

@Composable
fun HotReloadable(
    content: @Composable () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val client = remember { ZylixHotReloadClient.getInstance(context) }
    var reloadKey by remember { mutableStateOf(0) }

    DisposableEffect(Unit) {
        val listener: (String) -> Unit = { reloadKey++ }
        client.addHotUpdateListener(listener)
        onDispose {
            client.removeHotUpdateListener(listener)
        }
    }

    key(reloadKey) {
        content()
    }
}

// ============================================================================
// Extension Functions
// ============================================================================

fun Activity.enableHotReload() {
    ZylixHotReloadClient.getInstance(this).connect()
}

fun Activity.disableHotReload() {
    ZylixHotReloadClient.getInstance(this).disconnect()
}
