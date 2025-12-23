package com.zylix

import android.animation.ValueAnimator
import android.content.Context
import android.view.Choreographer
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject
import kotlin.math.*

// ============================================================================
// Animation Types
// ============================================================================

/**
 * Playback state for animations.
 */
enum class ZylixPlaybackState(val value: Int) {
    STOPPED(0),
    PLAYING(1),
    PAUSED(2),
    FINISHED(3)
}

/**
 * Loop mode for animations.
 */
enum class ZylixLoopMode(val value: Int) {
    NONE(0),
    LOOP(1),
    PING_PONG(2),
    LOOP_COUNT(3)
}

/**
 * Play direction.
 */
enum class ZylixPlayDirection(val value: Int) {
    FORWARD(0),
    REVERSE(1)
}

/**
 * Animation event types.
 */
enum class ZylixAnimationEventType(val value: Int) {
    STARTED(0),
    PAUSED(1),
    RESUMED(2),
    STOPPED(3),
    COMPLETED(4),
    LOOP_COMPLETED(5),
    FRAME_CHANGED(6),
    MARKER_REACHED(7)
}

/**
 * Animation event data.
 */
data class ZylixAnimationEvent(
    val eventType: ZylixAnimationEventType,
    val animationId: UInt = 0u,
    val currentFrame: UInt = 0u,
    val currentTime: Long = 0L,
    val loopCount: UInt = 0u,
    val markerName: String? = null
)

/**
 * Animation error types.
 */
sealed class ZylixAnimationError : Exception() {
    data object InvalidData : ZylixAnimationError()
    data class ParseError(override val message: String) : ZylixAnimationError()
    data class RenderError(override val message: String) : ZylixAnimationError()
    data class ResourceNotFound(val name: String) : ZylixAnimationError()
    data object UnsupportedFormat : ZylixAnimationError()
    data object NotInitialized : ZylixAnimationError()
}

// ============================================================================
// Easing Functions
// ============================================================================

/**
 * Standard easing functions.
 */
object ZylixEasing {

    // Linear
    fun linear(t: Float): Float = t

    // Quadratic
    fun easeInQuad(t: Float): Float = t * t
    fun easeOutQuad(t: Float): Float = t * (2 - t)
    fun easeInOutQuad(t: Float): Float =
        if (t < 0.5f) 2 * t * t else -1 + (4 - 2 * t) * t

    // Cubic
    fun easeInCubic(t: Float): Float = t * t * t
    fun easeOutCubic(t: Float): Float {
        val f = t - 1
        return f * f * f + 1
    }
    fun easeInOutCubic(t: Float): Float =
        if (t < 0.5f) 4 * t * t * t
        else {
            val f = 2 * t - 2
            0.5f * f * f * f + 1
        }

    // Quartic
    fun easeInQuart(t: Float): Float = t * t * t * t
    fun easeOutQuart(t: Float): Float {
        val f = t - 1
        return 1 - f * f * f * f
    }
    fun easeInOutQuart(t: Float): Float =
        if (t < 0.5f) 8 * t * t * t * t
        else {
            val f = t - 1
            1 - 8 * f * f * f * f
        }

    // Sinusoidal
    fun easeInSine(t: Float): Float = 1 - cos(t * PI.toFloat() / 2)
    fun easeOutSine(t: Float): Float = sin(t * PI.toFloat() / 2)
    fun easeInOutSine(t: Float): Float = 0.5f * (1 - cos(PI.toFloat() * t))

    // Exponential
    fun easeInExpo(t: Float): Float = if (t == 0f) 0f else 2f.pow(10 * (t - 1))
    fun easeOutExpo(t: Float): Float = if (t == 1f) 1f else 1 - 2f.pow(-10 * t)
    fun easeInOutExpo(t: Float): Float = when {
        t == 0f -> 0f
        t == 1f -> 1f
        t < 0.5f -> 0.5f * 2f.pow(20 * t - 10)
        else -> 1 - 0.5f * 2f.pow(-20 * t + 10)
    }

    // Elastic
    private val ELASTIC_C4 = (2 * PI / 3).toFloat()

    fun easeInElastic(t: Float): Float = when {
        t == 0f -> 0f
        t == 1f -> 1f
        else -> -2f.pow(10 * t - 10) * sin((t * 10 - 10.75f) * ELASTIC_C4)
    }

    fun easeOutElastic(t: Float): Float = when {
        t == 0f -> 0f
        t == 1f -> 1f
        else -> 2f.pow(-10 * t) * sin((t * 10 - 0.75f) * ELASTIC_C4) + 1
    }

    // Bounce
    private const val BOUNCE_N1 = 7.5625f
    private const val BOUNCE_D1 = 2.75f

    fun easeOutBounce(t: Float): Float {
        var t1 = t
        return when {
            t1 < 1 / BOUNCE_D1 -> BOUNCE_N1 * t1 * t1
            t1 < 2 / BOUNCE_D1 -> {
                t1 -= 1.5f / BOUNCE_D1
                BOUNCE_N1 * t1 * t1 + 0.75f
            }
            t1 < 2.5f / BOUNCE_D1 -> {
                t1 -= 2.25f / BOUNCE_D1
                BOUNCE_N1 * t1 * t1 + 0.9375f
            }
            else -> {
                t1 -= 2.625f / BOUNCE_D1
                BOUNCE_N1 * t1 * t1 + 0.984375f
            }
        }
    }

    fun easeInBounce(t: Float): Float = 1 - easeOutBounce(1 - t)

    // Spring
    fun spring(
        t: Float,
        stiffness: Float = 100f,
        damping: Float = 10f,
        mass: Float = 1f
    ): Float {
        val omega = sqrt(stiffness / mass)
        val zeta = damping / (2 * sqrt(stiffness * mass))

        return if (zeta < 1) {
            // Underdamped
            val omegaD = omega * sqrt(1 - zeta * zeta)
            val decay = exp(-zeta * omega * t)
            1 - decay * (cos(omegaD * t) + (zeta * omega / omegaD) * sin(omegaD * t))
        } else {
            // Critically damped or overdamped
            val decay = exp(-omega * t)
            1 - decay * (1 + omega * t)
        }
    }
}

// ============================================================================
// Timeline Animation
// ============================================================================

/**
 * Animation timeline for sequencing animations.
 */
class ZylixTimeline {

    private val _state = MutableStateFlow(ZylixPlaybackState.STOPPED)
    val state: StateFlow<ZylixPlaybackState> = _state.asStateFlow()

    private val _currentTime = MutableStateFlow(0.0)
    val currentTime: StateFlow<Double> = _currentTime.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    var duration: Double = 0.0
    var speed: Float = 1.0f
    var loopMode: ZylixLoopMode = ZylixLoopMode.NONE
    var loopCount: UInt = 0u

    private var lastFrameTime: Long = 0
    private var currentLoop: UInt = 0u
    private var direction: ZylixPlayDirection = ZylixPlayDirection.FORWARD
    private var frameCallback: Choreographer.FrameCallback? = null
    private val eventCallbacks = mutableListOf<(ZylixAnimationEvent) -> Unit>()

    // Playback control

    fun play() {
        if (_state.value == ZylixPlaybackState.PAUSED) {
            _state.value = ZylixPlaybackState.PLAYING
            startFrameCallback()
            emitEvent(ZylixAnimationEventType.RESUMED)
        } else {
            _state.value = ZylixPlaybackState.PLAYING
            _currentTime.value = 0.0
            currentLoop = 0u
            startFrameCallback()
            emitEvent(ZylixAnimationEventType.STARTED)
        }
    }

    fun pause() {
        if (_state.value != ZylixPlaybackState.PLAYING) return
        _state.value = ZylixPlaybackState.PAUSED
        stopFrameCallback()
        emitEvent(ZylixAnimationEventType.PAUSED)
    }

    fun stop() {
        _state.value = ZylixPlaybackState.STOPPED
        _currentTime.value = 0.0
        _progress.value = 0f
        currentLoop = 0u
        stopFrameCallback()
        emitEvent(ZylixAnimationEventType.STOPPED)
    }

    fun seek(time: Double) {
        _currentTime.value = maxOf(0.0, minOf(time, duration))
        updateProgress()
    }

    fun seekToProgress(p: Float) {
        seek(p.toDouble() * duration)
    }

    // Event handling

    fun onEvent(callback: (ZylixAnimationEvent) -> Unit) {
        synchronized(eventCallbacks) {
            eventCallbacks.add(callback)
        }
    }

    fun removeEventCallback(callback: (ZylixAnimationEvent) -> Unit) {
        synchronized(eventCallbacks) {
            eventCallbacks.remove(callback)
        }
    }

    fun clearEventCallbacks() {
        synchronized(eventCallbacks) {
            eventCallbacks.clear()
        }
    }

    // Private methods

    private fun startFrameCallback() {
        lastFrameTime = 0
        frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (_state.value != ZylixPlaybackState.PLAYING) return

                val frameTimeMs = frameTimeNanos / 1_000_000
                if (lastFrameTime == 0L) {
                    lastFrameTime = frameTimeMs
                    Choreographer.getInstance().postFrameCallback(this)
                    return
                }

                val delta = (frameTimeMs - lastFrameTime) * speed / 1000.0
                lastFrameTime = frameTimeMs

                // Update current time
                _currentTime.value = if (direction == ZylixPlayDirection.FORWARD) {
                    _currentTime.value + delta
                } else {
                    _currentTime.value - delta
                }

                // Handle end of timeline
                if (_currentTime.value >= duration) {
                    when (loopMode) {
                        ZylixLoopMode.NONE -> {
                            _currentTime.value = duration
                            _state.value = ZylixPlaybackState.FINISHED
                            emitEvent(ZylixAnimationEventType.COMPLETED)
                            return
                        }
                        ZylixLoopMode.LOOP -> {
                            _currentTime.value = _currentTime.value % duration
                            currentLoop++
                            emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                        }
                        ZylixLoopMode.PING_PONG -> {
                            direction = if (direction == ZylixPlayDirection.FORWARD)
                                ZylixPlayDirection.REVERSE else ZylixPlayDirection.FORWARD
                            _currentTime.value = duration
                            currentLoop++
                            emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                        }
                        ZylixLoopMode.LOOP_COUNT -> {
                            currentLoop++
                            if (currentLoop >= loopCount) {
                                _currentTime.value = duration
                                _state.value = ZylixPlaybackState.FINISHED
                                emitEvent(ZylixAnimationEventType.COMPLETED)
                                return
                            } else {
                                _currentTime.value = 0.0
                                emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                            }
                        }
                    }
                } else if (_currentTime.value < 0) {
                    if (loopMode == ZylixLoopMode.PING_PONG) {
                        direction = ZylixPlayDirection.FORWARD
                        _currentTime.value = 0.0
                    } else {
                        _currentTime.value = 0.0
                    }
                }

                updateProgress()
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
        Choreographer.getInstance().postFrameCallback(frameCallback!!)
    }

    private fun stopFrameCallback() {
        frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameCallback = null
    }

    private fun updateProgress() {
        _progress.value = if (duration > 0) (_currentTime.value / duration).toFloat() else 0f
    }

    private fun emitEvent(type: ZylixAnimationEventType, markerName: String? = null) {
        val event = ZylixAnimationEvent(
            eventType = type,
            currentFrame = (_currentTime.value * 30).toUInt(),
            currentTime = (_currentTime.value * 1000).toLong(),
            loopCount = currentLoop,
            markerName = markerName
        )
        val callbacks = synchronized(eventCallbacks) { eventCallbacks.toList() }
        callbacks.forEach { it(event) }
    }
}

// ============================================================================
// Lottie Animation
// ============================================================================

/**
 * Lottie marker.
 */
data class ZylixLottieMarker(
    val name: String,
    val time: Double,
    val duration: Double = 0.0
)

/**
 * Lottie animation wrapper.
 */
class ZylixLottieAnimation {

    private val _state = MutableStateFlow(ZylixPlaybackState.STOPPED)
    val state: StateFlow<ZylixPlaybackState> = _state.asStateFlow()

    private val _currentFrame = MutableStateFlow(0.0)
    val currentFrame: StateFlow<Double> = _currentFrame.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    // Metadata
    var name: String = ""
        private set
    var width: Float = 0f
        private set
    var height: Float = 0f
        private set
    var frameRate: Double = 30.0
        private set
    var startFrame: Double = 0.0
        private set
    var endFrame: Double = 0.0
        private set
    var markers: List<ZylixLottieMarker> = emptyList()
        private set

    // Playback settings
    var speed: Float = 1.0f
    var loopMode: ZylixLoopMode = ZylixLoopMode.NONE
    var loopCount: UInt = 0u

    private var lastFrameTime: Long = 0
    private var currentLoop: UInt = 0u
    private var direction: ZylixPlayDirection = ZylixPlayDirection.FORWARD
    private var frameCallback: Choreographer.FrameCallback? = null
    private val eventCallbacks = mutableListOf<(ZylixAnimationEvent) -> Unit>()

    val totalFrames: Double get() = endFrame - startFrame
    val duration: Double get() = totalFrames / frameRate

    // Loading

    @Throws(ZylixAnimationError::class)
    fun load(jsonString: String) {
        try {
            val json = JSONObject(jsonString)
            load(json)
        } catch (e: Exception) {
            throw ZylixAnimationError.ParseError(e.message ?: "Invalid JSON")
        }
    }

    @Throws(ZylixAnimationError::class)
    fun load(json: JSONObject) {
        name = json.optString("nm", "")
        width = json.optDouble("w", 0.0).toFloat()
        height = json.optDouble("h", 0.0).toFloat()
        frameRate = json.optDouble("fr", 30.0)
        startFrame = json.optDouble("ip", 0.0)
        endFrame = json.optDouble("op", 0.0)

        // Parse markers
        val markersArray = json.optJSONArray("markers")
        markers = if (markersArray != null) {
            (0 until markersArray.length()).mapNotNull { i ->
                val marker = markersArray.optJSONObject(i) ?: return@mapNotNull null
                ZylixLottieMarker(
                    name = marker.optString("cm", ""),
                    time = marker.optDouble("tm", 0.0),
                    duration = marker.optDouble("dr", 0.0)
                )
            }
        } else {
            emptyList()
        }

        _currentFrame.value = startFrame
    }

    @Throws(ZylixAnimationError::class)
    fun load(context: Context, assetName: String) {
        try {
            val jsonString = context.assets.open(assetName).bufferedReader().use { it.readText() }
            load(jsonString)
        } catch (e: Exception) {
            throw ZylixAnimationError.ResourceNotFound(assetName)
        }
    }

    // Playback control

    fun play() {
        if (_state.value == ZylixPlaybackState.PAUSED) {
            _state.value = ZylixPlaybackState.PLAYING
            startFrameCallback()
            emitEvent(ZylixAnimationEventType.RESUMED)
        } else {
            _state.value = ZylixPlaybackState.PLAYING
            _currentFrame.value = startFrame
            currentLoop = 0u
            startFrameCallback()
            emitEvent(ZylixAnimationEventType.STARTED)
        }
    }

    fun pause() {
        if (_state.value != ZylixPlaybackState.PLAYING) return
        _state.value = ZylixPlaybackState.PAUSED
        stopFrameCallback()
        emitEvent(ZylixAnimationEventType.PAUSED)
    }

    fun stop() {
        _state.value = ZylixPlaybackState.STOPPED
        _currentFrame.value = startFrame
        _progress.value = 0f
        currentLoop = 0u
        stopFrameCallback()
        emitEvent(ZylixAnimationEventType.STOPPED)
    }

    fun seek(frame: Double) {
        _currentFrame.value = maxOf(startFrame, minOf(frame, endFrame))
        updateProgress()
        emitEvent(ZylixAnimationEventType.FRAME_CHANGED)
    }

    fun seekToProgress(p: Float) {
        val frame = startFrame + p * totalFrames
        seek(frame)
    }

    fun seekToMarker(name: String): Boolean {
        val marker = markers.find { it.name == name } ?: return false
        seek(marker.time)
        emitEvent(ZylixAnimationEventType.MARKER_REACHED, name)
        return true
    }

    // Event handling

    fun onEvent(callback: (ZylixAnimationEvent) -> Unit) {
        synchronized(eventCallbacks) {
            eventCallbacks.add(callback)
        }
    }

    fun removeEventCallback(callback: (ZylixAnimationEvent) -> Unit) {
        synchronized(eventCallbacks) {
            eventCallbacks.remove(callback)
        }
    }

    fun clearEventCallbacks() {
        synchronized(eventCallbacks) {
            eventCallbacks.clear()
        }
    }

    // Private methods

    private fun startFrameCallback() {
        lastFrameTime = 0
        frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (_state.value != ZylixPlaybackState.PLAYING) return

                val frameTimeMs = frameTimeNanos / 1_000_000
                if (lastFrameTime == 0L) {
                    lastFrameTime = frameTimeMs
                    Choreographer.getInstance().postFrameCallback(this)
                    return
                }

                val deltaMs = frameTimeMs - lastFrameTime
                lastFrameTime = frameTimeMs

                // Calculate frame delta
                val frameDelta = (deltaMs / 1000.0) * frameRate * speed

                // Update current frame
                _currentFrame.value = if (direction == ZylixPlayDirection.FORWARD) {
                    _currentFrame.value + frameDelta
                } else {
                    _currentFrame.value - frameDelta
                }

                // Handle end of animation
                if (_currentFrame.value >= endFrame) {
                    when (loopMode) {
                        ZylixLoopMode.NONE -> {
                            _currentFrame.value = endFrame
                            _state.value = ZylixPlaybackState.FINISHED
                            emitEvent(ZylixAnimationEventType.COMPLETED)
                            return
                        }
                        ZylixLoopMode.LOOP -> {
                            _currentFrame.value = startFrame + (_currentFrame.value - startFrame) % totalFrames
                            currentLoop++
                            emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                        }
                        ZylixLoopMode.PING_PONG -> {
                            direction = if (direction == ZylixPlayDirection.FORWARD)
                                ZylixPlayDirection.REVERSE else ZylixPlayDirection.FORWARD
                            _currentFrame.value = endFrame
                            currentLoop++
                            emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                        }
                        ZylixLoopMode.LOOP_COUNT -> {
                            currentLoop++
                            if (currentLoop >= loopCount) {
                                _currentFrame.value = endFrame
                                _state.value = ZylixPlaybackState.FINISHED
                                emitEvent(ZylixAnimationEventType.COMPLETED)
                                return
                            } else {
                                _currentFrame.value = startFrame
                                emitEvent(ZylixAnimationEventType.LOOP_COMPLETED)
                            }
                        }
                    }
                } else if (_currentFrame.value < startFrame) {
                    if (loopMode == ZylixLoopMode.PING_PONG) {
                        direction = ZylixPlayDirection.FORWARD
                        _currentFrame.value = startFrame
                    } else {
                        _currentFrame.value = startFrame
                    }
                }

                updateProgress()
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
        Choreographer.getInstance().postFrameCallback(frameCallback!!)
    }

    private fun stopFrameCallback() {
        frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameCallback = null
    }

    private fun updateProgress() {
        _progress.value = if (totalFrames > 0) ((_currentFrame.value - startFrame) / totalFrames).toFloat() else 0f
    }

    private fun emitEvent(type: ZylixAnimationEventType, markerName: String? = null) {
        val event = ZylixAnimationEvent(
            eventType = type,
            currentFrame = _currentFrame.value.toUInt(),
            currentTime = (_currentFrame.value / frameRate * 1000).toLong(),
            loopCount = currentLoop,
            markerName = markerName
        )
        val callbacks = synchronized(eventCallbacks) { eventCallbacks.toList() }
        callbacks.forEach { it(event) }
    }
}

// ============================================================================
// Animation Manager
// ============================================================================

/**
 * Global animation manager singleton.
 */
object ZylixAnimationManager {

    private val lottieAnimations = java.util.concurrent.ConcurrentHashMap<UInt, ZylixLottieAnimation>()
    private val timelines = java.util.concurrent.ConcurrentHashMap<UInt, ZylixTimeline>()
    private val nextIdAtomic = java.util.concurrent.atomic.AtomicInteger(1)

    private val nextId: UInt
        get() = nextIdAtomic.getAndIncrement().toUInt()

    // Lottie management

    fun createLottie(): UInt {
        val id = nextId
        lottieAnimations[id] = ZylixLottieAnimation()
        return id
    }

    fun getLottie(id: UInt): ZylixLottieAnimation? = lottieAnimations[id]

    @Throws(ZylixAnimationError::class)
    fun loadLottie(jsonString: String): UInt {
        val id = createLottie()
        lottieAnimations[id]?.load(jsonString) ?: throw ZylixAnimationError.NotInitialized
        return id
    }

    @Throws(ZylixAnimationError::class)
    fun loadLottie(context: Context, assetName: String): UInt {
        val id = createLottie()
        lottieAnimations[id]?.load(context, assetName) ?: throw ZylixAnimationError.NotInitialized
        return id
    }

    fun destroyLottie(id: UInt) {
        lottieAnimations[id]?.stop()
        lottieAnimations.remove(id)
    }

    // Timeline management

    fun createTimeline(): UInt {
        val id = nextId
        timelines[id] = ZylixTimeline()
        return id
    }

    fun getTimeline(id: UInt): ZylixTimeline? = timelines[id]

    fun destroyTimeline(id: UInt) {
        timelines[id]?.stop()
        timelines.remove(id)
    }

    // Global control

    fun pauseAll() {
        lottieAnimations.values.forEach { it.pause() }
        timelines.values.forEach { it.pause() }
    }

    fun resumeAll() {
        lottieAnimations.values.filter { it.state.value == ZylixPlaybackState.PAUSED }.forEach { it.play() }
        timelines.values.filter { it.state.value == ZylixPlaybackState.PAUSED }.forEach { it.play() }
    }

    fun stopAll() {
        lottieAnimations.values.forEach { it.stop() }
        timelines.values.forEach { it.stop() }
    }
}

// ============================================================================
// Compose UI Components
// ============================================================================

/**
 * Lottie animation view for Compose.
 */
@Composable
fun ZylixLottieView(
    animation: ZylixLottieAnimation,
    modifier: Modifier = Modifier
) {
    val state by animation.state.collectAsState()
    val currentFrame by animation.currentFrame.collectAsState()
    val progress by animation.progress.collectAsState()

    Card(
        modifier = modifier.padding(16.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = animation.name.ifEmpty { "Lottie Animation" },
                style = MaterialTheme.typography.titleMedium
            )

            Text(
                text = "Frame: ${currentFrame.toInt()} / ${animation.endFrame.toInt()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth()
            )

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(
                    onClick = { animation.play() },
                    enabled = state != ZylixPlaybackState.PLAYING
                ) {
                    Text("▶")
                }

                IconButton(
                    onClick = { animation.pause() },
                    enabled = state == ZylixPlaybackState.PLAYING
                ) {
                    Text("⏸")
                }

                IconButton(onClick = { animation.stop() }) {
                    Text("⏹")
                }
            }
        }
    }
}

/**
 * Timeline view for Compose.
 */
@Composable
fun ZylixTimelineView(
    timeline: ZylixTimeline,
    modifier: Modifier = Modifier
) {
    val state by timeline.state.collectAsState()
    val currentTime by timeline.currentTime.collectAsState()
    val progress by timeline.progress.collectAsState()

    Column(
        modifier = modifier.padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth()
        )

        Text(
            text = String.format("%.2fs / %.2fs", currentTime, timeline.duration),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            IconButton(
                onClick = { timeline.play() },
                enabled = state != ZylixPlaybackState.PLAYING
            ) {
                Text("▶")
            }

            IconButton(
                onClick = { timeline.pause() },
                enabled = state == ZylixPlaybackState.PLAYING
            ) {
                Text("⏸")
            }

            IconButton(onClick = { timeline.stop() }) {
                Text("⏹")
            }
        }
    }
}

// ============================================================================
// Compose Modifiers
// ============================================================================

/**
 * Apply animated opacity.
 */
fun Modifier.zylixAnimatedOpacity(progress: Float, from: Float = 0f, to: Float = 1f): Modifier {
    val alpha = from + progress * (to - from)
    return this.alpha(alpha)
}

/**
 * Apply animated scale.
 */
fun Modifier.zylixAnimatedScale(progress: Float, from: Float = 0.5f, to: Float = 1f): Modifier {
    val scale = from + progress * (to - from)
    return this.scale(scale)
}

/**
 * Apply animated rotation.
 */
fun Modifier.zylixAnimatedRotation(progress: Float, from: Float = 0f, to: Float = 360f): Modifier {
    val rotation = from + progress * (to - from)
    return this.rotate(rotation)
}

/**
 * Apply animated offset.
 */
fun Modifier.zylixAnimatedOffset(
    progress: Float,
    fromX: Float = 0f, fromY: Float = 0f,
    toX: Float = 0f, toY: Float = 0f
): Modifier {
    val x = fromX + progress * (toX - fromX)
    val y = fromY + progress * (toY - fromY)
    return this.graphicsLayer {
        translationX = x
        translationY = y
    }
}
