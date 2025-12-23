/**
 * zylix-gesture.js - Web Platform Gesture Recognition for Zylix v0.10.0
 *
 * Provides gesture recognition using Pointer Events API:
 * - Tap (single, double, multi-tap)
 * - Long Press
 * - Pan/Drag
 * - Swipe
 * - Pinch (zoom)
 * - Rotation
 * - Edge Pan
 */

// ============================================================================
// Gesture Types
// ============================================================================

/**
 * 2D point with coordinates
 */
class ZylixPoint {
    constructor(x = 0, y = 0) {
        this.x = x;
        this.y = y;
    }

    static get zero() {
        return new ZylixPoint(0, 0);
    }

    distance(other) {
        const dx = this.x - other.x;
        const dy = this.y - other.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    add(other) {
        return new ZylixPoint(this.x + other.x, this.y + other.y);
    }

    subtract(other) {
        return new ZylixPoint(this.x - other.x, this.y - other.y);
    }

    multiply(scalar) {
        return new ZylixPoint(this.x * scalar, this.y * scalar);
    }
}

/**
 * Gesture state enum
 */
const ZylixGestureState = {
    POSSIBLE: 'possible',
    BEGAN: 'began',
    CHANGED: 'changed',
    ENDED: 'ended',
    CANCELLED: 'cancelled',
    FAILED: 'failed'
};

/**
 * Swipe direction enum
 */
const ZylixSwipeDirection = {
    UP: 'up',
    DOWN: 'down',
    LEFT: 'left',
    RIGHT: 'right'
};

/**
 * Edge enum for edge pan gestures
 */
const ZylixEdge = {
    LEFT: 'left',
    RIGHT: 'right',
    TOP: 'top',
    BOTTOM: 'bottom'
};

/**
 * Velocity data for gesture tracking
 */
class ZylixVelocity {
    constructor(x = 0, y = 0) {
        this.x = x;
        this.y = y;
    }

    get magnitude() {
        return Math.sqrt(this.x * this.x + this.y * this.y);
    }

    static get zero() {
        return new ZylixVelocity(0, 0);
    }
}

/**
 * Transform data for pinch/rotation gestures
 */
class ZylixTransform {
    constructor(scale = 1, rotation = 0, translation = ZylixPoint.zero) {
        this.scale = scale;
        this.rotation = rotation;
        this.translation = translation;
    }

    static get identity() {
        return new ZylixTransform();
    }
}

// ============================================================================
// Touch Tracking
// ============================================================================

/**
 * Individual touch point data
 */
class ZylixTouch {
    constructor(id, position, previousPosition = null, pressure = 1) {
        this.id = id;
        this.position = position;
        this.previousPosition = previousPosition || position;
        this.pressure = pressure;
        this.timestamp = Date.now();
    }
}

/**
 * Touch tracker for managing active touches
 */
class ZylixTouchTracker {
    constructor() {
        this._touches = new Map();
    }

    get touches() {
        return Array.from(this._touches.values());
    }

    get count() {
        return this._touches.size;
    }

    add(pointerId, x, y, pressure = 1) {
        const pos = new ZylixPoint(x, y);
        this._touches.set(pointerId, new ZylixTouch(pointerId, pos, pos, pressure));
    }

    update(pointerId, x, y, pressure = 1) {
        const existing = this._touches.get(pointerId);
        if (existing) {
            const newPos = new ZylixPoint(x, y);
            this._touches.set(pointerId, new ZylixTouch(
                pointerId, newPos, existing.position, pressure
            ));
        }
    }

    remove(pointerId) {
        this._touches.delete(pointerId);
    }

    get(pointerId) {
        return this._touches.get(pointerId);
    }

    clear() {
        this._touches.clear();
    }

    getCentroid() {
        if (this.count === 0) return ZylixPoint.zero;
        let x = 0, y = 0;
        for (const touch of this._touches.values()) {
            x += touch.position.x;
            y += touch.position.y;
        }
        return new ZylixPoint(x / this.count, y / this.count);
    }

    getSpan() {
        const touches = this.touches;
        if (touches.length < 2) return 0;
        return touches[0].position.distance(touches[1].position);
    }

    getAngle() {
        const touches = this.touches;
        if (touches.length < 2) return 0;
        const dx = touches[1].position.x - touches[0].position.x;
        const dy = touches[1].position.y - touches[0].position.y;
        return Math.atan2(dy, dx);
    }
}

// ============================================================================
// Gesture Recognizer Results
// ============================================================================

/**
 * Tap gesture result
 */
class ZylixTapResult {
    constructor(position, tapCount = 1) {
        this.position = position;
        this.tapCount = tapCount;
    }
}

/**
 * Long press gesture result
 */
class ZylixLongPressResult {
    constructor(position, state, duration = 0) {
        this.position = position;
        this.state = state;
        this.duration = duration;
    }
}

/**
 * Pan/Drag gesture result
 */
class ZylixPanResult {
    constructor(startPosition, currentPosition, translation, velocity, state) {
        this.startPosition = startPosition;
        this.currentPosition = currentPosition;
        this.translation = translation;
        this.velocity = velocity;
        this.state = state;
    }
}

/**
 * Swipe gesture result
 */
class ZylixSwipeResult {
    constructor(direction, velocity, startPosition, endPosition) {
        this.direction = direction;
        this.velocity = velocity;
        this.startPosition = startPosition;
        this.endPosition = endPosition;
    }
}

/**
 * Pinch gesture result
 */
class ZylixPinchResult {
    constructor(scale, center, velocity, state) {
        this.scale = scale;
        this.center = center;
        this.velocity = velocity;
        this.state = state;
    }
}

/**
 * Rotation gesture result
 */
class ZylixRotationResult {
    constructor(angle, center, velocity, state) {
        this.angle = angle;
        this.center = center;
        this.velocity = velocity;
        this.state = state;
    }
}

/**
 * Edge pan gesture result
 */
class ZylixEdgePanResult {
    constructor(edge, progress, translation, state) {
        this.edge = edge;
        this.progress = progress;
        this.translation = translation;
        this.state = state;
    }
}

// ============================================================================
// Gesture Recognizers
// ============================================================================

/**
 * Base class for gesture recognizers
 */
class ZylixGestureRecognizer {
    constructor(element) {
        this._element = element;
        this._state = ZylixGestureState.POSSIBLE;
        this._enabled = true;
        this._callbacks = new Map();
    }

    get state() { return this._state; }
    get enabled() { return this._enabled; }
    set enabled(value) { this._enabled = value; }

    on(event, callback) {
        if (!this._callbacks.has(event)) {
            this._callbacks.set(event, new Set());
        }
        this._callbacks.get(event).add(callback);
        return this;
    }

    off(event, callback) {
        if (this._callbacks.has(event)) {
            this._callbacks.get(event).delete(callback);
        }
        return this;
    }

    _emit(event, data) {
        if (this._callbacks.has(event)) {
            for (const cb of this._callbacks.get(event)) {
                cb(data);
            }
        }
    }

    reset() {
        this._state = ZylixGestureState.POSSIBLE;
    }

    destroy() {
        this._callbacks.clear();
    }
}

/**
 * Tap gesture recognizer
 */
class ZylixTapRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.requiredTaps = options.requiredTaps || 1;
        this.maxTapDistance = options.maxTapDistance || 20;
        this.maxTapDelay = options.maxTapDelay || 300;

        this._tapCount = 0;
        this._lastTapTime = 0;
        this._lastTapPosition = null;
        this._tapTimer = null;

        this._setupListeners();
    }

    _setupListeners() {
        let startPos = null;

        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;
            startPos = new ZylixPoint(e.clientX, e.clientY);
        });

        this._element.addEventListener('pointerup', (e) => {
            if (!this._enabled || !startPos) return;

            const endPos = new ZylixPoint(e.clientX, e.clientY);
            const distance = startPos.distance(endPos);

            if (distance > this.maxTapDistance) {
                this._resetTapState();
                return;
            }

            const now = Date.now();

            if (this._lastTapPosition &&
                now - this._lastTapTime < this.maxTapDelay &&
                endPos.distance(this._lastTapPosition) < this.maxTapDistance) {
                this._tapCount++;
            } else {
                this._tapCount = 1;
            }

            this._lastTapTime = now;
            this._lastTapPosition = endPos;

            clearTimeout(this._tapTimer);

            if (this._tapCount === this.requiredTaps) {
                this._state = ZylixGestureState.ENDED;
                this._emit('tap', new ZylixTapResult(endPos, this._tapCount));
                this._resetTapState();
            } else {
                this._tapTimer = setTimeout(() => {
                    this._resetTapState();
                }, this.maxTapDelay);
            }
        });
    }

    _resetTapState() {
        this._tapCount = 0;
        this._lastTapPosition = null;
        this._state = ZylixGestureState.POSSIBLE;
    }
}

/**
 * Long press gesture recognizer
 */
class ZylixLongPressRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.minimumDuration = options.minimumDuration || 500;
        this.maximumDistance = options.maximumDistance || 10;

        this._pressTimer = null;
        this._startPosition = null;
        this._startTime = 0;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            this._startPosition = new ZylixPoint(e.clientX, e.clientY);
            this._startTime = Date.now();
            this._state = ZylixGestureState.POSSIBLE;

            this._pressTimer = setTimeout(() => {
                this._state = ZylixGestureState.BEGAN;
                this._emit('longpress', new ZylixLongPressResult(
                    this._startPosition,
                    ZylixGestureState.BEGAN,
                    this.minimumDuration
                ));
            }, this.minimumDuration);
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled || !this._startPosition) return;

            const currentPos = new ZylixPoint(e.clientX, e.clientY);
            const distance = this._startPosition.distance(currentPos);

            if (distance > this.maximumDistance) {
                this._cancelLongPress();
            }
        });

        this._element.addEventListener('pointerup', (e) => {
            if (!this._enabled) return;

            if (this._state === ZylixGestureState.BEGAN) {
                const duration = Date.now() - this._startTime;
                this._state = ZylixGestureState.ENDED;
                this._emit('longpress', new ZylixLongPressResult(
                    new ZylixPoint(e.clientX, e.clientY),
                    ZylixGestureState.ENDED,
                    duration
                ));
            }

            this._cancelLongPress();
        });

        this._element.addEventListener('pointercancel', () => {
            this._cancelLongPress();
        });
    }

    _cancelLongPress() {
        clearTimeout(this._pressTimer);
        this._pressTimer = null;
        this._startPosition = null;
        this._state = ZylixGestureState.POSSIBLE;
    }
}

/**
 * Pan (drag) gesture recognizer
 */
class ZylixPanRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.minimumDistance = options.minimumDistance || 10;

        this._startPosition = null;
        this._currentPosition = null;
        this._lastPosition = null;
        this._lastTime = 0;
        this._velocity = ZylixVelocity.zero;
        this._isPanning = false;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            this._element.setPointerCapture(e.pointerId);
            this._startPosition = new ZylixPoint(e.clientX, e.clientY);
            this._currentPosition = this._startPosition;
            this._lastPosition = this._startPosition;
            this._lastTime = Date.now();
            this._velocity = ZylixVelocity.zero;
            this._isPanning = false;
            this._state = ZylixGestureState.POSSIBLE;
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled || !this._startPosition) return;

            const currentPos = new ZylixPoint(e.clientX, e.clientY);
            const distance = this._startPosition.distance(currentPos);

            // Calculate velocity
            const now = Date.now();
            const dt = Math.max((now - this._lastTime) / 1000, 0.001);
            this._velocity = new ZylixVelocity(
                (currentPos.x - this._lastPosition.x) / dt,
                (currentPos.y - this._lastPosition.y) / dt
            );
            this._lastPosition = currentPos;
            this._lastTime = now;
            this._currentPosition = currentPos;

            if (!this._isPanning && distance >= this.minimumDistance) {
                this._isPanning = true;
                this._state = ZylixGestureState.BEGAN;
                this._emit('pan', this._createResult(ZylixGestureState.BEGAN));
            } else if (this._isPanning) {
                this._state = ZylixGestureState.CHANGED;
                this._emit('pan', this._createResult(ZylixGestureState.CHANGED));
            }
        });

        this._element.addEventListener('pointerup', (e) => {
            if (!this._enabled) return;

            this._element.releasePointerCapture(e.pointerId);

            if (this._isPanning) {
                this._currentPosition = new ZylixPoint(e.clientX, e.clientY);
                this._state = ZylixGestureState.ENDED;
                this._emit('pan', this._createResult(ZylixGestureState.ENDED));
            }

            this._reset();
        });

        this._element.addEventListener('pointercancel', (e) => {
            if (this._isPanning) {
                this._state = ZylixGestureState.CANCELLED;
                this._emit('pan', this._createResult(ZylixGestureState.CANCELLED));
            }
            this._reset();
        });
    }

    _createResult(state) {
        const translation = this._startPosition.subtract(this._currentPosition).multiply(-1);
        return new ZylixPanResult(
            this._startPosition,
            this._currentPosition,
            translation,
            this._velocity,
            state
        );
    }

    _reset() {
        this._startPosition = null;
        this._currentPosition = null;
        this._isPanning = false;
        this._state = ZylixGestureState.POSSIBLE;
    }
}

/**
 * Swipe gesture recognizer
 */
class ZylixSwipeRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.minimumVelocity = options.minimumVelocity || 500;
        this.minimumDistance = options.minimumDistance || 50;
        this.directions = options.directions || Object.values(ZylixSwipeDirection);

        this._startPosition = null;
        this._startTime = 0;
        this._lastPosition = null;
        this._lastTime = 0;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            this._element.setPointerCapture(e.pointerId);
            this._startPosition = new ZylixPoint(e.clientX, e.clientY);
            this._startTime = Date.now();
            this._lastPosition = this._startPosition;
            this._lastTime = this._startTime;
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled || !this._startPosition) return;

            this._lastPosition = new ZylixPoint(e.clientX, e.clientY);
            this._lastTime = Date.now();
        });

        this._element.addEventListener('pointerup', (e) => {
            if (!this._enabled || !this._startPosition) return;

            this._element.releasePointerCapture(e.pointerId);

            const endPos = new ZylixPoint(e.clientX, e.clientY);
            const dx = endPos.x - this._startPosition.x;
            const dy = endPos.y - this._startPosition.y;
            const distance = Math.sqrt(dx * dx + dy * dy);

            const dt = Math.max((Date.now() - this._startTime) / 1000, 0.001);
            const velocity = new ZylixVelocity(dx / dt, dy / dt);

            if (distance >= this.minimumDistance && velocity.magnitude >= this.minimumVelocity) {
                const direction = this._determineDirection(dx, dy);
                if (direction && this.directions.includes(direction)) {
                    this._state = ZylixGestureState.ENDED;
                    this._emit('swipe', new ZylixSwipeResult(
                        direction, velocity, this._startPosition, endPos
                    ));
                }
            }

            this._reset();
        });

        this._element.addEventListener('pointercancel', () => {
            this._reset();
        });
    }

    _determineDirection(dx, dy) {
        const absDx = Math.abs(dx);
        const absDy = Math.abs(dy);

        if (absDx > absDy) {
            return dx > 0 ? ZylixSwipeDirection.RIGHT : ZylixSwipeDirection.LEFT;
        } else if (absDy > absDx) {
            return dy > 0 ? ZylixSwipeDirection.DOWN : ZylixSwipeDirection.UP;
        }
        return null;
    }

    _reset() {
        this._startPosition = null;
        this._state = ZylixGestureState.POSSIBLE;
    }
}

/**
 * Pinch gesture recognizer
 */
class ZylixPinchRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.minimumScale = options.minimumScale || 0.01;

        this._tracker = new ZylixTouchTracker();
        this._initialSpan = 0;
        this._currentScale = 1;
        this._lastScale = 1;
        this._lastTime = 0;
        this._isPinching = false;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            this._element.setPointerCapture(e.pointerId);
            this._tracker.add(e.pointerId, e.clientX, e.clientY, e.pressure);

            if (this._tracker.count === 2) {
                this._initialSpan = this._tracker.getSpan();
                this._currentScale = 1;
                this._lastScale = 1;
                this._lastTime = Date.now();
                this._isPinching = true;
                this._state = ZylixGestureState.BEGAN;
                this._emit('pinch', this._createResult(ZylixGestureState.BEGAN));
            }
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled) return;

            this._tracker.update(e.pointerId, e.clientX, e.clientY, e.pressure);

            if (this._isPinching && this._tracker.count === 2) {
                const currentSpan = this._tracker.getSpan();
                this._currentScale = currentSpan / this._initialSpan;

                const now = Date.now();
                const dt = Math.max((now - this._lastTime) / 1000, 0.001);
                const velocity = (this._currentScale - this._lastScale) / dt;
                this._lastScale = this._currentScale;
                this._lastTime = now;

                this._state = ZylixGestureState.CHANGED;
                this._emit('pinch', new ZylixPinchResult(
                    this._currentScale,
                    this._tracker.getCentroid(),
                    velocity,
                    ZylixGestureState.CHANGED
                ));
            }
        });

        const endHandler = (e) => {
            if (!this._enabled) return;

            this._element.releasePointerCapture(e.pointerId);
            this._tracker.remove(e.pointerId);

            if (this._isPinching && this._tracker.count < 2) {
                this._isPinching = false;
                this._state = ZylixGestureState.ENDED;
                this._emit('pinch', this._createResult(ZylixGestureState.ENDED));
            }
        };

        this._element.addEventListener('pointerup', endHandler);
        this._element.addEventListener('pointercancel', endHandler);
    }

    _createResult(state) {
        return new ZylixPinchResult(
            this._currentScale,
            this._tracker.getCentroid(),
            0,
            state
        );
    }
}

/**
 * Rotation gesture recognizer
 */
class ZylixRotationRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.minimumAngle = options.minimumAngle || 0.01;

        this._tracker = new ZylixTouchTracker();
        this._initialAngle = 0;
        this._currentAngle = 0;
        this._lastAngle = 0;
        this._lastTime = 0;
        this._isRotating = false;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            this._element.setPointerCapture(e.pointerId);
            this._tracker.add(e.pointerId, e.clientX, e.clientY, e.pressure);

            if (this._tracker.count === 2) {
                this._initialAngle = this._tracker.getAngle();
                this._currentAngle = 0;
                this._lastAngle = 0;
                this._lastTime = Date.now();
                this._isRotating = true;
                this._state = ZylixGestureState.BEGAN;
                this._emit('rotation', this._createResult(ZylixGestureState.BEGAN));
            }
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled) return;

            this._tracker.update(e.pointerId, e.clientX, e.clientY, e.pressure);

            if (this._isRotating && this._tracker.count === 2) {
                const currentRawAngle = this._tracker.getAngle();
                this._currentAngle = currentRawAngle - this._initialAngle;

                const now = Date.now();
                const dt = Math.max((now - this._lastTime) / 1000, 0.001);
                const velocity = (this._currentAngle - this._lastAngle) / dt;
                this._lastAngle = this._currentAngle;
                this._lastTime = now;

                this._state = ZylixGestureState.CHANGED;
                this._emit('rotation', new ZylixRotationResult(
                    this._currentAngle,
                    this._tracker.getCentroid(),
                    velocity,
                    ZylixGestureState.CHANGED
                ));
            }
        });

        const endHandler = (e) => {
            if (!this._enabled) return;

            this._element.releasePointerCapture(e.pointerId);
            this._tracker.remove(e.pointerId);

            if (this._isRotating && this._tracker.count < 2) {
                this._isRotating = false;
                this._state = ZylixGestureState.ENDED;
                this._emit('rotation', this._createResult(ZylixGestureState.ENDED));
            }
        };

        this._element.addEventListener('pointerup', endHandler);
        this._element.addEventListener('pointercancel', endHandler);
    }

    _createResult(state) {
        return new ZylixRotationResult(
            this._currentAngle,
            this._tracker.getCentroid(),
            0,
            state
        );
    }
}

/**
 * Edge pan gesture recognizer
 */
class ZylixEdgePanRecognizer extends ZylixGestureRecognizer {
    constructor(element, options = {}) {
        super(element);
        this.edge = options.edge || ZylixEdge.LEFT;
        this.edgeThreshold = options.edgeThreshold || 30;
        this.minimumDistance = options.minimumDistance || 10;

        this._startPosition = null;
        this._currentPosition = null;
        this._isPanning = false;
        this._maxDimension = 0;

        this._setupListeners();
    }

    _setupListeners() {
        this._element.addEventListener('pointerdown', (e) => {
            if (!this._enabled) return;

            const rect = this._element.getBoundingClientRect();
            const pos = new ZylixPoint(e.clientX - rect.left, e.clientY - rect.top);

            this._maxDimension = (this.edge === ZylixEdge.LEFT || this.edge === ZylixEdge.RIGHT)
                ? rect.width : rect.height;

            const isOnEdge = this._isOnEdge(pos, rect);
            if (!isOnEdge) return;

            this._element.setPointerCapture(e.pointerId);
            this._startPosition = pos;
            this._currentPosition = pos;
            this._isPanning = true;
            this._state = ZylixGestureState.BEGAN;
            this._emit('edgepan', this._createResult(ZylixGestureState.BEGAN));
        });

        this._element.addEventListener('pointermove', (e) => {
            if (!this._enabled || !this._isPanning) return;

            const rect = this._element.getBoundingClientRect();
            this._currentPosition = new ZylixPoint(e.clientX - rect.left, e.clientY - rect.top);
            this._state = ZylixGestureState.CHANGED;
            this._emit('edgepan', this._createResult(ZylixGestureState.CHANGED));
        });

        const endHandler = (e) => {
            if (!this._enabled || !this._isPanning) return;

            this._element.releasePointerCapture(e.pointerId);
            this._state = ZylixGestureState.ENDED;
            this._emit('edgepan', this._createResult(ZylixGestureState.ENDED));
            this._reset();
        };

        this._element.addEventListener('pointerup', endHandler);
        this._element.addEventListener('pointercancel', endHandler);
    }

    _isOnEdge(pos, rect) {
        switch (this.edge) {
            case ZylixEdge.LEFT: return pos.x < this.edgeThreshold;
            case ZylixEdge.RIGHT: return pos.x > rect.width - this.edgeThreshold;
            case ZylixEdge.TOP: return pos.y < this.edgeThreshold;
            case ZylixEdge.BOTTOM: return pos.y > rect.height - this.edgeThreshold;
            default: return false;
        }
    }

    _createResult(state) {
        const translation = this._startPosition.subtract(this._currentPosition).multiply(-1);
        let progress = 0;

        switch (this.edge) {
            case ZylixEdge.LEFT:
                progress = (this._currentPosition.x - this._startPosition.x) / this._maxDimension;
                break;
            case ZylixEdge.RIGHT:
                progress = (this._startPosition.x - this._currentPosition.x) / this._maxDimension;
                break;
            case ZylixEdge.TOP:
                progress = (this._currentPosition.y - this._startPosition.y) / this._maxDimension;
                break;
            case ZylixEdge.BOTTOM:
                progress = (this._startPosition.y - this._currentPosition.y) / this._maxDimension;
                break;
        }

        return new ZylixEdgePanResult(
            this.edge,
            Math.max(0, Math.min(1, progress)),
            translation,
            state
        );
    }

    _reset() {
        this._startPosition = null;
        this._currentPosition = null;
        this._isPanning = false;
        this._state = ZylixGestureState.POSSIBLE;
    }
}

// ============================================================================
// Gesture Manager
// ============================================================================

/**
 * Central manager for all gesture recognizers
 */
class ZylixGestureManager {
    constructor() {
        this._recognizers = new Map();
        this._elementRecognizers = new WeakMap();
    }

    /**
     * Add a tap recognizer to an element
     */
    addTap(element, options = {}) {
        const recognizer = new ZylixTapRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add a long press recognizer to an element
     */
    addLongPress(element, options = {}) {
        const recognizer = new ZylixLongPressRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add a pan recognizer to an element
     */
    addPan(element, options = {}) {
        const recognizer = new ZylixPanRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add a swipe recognizer to an element
     */
    addSwipe(element, options = {}) {
        const recognizer = new ZylixSwipeRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add a pinch recognizer to an element
     */
    addPinch(element, options = {}) {
        const recognizer = new ZylixPinchRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add a rotation recognizer to an element
     */
    addRotation(element, options = {}) {
        const recognizer = new ZylixRotationRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    /**
     * Add an edge pan recognizer to an element
     */
    addEdgePan(element, options = {}) {
        const recognizer = new ZylixEdgePanRecognizer(element, options);
        this._registerRecognizer(element, recognizer);
        return recognizer;
    }

    _registerRecognizer(element, recognizer) {
        const id = this._generateId();
        this._recognizers.set(id, recognizer);

        if (!this._elementRecognizers.has(element)) {
            this._elementRecognizers.set(element, []);
        }
        this._elementRecognizers.get(element).push({ id, recognizer });

        return recognizer;
    }

    _generateId() {
        return `zylix-gesture-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Remove a recognizer
     */
    removeRecognizer(recognizer) {
        for (const [id, rec] of this._recognizers) {
            if (rec === recognizer) {
                rec.destroy();
                this._recognizers.delete(id);
                break;
            }
        }
    }

    /**
     * Remove all recognizers from an element
     */
    removeAll(element) {
        const elementRecs = this._elementRecognizers.get(element);
        if (elementRecs) {
            for (const { id, recognizer } of elementRecs) {
                recognizer.destroy();
                this._recognizers.delete(id);
            }
            this._elementRecognizers.delete(element);
        }
    }

    /**
     * Reset all recognizers
     */
    resetAll() {
        for (const recognizer of this._recognizers.values()) {
            recognizer.reset();
        }
    }

    /**
     * Get singleton instance
     */
    static shared() {
        if (!ZylixGestureManager._instance) {
            ZylixGestureManager._instance = new ZylixGestureManager();
        }
        return ZylixGestureManager._instance;
    }
}

ZylixGestureManager._instance = null;

// ============================================================================
// Convenience Functions
// ============================================================================

/**
 * Add tap gesture to element
 */
function zylixOnTap(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addTap(element, options);
    recognizer.on('tap', callback);
    return recognizer;
}

/**
 * Add long press gesture to element
 */
function zylixOnLongPress(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addLongPress(element, options);
    recognizer.on('longpress', callback);
    return recognizer;
}

/**
 * Add pan/drag gesture to element
 */
function zylixOnPan(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addPan(element, options);
    recognizer.on('pan', callback);
    return recognizer;
}

/**
 * Add swipe gesture to element
 */
function zylixOnSwipe(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addSwipe(element, options);
    recognizer.on('swipe', callback);
    return recognizer;
}

/**
 * Add pinch gesture to element
 */
function zylixOnPinch(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addPinch(element, options);
    recognizer.on('pinch', callback);
    return recognizer;
}

/**
 * Add rotation gesture to element
 */
function zylixOnRotation(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addRotation(element, options);
    recognizer.on('rotation', callback);
    return recognizer;
}

/**
 * Add edge pan gesture to element
 */
function zylixOnEdgePan(element, callback, options = {}) {
    const recognizer = ZylixGestureManager.shared().addEdgePan(element, options);
    recognizer.on('edgepan', callback);
    return recognizer;
}

// ============================================================================
// Main Gesture Object
// ============================================================================

/**
 * Main Zylix Gesture interface
 */
const ZylixGesture = {
    // Types
    Point: ZylixPoint,
    Velocity: ZylixVelocity,
    Transform: ZylixTransform,
    GestureState: ZylixGestureState,
    SwipeDirection: ZylixSwipeDirection,
    Edge: ZylixEdge,

    // Results
    TapResult: ZylixTapResult,
    LongPressResult: ZylixLongPressResult,
    PanResult: ZylixPanResult,
    SwipeResult: ZylixSwipeResult,
    PinchResult: ZylixPinchResult,
    RotationResult: ZylixRotationResult,
    EdgePanResult: ZylixEdgePanResult,

    // Recognizers
    TapRecognizer: ZylixTapRecognizer,
    LongPressRecognizer: ZylixLongPressRecognizer,
    PanRecognizer: ZylixPanRecognizer,
    SwipeRecognizer: ZylixSwipeRecognizer,
    PinchRecognizer: ZylixPinchRecognizer,
    RotationRecognizer: ZylixRotationRecognizer,
    EdgePanRecognizer: ZylixEdgePanRecognizer,

    // Manager
    Manager: ZylixGestureManager,

    // Convenience functions
    onTap: zylixOnTap,
    onLongPress: zylixOnLongPress,
    onPan: zylixOnPan,
    onSwipe: zylixOnSwipe,
    onPinch: zylixOnPinch,
    onRotation: zylixOnRotation,
    onEdgePan: zylixOnEdgePan
};

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZylixGesture;
}

if (typeof window !== 'undefined') {
    window.ZylixGesture = ZylixGesture;
}

if (typeof globalThis !== 'undefined') {
    globalThis.ZylixGesture = ZylixGesture;
}
