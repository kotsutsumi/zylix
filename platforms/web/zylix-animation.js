/**
 * Zylix Animation - Cross-platform animation module for Web
 *
 * Provides Lottie animation support and timeline-based animations.
 *
 * @module ZylixAnimation
 * @version 0.11.0
 */

// ============================================================================
// Constants
// ============================================================================

/** Playback state enum */
const PlaybackState = Object.freeze({
    STOPPED: 0,
    PLAYING: 1,
    PAUSED: 2,
    FINISHED: 3
});

/** Loop mode enum */
const LoopMode = Object.freeze({
    NONE: 0,
    LOOP: 1,
    PING_PONG: 2,
    LOOP_COUNT: 3
});

/** Play direction enum */
const PlayDirection = Object.freeze({
    FORWARD: 0,
    REVERSE: 1
});

/** Animation event types */
const AnimationEventType = Object.freeze({
    STARTED: 0,
    PAUSED: 1,
    RESUMED: 2,
    STOPPED: 3,
    COMPLETED: 4,
    LOOP_COMPLETED: 5,
    FRAME_CHANGED: 6,
    MARKER_REACHED: 7
});

// ============================================================================
// Easing Functions
// ============================================================================

/**
 * Standard easing functions
 */
const Easing = {
    // Linear
    linear: (t) => t,

    // Quadratic
    easeInQuad: (t) => t * t,
    easeOutQuad: (t) => t * (2 - t),
    easeInOutQuad: (t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t,

    // Cubic
    easeInCubic: (t) => t * t * t,
    easeOutCubic: (t) => {
        const f = t - 1;
        return f * f * f + 1;
    },
    easeInOutCubic: (t) => {
        if (t < 0.5) return 4 * t * t * t;
        const f = 2 * t - 2;
        return 0.5 * f * f * f + 1;
    },

    // Quartic
    easeInQuart: (t) => t * t * t * t,
    easeOutQuart: (t) => {
        const f = t - 1;
        return 1 - f * f * f * f;
    },
    easeInOutQuart: (t) => {
        if (t < 0.5) return 8 * t * t * t * t;
        const f = t - 1;
        return 1 - 8 * f * f * f * f;
    },

    // Quintic
    easeInQuint: (t) => t * t * t * t * t,
    easeOutQuint: (t) => {
        const f = t - 1;
        return 1 + f * f * f * f * f;
    },
    easeInOutQuint: (t) => {
        if (t < 0.5) return 16 * t * t * t * t * t;
        const f = 2 * t - 2;
        return 0.5 * f * f * f * f * f + 1;
    },

    // Sinusoidal
    easeInSine: (t) => 1 - Math.cos(t * Math.PI / 2),
    easeOutSine: (t) => Math.sin(t * Math.PI / 2),
    easeInOutSine: (t) => 0.5 * (1 - Math.cos(Math.PI * t)),

    // Exponential
    easeInExpo: (t) => t === 0 ? 0 : Math.pow(2, 10 * (t - 1)),
    easeOutExpo: (t) => t === 1 ? 1 : 1 - Math.pow(2, -10 * t),
    easeInOutExpo: (t) => {
        if (t === 0) return 0;
        if (t === 1) return 1;
        if (t < 0.5) return 0.5 * Math.pow(2, 20 * t - 10);
        return 1 - 0.5 * Math.pow(2, -20 * t + 10);
    },

    // Circular
    easeInCirc: (t) => 1 - Math.sqrt(1 - t * t),
    easeOutCirc: (t) => {
        const f = t - 1;
        return Math.sqrt(1 - f * f);
    },
    easeInOutCirc: (t) => {
        if (t < 0.5) return 0.5 * (1 - Math.sqrt(1 - 4 * t * t));
        return 0.5 * (Math.sqrt(1 - Math.pow(-2 * t + 2, 2)) + 1);
    },

    // Back (overshoot)
    easeInBack: (t) => {
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return c3 * t * t * t - c1 * t * t;
    },
    easeOutBack: (t) => {
        const c1 = 1.70158;
        const c3 = c1 + 1;
        const f = t - 1;
        return 1 + c3 * f * f * f + c1 * f * f;
    },
    easeInOutBack: (t) => {
        const c1 = 1.70158;
        const c2 = c1 * 1.525;
        if (t < 0.5) {
            return (Math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2;
        }
        return (Math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
    },

    // Elastic
    easeInElastic: (t) => {
        if (t === 0) return 0;
        if (t === 1) return 1;
        const c4 = (2 * Math.PI) / 3;
        return -Math.pow(2, 10 * t - 10) * Math.sin((t * 10 - 10.75) * c4);
    },
    easeOutElastic: (t) => {
        if (t === 0) return 0;
        if (t === 1) return 1;
        const c4 = (2 * Math.PI) / 3;
        return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
    },
    easeInOutElastic: (t) => {
        if (t === 0) return 0;
        if (t === 1) return 1;
        const c5 = (2 * Math.PI) / 4.5;
        if (t < 0.5) {
            return -(Math.pow(2, 20 * t - 10) * Math.sin((20 * t - 11.125) * c5)) / 2;
        }
        return (Math.pow(2, -20 * t + 10) * Math.sin((20 * t - 11.125) * c5)) / 2 + 1;
    },

    // Bounce
    easeOutBounce: (t) => {
        const n1 = 7.5625;
        const d1 = 2.75;
        if (t < 1 / d1) {
            return n1 * t * t;
        } else if (t < 2 / d1) {
            const t1 = t - 1.5 / d1;
            return n1 * t1 * t1 + 0.75;
        } else if (t < 2.5 / d1) {
            const t1 = t - 2.25 / d1;
            return n1 * t1 * t1 + 0.9375;
        } else {
            const t1 = t - 2.625 / d1;
            return n1 * t1 * t1 + 0.984375;
        }
    },
    easeInBounce: (t) => 1 - Easing.easeOutBounce(1 - t),
    easeInOutBounce: (t) => {
        if (t < 0.5) return (1 - Easing.easeOutBounce(1 - 2 * t)) / 2;
        return (1 + Easing.easeOutBounce(2 * t - 1)) / 2;
    },

    // Spring
    spring: (t, stiffness = 100, damping = 10, mass = 1) => {
        const omega = Math.sqrt(stiffness / mass);
        const zeta = damping / (2 * Math.sqrt(stiffness * mass));

        if (zeta < 1) {
            // Underdamped
            const omegaD = omega * Math.sqrt(1 - zeta * zeta);
            const decay = Math.exp(-zeta * omega * t);
            return 1 - decay * (Math.cos(omegaD * t) + (zeta * omega / omegaD) * Math.sin(omegaD * t));
        } else {
            // Critically damped or overdamped
            const decay = Math.exp(-omega * t);
            return 1 - decay * (1 + omega * t);
        }
    },

    // Cubic Bezier
    cubicBezier: (x1, y1, x2, y2) => {
        return (t) => {
            // Newton-Raphson iteration to find x for given t
            let x = t;
            for (let i = 0; i < 8; i++) {
                const xEst = sampleCurveX(x, x1, x2) - t;
                if (Math.abs(xEst) < 0.0001) break;
                const d = sampleCurveDerivativeX(x, x1, x2);
                if (Math.abs(d) < 0.0001) break;
                x = x - xEst / d;
            }
            return sampleCurveY(x, y1, y2);
        };

        function sampleCurveX(t, x1, x2) {
            return ((1 - 3 * x2 + 3 * x1) * t + (3 * x2 - 6 * x1)) * t * t + 3 * x1 * t;
        }

        function sampleCurveY(t, y1, y2) {
            return ((1 - 3 * y2 + 3 * y1) * t + (3 * y2 - 6 * y1)) * t * t + 3 * y1 * t;
        }

        function sampleCurveDerivativeX(t, x1, x2) {
            return (3 - 9 * x2 + 9 * x1) * t * t + (6 * x2 - 12 * x1) * t + 3 * x1;
        }
    }
};

// CSS standard easing presets
Easing.ease = Easing.cubicBezier(0.25, 0.1, 0.25, 1.0);
Easing.easeIn = Easing.cubicBezier(0.42, 0, 1.0, 1.0);
Easing.easeOut = Easing.cubicBezier(0, 0, 0.58, 1.0);
Easing.easeInOut = Easing.cubicBezier(0.42, 0, 0.58, 1.0);

// ============================================================================
// Timeline Animation
// ============================================================================

/**
 * Animation timeline for sequencing animations
 */
class Timeline {
    constructor() {
        this.state = PlaybackState.STOPPED;
        this.currentTime = 0;
        this.duration = 0;
        this.speed = 1.0;
        this.loopMode = LoopMode.NONE;
        this.loopCount = 0;

        this._currentLoop = 0;
        this._direction = PlayDirection.FORWARD;
        this._lastTimestamp = 0;
        this._animationFrameId = null;
        this._callbacks = [];
        this._tracks = [];
    }

    /**
     * Add a property track
     */
    addTrack(name, initialValue) {
        const track = new PropertyTrack(name, initialValue);
        this._tracks.push(track);
        return track;
    }

    /**
     * Get track by name
     */
    getTrack(name) {
        return this._tracks.find(t => t.name === name);
    }

    /**
     * Update duration based on tracks
     */
    updateDuration() {
        this.duration = Math.max(...this._tracks.map(t => t.getDuration()), 0);
    }

    // Playback control

    play() {
        if (this.state === PlaybackState.PAUSED) {
            this.state = PlaybackState.PLAYING;
            this._startAnimationFrame();
            this._emitEvent(AnimationEventType.RESUMED);
        } else {
            this.state = PlaybackState.PLAYING;
            this.currentTime = 0;
            this._currentLoop = 0;
            this._startAnimationFrame();
            this._emitEvent(AnimationEventType.STARTED);
        }
    }

    pause() {
        if (this.state !== PlaybackState.PLAYING) return;
        this.state = PlaybackState.PAUSED;
        this._stopAnimationFrame();
        this._emitEvent(AnimationEventType.PAUSED);
    }

    stop() {
        this.state = PlaybackState.STOPPED;
        this.currentTime = 0;
        this._currentLoop = 0;
        this._stopAnimationFrame();
        this._emitEvent(AnimationEventType.STOPPED);
    }

    seek(time) {
        this.currentTime = Math.max(0, Math.min(time, this.duration));
        this._updateTracks();
    }

    seekToProgress(progress) {
        this.seek(progress * this.duration);
    }

    get progress() {
        return this.duration > 0 ? this.currentTime / this.duration : 0;
    }

    // Event handling

    on(eventType, callback) {
        this._callbacks.push({ type: eventType, callback });
        return this;
    }

    // Private methods

    _startAnimationFrame() {
        this._lastTimestamp = 0;
        const tick = (timestamp) => {
            if (this.state !== PlaybackState.PLAYING) return;

            if (this._lastTimestamp === 0) {
                this._lastTimestamp = timestamp;
                this._animationFrameId = requestAnimationFrame(tick);
                return;
            }

            const delta = ((timestamp - this._lastTimestamp) / 1000) * this.speed;
            this._lastTimestamp = timestamp;

            // Update current time
            if (this._direction === PlayDirection.FORWARD) {
                this.currentTime += delta;
            } else {
                this.currentTime -= delta;
            }

            // Handle end of timeline
            if (this.currentTime >= this.duration) {
                switch (this.loopMode) {
                    case LoopMode.NONE:
                        this.currentTime = this.duration;
                        this.state = PlaybackState.FINISHED;
                        this._updateTracks();
                        this._emitEvent(AnimationEventType.COMPLETED);
                        return;

                    case LoopMode.LOOP:
                        this.currentTime = this.currentTime % this.duration;
                        this._currentLoop++;
                        this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        break;

                    case LoopMode.PING_PONG:
                        this._direction = this._direction === PlayDirection.FORWARD
                            ? PlayDirection.REVERSE : PlayDirection.FORWARD;
                        this.currentTime = this.duration;
                        this._currentLoop++;
                        this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        break;

                    case LoopMode.LOOP_COUNT:
                        this._currentLoop++;
                        if (this._currentLoop >= this.loopCount) {
                            this.currentTime = this.duration;
                            this.state = PlaybackState.FINISHED;
                            this._updateTracks();
                            this._emitEvent(AnimationEventType.COMPLETED);
                            return;
                        } else {
                            this.currentTime = 0;
                            this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        }
                        break;
                }
            } else if (this.currentTime < 0) {
                if (this.loopMode === LoopMode.PING_PONG) {
                    this._direction = PlayDirection.FORWARD;
                    this.currentTime = 0;
                } else {
                    this.currentTime = 0;
                }
            }

            this._updateTracks();
            this._animationFrameId = requestAnimationFrame(tick);
        };

        this._animationFrameId = requestAnimationFrame(tick);
    }

    _stopAnimationFrame() {
        if (this._animationFrameId) {
            cancelAnimationFrame(this._animationFrameId);
            this._animationFrameId = null;
        }
    }

    _updateTracks() {
        for (const track of this._tracks) {
            track.update(this.currentTime * 1000); // Convert to ms
        }
    }

    _emitEvent(type, data = {}) {
        const event = {
            type,
            animationId: 0,
            currentTime: this.currentTime,
            progress: this.progress,
            loopCount: this._currentLoop,
            ...data
        };
        for (const { type: t, callback } of this._callbacks) {
            if (t === type || t === 'all') {
                callback(event);
            }
        }
    }
}

/**
 * Property track for animating values
 */
class PropertyTrack {
    constructor(name, initialValue) {
        this.name = name;
        this.keyframes = [{ time: 0, value: initialValue, easing: Easing.linear }];
        this.currentValue = initialValue;
    }

    /**
     * Add a keyframe
     */
    to(timeMs, value, easing = Easing.linear) {
        this.keyframes.push({ time: timeMs, value, easing });
        this.keyframes.sort((a, b) => a.time - b.time);
        return this;
    }

    /**
     * Get duration
     */
    getDuration() {
        if (this.keyframes.length === 0) return 0;
        return this.keyframes[this.keyframes.length - 1].time;
    }

    /**
     * Update current value based on time
     */
    update(timeMs) {
        if (this.keyframes.length === 0) return;
        if (this.keyframes.length === 1) {
            this.currentValue = this.keyframes[0].value;
            return;
        }

        // Find surrounding keyframes
        let prevIdx = 0;
        let nextIdx = this.keyframes.length - 1;

        for (let i = 0; i < this.keyframes.length; i++) {
            if (this.keyframes[i].time <= timeMs) {
                prevIdx = i;
            }
            if (this.keyframes[i].time >= timeMs) {
                nextIdx = i;
                break;
            }
        }

        const prev = this.keyframes[prevIdx];
        const next = this.keyframes[nextIdx];

        if (prevIdx === nextIdx || prev.time === next.time) {
            this.currentValue = prev.value;
            return;
        }

        // Interpolate
        const duration = next.time - prev.time;
        const elapsed = timeMs - prev.time;
        const t = next.easing(elapsed / duration);

        this.currentValue = this._interpolate(prev.value, next.value, t);
    }

    _interpolate(a, b, t) {
        if (typeof a === 'number' && typeof b === 'number') {
            return a + (b - a) * t;
        }
        if (typeof a === 'object' && typeof b === 'object') {
            const result = {};
            for (const key in a) {
                if (key in b) {
                    result[key] = this._interpolate(a[key], b[key], t);
                }
            }
            return result;
        }
        return t < 0.5 ? a : b;
    }
}

// ============================================================================
// Lottie Animation
// ============================================================================

/**
 * Lottie animation wrapper
 */
class LottieAnimation {
    constructor() {
        this.state = PlaybackState.STOPPED;
        this.currentFrame = 0;
        this.progress = 0;

        // Metadata
        this.name = '';
        this.width = 0;
        this.height = 0;
        this.frameRate = 30;
        this.startFrame = 0;
        this.endFrame = 0;
        this.markers = [];

        // Playback settings
        this.speed = 1.0;
        this.loopMode = LoopMode.NONE;
        this.loopCount = 0;

        this._currentLoop = 0;
        this._direction = PlayDirection.FORWARD;
        this._lastTimestamp = 0;
        this._animationFrameId = null;
        this._callbacks = [];
        this._jsonData = null;
    }

    get totalFrames() {
        return this.endFrame - this.startFrame;
    }

    get duration() {
        return this.totalFrames / this.frameRate;
    }

    // Loading

    loadFromJson(jsonString) {
        const json = typeof jsonString === 'string' ? JSON.parse(jsonString) : jsonString;
        this._loadFromObject(json);
    }

    async loadFromUrl(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const json = await response.json();
            this._loadFromObject(json);
        } catch (error) {
            console.error(`Failed to load Lottie from URL: ${url}`, error);
            throw error; // Re-throw to allow caller to handle
        }
    }

    _loadFromObject(json) {
        this._jsonData = json;

        // Parse metadata
        this.name = json.nm || '';
        this.width = json.w || 0;
        this.height = json.h || 0;
        this.frameRate = json.fr || 30;
        this.startFrame = json.ip || 0;
        this.endFrame = json.op || 0;

        // Parse markers
        if (json.markers && Array.isArray(json.markers)) {
            this.markers = json.markers.map(m => ({
                name: m.cm || '',
                time: m.tm || 0,
                duration: m.dr || 0
            }));
        }

        this.currentFrame = this.startFrame;
    }

    // Playback control

    play() {
        if (this.state === PlaybackState.PAUSED) {
            this.state = PlaybackState.PLAYING;
            this._startAnimationFrame();
            this._emitEvent(AnimationEventType.RESUMED);
        } else {
            this.state = PlaybackState.PLAYING;
            this.currentFrame = this.startFrame;
            this._currentLoop = 0;
            this._startAnimationFrame();
            this._emitEvent(AnimationEventType.STARTED);
        }
    }

    pause() {
        if (this.state !== PlaybackState.PLAYING) return;
        this.state = PlaybackState.PAUSED;
        this._stopAnimationFrame();
        this._emitEvent(AnimationEventType.PAUSED);
    }

    stop() {
        this.state = PlaybackState.STOPPED;
        this.currentFrame = this.startFrame;
        this.progress = 0;
        this._currentLoop = 0;
        this._stopAnimationFrame();
        this._emitEvent(AnimationEventType.STOPPED);
    }

    seekToFrame(frame) {
        this.currentFrame = Math.max(this.startFrame, Math.min(frame, this.endFrame));
        this._updateProgress();
        this._emitEvent(AnimationEventType.FRAME_CHANGED);
    }

    seekToProgress(p) {
        const frame = this.startFrame + p * this.totalFrames;
        this.seekToFrame(frame);
    }

    seekToMarker(name) {
        const marker = this.markers.find(m => m.name === name);
        if (!marker) return false;
        this.seekToFrame(marker.time);
        this._emitEvent(AnimationEventType.MARKER_REACHED, { markerName: name });
        return true;
    }

    // Event handling

    on(eventType, callback) {
        this._callbacks.push({ type: eventType, callback });
        return this;
    }

    // Private methods

    _startAnimationFrame() {
        this._lastTimestamp = 0;
        const tick = (timestamp) => {
            if (this.state !== PlaybackState.PLAYING) return;

            if (this._lastTimestamp === 0) {
                this._lastTimestamp = timestamp;
                this._animationFrameId = requestAnimationFrame(tick);
                return;
            }

            const deltaMs = timestamp - this._lastTimestamp;
            this._lastTimestamp = timestamp;

            // Calculate frame delta
            const frameDelta = (deltaMs / 1000) * this.frameRate * this.speed;

            // Update current frame
            if (this._direction === PlayDirection.FORWARD) {
                this.currentFrame += frameDelta;
            } else {
                this.currentFrame -= frameDelta;
            }

            // Handle end of animation
            if (this.currentFrame >= this.endFrame) {
                switch (this.loopMode) {
                    case LoopMode.NONE:
                        this.currentFrame = this.endFrame;
                        this.state = PlaybackState.FINISHED;
                        this._updateProgress();
                        this._emitEvent(AnimationEventType.COMPLETED);
                        return;

                    case LoopMode.LOOP:
                        this.currentFrame = this.startFrame + (this.currentFrame - this.startFrame) % this.totalFrames;
                        this._currentLoop++;
                        this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        break;

                    case LoopMode.PING_PONG:
                        this._direction = this._direction === PlayDirection.FORWARD
                            ? PlayDirection.REVERSE : PlayDirection.FORWARD;
                        this.currentFrame = this.endFrame;
                        this._currentLoop++;
                        this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        break;

                    case LoopMode.LOOP_COUNT:
                        this._currentLoop++;
                        if (this._currentLoop >= this.loopCount) {
                            this.currentFrame = this.endFrame;
                            this.state = PlaybackState.FINISHED;
                            this._updateProgress();
                            this._emitEvent(AnimationEventType.COMPLETED);
                            return;
                        } else {
                            this.currentFrame = this.startFrame;
                            this._emitEvent(AnimationEventType.LOOP_COMPLETED);
                        }
                        break;
                }
            } else if (this.currentFrame < this.startFrame) {
                if (this.loopMode === LoopMode.PING_PONG) {
                    this._direction = PlayDirection.FORWARD;
                    this.currentFrame = this.startFrame;
                } else {
                    this.currentFrame = this.startFrame;
                }
            }

            this._updateProgress();
            this._animationFrameId = requestAnimationFrame(tick);
        };

        this._animationFrameId = requestAnimationFrame(tick);
    }

    _stopAnimationFrame() {
        if (this._animationFrameId) {
            cancelAnimationFrame(this._animationFrameId);
            this._animationFrameId = null;
        }
    }

    _updateProgress() {
        this.progress = this.totalFrames > 0
            ? (this.currentFrame - this.startFrame) / this.totalFrames
            : 0;
    }

    _emitEvent(type, data = {}) {
        const event = {
            type,
            animationId: 0,
            currentFrame: Math.floor(this.currentFrame),
            currentTime: (this.currentFrame / this.frameRate) * 1000,
            progress: this.progress,
            loopCount: this._currentLoop,
            ...data
        };
        for (const { type: t, callback } of this._callbacks) {
            if (t === type || t === 'all') {
                callback(event);
            }
        }
    }
}

// ============================================================================
// Animation Manager
// ============================================================================

/**
 * Global animation manager
 */
class AnimationManager {
    constructor() {
        this._lottieAnimations = new Map();
        this._timelines = new Map();
        this._nextId = 1;
    }

    // Singleton
    static _instance = null;
    static shared() {
        if (!AnimationManager._instance) {
            AnimationManager._instance = new AnimationManager();
        }
        return AnimationManager._instance;
    }

    // Lottie management

    createLottie() {
        const id = this._nextId++;
        this._lottieAnimations.set(id, new LottieAnimation());
        return id;
    }

    getLottie(id) {
        return this._lottieAnimations.get(id);
    }

    loadLottieFromJson(json) {
        const id = this.createLottie();
        const animation = this._lottieAnimations.get(id);
        animation.loadFromJson(json);
        return id;
    }

    async loadLottieFromUrl(url) {
        const id = this.createLottie();
        const animation = this._lottieAnimations.get(id);
        await animation.loadFromUrl(url);
        return id;
    }

    destroyLottie(id) {
        const animation = this._lottieAnimations.get(id);
        if (animation) {
            animation.stop();
            this._lottieAnimations.delete(id);
        }
    }

    // Timeline management

    createTimeline() {
        const id = this._nextId++;
        this._timelines.set(id, new Timeline());
        return id;
    }

    getTimeline(id) {
        return this._timelines.get(id);
    }

    destroyTimeline(id) {
        const timeline = this._timelines.get(id);
        if (timeline) {
            timeline.stop();
            this._timelines.delete(id);
        }
    }

    // Global control

    pauseAll() {
        this._lottieAnimations.forEach(a => a.pause());
        this._timelines.forEach(t => t.pause());
    }

    resumeAll() {
        this._lottieAnimations.forEach(a => {
            if (a.state === PlaybackState.PAUSED) a.play();
        });
        this._timelines.forEach(t => {
            if (t.state === PlaybackState.PAUSED) t.play();
        });
    }

    stopAll() {
        this._lottieAnimations.forEach(a => a.stop());
        this._timelines.forEach(t => t.stop());
    }
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Create a simple tween animation
 */
function tween(from, to, durationMs, easing = Easing.linear) {
    const timeline = new Timeline();
    const track = timeline.addTrack('value', from);
    track.to(durationMs, to, easing);
    timeline.duration = durationMs / 1000;
    return timeline;
}

/**
 * Interpolate between two values
 */
function lerp(a, b, t) {
    return a + (b - a) * t;
}

// CSS properties that should not have units appended
const UNITLESS_PROPERTIES = new Set([
    'opacity', 'zIndex', 'z-index', 'fontWeight', 'font-weight',
    'lineHeight', 'line-height', 'flexGrow', 'flex-grow', 'flexShrink',
    'flex-shrink', 'order', 'orphans', 'widows', 'zoom', 'fillOpacity',
    'fill-opacity', 'floodOpacity', 'flood-opacity', 'stopOpacity',
    'stop-opacity', 'strokeOpacity', 'stroke-opacity', 'strokeMiterlimit',
    'stroke-miterlimit', 'columnCount', 'column-count'
]);

/**
 * Determine the appropriate CSS unit for a property
 */
function getCssUnit(property, unit) {
    // If explicit unit is provided, use it
    if (unit !== undefined) return unit;
    // No unit for unitless properties
    if (UNITLESS_PROPERTIES.has(property)) return '';
    // Default to px for most numeric properties
    return 'px';
}

/**
 * Apply animation to element style
 * @param {HTMLElement} element - Target element
 * @param {string} property - CSS property name
 * @param {number} from - Starting value
 * @param {number} to - Ending value
 * @param {number} durationMs - Duration in milliseconds
 * @param {Function} easing - Easing function (default: linear)
 * @param {string} [unit] - CSS unit (default: auto-detected based on property)
 */
function animateStyle(element, property, from, to, durationMs, easing = Easing.linear, unit) {
    const timeline = tween(from, to, durationMs, easing);
    const track = timeline.getTrack('value');
    const cssUnit = getCssUnit(property, unit);

    timeline.on('all', () => {
        const value = track.currentValue;
        element.style[property] = typeof value === 'number'
            ? value + cssUnit
            : value;
    });

    timeline.play();
    return timeline;
}

// ============================================================================
// Exports
// ============================================================================

// Create global namespace
const ZylixAnimation = {
    // Constants
    PlaybackState,
    LoopMode,
    PlayDirection,
    AnimationEventType,

    // Classes
    Timeline,
    PropertyTrack,
    LottieAnimation,
    Easing,

    // Manager
    Manager: AnimationManager,

    // Utility functions
    tween,
    lerp,
    animateStyle,
    getCssUnit,
    UNITLESS_PROPERTIES,

    // Version
    VERSION: '0.11.0'
};

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZylixAnimation;
}

if (typeof window !== 'undefined') {
    window.ZylixAnimation = ZylixAnimation;
}
