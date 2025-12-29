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

## Advanced Features

Zylix Android provides comprehensive advanced features for building production-ready applications.

### Async Operations (ZylixAsync)

Future-based async operations with coroutines integration:

```kotlin
import com.zylix.*

// Create a future from async operation
val future = ZylixFuture.from(scope) {
    delay(1000)
    "async result"
}

// Chain callbacks
future
    .then { result -> println("Got: $result") }
    .catch { error -> println("Error: $error") }
    .finally { println("Done") }

// Await in coroutine
val result = future.await()

// Static factories
val resolved = ZylixFuture.resolved("immediate")
val rejected = ZylixFuture.rejected<String>(Exception("error"))
```

### HTTP Client

```kotlin
import com.zylix.ZylixHttpClient

// Simple GET request
ZylixHttpClient.shared.get("https://api.example.com/users")
    .then { response ->
        if (response.isSuccess) {
            val json = response.json()
            println("Data: $json")
        }
    }

// POST with JSON body
ZylixHttpClient.shared.postJson(
    "https://api.example.com/users",
    JSONObject().put("name", "John")
).then { response ->
    println("Created: ${response.body}")
}
```

### Task Scheduler

```kotlin
import com.zylix.*

// Schedule a task with priority
val handle = ZylixScheduler.shared.schedule(TaskPriority.HIGH) {
    doImportantWork()
}

// Schedule with delay
ZylixScheduler.shared.scheduleDelayed(1000L, TaskPriority.NORMAL) {
    doDelayedWork()
}

// Cancel a task
handle.cancel()
```

### Animation System (ZylixAnimation)

Rich animation support with easing functions and springs:

```kotlin
import com.zylix.*

// Easing functions
val progress = ZylixEasing.easeOutBounce(t)
val cubic = ZylixEasing.easeInOutCubic(t)

// Spring animation with Compose
@Composable
fun AnimatedBox() {
    val spring = rememberSpringValue(0f, SpringConfig.bouncy)

    Box(
        Modifier
            .offset(x = spring.value.dp)
            .clickable { spring.animateTo(100f) }
    )
}

// Keyframe animation
val animation = KeyframeAnimation(listOf(
    Keyframe(0f, 0f),
    Keyframe(0.5f, 100f),
    Keyframe(1f, 50f)
))
val value = animation.getValue(progress)
```

### Hot Reload (Development)

Enable hot reload for faster development iteration:

```kotlin
import com.zylix.*

// Enable in your Activity
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHotReload()

        setContent {
            HotReloadable {
                MyAppContent()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disableHotReload()
    }
}

// Monitor state
@Composable
fun DevOverlay() {
    val state by rememberHotReloadState()

    when (state) {
        HotReloadState.CONNECTED -> Text("HMR Connected")
        HotReloadState.RELOADING -> CircularProgressIndicator()
        else -> {}
    }
}
```

### 50+ UI Components (ZylixComponents)

Pre-built Compose components for common UI patterns:

```kotlin
import com.zylix.components.*

// Modal
ZylixModal(visible = showModal, onDismiss = { showModal = false }) {
    Text("Modal Content")
}

// Tooltip
ZylixTooltip(content = { Text("Tooltip text") }) {
    Button(onClick = {}) { Text("Hover me") }
}

// Loading states
ZylixSkeleton(width = 200.dp, height = 20.dp)
ZylixSpinner(size = 48.dp)

// Form components
ZylixTextField(value = text, onValueChange = { text = it })
ZylixCheckbox(checked = isChecked, onCheckedChange = { isChecked = it })
```

## Testing

### Running Tests

```bash
# Unit tests
./gradlew :zylix-android:test

# Instrumented tests (requires emulator/device)
./gradlew :zylix-android:connectedAndroidTest
```

### Test Coverage

**ZylixAsyncTests**:
- Future state management (resolve, reject, cancel)
- Callback chains (then, catch, finally)
- HTTP response parsing
- Task priority ordering

**ZylixAnimationTests**:
- Easing function accuracy
- Spring configuration
- Keyframe interpolation

## Project Structure

```
platforms/android/
├── README.md                    # This file
├── build.gradle.kts             # Root build config
├── settings.gradle.kts          # Module settings
├── zylix-android/               # Library module
│   ├── build.gradle.kts
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   ├── cpp/
│       │   │   ├── CMakeLists.txt   # JNI build config
│       │   │   └── zylix_jni.c      # JNI bridge
│       │   ├── java/com/zylix/
│       │   │   ├── ZylixNative.kt   # JNI interface
│       │   │   ├── ZylixCore.kt     # Kotlin wrapper
│       │   │   ├── ZylixAsync.kt    # Futures, HTTP, Scheduler
│       │   │   ├── ZylixAnimation.kt # Easing, Springs, Timelines
│       │   │   ├── ZylixComponents.kt # 50+ UI components
│       │   │   └── ZylixHotReload.kt  # HMR development tools
│       │   └── jniLibs/             # Pre-built .so files
│       │       ├── arm64-v8a/
│       │       ├── armeabi-v7a/
│       │       ├── x86_64/
│       │       └── x86/
│       └── test/kotlin/com/zylix/
│           ├── ZylixAsyncTests.kt   # Async unit tests
│           └── ZylixAnimationTests.kt # Animation unit tests
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
- Zig 0.15.0+
