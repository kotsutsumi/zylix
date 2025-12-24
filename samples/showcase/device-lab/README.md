# Device Lab Showcase

Demonstration of Zylix platform-specific device feature integration.

## Overview

This showcase demonstrates device and platform-specific capabilities:
- Motion sensors (accelerometer, gyroscope)
- Location services (GPS, compass)
- Camera and media
- Biometric authentication
- Haptic feedback
- Push notifications
- Device information

## Project Structure

```
device-lab/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig     # Entry point
│       ├── app.zig      # App state
│       └── lab.zig      # Device lab UI
└── platforms/
```

## Features

### Motion Sensors
- Accelerometer data (x, y, z)
- Gyroscope rotation rates
- Device orientation
- Shake detection

### Location Services
- GPS coordinates
- Compass heading
- Location permissions
- Distance tracking

### Camera & Media
- Photo capture
- Video recording
- Gallery access
- QR code scanning

### Biometrics
- Face ID / Face Unlock
- Touch ID / Fingerprint
- Secure authentication flow

### Haptic Feedback
- Light, medium, heavy impact
- Selection feedback
- Notification patterns
- Custom vibration

### Notifications
- Local notifications
- Push notification handling
- Badge management
- Action buttons

### Device Info
- Platform detection
- Screen metrics
- Battery status
- Network connectivity

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Initialization
void app_init(void);
void app_deinit(void);

// Feature selection
void app_select_feature(uint32_t feature);

// Motion sensors
void app_update_accelerometer(float x, float y, float z);
void app_update_gyroscope(float x, float y, float z);
void app_update_compass(float heading);

// Location
void app_update_location(double lat, double lon, float accuracy);
void app_set_location_permission(uint8_t granted);

// Camera
void app_set_camera_permission(uint8_t granted);
void app_photo_captured(void);

// Biometrics
void app_biometric_result(uint8_t success);
int32_t app_is_biometric_available(void);

// Haptic
void app_trigger_haptic(uint8_t type);

// Notifications
void app_set_notification_permission(uint8_t granted);
void app_schedule_notification(void);

// Device info
void app_set_battery_level(float level);
void app_set_network_status(uint8_t connected);
```

## Platform Integration

### iOS (Swift)
```swift
import CoreMotion
import CoreLocation
import LocalAuthentication

// Motion
let motionManager = CMMotionManager()
motionManager.startAccelerometerUpdates(to: .main) { data, _ in
    if let d = data {
        app_update_accelerometer(Float(d.acceleration.x),
                                  Float(d.acceleration.y),
                                  Float(d.acceleration.z))
    }
}

// Biometrics
let context = LAContext()
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Authenticate") { success, _ in
    app_biometric_result(success ? 1 : 0)
}
```

### Android (Kotlin)
```kotlin
import android.hardware.SensorManager
import android.location.LocationManager
import androidx.biometric.BiometricPrompt

// Motion
sensorManager.registerListener(object : SensorEventListener {
    override fun onSensorChanged(event: SensorEvent) {
        app_update_accelerometer(event.values[0],
                                  event.values[1],
                                  event.values[2])
    }
}, accelerometer, SensorManager.SENSOR_DELAY_UI)

// Biometrics
biometricPrompt.authenticate(promptInfo)
```

## Related Showcases

- [AI Playground](../ai-playground/) - AI/ML integration
- [Component Gallery](../component-gallery/) - UI components

## License

MIT License
