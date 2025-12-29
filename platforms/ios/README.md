# Zylix iOS Platform

Swift bindings for Zylix Core.

## Architecture

```
┌─────────────────────────────────────────────────┐
│              SwiftUI App Layer                   │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │ ContentView │  │ ZylixObservable         │   │
│  │ TodoView    │  │ (Auto state sync)       │   │
│  └─────────────┘  └─────────────────────────┘   │
└─────────────────────────┬───────────────────────┘
                          │
┌─────────────────────────▼───────────────────────┐
│              ZylixSwift Package                  │
│  ┌─────────────────────────────────────────┐    │
│  │ ZylixCore.swift                          │    │
│  │ - initialize() / shutdown()              │    │
│  │ - dispatch(eventType:payload:)           │    │
│  │ - state / diff / stateVersion           │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────┘
                          │ C ABI
┌─────────────────────────▼───────────────────────┐
│              CZylix (C Bridge)                   │
│  ┌─────────────────────────────────────────┐    │
│  │ zylix.h                                  │    │
│  │ - zylix_init() / zylix_deinit()         │    │
│  │ - zylix_dispatch()                       │    │
│  │ - zylix_get_state()                      │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────┘
                          │
┌─────────────────────────▼───────────────────────┐
│              libzylix.a (Zig → ARM64)           │
│  ┌─────────────────────────────────────────┐    │
│  │ State Management                         │    │
│  │ Event Queue                              │    │
│  │ Diff Engine                              │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Building

### 1. Build Zig Static Library

```bash
# From platforms/ios directory
./build-zig.sh

# Output:
# - lib/libzylix-macos-arm64.a  (Apple Silicon)
# - lib/libzylix-macos-x64.a    (Intel)
# - lib/libzylix.a              (Universal)
```

### 2. Import ZylixSwift Package

Add the package to your Xcode project:

```swift
// Package.swift dependency
.package(path: "../ZylixSwift")
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Add Local → Select ZylixSwift folder

### 3. Link Static Library

In Xcode:
1. Select your target → Build Settings
2. Add to "Library Search Paths": `$(PROJECT_DIR)/path/to/platforms/ios/lib`
3. Add to "Other Linker Flags": `-lzylix`

## Usage

### Basic Usage

```swift
import ZylixSwift

// Initialize
try ZylixCore.shared.initialize()

// Dispatch event
try ZylixCore.shared.dispatch(eventType: 0x1000)

// Get state
if let state = ZylixCore.shared.state {
    print("Version: \(state.version)")
    print("Loading: \(state.isLoading)")
}

// Shutdown
try ZylixCore.shared.shutdown()
```

### SwiftUI Integration

```swift
import SwiftUI
import ZylixSwift

struct ContentView: View {
    @StateObject var zylix = ZylixObservable()

    var body: some View {
        VStack(spacing: 20) {
            Text("Counter: \(zylix.counter)")
                .font(.largeTitle)

            HStack(spacing: 20) {
                Button("-") { zylix.decrement() }
                Button("Reset") { zylix.reset() }
                Button("+") { zylix.increment() }
            }
            .font(.title)

            Text("Version: \(zylix.stateVersion)")
                .font(.caption)
        }
    }
}
```

### Counter Convenience Methods

```swift
// Using ZylixCore
try ZylixCore.shared.increment()
try ZylixCore.shared.decrement()
try ZylixCore.shared.reset()
let value = ZylixCore.shared.counterValue

// Using ZylixObservable (SwiftUI)
zylix.increment()
zylix.decrement()
zylix.reset()
let counter = zylix.counter
```

## Advanced Features

ZylixSwift provides comprehensive advanced features for building production-ready applications.

### Error Boundaries

Catch and handle errors gracefully in your SwiftUI views:

```swift
import ZylixSwift

struct MyApp: View {
    var body: some View {
        ErrorBoundary {
            RiskyContent()
        } fallback: { error, retry in
            VStack {
                Text("Something went wrong: \(error.localizedDescription)")
                Button("Retry", action: retry)
            }
        }
    }
}
```

### Context API

Share state across your view hierarchy without prop drilling:

```swift
// Define your context value
class ThemeContext: ContextValue {
    @Published var isDark = false
}

// Provide context
ContextProvider(ThemeContext()) {
    ContentView()
}

// Consume context
struct ThemedButton: View {
    @UseContext var theme: ThemeContext

    var body: some View {
        Button("Toggle Theme") {
            theme.isDark.toggle()
        }
    }
}
```

### Suspense & Async Resources

Handle async data loading with elegant loading states:

```swift
// Create a resource
let userResource = createResource {
    try await api.fetchUser(id: userId)
}

// Use with Suspense
Suspense(isLoading: userResource.isLoading) {
    if let user = userResource.data {
        UserProfile(user: user)
    }
} fallback: {
    DefaultLoadingView()
}
```

### Portal/Modal System

Render content outside the normal view hierarchy:

```swift
// Simple modal
@State var showModal = false

MyView()
    .modal(isPresented: $showModal) {
        SettingsPanel()
    }

// Custom portal
Portal(id: "notification") {
    NotificationBanner(message: "Success!")
}
```

### Animation System

Rich animation support with easing functions, springs, and timelines:

```swift
// Spring animations
let spring = useSpring(initial: 0, config: .bouncy)
spring.set(100)

// Timeline animations
let timeline = Timeline(duration: 2.0)
timeline.loopMode = .pingPong
timeline.play()

// Keyframe animations
let animation = KeyframeAnimation(keyframes: [
    Keyframe(time: 0, value: 0),
    Keyframe(time: 0.5, value: 100, easing: ZylixEasing.easeOutBounce),
    Keyframe(time: 1, value: 50)
])

// Built-in easing functions
ZylixEasing.linear(_:)
ZylixEasing.easeInQuad(_:)
ZylixEasing.easeOutCubic(_:)
ZylixEasing.easeInOutExpo(_:)
ZylixEasing.spring(_:stiffness:damping:mass:)
```

### Async Operations

Future-based async operations with HTTP client and task scheduling:

```swift
// HTTP Client
let response = ZylixHttpClient.shared.get("https://api.example.com/users")
response.then { result in
    let users = try result.decode([User].self)
}

// Task scheduling with priorities
ZylixScheduler.shared.schedule(priority: .high) {
    await processImportantTask()
}

// Retry with backoff
let result = try await retry(maxAttempts: 3) {
    try await api.fetchData()
}
```

### Hot Reload (Development)

Enable hot reload for faster development iteration:

```swift
// Enable in your app
ZylixHotReloadClient.shared.connect()

// Wrap views for hot reload
HotReloadable {
    ContentView()
}

// Show dev tools
DevToolsOverlay()
```

### Event Type Enum

```swift
// Using EventType enum
try ZylixCore.shared.dispatch(.counterIncrement)
try ZylixCore.shared.dispatch(.counterDecrement)
try ZylixCore.shared.dispatch(.navigate, payload: data)

// Available event types
ZylixCore.EventType.appInit           // 0x0001
ZylixCore.EventType.counterIncrement  // 0x1000
ZylixCore.EventType.counterDecrement  // 0x1001
ZylixCore.EventType.counterReset      // 0x1002
```

## Demo App

The Zylix iOS demo app showcases both Counter and TodoMVC implementations in a TabView interface.

### Features

- **Counter Tab**: Demonstrates Zylix Core integration via C FFI
  - Increment/Decrement/Reset functionality
  - Real-time state synchronization with Zig backend

- **Todos Tab**: Pure SwiftUI TodoMVC implementation
  - Add, edit, and delete todos
  - Toggle completion status
  - Filter by All/Active/Completed
  - Toggle all / Clear completed

### Running the Demo

```bash
# Build and run on iOS Simulator
xcodebuild -project Zylix.xcodeproj -scheme Zylix \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' \
  build

# Install and launch
xcrun simctl install "iPhone 16 Pro" ~/Library/Developer/Xcode/DerivedData/Zylix-*/Build/Products/Debug-iphonesimulator/Zylix.app
xcrun simctl launch "iPhone 16 Pro" com.zylix.app
```

## Testing

The project includes comprehensive unit tests for the TodoViewModel.

### Running Tests

```bash
xcodebuild test -project Zylix.xcodeproj -scheme ZylixTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2'
```

### Test Coverage

**TodoViewModelTests** (36 tests):
- Initial state validation
- Add/remove todo operations
- Toggle individual and all todos
- Filter functionality (All/Active/Completed)
- Clear completed
- Text editing with whitespace handling
- Computed properties (counts, allCompleted)
- TodoItem and FilterMode tests

**ZylixAdvancedTests** (40+ tests):
- Future/Promise pattern (resolve, reject, cancel, callbacks)
- HTTP Response parsing
- Task scheduler and priority
- Animation easing functions
- Modal and VirtualList configuration
- HotReload state management

## Project Structure

```
platforms/ios/
├── README.md                 # This file
├── Zylix.xcodeproj/         # Main Xcode project
├── Zylix/
│   ├── Sources/
│   │   ├── ZylixApp.swift       # App entry with TabView
│   │   ├── ContentView.swift    # Counter demo
│   │   ├── TodoView.swift       # TodoMVC UI
│   │   ├── TodoViewModel.swift  # TodoMVC state management
│   │   ├── ZylixBridge.swift    # C FFI bridge
│   │   └── Zylix-Bridging-Header.h
│   ├── Resources/
│   │   └── Info.plist
│   └── Libraries/
│       └── libzylix.a           # Zig static library
├── ZylixTests/              # Unit tests
│   └── TodoViewModelTests.swift
├── ZylixSwift/              # Swift Package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CZylix/          # C Bridge
│   │   │   └── include/
│   │   │       ├── zylix.h
│   │   │       └── module.modulemap
│   │   └── ZylixSwift/      # Swift Wrapper
│   │       ├── ZylixCore.swift      # Core FFI integration
│   │       ├── ZylixAdvanced.swift  # Error Boundaries, Context, Suspense
│   │       ├── ZylixAnimation.swift # Easing, Springs, Timelines
│   │       ├── ZylixAsync.swift     # Futures, HTTP, Scheduler
│   │       └── ZylixHotReload.swift # HMR development tools
│   └── Tests/
│       └── ZylixSwiftTests/
│           ├── ZylixSwiftTests.swift
│           └── ZylixAdvancedTests.swift
└── ZylixTodoDemo/           # Legacy Demo App
    └── ...
```

## Event Types

| Event Type | Constant | Description |
|------------|----------|-------------|
| `0x0001` | `ZYLIX_EVENT_APP_INIT` | App initialization |
| `0x0002` | `ZYLIX_EVENT_APP_TERMINATE` | App termination |
| `0x0003` | `ZYLIX_EVENT_APP_FOREGROUND` | App entering foreground |
| `0x0004` | `ZYLIX_EVENT_APP_BACKGROUND` | App entering background |
| `0x0100` | `ZYLIX_EVENT_BUTTON_PRESS` | Button press with ID |
| `0x0101` | `ZYLIX_EVENT_TEXT_INPUT` | Text input |
| `0x0200` | `ZYLIX_EVENT_NAVIGATE` | Navigate to screen |
| `0x0201` | `ZYLIX_EVENT_NAVIGATE_BACK` | Navigate back |
| `0x1000` | `ZYLIX_EVENT_COUNTER_INCREMENT` | Counter increment |
| `0x1001` | `ZYLIX_EVENT_COUNTER_DECREMENT` | Counter decrement |
| `0x1002` | `ZYLIX_EVENT_COUNTER_RESET` | Counter reset |

## Requirements

- iOS 15.0+
- macOS 12.0+ (for development)
- Xcode 15.0+
- Zig 0.15.0+
