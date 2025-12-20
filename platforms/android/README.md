# Zylix Android Platform

Kotlin bindings for Zylix Core with Jetpack Compose.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│            Jetpack Compose App Layer                     │
│  ┌─────────────┐  ┌─────────────────────────────────┐   │
│  │ TodoScreen  │  │ TodoViewModel                   │   │
│  │ Composables │  │ (StateFlow auto-sync)           │   │
│  └─────────────┘  └─────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│              zylix-android Library                       │
│  ┌─────────────────────────────────────────────────┐    │
│  │ ZylixCore.kt                                     │    │
│  │ - initialize() / shutdown()                      │    │
│  │ - dispatch(eventType)                            │    │
│  │ - stateVersionFlow                               │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────┘
                          │ JNI
┌─────────────────────────▼───────────────────────────────┐
│              Native Bridge (zylix_jni.c)                 │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Java_com_zylix_ZylixNative_*()                  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│              libzylix.so (Zig → ARM64/ARM/x86_64/x86)   │
└─────────────────────────────────────────────────────────┘
```

## Building

### 1. Build Zig Shared Libraries

```bash
cd core

# Build all Android ABIs
zig build android -Doptimize=ReleaseFast

# Output:
# zig-out/android/arm64-v8a/libzylix.so
# zig-out/android/armeabi-v7a/libzylix.so
# zig-out/android/x86_64/libzylix.so
# zig-out/android/x86/libzylix.so
```

### 2. Copy Libraries to jniLibs

```bash
# From project root
cp core/zig-out/android/arm64-v8a/libzylix.so platforms/android/zylix-android/src/main/jniLibs/arm64-v8a/
cp core/zig-out/android/armeabi-v7a/libzylix.so platforms/android/zylix-android/src/main/jniLibs/armeabi-v7a/
cp core/zig-out/android/x86_64/libzylix.so platforms/android/zylix-android/src/main/jniLibs/x86_64/
cp core/zig-out/android/x86/libzylix.so platforms/android/zylix-android/src/main/jniLibs/x86/
```

### 3. Build Android Project

```bash
cd platforms/android
./gradlew assembleDebug
```

### 4. Install on Device/Emulator

```bash
./gradlew installDebug
```

## Usage

### Basic Usage

```kotlin
import com.zylix.ZylixCore

// Get instance and initialize
val zylix = ZylixCore.instance
zylix.initialize()

// Dispatch an event
zylix.dispatch(0x1000)

// Check state version
println("Version: ${zylix.stateVersion}")

// Shutdown when done
zylix.shutdown()
```

### With Compose

```kotlin
import com.zylix.ZylixCore
import androidx.compose.runtime.collectAsState

@Composable
fun MyScreen() {
    val stateVersion by ZylixCore.instance.stateVersionFlow.collectAsState()

    Text("State Version: $stateVersion")

    Button(onClick = {
        ZylixCore.instance.dispatch(0x1000)
    }) {
        Text("Increment")
    }
}
```

## Project Structure

```
platforms/android/
├── README.md                    # This file
├── build.gradle.kts             # Root build config
├── settings.gradle.kts          # Module settings
├── zylix-android/               # Library module
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── cpp/
│       │   ├── CMakeLists.txt   # JNI build config
│       │   └── zylix_jni.c      # JNI bridge
│       ├── java/com/zylix/
│       │   ├── ZylixNative.kt   # JNI interface
│       │   └── ZylixCore.kt     # Kotlin wrapper
│       └── jniLibs/             # Pre-built .so files
│           ├── arm64-v8a/
│           ├── armeabi-v7a/
│           ├── x86_64/
│           └── x86/
└── demo/                        # Demo app
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        └── java/com/zylix/demo/
            ├── MainActivity.kt
            └── TodoViewModel.kt
```

## Supported ABIs

| ABI | Target | Size |
|-----|--------|------|
| arm64-v8a | 64-bit ARM | ~828KB |
| armeabi-v7a | 32-bit ARM | ~814KB |
| x86_64 | 64-bit x86 (Emulator) | ~799KB |
| x86 | 32-bit x86 (Emulator) | ~683KB |

## Event Types

| Event Type | Description |
|------------|-------------|
| `0x1000` | Counter increment |
| `0x1001` | Counter decrement |
| `0x2000` | Screen change |
| `0x3000` | Todo: Add |
| `0x3001` | Todo: Remove |
| `0x3002` | Todo: Toggle |

## Requirements

- Android SDK 24+ (Android 7.0+)
- Android Studio Hedgehog or later
- Kotlin 1.9+
- Zig 0.14.0+
