package com.zylix.app.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.zylix.ZylixDevice
import com.zylix.ZylixHapticsManager
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceTestScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Initialize device manager
    val device = remember { ZylixDevice.initialize(context) }

    // Permission states
    var hasLocationPermission by remember {
        mutableStateOf(device.location.hasPermission())
    }
    var hasCameraPermission by remember {
        mutableStateOf(device.camera.hasPermission())
    }
    var hasAudioPermission by remember {
        mutableStateOf(device.audio.hasRecordPermission())
    }

    // Status messages
    val statusMessages = remember { mutableStateListOf<String>() }

    fun addStatus(message: String) {
        val timestamp = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        statusMessages.add(0, "[$timestamp] $message")
        if (statusMessages.size > 20) {
            statusMessages.removeLast()
        }
    }

    // Permission launchers
    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasLocationPermission = granted
        addStatus("Location permission: ${if (granted) "granted" else "denied"}")
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasCameraPermission = granted
        addStatus("Camera permission: ${if (granted) "granted" else "denied"}")
    }

    val audioPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasAudioPermission = granted
        addStatus("Audio permission: ${if (granted) "granted" else "denied"}")
    }

    // Sensor states
    val accelerometerData by device.sensors.accelerometerData.collectAsState()
    val isAccelerometerActive by device.sensors.isAccelerometerActive.collectAsState()
    val isGyroscopeActive by device.sensors.isGyroscopeActive.collectAsState()

    // Location state
    val currentLocation by device.location.currentLocation.collectAsState()
    val isLocationUpdating by device.location.isUpdating.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Device Test") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Location Section
            item {
                SectionCard(title = "Location", icon = Icons.Default.LocationOn) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Permission")
                        Text(
                            if (hasLocationPermission) "Granted" else "Denied",
                            color = if (hasLocationPermission)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }

                    currentLocation?.let { loc ->
                        Text("Lat: ${String.format("%.4f", loc.latitude)}")
                        Text("Lon: ${String.format("%.4f", loc.longitude)}")
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = {
                                locationPermissionLauncher.launch(
                                    Manifest.permission.ACCESS_FINE_LOCATION
                                )
                            },
                            enabled = !hasLocationPermission
                        ) {
                            Text("Request")
                        }

                        Button(
                            onClick = {
                                if (isLocationUpdating) {
                                    device.location.stopUpdating()
                                    addStatus("Location updates stopped")
                                } else {
                                    device.location.startUpdating()
                                    addStatus("Location updates started")
                                }
                            },
                            enabled = hasLocationPermission
                        ) {
                            Text(if (isLocationUpdating) "Stop" else "Start")
                        }

                        Button(
                            onClick = {
                                scope.launch {
                                    try {
                                        val loc = device.location.getCurrentLocation()
                                        addStatus("Location: ${loc.latitude}, ${loc.longitude}")
                                    } catch (e: Exception) {
                                        addStatus("Location error: ${e.message}")
                                    }
                                }
                            },
                            enabled = hasLocationPermission
                        ) {
                            Text("Get")
                        }
                    }
                }
            }

            // Haptics Section
            item {
                SectionCard(title = "Haptics", icon = Icons.Default.Vibration) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Available")
                        Text(
                            if (device.haptics.isAvailable) "Yes" else "No",
                            color = if (device.haptics.isAvailable)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = {
                            device.haptics.impact(ZylixHapticsManager.ImpactStyle.LIGHT)
                            addStatus("Light haptic")
                        }) {
                            Text("Light")
                        }
                        Button(onClick = {
                            device.haptics.impact(ZylixHapticsManager.ImpactStyle.MEDIUM)
                            addStatus("Medium haptic")
                        }) {
                            Text("Medium")
                        }
                        Button(onClick = {
                            device.haptics.impact(ZylixHapticsManager.ImpactStyle.HEAVY)
                            addStatus("Heavy haptic")
                        }) {
                            Text("Heavy")
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = {
                            device.haptics.notification(ZylixHapticsManager.NotificationType.SUCCESS)
                            addStatus("Success notification")
                        }) {
                            Text("Success")
                        }
                        Button(onClick = {
                            device.haptics.notification(ZylixHapticsManager.NotificationType.ERROR)
                            addStatus("Error notification")
                        }) {
                            Text("Error")
                        }
                        Button(onClick = {
                            device.haptics.selection()
                            addStatus("Selection haptic")
                        }) {
                            Text("Tick")
                        }
                    }
                }
            }

            // Sensors Section
            item {
                SectionCard(title = "Sensors", icon = Icons.Default.Sensors) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Accelerometer")
                        Text(
                            if (device.sensors.isAccelerometerAvailable) "Available" else "N/A",
                            color = if (device.sensors.isAccelerometerAvailable)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.outline
                        )
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Gyroscope")
                        Text(
                            if (device.sensors.isGyroscopeAvailable) "Available" else "N/A",
                            color = if (device.sensors.isGyroscopeAvailable)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.outline
                        )
                    }

                    accelerometerData?.let { data ->
                        Text("Accel X: ${String.format("%.2f", data.x)}")
                        Text("Accel Y: ${String.format("%.2f", data.y)}")
                        Text("Accel Z: ${String.format("%.2f", data.z)}")
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = {
                            if (isAccelerometerActive) {
                                device.sensors.stopAccelerometer()
                                addStatus("Accelerometer stopped")
                            } else {
                                device.sensors.startAccelerometer()
                                addStatus("Accelerometer started")
                            }
                        }) {
                            Text(if (isAccelerometerActive) "Stop Accel" else "Start Accel")
                        }

                        Button(onClick = {
                            if (isGyroscopeActive) {
                                device.sensors.stopGyroscope()
                                addStatus("Gyroscope stopped")
                            } else {
                                device.sensors.startGyroscope()
                                addStatus("Gyroscope started")
                            }
                        }) {
                            Text(if (isGyroscopeActive) "Stop Gyro" else "Start Gyro")
                        }
                    }
                }
            }

            // Notifications Section
            item {
                SectionCard(title = "Notifications", icon = Icons.Default.Notifications) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Permission")
                        Text(
                            if (device.notifications.hasPermission()) "Granted" else "Denied",
                            color = if (device.notifications.hasPermission())
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }

                    Button(onClick = {
                        device.notifications.show(
                            id = System.currentTimeMillis().toInt(),
                            title = "Zylix Test",
                            body = "This is a test notification from Zylix Device"
                        )
                        addStatus("Notification shown")
                    }) {
                        Text("Show Test Notification")
                    }
                }
            }

            // Camera Section
            item {
                SectionCard(title = "Camera", icon = Icons.Default.CameraAlt) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Permission")
                        Text(
                            if (hasCameraPermission) "Granted" else "Denied",
                            color = if (hasCameraPermission)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }

                    val cameras = remember { device.camera.getAvailableCameras() }
                    Text("Available cameras: ${cameras.size}")
                    cameras.forEach { cam ->
                        Text("  ${cam.id}: ${if (cam.isFrontFacing) "Front" else "Back"}, Flash: ${cam.hasFlash}")
                    }

                    Button(
                        onClick = {
                            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                        },
                        enabled = !hasCameraPermission
                    ) {
                        Text("Request Permission")
                    }
                }
            }

            // Audio Section
            item {
                SectionCard(title = "Audio", icon = Icons.Default.Mic) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Recording Permission")
                        Text(
                            if (hasAudioPermission) "Granted" else "Denied",
                            color = if (hasAudioPermission)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }

                    Button(
                        onClick = {
                            audioPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        },
                        enabled = !hasAudioPermission
                    ) {
                        Text("Request Permission")
                    }
                }
            }

            // Status Log Section
            item {
                SectionCard(title = "Status Log", icon = Icons.Default.List) {
                    if (statusMessages.isEmpty()) {
                        Text(
                            "No status messages yet",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.outline
                        )
                    }
                }
            }

            items(statusMessages) { message ->
                Text(
                    message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.outline,
                    modifier = Modifier.padding(start = 16.dp)
                )
            }
        }
    }
}

@Composable
fun SectionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(icon, contentDescription = null)
                Text(
                    title,
                    style = MaterialTheme.typography.titleMedium
                )
            }
            content()
        }
    }
}
