package com.zylix.test

import android.graphics.Rect
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.ServerSocket
import java.net.Socket
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Zylix Test Server for Android
 * HTTP server that receives commands from Zig Android driver and executes them using UIAutomator2
 */
class ZylixTestServer(private val port: Int = 6790) {

    private val gson = Gson()
    private val sessions = ConcurrentHashMap<String, Session>()
    private var sessionCounter = 0
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /**
     * Session manages UiDevice and element references
     */
    class Session(
        val id: String,
        val device: UiDevice,
        val packageName: String
    ) {
        private val elements = ConcurrentHashMap<String, UiObject2>()
        private var elementCounter = 0

        fun storeElement(element: UiObject2): String {
            val id = "element-${++elementCounter}"
            elements[id] = element
            return id
        }

        fun getElement(id: String): UiObject2? = elements[id]

        fun clearElements() {
            elements.clear()
        }
    }

    /**
     * Command result
     */
    data class CommandResult(
        val sessionId: String? = null,
        val elementId: String? = null,
        val elements: List<String>? = null,
        val value: Any? = null,
        val error: String? = null,
        val success: Boolean? = null
    )

    /**
     * Start the HTTP server
     */
    fun start() {
        isRunning = true
        scope.launch {
            try {
                serverSocket = ServerSocket(port)
                println("ZylixTestServer started on port $port")

                while (isRunning) {
                    val client = serverSocket?.accept() ?: break
                    launch { handleClient(client) }
                }
            } catch (e: Exception) {
                if (isRunning) {
                    println("Server error: ${e.message}")
                }
            }
        }
    }

    /**
     * Stop the server
     */
    fun stop() {
        isRunning = false
        sessions.values.forEach { it.clearElements() }
        sessions.clear()
        serverSocket?.close()
        scope.cancel()
        println("ZylixTestServer stopped")
    }

    private suspend fun handleClient(client: Socket) = withContext(Dispatchers.IO) {
        try {
            val reader = BufferedReader(InputStreamReader(client.getInputStream()))
            val writer = PrintWriter(client.getOutputStream(), true)

            // Parse HTTP request
            val requestLine = reader.readLine() ?: return@withContext
            val parts = requestLine.split(" ")
            if (parts.size < 2) return@withContext

            val method = parts[0]
            val path = parts[1]

            // Read headers
            val headers = mutableMapOf<String, String>()
            var line: String?
            while (reader.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                val colonIndex = line!!.indexOf(':')
                if (colonIndex > 0) {
                    headers[line!!.substring(0, colonIndex).trim().lowercase()] =
                        line!!.substring(colonIndex + 1).trim()
                }
            }

            // Read body
            val contentLength = headers["content-length"]?.toIntOrNull() ?: 0
            val body = if (contentLength > 0) {
                val bodyChars = CharArray(contentLength)
                reader.read(bodyChars, 0, contentLength)
                String(bodyChars)
            } else null

            // Handle command
            val bodyJson = if (body != null && body.isNotEmpty()) {
                gson.fromJson(body, JsonObject::class.java)
            } else null

            val result = handleCommand(path, method, bodyJson)
            val responseJson = gson.toJson(result)

            // Send HTTP response
            writer.println("HTTP/1.1 200 OK")
            writer.println("Content-Type: application/json")
            writer.println("Content-Length: ${responseJson.length}")
            writer.println()
            writer.print(responseJson)
            writer.flush()

        } catch (e: Exception) {
            println("Client error: ${e.message}")
        } finally {
            client.close()
        }
    }

    /**
     * Handle incoming command
     */
    fun handleCommand(path: String, method: String, body: JsonObject?): CommandResult {
        val segments = path.split("/").filter { it.isNotEmpty() }

        if (segments.isEmpty() || segments[0] != "session") {
            return CommandResult(error = "Invalid path")
        }

        // New session
        if (segments.size >= 2 && segments[1] == "new") {
            return handleNewSession(body)
        }

        // Existing session commands
        if (segments.size < 2) {
            return CommandResult(error = "Missing session ID")
        }

        val sessionId = segments[1]
        val session = sessions[sessionId]
            ?: return CommandResult(error = "Session not found")

        if (segments.size < 3) {
            // DELETE session
            if (method == "DELETE") {
                return handleClose(session)
            }
            return CommandResult(error = "Missing command")
        }

        val command = segments[2]

        return when (command) {
            "element" -> {
                if (segments.size >= 5) {
                    // Element action: /session/{id}/element/{elementId}/{action}
                    val elementId = segments[3]
                    val action = segments[4]
                    handleElementAction(session, elementId, action, segments.drop(5), body)
                } else {
                    handleFindElement(session, body)
                }
            }
            "elements" -> handleFindElements(session, body)
            "screenshot" -> handleScreenshot(session)
            "actions" -> handleActions(session, body)
            else -> CommandResult(error = "Unknown command: $command")
        }
    }

    // Session Management

    private fun handleNewSession(body: JsonObject?): CommandResult {
        val capabilities = body?.getAsJsonObject("capabilities")
            ?.getAsJsonObject("alwaysMatch")
            ?: return CommandResult(error = "Missing capabilities")

        val packageName = capabilities.get("appPackage")?.asString
            ?: return CommandResult(error = "Missing appPackage")

        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        val sessionId = "session-${++sessionCounter}"
        val session = Session(sessionId, device, packageName)

        // Launch the app
        val context = InstrumentationRegistry.getInstrumentation().context
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            device.wait(Until.hasObject(By.pkg(packageName).depth(0)), 10000)
        }

        sessions[sessionId] = session
        return CommandResult(sessionId = sessionId, success = true)
    }

    private fun handleClose(session: Session): CommandResult {
        session.clearElements()
        sessions.remove(session.id)
        return CommandResult(success = true)
    }

    // Element Finding

    private fun handleFindElement(session: Session, body: JsonObject?): CommandResult {
        val strategy = body?.get("using")?.asString
            ?: return CommandResult(error = "Missing strategy")
        val value = body.get("value")?.asString
            ?: return CommandResult(error = "Missing value")

        val element = findElement(session.device, strategy, value)
            ?: return CommandResult(elementId = null)

        val elementId = session.storeElement(element)
        return CommandResult(elementId = elementId)
    }

    private fun handleFindElements(session: Session, body: JsonObject?): CommandResult {
        val strategy = body?.get("using")?.asString
            ?: return CommandResult(error = "Missing strategy")
        val value = body.get("value")?.asString
            ?: return CommandResult(error = "Missing value")

        val elements = findElements(session.device, strategy, value)
        val elementIds = elements.map { session.storeElement(it) }

        return CommandResult(elements = elementIds)
    }

    private fun findElement(device: UiDevice, strategy: String, value: String): UiObject2? {
        val selector = buildSelector(strategy, value) ?: return null
        return try {
            device.findObject(selector)
        } catch (e: Exception) {
            null
        }
    }

    private fun findElements(device: UiDevice, strategy: String, value: String): List<UiObject2> {
        val selector = buildSelector(strategy, value) ?: return emptyList()
        return try {
            device.findObjects(selector)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun buildSelector(strategy: String, value: String): BySelector? {
        return when (strategy) {
            "accessibility id" -> By.desc(value)
            "id", "resource-id" -> By.res(value)
            "class name" -> By.clazz(value)
            "xpath" -> null // XPath not directly supported
            "-android uiautomator" -> {
                // Parse UiSelector syntax
                when {
                    value.contains(".text(") -> {
                        val text = extractStringArg(value, "text")
                        if (text != null) By.text(text) else null
                    }
                    value.contains(".textContains(") -> {
                        val text = extractStringArg(value, "textContains")
                        if (text != null) By.textContains(text) else null
                    }
                    value.contains(".resourceId(") -> {
                        val id = extractStringArg(value, "resourceId")
                        if (id != null) By.res(id) else null
                    }
                    value.contains(".className(") -> {
                        val cls = extractStringArg(value, "className")
                        if (cls != null) By.clazz(cls) else null
                    }
                    value.contains(".description(") -> {
                        val desc = extractStringArg(value, "description")
                        if (desc != null) By.desc(desc) else null
                    }
                    else -> null
                }
            }
            else -> null
        }
    }

    private fun extractStringArg(selector: String, method: String): String? {
        val pattern = Regex("""$method\("([^"]*)"\)""")
        return pattern.find(selector)?.groupValues?.getOrNull(1)
    }

    // Element Actions

    private fun handleElementAction(
        session: Session,
        elementId: String,
        action: String,
        extraSegments: List<String>,
        body: JsonObject?
    ): CommandResult {
        val element = session.getElement(elementId)
            ?: return CommandResult(error = "Element not found")

        return when (action) {
            "click" -> {
                element.click()
                CommandResult(success = true)
            }
            "clear" -> {
                element.clear()
                CommandResult(success = true)
            }
            "value" -> {
                val text = body?.get("text")?.asString ?: ""
                element.text = text
                CommandResult(success = true)
            }
            "text" -> {
                CommandResult(value = element.text ?: "")
            }
            "displayed" -> {
                CommandResult(value = element.isEnabled)
            }
            "enabled" -> {
                CommandResult(value = element.isEnabled)
            }
            "rect" -> {
                val bounds = element.visibleBounds
                CommandResult(value = mapOf(
                    "x" to bounds.left,
                    "y" to bounds.top,
                    "width" to bounds.width(),
                    "height" to bounds.height()
                ))
            }
            "attribute" -> {
                val attrName = extraSegments.firstOrNull() ?: ""
                val attrValue = when (attrName) {
                    "text" -> element.text
                    "content-desc" -> element.contentDescription
                    "class" -> element.className
                    "resource-id" -> element.resourceName
                    "enabled" -> element.isEnabled.toString()
                    "clickable" -> element.isClickable.toString()
                    "focusable" -> element.isFocusable.toString()
                    "scrollable" -> element.isScrollable.toString()
                    else -> null
                }
                CommandResult(value = attrValue)
            }
            "screenshot" -> {
                // Element screenshot not directly supported, use full screenshot
                handleScreenshot(session)
            }
            else -> CommandResult(error = "Unknown action: $action")
        }
    }

    // Touch Actions (W3C Actions API)

    private fun handleActions(session: Session, body: JsonObject?): CommandResult {
        val actionsArray = body?.getAsJsonArray("actions")
            ?: return CommandResult(error = "Missing actions")

        try {
            for (actionSequence in actionsArray) {
                val sequence = actionSequence.asJsonObject
                val type = sequence.get("type")?.asString ?: continue
                val actions = sequence.getAsJsonArray("actions") ?: continue

                if (type == "pointer") {
                    executePointerActions(session.device, actions)
                }
            }
            return CommandResult(success = true)
        } catch (e: Exception) {
            return CommandResult(error = "Action failed: ${e.message}")
        }
    }

    private fun executePointerActions(device: UiDevice, actions: com.google.gson.JsonArray) {
        var currentX = 0
        var currentY = 0
        var isDown = false

        for (action in actions) {
            val actionObj = action.asJsonObject
            val actionType = actionObj.get("type")?.asString ?: continue

            when (actionType) {
                "pointerMove" -> {
                    currentX = actionObj.get("x")?.asInt ?: currentX
                    currentY = actionObj.get("y")?.asInt ?: currentY

                    if (isDown) {
                        // Swipe in progress
                        val duration = actionObj.get("duration")?.asLong ?: 0
                        if (duration > 0) {
                            SystemClock.sleep(duration)
                        }
                    }
                }
                "pointerDown" -> {
                    isDown = true
                }
                "pointerUp" -> {
                    if (isDown) {
                        device.click(currentX, currentY)
                    }
                    isDown = false
                }
                "pause" -> {
                    val duration = actionObj.get("duration")?.asLong ?: 0
                    if (duration > 0) {
                        SystemClock.sleep(duration)
                    }
                }
            }
        }
    }

    // Screenshot

    private fun handleScreenshot(session: Session): CommandResult {
        return try {
            val bitmap = session.device.takeScreenshot()
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            val base64 = Base64.getEncoder().encodeToString(stream.toByteArray())
            CommandResult(value = base64)
        } catch (e: Exception) {
            CommandResult(error = "Screenshot failed: ${e.message}")
        }
    }
}
