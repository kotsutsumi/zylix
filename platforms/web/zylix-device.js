/**
 * zylix-device.js - Web Platform Device Features for Zylix v0.10.0
 *
 * Provides native device API integration using Web APIs:
 * - Geolocation API for location services
 * - Vibration API for haptic feedback
 * - Generic Sensor API for accelerometer/gyroscope
 * - Notification API for notifications
 * - MediaDevices API for camera/audio
 */

// ============================================================================
// Location Manager
// ============================================================================

class ZylixLocationManager {
    constructor() {
        this._watchId = null;
        this._currentLocation = null;
        this._isUpdating = false;
        this._listeners = new Set();
    }

    /**
     * Check if geolocation is available
     */
    get isAvailable() {
        return 'geolocation' in navigator;
    }

    /**
     * Check if permission is granted (best effort - may not be accurate)
     */
    async hasPermission() {
        if (!this.isAvailable) return false;
        try {
            const result = await navigator.permissions.query({ name: 'geolocation' });
            return result.state === 'granted';
        } catch {
            return false;
        }
    }

    /**
     * Get current location
     */
    getCurrentLocation(options = {}) {
        return new Promise((resolve, reject) => {
            if (!this.isAvailable) {
                reject(new Error('Geolocation not available'));
                return;
            }

            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const loc = this._toZylixLocation(position);
                    this._currentLocation = loc;
                    this._notifyListeners(loc);
                    resolve(loc);
                },
                (error) => {
                    reject(new Error(this._getErrorMessage(error)));
                },
                {
                    enableHighAccuracy: options.highAccuracy ?? true,
                    timeout: options.timeout ?? 10000,
                    maximumAge: options.maximumAge ?? 0,
                }
            );
        });
    }

    /**
     * Start continuous location updates
     */
    startUpdating(options = {}) {
        if (!this.isAvailable || this._isUpdating) return;

        this._watchId = navigator.geolocation.watchPosition(
            (position) => {
                const loc = this._toZylixLocation(position);
                this._currentLocation = loc;
                this._notifyListeners(loc);
            },
            (error) => {
                console.error('[ZylixLocation] Watch error:', this._getErrorMessage(error));
            },
            {
                enableHighAccuracy: options.highAccuracy ?? true,
                timeout: options.timeout ?? 10000,
                maximumAge: options.maximumAge ?? 1000,
            }
        );
        this._isUpdating = true;
    }

    /**
     * Stop location updates
     */
    stopUpdating() {
        if (this._watchId !== null) {
            navigator.geolocation.clearWatch(this._watchId);
            this._watchId = null;
        }
        this._isUpdating = false;
    }

    /**
     * Get current location (cached)
     */
    get currentLocation() {
        return this._currentLocation;
    }

    /**
     * Check if updates are active
     */
    get isUpdating() {
        return this._isUpdating;
    }

    /**
     * Subscribe to location updates
     */
    subscribe(listener) {
        this._listeners.add(listener);
        return () => this._listeners.delete(listener);
    }

    _toZylixLocation(position) {
        return {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            altitude: position.coords.altitude,
            accuracy: position.coords.accuracy,
            altitudeAccuracy: position.coords.altitudeAccuracy,
            heading: position.coords.heading,
            speed: position.coords.speed,
            timestamp: position.timestamp,
        };
    }

    _notifyListeners(location) {
        this._listeners.forEach(listener => {
            try {
                listener(location);
            } catch (e) {
                console.error('[ZylixLocation] Listener error:', e);
            }
        });
    }

    _getErrorMessage(error) {
        switch (error.code) {
            case error.PERMISSION_DENIED:
                return 'Location permission denied';
            case error.POSITION_UNAVAILABLE:
                return 'Location unavailable';
            case error.TIMEOUT:
                return 'Location request timeout';
            default:
                return 'Unknown location error';
        }
    }
}

// ============================================================================
// Haptics Manager
// ============================================================================

class ZylixHapticsManager {
    /**
     * Check if vibration is available
     */
    get isAvailable() {
        return 'vibrate' in navigator;
    }

    /**
     * Trigger impact feedback
     * @param {string} style - 'light' | 'medium' | 'heavy' | 'rigid' | 'soft'
     */
    impact(style = 'medium') {
        if (!this.isAvailable) return;

        const patterns = {
            light: [10],
            medium: [25],
            heavy: [50],
            rigid: [5, 5, 5],
            soft: [15, 10, 15],
        };

        navigator.vibrate(patterns[style] || patterns.medium);
    }

    /**
     * Trigger notification feedback
     * @param {string} type - 'success' | 'warning' | 'error'
     */
    notification(type = 'success') {
        if (!this.isAvailable) return;

        const patterns = {
            success: [10, 50, 10],
            warning: [25, 50, 25],
            error: [50, 100, 50, 100, 50],
        };

        navigator.vibrate(patterns[type] || patterns.success);
    }

    /**
     * Trigger selection feedback
     */
    selection() {
        if (!this.isAvailable) return;
        navigator.vibrate([5]);
    }

    /**
     * Custom vibration pattern
     * @param {number[]} pattern - Array of durations in ms
     */
    vibrate(pattern) {
        if (!this.isAvailable) return;
        navigator.vibrate(pattern);
    }

    /**
     * Stop vibration
     */
    stop() {
        if (!this.isAvailable) return;
        navigator.vibrate(0);
    }
}

// ============================================================================
// Sensors Manager
// ============================================================================

class ZylixSensorsManager {
    constructor() {
        this._accelerometer = null;
        this._gyroscope = null;
        this._accelerometerData = null;
        this._gyroscopeData = null;
        this._accelerometerListeners = new Set();
        this._gyroscopeListeners = new Set();
    }

    /**
     * Check if accelerometer is available
     */
    get isAccelerometerAvailable() {
        return 'Accelerometer' in window;
    }

    /**
     * Check if gyroscope is available
     */
    get isGyroscopeAvailable() {
        return 'Gyroscope' in window;
    }

    /**
     * Get current accelerometer data
     */
    get accelerometerData() {
        return this._accelerometerData;
    }

    /**
     * Get current gyroscope data
     */
    get gyroscopeData() {
        return this._gyroscopeData;
    }

    /**
     * Check if accelerometer is active
     */
    get isAccelerometerActive() {
        return this._accelerometer !== null;
    }

    /**
     * Check if gyroscope is active
     */
    get isGyroscopeActive() {
        return this._gyroscope !== null;
    }

    /**
     * Start accelerometer
     */
    async startAccelerometer(frequency = 60) {
        if (!this.isAccelerometerAvailable) {
            throw new Error('Accelerometer not available');
        }

        try {
            // Request permission if needed (iOS Safari)
            if (typeof DeviceMotionEvent !== 'undefined' &&
                typeof DeviceMotionEvent.requestPermission === 'function') {
                const permission = await DeviceMotionEvent.requestPermission();
                if (permission !== 'granted') {
                    throw new Error('Accelerometer permission denied');
                }
            }

            this._accelerometer = new Accelerometer({ frequency });
            this._accelerometer.addEventListener('reading', () => {
                this._accelerometerData = {
                    x: this._accelerometer.x,
                    y: this._accelerometer.y,
                    z: this._accelerometer.z,
                    timestamp: Date.now(),
                };
                this._notifyAccelerometerListeners(this._accelerometerData);
            });
            this._accelerometer.addEventListener('error', (event) => {
                console.error('[ZylixSensors] Accelerometer error:', event.error);
            });
            this._accelerometer.start();
        } catch (error) {
            // Fallback to DeviceMotionEvent
            this._startDeviceMotion();
        }
    }

    /**
     * Stop accelerometer
     */
    stopAccelerometer() {
        if (this._accelerometer) {
            this._accelerometer.stop();
            this._accelerometer = null;
        }
        window.removeEventListener('devicemotion', this._deviceMotionHandler);
    }

    /**
     * Start gyroscope
     */
    async startGyroscope(frequency = 60) {
        if (!this.isGyroscopeAvailable) {
            throw new Error('Gyroscope not available');
        }

        try {
            // Request permission if needed (iOS Safari)
            if (typeof DeviceOrientationEvent !== 'undefined' &&
                typeof DeviceOrientationEvent.requestPermission === 'function') {
                const permission = await DeviceOrientationEvent.requestPermission();
                if (permission !== 'granted') {
                    throw new Error('Gyroscope permission denied');
                }
            }

            this._gyroscope = new Gyroscope({ frequency });
            this._gyroscope.addEventListener('reading', () => {
                this._gyroscopeData = {
                    x: this._gyroscope.x,
                    y: this._gyroscope.y,
                    z: this._gyroscope.z,
                    timestamp: Date.now(),
                };
                this._notifyGyroscopeListeners(this._gyroscopeData);
            });
            this._gyroscope.addEventListener('error', (event) => {
                console.error('[ZylixSensors] Gyroscope error:', event.error);
            });
            this._gyroscope.start();
        } catch (error) {
            // Fallback to DeviceOrientationEvent
            this._startDeviceOrientation();
        }
    }

    /**
     * Stop gyroscope
     */
    stopGyroscope() {
        if (this._gyroscope) {
            this._gyroscope.stop();
            this._gyroscope = null;
        }
        window.removeEventListener('deviceorientation', this._deviceOrientationHandler);
    }

    /**
     * Subscribe to accelerometer updates
     */
    subscribeAccelerometer(listener) {
        this._accelerometerListeners.add(listener);
        return () => this._accelerometerListeners.delete(listener);
    }

    /**
     * Subscribe to gyroscope updates
     */
    subscribeGyroscope(listener) {
        this._gyroscopeListeners.add(listener);
        return () => this._gyroscopeListeners.delete(listener);
    }

    _startDeviceMotion() {
        this._deviceMotionHandler = (event) => {
            const acc = event.accelerationIncludingGravity;
            if (acc) {
                this._accelerometerData = {
                    x: acc.x || 0,
                    y: acc.y || 0,
                    z: acc.z || 0,
                    timestamp: Date.now(),
                };
                this._notifyAccelerometerListeners(this._accelerometerData);
            }
        };
        window.addEventListener('devicemotion', this._deviceMotionHandler);
        this._accelerometer = true; // Mark as active
    }

    _startDeviceOrientation() {
        this._deviceOrientationHandler = (event) => {
            this._gyroscopeData = {
                alpha: event.alpha || 0,
                beta: event.beta || 0,
                gamma: event.gamma || 0,
                timestamp: Date.now(),
            };
            this._notifyGyroscopeListeners(this._gyroscopeData);
        };
        window.addEventListener('deviceorientation', this._deviceOrientationHandler);
        this._gyroscope = true; // Mark as active
    }

    _notifyAccelerometerListeners(data) {
        this._accelerometerListeners.forEach(listener => {
            try {
                listener(data);
            } catch (e) {
                console.error('[ZylixSensors] Accelerometer listener error:', e);
            }
        });
    }

    _notifyGyroscopeListeners(data) {
        this._gyroscopeListeners.forEach(listener => {
            try {
                listener(data);
            } catch (e) {
                console.error('[ZylixSensors] Gyroscope listener error:', e);
            }
        });
    }
}

// ============================================================================
// Notifications Manager
// ============================================================================

class ZylixNotificationsManager {
    /**
     * Check if notifications are available
     */
    get isAvailable() {
        return 'Notification' in window;
    }

    /**
     * Check if permission is granted
     */
    hasPermission() {
        if (!this.isAvailable) return false;
        return Notification.permission === 'granted';
    }

    /**
     * Request notification permission
     */
    async requestPermission() {
        if (!this.isAvailable) return false;
        const result = await Notification.requestPermission();
        return result === 'granted';
    }

    /**
     * Show a notification
     */
    show(options = {}) {
        if (!this.hasPermission()) {
            console.warn('[ZylixNotifications] Permission not granted');
            return null;
        }

        const notification = new Notification(options.title || 'Zylix', {
            body: options.body || '',
            icon: options.icon || undefined,
            badge: options.badge || undefined,
            tag: options.tag || undefined,
            requireInteraction: options.requireInteraction || false,
            silent: options.silent || false,
            data: options.data || undefined,
        });

        if (options.onClick) {
            notification.onclick = options.onClick;
        }

        if (options.onClose) {
            notification.onclose = options.onClose;
        }

        if (options.onError) {
            notification.onerror = options.onError;
        }

        return notification;
    }

    /**
     * Schedule a notification (requires Service Worker)
     */
    async schedule(options = {}) {
        if (!('serviceWorker' in navigator)) {
            throw new Error('Service Worker not supported');
        }

        const registration = await navigator.serviceWorker.ready;

        if (!registration.showNotification) {
            throw new Error('Notification API not supported in Service Worker');
        }

        return registration.showNotification(options.title || 'Zylix', {
            body: options.body || '',
            icon: options.icon || undefined,
            badge: options.badge || undefined,
            tag: options.tag || undefined,
            requireInteraction: options.requireInteraction || false,
            silent: options.silent || false,
            data: options.data || undefined,
        });
    }
}

// ============================================================================
// Camera Manager
// ============================================================================

class ZylixCameraManager {
    constructor() {
        this._stream = null;
        this._videoElement = null;
    }

    /**
     * Check if camera is available
     */
    get isAvailable() {
        return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
    }

    /**
     * Check if permission is granted
     */
    async hasPermission() {
        if (!this.isAvailable) return false;
        try {
            const result = await navigator.permissions.query({ name: 'camera' });
            return result.state === 'granted';
        } catch {
            return false;
        }
    }

    /**
     * Get available cameras
     */
    async getAvailableCameras() {
        if (!this.isAvailable) return [];

        try {
            const devices = await navigator.mediaDevices.enumerateDevices();
            return devices
                .filter(device => device.kind === 'videoinput')
                .map((device, index) => ({
                    id: device.deviceId,
                    label: device.label || `Camera ${index + 1}`,
                    isFrontFacing: device.label.toLowerCase().includes('front') ||
                                   device.label.toLowerCase().includes('facetime'),
                    hasFlash: false, // Web API doesn't expose flash info
                }));
        } catch (error) {
            console.error('[ZylixCamera] Error enumerating devices:', error);
            return [];
        }
    }

    /**
     * Start camera preview
     */
    async startPreview(videoElement, options = {}) {
        if (!this.isAvailable) {
            throw new Error('Camera not available');
        }

        const constraints = {
            video: {
                facingMode: options.facingMode || 'environment',
                width: options.width ? { ideal: options.width } : undefined,
                height: options.height ? { ideal: options.height } : undefined,
                deviceId: options.deviceId ? { exact: options.deviceId } : undefined,
            },
        };

        try {
            this._stream = await navigator.mediaDevices.getUserMedia(constraints);
            this._videoElement = videoElement;
            videoElement.srcObject = this._stream;
            await videoElement.play();
        } catch (error) {
            throw new Error(`Failed to start camera: ${error.message}`);
        }
    }

    /**
     * Stop camera preview
     */
    stopPreview() {
        if (this._stream) {
            this._stream.getTracks().forEach(track => track.stop());
            this._stream = null;
        }
        if (this._videoElement) {
            this._videoElement.srcObject = null;
            this._videoElement = null;
        }
    }

    /**
     * Capture photo from video stream
     */
    capturePhoto(options = {}) {
        if (!this._videoElement || !this._stream) {
            throw new Error('Camera not started');
        }

        const canvas = document.createElement('canvas');
        canvas.width = options.width || this._videoElement.videoWidth;
        canvas.height = options.height || this._videoElement.videoHeight;

        const ctx = canvas.getContext('2d');
        ctx.drawImage(this._videoElement, 0, 0, canvas.width, canvas.height);

        return canvas.toDataURL(options.format || 'image/jpeg', options.quality || 0.9);
    }

    /**
     * Check if camera is active
     */
    get isActive() {
        return this._stream !== null;
    }
}

// ============================================================================
// Audio Manager
// ============================================================================

class ZylixAudioManager {
    constructor() {
        this._mediaRecorder = null;
        this._audioChunks = [];
        this._stream = null;
        this._audioContext = null;
        this._isRecording = false;
    }

    /**
     * Check if audio recording is available
     */
    get isRecordingAvailable() {
        return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
    }

    /**
     * Check if audio playback is available
     */
    get isPlaybackAvailable() {
        return 'AudioContext' in window || 'webkitAudioContext' in window;
    }

    /**
     * Check if recording permission is granted
     */
    async hasRecordPermission() {
        if (!this.isRecordingAvailable) return false;
        try {
            const result = await navigator.permissions.query({ name: 'microphone' });
            return result.state === 'granted';
        } catch {
            return false;
        }
    }

    /**
     * Start audio recording
     */
    async startRecording(options = {}) {
        if (!this.isRecordingAvailable) {
            throw new Error('Audio recording not available');
        }

        if (this._isRecording) {
            throw new Error('Already recording');
        }

        try {
            this._stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: options.echoCancellation ?? true,
                    noiseSuppression: options.noiseSuppression ?? true,
                    autoGainControl: options.autoGainControl ?? true,
                },
            });

            this._audioChunks = [];
            this._mediaRecorder = new MediaRecorder(this._stream, {
                mimeType: options.mimeType || 'audio/webm',
            });

            this._mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this._audioChunks.push(event.data);
                }
            };

            this._mediaRecorder.start(options.timeslice || 1000);
            this._isRecording = true;
        } catch (error) {
            throw new Error(`Failed to start recording: ${error.message}`);
        }
    }

    /**
     * Stop audio recording
     */
    stopRecording() {
        return new Promise((resolve, reject) => {
            if (!this._isRecording || !this._mediaRecorder) {
                reject(new Error('Not recording'));
                return;
            }

            this._mediaRecorder.onstop = () => {
                const blob = new Blob(this._audioChunks, { type: 'audio/webm' });
                this._cleanup();
                resolve(blob);
            };

            this._mediaRecorder.stop();
        });
    }

    /**
     * Cancel recording
     */
    cancelRecording() {
        if (this._mediaRecorder && this._isRecording) {
            this._mediaRecorder.stop();
        }
        this._cleanup();
    }

    /**
     * Play audio from URL or Blob
     */
    async play(source) {
        if (!this.isPlaybackAvailable) {
            throw new Error('Audio playback not available');
        }

        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        this._audioContext = new AudioContextClass();

        let arrayBuffer;
        if (source instanceof Blob) {
            arrayBuffer = await source.arrayBuffer();
        } else if (typeof source === 'string') {
            const response = await fetch(source);
            arrayBuffer = await response.arrayBuffer();
        } else {
            throw new Error('Invalid audio source');
        }

        const audioBuffer = await this._audioContext.decodeAudioData(arrayBuffer);
        const sourceNode = this._audioContext.createBufferSource();
        sourceNode.buffer = audioBuffer;
        sourceNode.connect(this._audioContext.destination);
        sourceNode.start();

        return sourceNode;
    }

    /**
     * Get current volume level (for visualization)
     */
    async getInputLevel() {
        if (!this._stream) return 0;

        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        const audioContext = new AudioContextClass();
        const analyser = audioContext.createAnalyser();
        const source = audioContext.createMediaStreamSource(this._stream);
        source.connect(analyser);

        const dataArray = new Uint8Array(analyser.frequencyBinCount);
        analyser.getByteFrequencyData(dataArray);

        const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
        return average / 255;
    }

    /**
     * Check if currently recording
     */
    get isRecording() {
        return this._isRecording;
    }

    _cleanup() {
        if (this._stream) {
            this._stream.getTracks().forEach(track => track.stop());
            this._stream = null;
        }
        this._mediaRecorder = null;
        this._audioChunks = [];
        this._isRecording = false;
    }
}

// ============================================================================
// Zylix Device (Unified Manager)
// ============================================================================

class ZylixDevice {
    constructor() {
        this.location = new ZylixLocationManager();
        this.haptics = new ZylixHapticsManager();
        this.sensors = new ZylixSensorsManager();
        this.notifications = new ZylixNotificationsManager();
        this.camera = new ZylixCameraManager();
        this.audio = new ZylixAudioManager();
    }

    /**
     * Get device info
     */
    getDeviceInfo() {
        return {
            platform: 'web',
            userAgent: navigator.userAgent,
            language: navigator.language,
            languages: navigator.languages,
            online: navigator.onLine,
            cookieEnabled: navigator.cookieEnabled,
            doNotTrack: navigator.doNotTrack,
            maxTouchPoints: navigator.maxTouchPoints,
            hardwareConcurrency: navigator.hardwareConcurrency,
            deviceMemory: navigator.deviceMemory,
            connection: navigator.connection ? {
                effectiveType: navigator.connection.effectiveType,
                downlink: navigator.connection.downlink,
                rtt: navigator.connection.rtt,
                saveData: navigator.connection.saveData,
            } : null,
        };
    }

    /**
     * Get battery info (if available)
     */
    async getBatteryInfo() {
        if (!('getBattery' in navigator)) {
            return null;
        }

        try {
            const battery = await navigator.getBattery();
            return {
                charging: battery.charging,
                level: battery.level,
                chargingTime: battery.chargingTime,
                dischargingTime: battery.dischargingTime,
            };
        } catch {
            return null;
        }
    }

    /**
     * Get screen info
     */
    getScreenInfo() {
        return {
            width: window.screen.width,
            height: window.screen.height,
            availWidth: window.screen.availWidth,
            availHeight: window.screen.availHeight,
            colorDepth: window.screen.colorDepth,
            pixelDepth: window.screen.pixelDepth,
            orientation: window.screen.orientation ? {
                type: window.screen.orientation.type,
                angle: window.screen.orientation.angle,
            } : null,
            devicePixelRatio: window.devicePixelRatio,
        };
    }

    /**
     * Request wake lock (keep screen on)
     */
    async requestWakeLock() {
        if (!('wakeLock' in navigator)) {
            throw new Error('Wake Lock API not supported');
        }

        return navigator.wakeLock.request('screen');
    }

    /**
     * Check if feature is available
     */
    isFeatureAvailable(feature) {
        switch (feature) {
            case 'location':
                return this.location.isAvailable;
            case 'haptics':
                return this.haptics.isAvailable;
            case 'accelerometer':
                return this.sensors.isAccelerometerAvailable;
            case 'gyroscope':
                return this.sensors.isGyroscopeAvailable;
            case 'notifications':
                return this.notifications.isAvailable;
            case 'camera':
                return this.camera.isAvailable;
            case 'audio':
                return this.audio.isRecordingAvailable;
            case 'battery':
                return 'getBattery' in navigator;
            case 'wakeLock':
                return 'wakeLock' in navigator;
            default:
                return false;
        }
    }
}

// ============================================================================
// Singleton Instance
// ============================================================================

const zylixDevice = new ZylixDevice();

// ============================================================================
// Export
// ============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        ZylixDevice,
        ZylixLocationManager,
        ZylixHapticsManager,
        ZylixSensorsManager,
        ZylixNotificationsManager,
        ZylixCameraManager,
        ZylixAudioManager,
        zylixDevice,
    };
} else if (typeof window !== 'undefined') {
    window.ZylixDevice = ZylixDevice;
    window.ZylixLocationManager = ZylixLocationManager;
    window.ZylixHapticsManager = ZylixHapticsManager;
    window.ZylixSensorsManager = ZylixSensorsManager;
    window.ZylixNotificationsManager = ZylixNotificationsManager;
    window.ZylixCameraManager = ZylixCameraManager;
    window.ZylixAudioManager = ZylixAudioManager;
    window.zylixDevice = zylixDevice;
}
