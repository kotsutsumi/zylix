package com.zylix

import android.view.MotionEvent
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateRotation
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.changedToUp
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

// ============================================================================
// Gesture Types
// ============================================================================

/**
 * 2D point with coordinates
 */
data class ZylixPoint(
    val x: Float,
    val y: Float
) {
    fun toOffset(): Offset = Offset(x, y)

    companion object {
        val Zero = ZylixPoint(0f, 0f)

        fun fromOffset(offset: Offset) = ZylixPoint(offset.x, offset.y)
    }
}

/**
 * Gesture state enum matching Zig core
 */
enum class ZylixGestureState {
    POSSIBLE,
    BEGAN,
    CHANGED,
    ENDED,
    CANCELLED,
    FAILED
}

/**
 * Swipe direction enum
 */
enum class ZylixSwipeDirection {
    UP,
    DOWN,
    LEFT,
    RIGHT
}

/**
 * Edge for edge pan gestures
 */
enum class ZylixEdge {
    LEFT,
    RIGHT,
    TOP,
    BOTTOM
}

/**
 * Velocity data for gesture tracking
 */
data class ZylixVelocity(
    val x: Float,
    val y: Float
) {
    val magnitude: Float
        get() = sqrt(x * x + y * y)

    companion object {
        val Zero = ZylixVelocity(0f, 0f)
    }
}

/**
 * Transform data for pinch/rotation gestures
 */
data class ZylixTransform(
    val scale: Float = 1f,
    val rotation: Float = 0f,
    val translation: ZylixPoint = ZylixPoint.Zero
) {
    companion object {
        val Identity = ZylixTransform()
    }
}

// ============================================================================
// Touch Data
// ============================================================================

/**
 * Individual touch point data
 */
data class ZylixTouch(
    val id: Long,
    val position: ZylixPoint,
    val previousPosition: ZylixPoint,
    val pressure: Float = 1f,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Touch event with all active touches
 */
data class ZylixTouchEvent(
    val touches: List<ZylixTouch>,
    val state: ZylixGestureState,
    val timestamp: Long = System.currentTimeMillis()
) {
    val touchCount: Int get() = touches.size
    val firstTouch: ZylixTouch? get() = touches.firstOrNull()
}

// ============================================================================
// Gesture Recognizer Results
// ============================================================================

/**
 * Tap gesture result
 */
data class ZylixTapResult(
    val position: ZylixPoint,
    val tapCount: Int = 1
)

/**
 * Long press gesture result
 */
data class ZylixLongPressResult(
    val position: ZylixPoint,
    val state: ZylixGestureState,
    val duration: Long = 0
)

/**
 * Pan/Drag gesture result
 */
data class ZylixPanResult(
    val startPosition: ZylixPoint,
    val currentPosition: ZylixPoint,
    val translation: ZylixPoint,
    val velocity: ZylixVelocity,
    val state: ZylixGestureState
)

/**
 * Swipe gesture result
 */
data class ZylixSwipeResult(
    val direction: ZylixSwipeDirection,
    val velocity: ZylixVelocity,
    val startPosition: ZylixPoint,
    val endPosition: ZylixPoint
)

/**
 * Pinch gesture result
 */
data class ZylixPinchResult(
    val scale: Float,
    val center: ZylixPoint,
    val velocity: Float,
    val state: ZylixGestureState
)

/**
 * Rotation gesture result
 */
data class ZylixRotationResult(
    val angle: Float,
    val center: ZylixPoint,
    val velocity: Float,
    val state: ZylixGestureState
)

/**
 * Edge pan gesture result
 */
data class ZylixEdgePanResult(
    val edge: ZylixEdge,
    val progress: Float,
    val translation: ZylixPoint,
    val state: ZylixGestureState
)

// ============================================================================
// Gesture Recognizers
// ============================================================================

/**
 * Tap gesture recognizer
 */
class ZylixTapRecognizer(
    val requiredTaps: Int = 1,
    val requiredTouches: Int = 1,
    val maxTapDistance: Float = 20f
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var onTapCallback: ((ZylixTapResult) -> Unit)? = null

    fun onTap(callback: (ZylixTapResult) -> Unit) {
        onTapCallback = callback
    }

    internal fun handleTap(position: Offset, tapCount: Int = 1) {
        if (tapCount == requiredTaps) {
            _state.value = ZylixGestureState.ENDED
            onTapCallback?.invoke(ZylixTapResult(ZylixPoint.fromOffset(position), tapCount))
            _state.value = ZylixGestureState.POSSIBLE
        }
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
    }
}

/**
 * Long press gesture recognizer
 */
class ZylixLongPressRecognizer(
    val minimumDuration: Long = 500, // milliseconds
    val maximumDistance: Float = 10f,
    val requiredTouches: Int = 1
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var startTime: Long = 0
    private var startPosition: ZylixPoint = ZylixPoint.Zero

    private var onLongPressCallback: ((ZylixLongPressResult) -> Unit)? = null

    fun onLongPress(callback: (ZylixLongPressResult) -> Unit) {
        onLongPressCallback = callback
    }

    internal fun handleLongPressStart(position: Offset) {
        startTime = System.currentTimeMillis()
        startPosition = ZylixPoint.fromOffset(position)
        _state.value = ZylixGestureState.BEGAN
        onLongPressCallback?.invoke(
            ZylixLongPressResult(startPosition, ZylixGestureState.BEGAN, 0)
        )
    }

    internal fun handleLongPressEnd(position: Offset) {
        val duration = System.currentTimeMillis() - startTime
        _state.value = ZylixGestureState.ENDED
        onLongPressCallback?.invoke(
            ZylixLongPressResult(ZylixPoint.fromOffset(position), ZylixGestureState.ENDED, duration)
        )
        reset()
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        startTime = 0
    }
}

/**
 * Pan (drag) gesture recognizer
 */
class ZylixPanRecognizer(
    val minimumDistance: Float = 10f,
    val requiredTouches: Int = 1
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var startPosition: ZylixPoint = ZylixPoint.Zero
    private var currentPosition: ZylixPoint = ZylixPoint.Zero
    private var lastTimestamp: Long = 0
    private var velocity: ZylixVelocity = ZylixVelocity.Zero

    private var onPanCallback: ((ZylixPanResult) -> Unit)? = null

    fun onPan(callback: (ZylixPanResult) -> Unit) {
        onPanCallback = callback
    }

    internal fun handleDragStart(position: Offset) {
        startPosition = ZylixPoint.fromOffset(position)
        currentPosition = startPosition
        lastTimestamp = System.currentTimeMillis()
        velocity = ZylixVelocity.Zero
        _state.value = ZylixGestureState.BEGAN
        notifyCallback(ZylixGestureState.BEGAN)
    }

    internal fun handleDrag(change: Offset, amount: Offset) {
        val now = System.currentTimeMillis()
        val dt = (now - lastTimestamp).coerceAtLeast(1) / 1000f

        currentPosition = ZylixPoint.fromOffset(change)
        velocity = ZylixVelocity(amount.x / dt, amount.y / dt)
        lastTimestamp = now

        _state.value = ZylixGestureState.CHANGED
        notifyCallback(ZylixGestureState.CHANGED)
    }

    internal fun handleDragEnd() {
        _state.value = ZylixGestureState.ENDED
        notifyCallback(ZylixGestureState.ENDED)
        reset()
    }

    internal fun handleDragCancel() {
        _state.value = ZylixGestureState.CANCELLED
        notifyCallback(ZylixGestureState.CANCELLED)
        reset()
    }

    private fun notifyCallback(state: ZylixGestureState) {
        val translation = ZylixPoint(
            currentPosition.x - startPosition.x,
            currentPosition.y - startPosition.y
        )
        onPanCallback?.invoke(
            ZylixPanResult(startPosition, currentPosition, translation, velocity, state)
        )
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        startPosition = ZylixPoint.Zero
        currentPosition = ZylixPoint.Zero
        velocity = ZylixVelocity.Zero
    }
}

/**
 * Swipe gesture recognizer
 */
class ZylixSwipeRecognizer(
    val minimumVelocity: Float = 500f,
    val minimumDistance: Float = 50f,
    val directions: Set<ZylixSwipeDirection> = ZylixSwipeDirection.entries.toSet()
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var startPosition: ZylixPoint = ZylixPoint.Zero
    private var startTime: Long = 0

    private var onSwipeCallback: ((ZylixSwipeResult) -> Unit)? = null

    fun onSwipe(callback: (ZylixSwipeResult) -> Unit) {
        onSwipeCallback = callback
    }

    internal fun handleSwipeStart(position: Offset) {
        startPosition = ZylixPoint.fromOffset(position)
        startTime = System.currentTimeMillis()
        _state.value = ZylixGestureState.BEGAN
    }

    internal fun handleSwipeEnd(endPosition: Offset, velocity: Offset) {
        val end = ZylixPoint.fromOffset(endPosition)
        val dx = end.x - startPosition.x
        val dy = end.y - startPosition.y
        val distance = sqrt(dx * dx + dy * dy)
        val vel = ZylixVelocity(velocity.x, velocity.y)

        if (distance >= minimumDistance && vel.magnitude >= minimumVelocity) {
            val direction = determineDirection(dx, dy)
            if (direction != null && direction in directions) {
                _state.value = ZylixGestureState.ENDED
                onSwipeCallback?.invoke(
                    ZylixSwipeResult(direction, vel, startPosition, end)
                )
            } else {
                _state.value = ZylixGestureState.FAILED
            }
        } else {
            _state.value = ZylixGestureState.FAILED
        }

        reset()
    }

    private fun determineDirection(dx: Float, dy: Float): ZylixSwipeDirection? {
        val absDx = abs(dx)
        val absDy = abs(dy)

        return when {
            absDx > absDy -> if (dx > 0) ZylixSwipeDirection.RIGHT else ZylixSwipeDirection.LEFT
            absDy > absDx -> if (dy > 0) ZylixSwipeDirection.DOWN else ZylixSwipeDirection.UP
            else -> null
        }
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        startPosition = ZylixPoint.Zero
        startTime = 0
    }
}

/**
 * Pinch gesture recognizer
 */
class ZylixPinchRecognizer(
    val minimumScale: Float = 0.01f
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var currentScale: Float = 1f
    private var lastScale: Float = 1f
    private var lastTimestamp: Long = 0

    private var onPinchCallback: ((ZylixPinchResult) -> Unit)? = null

    fun onPinch(callback: (ZylixPinchResult) -> Unit) {
        onPinchCallback = callback
    }

    internal fun handlePinchStart() {
        currentScale = 1f
        lastScale = 1f
        lastTimestamp = System.currentTimeMillis()
        _state.value = ZylixGestureState.BEGAN
    }

    internal fun handlePinchChange(scale: Float, centroid: Offset) {
        val now = System.currentTimeMillis()
        val dt = (now - lastTimestamp).coerceAtLeast(1) / 1000f

        currentScale *= scale
        val velocity = (currentScale - lastScale) / dt
        lastScale = currentScale
        lastTimestamp = now

        _state.value = ZylixGestureState.CHANGED
        onPinchCallback?.invoke(
            ZylixPinchResult(currentScale, ZylixPoint.fromOffset(centroid), velocity, ZylixGestureState.CHANGED)
        )
    }

    internal fun handlePinchEnd(centroid: Offset) {
        _state.value = ZylixGestureState.ENDED
        onPinchCallback?.invoke(
            ZylixPinchResult(currentScale, ZylixPoint.fromOffset(centroid), 0f, ZylixGestureState.ENDED)
        )
        reset()
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        currentScale = 1f
        lastScale = 1f
    }
}

/**
 * Rotation gesture recognizer
 */
class ZylixRotationRecognizer(
    val minimumAngle: Float = 0.01f // radians
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var currentAngle: Float = 0f
    private var lastAngle: Float = 0f
    private var lastTimestamp: Long = 0

    private var onRotationCallback: ((ZylixRotationResult) -> Unit)? = null

    fun onRotation(callback: (ZylixRotationResult) -> Unit) {
        onRotationCallback = callback
    }

    internal fun handleRotationStart() {
        currentAngle = 0f
        lastAngle = 0f
        lastTimestamp = System.currentTimeMillis()
        _state.value = ZylixGestureState.BEGAN
    }

    internal fun handleRotationChange(rotation: Float, centroid: Offset) {
        val now = System.currentTimeMillis()
        val dt = (now - lastTimestamp).coerceAtLeast(1) / 1000f

        currentAngle += rotation
        val velocity = (currentAngle - lastAngle) / dt
        lastAngle = currentAngle
        lastTimestamp = now

        _state.value = ZylixGestureState.CHANGED
        onRotationCallback?.invoke(
            ZylixRotationResult(currentAngle, ZylixPoint.fromOffset(centroid), velocity, ZylixGestureState.CHANGED)
        )
    }

    internal fun handleRotationEnd(centroid: Offset) {
        _state.value = ZylixGestureState.ENDED
        onRotationCallback?.invoke(
            ZylixRotationResult(currentAngle, ZylixPoint.fromOffset(centroid), 0f, ZylixGestureState.ENDED)
        )
        reset()
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        currentAngle = 0f
        lastAngle = 0f
    }
}

/**
 * Edge pan gesture recognizer
 */
class ZylixEdgePanRecognizer(
    val edge: ZylixEdge,
    val edgeThreshold: Float = 30f,
    val minimumDistance: Float = 10f
) {
    private val _state = MutableStateFlow(ZylixGestureState.POSSIBLE)
    val state: StateFlow<ZylixGestureState> = _state.asStateFlow()

    private var startPosition: ZylixPoint = ZylixPoint.Zero
    private var currentPosition: ZylixPoint = ZylixPoint.Zero
    private var maxDimension: Float = 0f

    private var onEdgePanCallback: ((ZylixEdgePanResult) -> Unit)? = null

    fun onEdgePan(callback: (ZylixEdgePanResult) -> Unit) {
        onEdgePanCallback = callback
    }

    internal fun handleStart(position: Offset, screenWidth: Float, screenHeight: Float) {
        maxDimension = when (edge) {
            ZylixEdge.LEFT, ZylixEdge.RIGHT -> screenWidth
            ZylixEdge.TOP, ZylixEdge.BOTTOM -> screenHeight
        }

        val isOnEdge = when (edge) {
            ZylixEdge.LEFT -> position.x < edgeThreshold
            ZylixEdge.RIGHT -> position.x > screenWidth - edgeThreshold
            ZylixEdge.TOP -> position.y < edgeThreshold
            ZylixEdge.BOTTOM -> position.y > screenHeight - edgeThreshold
        }

        if (isOnEdge) {
            startPosition = ZylixPoint.fromOffset(position)
            currentPosition = startPosition
            _state.value = ZylixGestureState.BEGAN
            notifyCallback(ZylixGestureState.BEGAN)
        }
    }

    internal fun handleChange(position: Offset) {
        if (_state.value != ZylixGestureState.BEGAN && _state.value != ZylixGestureState.CHANGED) return

        currentPosition = ZylixPoint.fromOffset(position)
        _state.value = ZylixGestureState.CHANGED
        notifyCallback(ZylixGestureState.CHANGED)
    }

    internal fun handleEnd() {
        if (_state.value == ZylixGestureState.POSSIBLE) return

        _state.value = ZylixGestureState.ENDED
        notifyCallback(ZylixGestureState.ENDED)
        reset()
    }

    private fun notifyCallback(state: ZylixGestureState) {
        val translation = ZylixPoint(
            currentPosition.x - startPosition.x,
            currentPosition.y - startPosition.y
        )

        val progress = when (edge) {
            ZylixEdge.LEFT -> (currentPosition.x - startPosition.x) / maxDimension
            ZylixEdge.RIGHT -> (startPosition.x - currentPosition.x) / maxDimension
            ZylixEdge.TOP -> (currentPosition.y - startPosition.y) / maxDimension
            ZylixEdge.BOTTOM -> (startPosition.y - currentPosition.y) / maxDimension
        }.coerceIn(0f, 1f)

        onEdgePanCallback?.invoke(
            ZylixEdgePanResult(edge, progress, translation, state)
        )
    }

    fun reset() {
        _state.value = ZylixGestureState.POSSIBLE
        startPosition = ZylixPoint.Zero
        currentPosition = ZylixPoint.Zero
    }
}

// ============================================================================
// Gesture Manager
// ============================================================================

/**
 * Central manager for all gesture recognizers
 */
class ZylixGestureManager {
    private val tapRecognizers = mutableListOf<ZylixTapRecognizer>()
    private val longPressRecognizers = mutableListOf<ZylixLongPressRecognizer>()
    private val panRecognizers = mutableListOf<ZylixPanRecognizer>()
    private val swipeRecognizers = mutableListOf<ZylixSwipeRecognizer>()
    private val pinchRecognizers = mutableListOf<ZylixPinchRecognizer>()
    private val rotationRecognizers = mutableListOf<ZylixRotationRecognizer>()
    private val edgePanRecognizers = mutableListOf<ZylixEdgePanRecognizer>()

    fun addTapRecognizer(recognizer: ZylixTapRecognizer) {
        tapRecognizers.add(recognizer)
    }

    fun addLongPressRecognizer(recognizer: ZylixLongPressRecognizer) {
        longPressRecognizers.add(recognizer)
    }

    fun addPanRecognizer(recognizer: ZylixPanRecognizer) {
        panRecognizers.add(recognizer)
    }

    fun addSwipeRecognizer(recognizer: ZylixSwipeRecognizer) {
        swipeRecognizers.add(recognizer)
    }

    fun addPinchRecognizer(recognizer: ZylixPinchRecognizer) {
        pinchRecognizers.add(recognizer)
    }

    fun addRotationRecognizer(recognizer: ZylixRotationRecognizer) {
        rotationRecognizers.add(recognizer)
    }

    fun addEdgePanRecognizer(recognizer: ZylixEdgePanRecognizer) {
        edgePanRecognizers.add(recognizer)
    }

    fun removeRecognizer(recognizer: Any) {
        when (recognizer) {
            is ZylixTapRecognizer -> tapRecognizers.remove(recognizer)
            is ZylixLongPressRecognizer -> longPressRecognizers.remove(recognizer)
            is ZylixPanRecognizer -> panRecognizers.remove(recognizer)
            is ZylixSwipeRecognizer -> swipeRecognizers.remove(recognizer)
            is ZylixPinchRecognizer -> pinchRecognizers.remove(recognizer)
            is ZylixRotationRecognizer -> rotationRecognizers.remove(recognizer)
            is ZylixEdgePanRecognizer -> edgePanRecognizers.remove(recognizer)
        }
    }

    fun resetAll() {
        tapRecognizers.forEach { it.reset() }
        longPressRecognizers.forEach { it.reset() }
        panRecognizers.forEach { it.reset() }
        swipeRecognizers.forEach { it.reset() }
        pinchRecognizers.forEach { it.reset() }
        rotationRecognizers.forEach { it.reset() }
        edgePanRecognizers.forEach { it.reset() }
    }

    companion object {
        @Volatile
        private var instance: ZylixGestureManager? = null

        fun shared(): ZylixGestureManager {
            return instance ?: synchronized(this) {
                instance ?: ZylixGestureManager().also { instance = it }
            }
        }
    }
}

// ============================================================================
// Compose Modifier Extensions
// ============================================================================

/**
 * Detect tap gestures
 */
fun Modifier.zylixOnTap(
    tapCount: Int = 1,
    onTap: (ZylixPoint) -> Unit
): Modifier = this.pointerInput(tapCount) {
    detectTapGestures(
        onTap = { offset ->
            if (tapCount == 1) onTap(ZylixPoint.fromOffset(offset))
        },
        onDoubleTap = { offset ->
            if (tapCount == 2) onTap(ZylixPoint.fromOffset(offset))
        }
    )
}

/**
 * Detect long press gestures
 */
fun Modifier.zylixOnLongPress(
    onLongPress: (ZylixLongPressResult) -> Unit
): Modifier = this.pointerInput(Unit) {
    detectTapGestures(
        onLongPress = { offset ->
            onLongPress(
                ZylixLongPressResult(
                    ZylixPoint.fromOffset(offset),
                    ZylixGestureState.ENDED
                )
            )
        }
    )
}

/**
 * Detect drag/pan gestures
 */
fun Modifier.zylixOnDrag(
    onDragStart: ((ZylixPoint) -> Unit)? = null,
    onDrag: (ZylixPanResult) -> Unit,
    onDragEnd: ((ZylixPanResult) -> Unit)? = null
): Modifier {
    var startPos = Offset.Zero
    var currentPos = Offset.Zero
    var lastTime = 0L
    var velocity = Offset.Zero

    return this.pointerInput(Unit) {
        detectDragGestures(
            onDragStart = { offset ->
                startPos = offset
                currentPos = offset
                lastTime = System.currentTimeMillis()
                velocity = Offset.Zero
                onDragStart?.invoke(ZylixPoint.fromOffset(offset))
            },
            onDrag = { change, dragAmount ->
                val now = System.currentTimeMillis()
                val dt = (now - lastTime).coerceAtLeast(1) / 1000f

                currentPos = change.position
                velocity = Offset(dragAmount.x / dt, dragAmount.y / dt)
                lastTime = now

                val translation = ZylixPoint(
                    currentPos.x - startPos.x,
                    currentPos.y - startPos.y
                )

                onDrag(
                    ZylixPanResult(
                        ZylixPoint.fromOffset(startPos),
                        ZylixPoint.fromOffset(currentPos),
                        translation,
                        ZylixVelocity(velocity.x, velocity.y),
                        ZylixGestureState.CHANGED
                    )
                )
            },
            onDragEnd = {
                val translation = ZylixPoint(
                    currentPos.x - startPos.x,
                    currentPos.y - startPos.y
                )
                onDragEnd?.invoke(
                    ZylixPanResult(
                        ZylixPoint.fromOffset(startPos),
                        ZylixPoint.fromOffset(currentPos),
                        translation,
                        ZylixVelocity(velocity.x, velocity.y),
                        ZylixGestureState.ENDED
                    )
                )
            }
        )
    }
}

/**
 * Detect pinch (scale) gestures
 */
fun Modifier.zylixOnPinch(
    onPinch: (ZylixPinchResult) -> Unit
): Modifier = this.pointerInput(Unit) {
    var totalScale = 1f
    var lastScale = 1f
    var lastTime = 0L
    var hasStarted = false

    awaitEachGesture {
        do {
            val event = awaitPointerEvent()

            if (event.changes.size >= 2) {
                if (!hasStarted) {
                    hasStarted = true
                    totalScale = 1f
                    lastScale = 1f
                    lastTime = System.currentTimeMillis()
                }

                val zoomChange = event.calculateZoom()
                if (zoomChange != 1f) {
                    val now = System.currentTimeMillis()
                    val dt = (now - lastTime).coerceAtLeast(1) / 1000f

                    totalScale *= zoomChange
                    val velocity = (totalScale - lastScale) / dt
                    lastScale = totalScale
                    lastTime = now

                    val centroid = event.calculateCentroid(useCurrent = true)

                    onPinch(
                        ZylixPinchResult(
                            totalScale,
                            ZylixPoint.fromOffset(centroid),
                            velocity,
                            ZylixGestureState.CHANGED
                        )
                    )

                    event.changes.forEach { it.consume() }
                }
            } else if (hasStarted) {
                hasStarted = false
                onPinch(
                    ZylixPinchResult(
                        totalScale,
                        ZylixPoint.Zero,
                        0f,
                        ZylixGestureState.ENDED
                    )
                )
            }
        } while (event.changes.any { it.pressed })
    }
}

/**
 * Detect rotation gestures
 */
fun Modifier.zylixOnRotation(
    onRotation: (ZylixRotationResult) -> Unit
): Modifier = this.pointerInput(Unit) {
    var totalAngle = 0f
    var lastAngle = 0f
    var lastTime = 0L
    var hasStarted = false

    awaitEachGesture {
        do {
            val event = awaitPointerEvent()

            if (event.changes.size >= 2) {
                if (!hasStarted) {
                    hasStarted = true
                    totalAngle = 0f
                    lastAngle = 0f
                    lastTime = System.currentTimeMillis()
                }

                val rotationChange = event.calculateRotation()
                if (rotationChange != 0f) {
                    val now = System.currentTimeMillis()
                    val dt = (now - lastTime).coerceAtLeast(1) / 1000f

                    totalAngle += rotationChange
                    val velocity = (totalAngle - lastAngle) / dt
                    lastAngle = totalAngle
                    lastTime = now

                    val centroid = event.calculateCentroid(useCurrent = true)

                    onRotation(
                        ZylixRotationResult(
                            totalAngle,
                            ZylixPoint.fromOffset(centroid),
                            velocity,
                            ZylixGestureState.CHANGED
                        )
                    )

                    event.changes.forEach { it.consume() }
                }
            } else if (hasStarted) {
                hasStarted = false
                onRotation(
                    ZylixRotationResult(
                        totalAngle,
                        ZylixPoint.Zero,
                        0f,
                        ZylixGestureState.ENDED
                    )
                )
            }
        } while (event.changes.any { it.pressed })
    }
}

/**
 * Detect combined transform gestures (pinch + rotation)
 */
fun Modifier.zylixOnTransform(
    onTransform: (ZylixTransform) -> Unit
): Modifier = this.pointerInput(Unit) {
    var scale = 1f
    var rotation = 0f
    var translation = Offset.Zero
    var hasStarted = false

    awaitEachGesture {
        do {
            val event = awaitPointerEvent()

            if (event.changes.size >= 2) {
                if (!hasStarted) {
                    hasStarted = true
                    scale = 1f
                    rotation = 0f
                    translation = Offset.Zero
                }

                val zoomChange = event.calculateZoom()
                val rotationChange = event.calculateRotation()
                val panChange = event.calculatePan()

                if (zoomChange != 1f || rotationChange != 0f || panChange != Offset.Zero) {
                    scale *= zoomChange
                    rotation += rotationChange
                    translation += panChange

                    onTransform(
                        ZylixTransform(
                            scale,
                            rotation,
                            ZylixPoint(translation.x, translation.y)
                        )
                    )

                    event.changes.forEach { it.consume() }
                }
            } else if (hasStarted) {
                hasStarted = false
            }
        } while (event.changes.any { it.pressed })
    }
}

/**
 * Detect swipe gestures
 */
fun Modifier.zylixOnSwipe(
    minimumVelocity: Float = 500f,
    minimumDistance: Float = 50f,
    directions: Set<ZylixSwipeDirection> = ZylixSwipeDirection.entries.toSet(),
    onSwipe: (ZylixSwipeResult) -> Unit
): Modifier {
    var startPos = Offset.Zero
    var startTime = 0L

    return this.pointerInput(directions) {
        awaitEachGesture {
            val down = awaitFirstDown()
            startPos = down.position
            startTime = System.currentTimeMillis()

            var lastVelocity = Offset.Zero
            var lastPosition = startPos
            var lastTime = startTime

            do {
                val event = awaitPointerEvent()
                val change = event.changes.firstOrNull() ?: break

                val now = System.currentTimeMillis()
                val dt = (now - lastTime).coerceAtLeast(1) / 1000f

                val delta = change.position - lastPosition
                lastVelocity = Offset(delta.x / dt, delta.y / dt)
                lastPosition = change.position
                lastTime = now

                if (change.changedToUp()) {
                    val endPos = change.position
                    val dx = endPos.x - startPos.x
                    val dy = endPos.y - startPos.y
                    val distance = sqrt(dx * dx + dy * dy)
                    val velocity = sqrt(lastVelocity.x * lastVelocity.x + lastVelocity.y * lastVelocity.y)

                    if (distance >= minimumDistance && velocity >= minimumVelocity) {
                        val direction = when {
                            abs(dx) > abs(dy) -> if (dx > 0) ZylixSwipeDirection.RIGHT else ZylixSwipeDirection.LEFT
                            abs(dy) > abs(dx) -> if (dy > 0) ZylixSwipeDirection.DOWN else ZylixSwipeDirection.UP
                            else -> null
                        }

                        if (direction != null && direction in directions) {
                            onSwipe(
                                ZylixSwipeResult(
                                    direction,
                                    ZylixVelocity(lastVelocity.x, lastVelocity.y),
                                    ZylixPoint.fromOffset(startPos),
                                    ZylixPoint.fromOffset(endPos)
                                )
                            )
                        }
                    }
                    break
                }
            } while (true)
        }
    }
}
