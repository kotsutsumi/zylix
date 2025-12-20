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
# iOS Simulator (arm64)
cd core
zig build ios-sim -Doptimize=ReleaseFast

# Output: zig-out/ios-simulator/libzylix.a
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
2. Add to "Library Search Paths": `$(PROJECT_DIR)/../../../core/zig-out/ios-simulator`
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
        VStack {
            Text("State Version: \(zylix.stateVersion)")

            Button("Increment") {
                zylix.dispatch(eventType: 0x1000)
            }
        }
    }
}
```

## Project Structure

```
platforms/ios/
├── README.md                 # This file
├── ZylixSwift/              # Swift Package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CZylix/          # C Bridge
│   │   │   └── include/
│   │   │       ├── zylix.h
│   │   │       └── module.modulemap
│   │   └── ZylixSwift/      # Swift Wrapper
│   │       └── ZylixCore.swift
│   └── Tests/
│       └── ZylixSwiftTests/
└── ZylixTodoDemo/           # Demo App
    ├── ZylixTodoDemo.xcodeproj
    └── ZylixTodoDemo/
        ├── ZylixTodoDemoApp.swift
        ├── ContentView.swift
        ├── TodoViewModel.swift
        └── Assets.xcassets/
```

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

- iOS 15.0+
- macOS 12.0+ (for development)
- Xcode 15.0+
- Zig 0.14.0+
