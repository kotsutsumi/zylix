package com.zylix

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager as Camera2Manager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

// ============================================================================
// Device Error Types
// ============================================================================

sealed class ZylixDeviceError : Exception() {
    data object PermissionDenied : ZylixDeviceError()
    data object DeviceNotAvailable : ZylixDeviceError()
    data object NotInitialized : ZylixDeviceError()
    data object RecordingError : ZylixDeviceError()
    data class Unknown(override val message: String) : ZylixDeviceError()
}

// ============================================================================
// Location Manager
// ============================================================================

/**
 * Location manager for GPS and network-based location services.
 */
class ZylixLocationManager(private val context: Context) {

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private val _currentLocation = MutableStateFlow<Location?>(null)
    val currentLocation: StateFlow<Location?> = _currentLocation.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private var locationListener: LocationListener? = null

    val isLocationEnabled: Boolean
        get() = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Start receiving location updates.
     */
    @SuppressLint("MissingPermission")
    fun startUpdating(minTimeMs: Long = 1000, minDistanceM: Float = 1f) {
        if (!hasPermission()) return
        if (_isUpdating.value) return

        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                _currentLocation.value = location
            }

            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        val provider = when {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> return
        }

        locationManager.requestLocationUpdates(
            provider,
            minTimeMs,
            minDistanceM,
            locationListener!!
        )
        _isUpdating.value = true
    }

    /**
     * Stop receiving location updates.
     */
    fun stopUpdating() {
        locationListener?.let {
            locationManager.removeUpdates(it)
            locationListener = null
        }
        _isUpdating.value = false
    }

    /**
     * Get current location as a one-shot request.
     */
    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): Location {
        if (!hasPermission()) {
            throw ZylixDeviceError.PermissionDenied
        }

        return suspendCancellableCoroutine { continuation ->
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    locationManager.removeUpdates(this)
                    continuation.resume(location)
                }

                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {
                    locationManager.removeUpdates(this)
                    continuation.resumeWithException(ZylixDeviceError.DeviceNotAvailable)
                }
            }

            val provider = when {
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                    LocationManager.GPS_PROVIDER
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                    LocationManager.NETWORK_PROVIDER
                else -> {
                    continuation.resumeWithException(ZylixDeviceError.DeviceNotAvailable)
                    return@suspendCancellableCoroutine
                }
            }

            locationManager.requestLocationUpdates(provider, 0, 0f, listener)

            continuation.invokeOnCancellation {
                locationManager.removeUpdates(listener)
            }
        }
    }

    /**
     * Get last known location (cached).
     */
    @SuppressLint("MissingPermission")
    fun getLastKnownLocation(): Location? {
        if (!hasPermission()) return null

        return locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
    }

    /**
     * Calculate distance between two locations in meters.
     */
    fun distance(from: Location, to: Location): Float {
        return from.distanceTo(to)
    }
}

// ============================================================================
// Haptics Manager
// ============================================================================

/**
 * Haptic feedback manager for vibration effects.
 */
class ZylixHapticsManager(private val context: Context) {

    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val vibratorManager =
            context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
        vibratorManager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    val isAvailable: Boolean
        get() = vibrator.hasVibrator()

    enum class ImpactStyle { LIGHT, MEDIUM, HEAVY }
    enum class NotificationType { SUCCESS, WARNING, ERROR }

    /**
     * Trigger impact feedback.
     */
    fun impact(style: ImpactStyle, intensity: Float = 1.0f) {
        if (!isAvailable) return

        val (duration, amplitude) = when (style) {
            ImpactStyle.LIGHT -> 20L to (50 * intensity).toInt().coerceIn(1, 255)
            ImpactStyle.MEDIUM -> 40L to (128 * intensity).toInt().coerceIn(1, 255)
            ImpactStyle.HEAVY -> 60L to (255 * intensity).toInt().coerceIn(1, 255)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(duration, amplitude)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
    }

    /**
     * Trigger notification feedback.
     */
    fun notification(type: NotificationType) {
        if (!isAvailable) return

        val pattern = when (type) {
            NotificationType.SUCCESS -> longArrayOf(0, 30, 50, 30)
            NotificationType.WARNING -> longArrayOf(0, 50, 100, 50)
            NotificationType.ERROR -> longArrayOf(0, 100, 50, 100, 50, 100)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createWaveform(pattern, -1)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    /**
     * Trigger selection feedback (tick).
     */
    fun selection() {
        if (!isAvailable) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            vibrator.vibrate(
                VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(10, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(10)
        }
    }

    /**
     * Cancel any ongoing vibration.
     */
    fun cancel() {
        vibrator.cancel()
    }
}

// ============================================================================
// Sensors Manager
// ============================================================================

/**
 * Sensor data classes.
 */
data class AccelerometerData(val x: Float, val y: Float, val z: Float, val timestamp: Long)
data class GyroscopeData(val x: Float, val y: Float, val z: Float, val timestamp: Long)
data class MagnetometerData(val x: Float, val y: Float, val z: Float, val timestamp: Long)

/**
 * Sensors manager for accelerometer, gyroscope, magnetometer.
 */
class ZylixSensorsManager(context: Context) {

    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private val accelerometer: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gyroscope: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    private val magnetometer: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

    private val _accelerometerData = MutableStateFlow<AccelerometerData?>(null)
    val accelerometerData: StateFlow<AccelerometerData?> = _accelerometerData.asStateFlow()

    private val _gyroscopeData = MutableStateFlow<GyroscopeData?>(null)
    val gyroscopeData: StateFlow<GyroscopeData?> = _gyroscopeData.asStateFlow()

    private val _magnetometerData = MutableStateFlow<MagnetometerData?>(null)
    val magnetometerData: StateFlow<MagnetometerData?> = _magnetometerData.asStateFlow()

    private val _isAccelerometerActive = MutableStateFlow(false)
    val isAccelerometerActive: StateFlow<Boolean> = _isAccelerometerActive.asStateFlow()

    private val _isGyroscopeActive = MutableStateFlow(false)
    val isGyroscopeActive: StateFlow<Boolean> = _isGyroscopeActive.asStateFlow()

    private val _isMagnetometerActive = MutableStateFlow(false)
    val isMagnetometerActive: StateFlow<Boolean> = _isMagnetometerActive.asStateFlow()

    val isAccelerometerAvailable: Boolean get() = accelerometer != null
    val isGyroscopeAvailable: Boolean get() = gyroscope != null
    val isMagnetometerAvailable: Boolean get() = magnetometer != null

    private var accelerometerListener: SensorEventListener? = null
    private var gyroscopeListener: SensorEventListener? = null
    private var magnetometerListener: SensorEventListener? = null

    /**
     * Start accelerometer updates.
     */
    fun startAccelerometer(samplingPeriodUs: Int = SensorManager.SENSOR_DELAY_NORMAL) {
        if (accelerometer == null || _isAccelerometerActive.value) return

        accelerometerListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                _accelerometerData.value = AccelerometerData(
                    event.values[0], event.values[1], event.values[2], event.timestamp
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(accelerometerListener, accelerometer, samplingPeriodUs)
        _isAccelerometerActive.value = true
    }

    /**
     * Stop accelerometer updates.
     */
    fun stopAccelerometer() {
        accelerometerListener?.let {
            sensorManager.unregisterListener(it)
            accelerometerListener = null
        }
        _isAccelerometerActive.value = false
    }

    /**
     * Start gyroscope updates.
     */
    fun startGyroscope(samplingPeriodUs: Int = SensorManager.SENSOR_DELAY_NORMAL) {
        if (gyroscope == null || _isGyroscopeActive.value) return

        gyroscopeListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                _gyroscopeData.value = GyroscopeData(
                    event.values[0], event.values[1], event.values[2], event.timestamp
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(gyroscopeListener, gyroscope, samplingPeriodUs)
        _isGyroscopeActive.value = true
    }

    /**
     * Stop gyroscope updates.
     */
    fun stopGyroscope() {
        gyroscopeListener?.let {
            sensorManager.unregisterListener(it)
            gyroscopeListener = null
        }
        _isGyroscopeActive.value = false
    }

    /**
     * Start magnetometer updates.
     */
    fun startMagnetometer(samplingPeriodUs: Int = SensorManager.SENSOR_DELAY_NORMAL) {
        if (magnetometer == null || _isMagnetometerActive.value) return

        magnetometerListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                _magnetometerData.value = MagnetometerData(
                    event.values[0], event.values[1], event.values[2], event.timestamp
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(magnetometerListener, magnetometer, samplingPeriodUs)
        _isMagnetometerActive.value = true
    }

    /**
     * Stop magnetometer updates.
     */
    fun stopMagnetometer() {
        magnetometerListener?.let {
            sensorManager.unregisterListener(it)
            magnetometerListener = null
        }
        _isMagnetometerActive.value = false
    }

    /**
     * Stop all sensors.
     */
    fun stopAll() {
        stopAccelerometer()
        stopGyroscope()
        stopMagnetometer()
    }
}

// ============================================================================
// Notifications Manager
// ============================================================================

/**
 * Local notifications manager.
 */
class ZylixNotificationsManager(private val context: Context) {

    private val notificationManager = NotificationManagerCompat.from(context)

    companion object {
        const val DEFAULT_CHANNEL_ID = "zylix_default"
        const val DEFAULT_CHANNEL_NAME = "Zylix Notifications"
    }

    init {
        createDefaultChannel()
    }

    private fun createDefaultChannel() {
        val channel = NotificationChannelCompat.Builder(
            DEFAULT_CHANNEL_ID,
            NotificationManagerCompat.IMPORTANCE_DEFAULT
        )
            .setName(DEFAULT_CHANNEL_NAME)
            .setDescription("Default notification channel for Zylix")
            .build()

        notificationManager.createNotificationChannel(channel)
    }

    fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            notificationManager.areNotificationsEnabled()
        }
    }

    /**
     * Show a notification.
     */
    @SuppressLint("MissingPermission")
    fun show(
        id: Int,
        title: String,
        body: String,
        channelId: String = DEFAULT_CHANNEL_ID
    ) {
        if (!hasPermission()) return

        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(id, notification)
    }

    /**
     * Cancel a notification.
     */
    fun cancel(id: Int) {
        notificationManager.cancel(id)
    }

    /**
     * Cancel all notifications.
     */
    fun cancelAll() {
        notificationManager.cancelAll()
    }
}

// ============================================================================
// Camera Manager
// ============================================================================

/**
 * Camera information.
 */
data class CameraInfo(
    val id: String,
    val isFrontFacing: Boolean,
    val hasFlash: Boolean
)

/**
 * Camera manager for device cameras.
 * Note: For actual capture, use CameraX in your UI layer.
 */
class ZylixCameraManager(private val context: Context) {

    private val cameraManager: Camera2Manager =
        context.getSystemService(Context.CAMERA_SERVICE) as Camera2Manager

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Get available cameras.
     */
    fun getAvailableCameras(): List<CameraInfo> {
        return try {
            cameraManager.cameraIdList.map { id ->
                val characteristics = cameraManager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val hasFlash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false

                CameraInfo(
                    id = id,
                    isFrontFacing = facing == CameraCharacteristics.LENS_FACING_FRONT,
                    hasFlash = hasFlash
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Get back camera ID.
     */
    fun getBackCameraId(): String? {
        return getAvailableCameras().find { !it.isFrontFacing }?.id
    }

    /**
     * Get front camera ID.
     */
    fun getFrontCameraId(): String? {
        return getAvailableCameras().find { it.isFrontFacing }?.id
    }
}

// ============================================================================
// Audio Manager
// ============================================================================

/**
 * Audio recording and playback manager.
 */
class ZylixAudioManager(private val context: Context) {

    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _recordingFile = MutableStateFlow<File?>(null)
    val recordingFile: StateFlow<File?> = _recordingFile.asStateFlow()

    fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Start recording audio.
     */
    @SuppressLint("MissingPermission")
    fun startRecording(outputFile: File? = null): File {
        if (!hasRecordPermission()) {
            throw ZylixDeviceError.PermissionDenied
        }

        if (_isRecording.value) {
            throw ZylixDeviceError.RecordingError
        }

        val file = outputFile ?: File(
            context.cacheDir,
            "zylix_recording_${System.currentTimeMillis()}.m4a"
        )

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128000)
            setAudioSamplingRate(44100)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }

        _isRecording.value = true
        _recordingFile.value = file
        return file
    }

    /**
     * Stop recording.
     */
    fun stopRecording(): File? {
        mediaRecorder?.apply {
            stop()
            release()
        }
        mediaRecorder = null
        _isRecording.value = false
        return _recordingFile.value
    }

    /**
     * Play audio from file.
     */
    fun play(file: File, onCompletion: (() -> Unit)? = null) {
        if (_isPlaying.value) {
            stopPlaying()
        }

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            setDataSource(file.absolutePath)
            setOnCompletionListener {
                _isPlaying.value = false
                onCompletion?.invoke()
            }
            prepare()
            start()
        }
        _isPlaying.value = true
    }

    /**
     * Stop playback.
     */
    fun stopPlaying() {
        mediaPlayer?.apply {
            stop()
            release()
        }
        mediaPlayer = null
        _isPlaying.value = false
    }

    /**
     * Pause playback.
     */
    fun pause() {
        mediaPlayer?.pause()
        _isPlaying.value = false
    }

    /**
     * Resume playback.
     */
    fun resume() {
        mediaPlayer?.start()
        _isPlaying.value = true
    }

    /**
     * Release all resources.
     */
    fun release() {
        stopRecording()
        stopPlaying()
    }
}

// ============================================================================
// Unified Device Manager
// ============================================================================

/**
 * Unified device manager providing access to all device features.
 */
class ZylixDevice private constructor(context: Context) {

    val location: ZylixLocationManager = ZylixLocationManager(context)
    val haptics: ZylixHapticsManager = ZylixHapticsManager(context)
    val sensors: ZylixSensorsManager = ZylixSensorsManager(context)
    val notifications: ZylixNotificationsManager = ZylixNotificationsManager(context)
    val camera: ZylixCameraManager = ZylixCameraManager(context)
    val audio: ZylixAudioManager = ZylixAudioManager(context)

    companion object {
        @Volatile
        private var instance: ZylixDevice? = null

        /**
         * Initialize the device manager. Must be called with application context.
         */
        fun initialize(context: Context): ZylixDevice {
            return instance ?: synchronized(this) {
                instance ?: ZylixDevice(context.applicationContext).also { instance = it }
            }
        }

        /**
         * Get the shared instance. Must call initialize() first.
         */
        fun getInstance(): ZylixDevice {
            return instance ?: throw ZylixDeviceError.NotInitialized
        }
    }

    /**
     * Release all device resources.
     */
    fun release() {
        location.stopUpdating()
        sensors.stopAll()
        audio.release()
    }
}
