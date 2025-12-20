# Zylix macOS Platform

Native macOS application with SwiftUI Todo demo.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│               SwiftUI App Layer                          │
│  ┌─────────────┐  ┌─────────────────────────────────┐   │
│  │  TodoView   │  │ TodoViewModel                   │   │
│  │ (SwiftUI)   │  │ (@Published state)              │   │
│  └─────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Future: C FFI
                          ▼
┌─────────────────────────────────────────────────────────┐
│              libzylix.dylib (Zig → ARM64/x86_64)        │
└─────────────────────────────────────────────────────────┘
```

## Building

### Prerequisites

- macOS 13.0+
- Xcode 16.0+
- XcodeGen (`brew install xcodegen`)

### 1. Generate Xcode Project

```bash
cd platforms/macos
xcodegen generate
```

### 2. Build with Xcode

```bash
xcodebuild -project Zylix.xcodeproj -scheme Zylix -configuration Debug build
```

Or open in Xcode:

```bash
open Zylix.xcodeproj
```

### 3. Run

Press ⌘R in Xcode or:

```bash
open ~/Library/Developer/Xcode/DerivedData/Zylix-*/Build/Products/Debug/Zylix\ Todo.app
```

## Project Structure

```
platforms/macos/
├── README.md                    # This file
├── project.yml                  # XcodeGen project config
├── Zylix.xcodeproj/            # Generated Xcode project
├── Zylix/
│   ├── Sources/
│   │   ├── ZylixApp.swift       # App entry point
│   │   ├── TodoView.swift       # Main Todo UI
│   │   ├── TodoViewModel.swift  # Todo state management
│   │   ├── Zylix-Bridging-Header.h  # C ABI declarations
│   │   ├── ContentView.swift    # (Legacy) Counter demo
│   │   └── ZylixBridge.swift    # (Legacy) Zig bridge
│   └── Resources/
│       └── Info.plist           # App metadata
└── build/                       # Build outputs
```

## Features

- **SwiftUI Native**: Modern declarative UI
- **macOS Design**: Native look and feel with hover effects
- **Todo Operations**: Add, toggle, delete, filter todos
- **Performance Stats**: Real-time render count and timing

## Event Types

| Event Type | Value | Description |
|------------|-------|-------------|
| `TODO_ADD` | `0x3000` | Add new todo |
| `TODO_REMOVE` | `0x3001` | Remove todo |
| `TODO_TOGGLE` | `0x3002` | Toggle completion |
| `TODO_TOGGLE_ALL` | `0x3003` | Toggle all todos |
| `TODO_CLEAR_DONE` | `0x3004` | Clear completed |
| `TODO_SET_FILTER` | `0x3005` | Set filter mode |

## Future Integration

The current demo uses pure Swift for state management. Future versions will integrate with Zylix Core via C FFI:

```swift
// Future: ZylixBridge integration
func addTodo(_ text: String) {
    let result = zylix_dispatch(ZYLIX_EVENT_TODO_ADD, text, text.count)
    if result == ZYLIX_OK {
        refreshState()
    }
}
```

## Requirements

- macOS 13.0+ (Ventura)
- Xcode 16.0+
- Swift 5.9+
- XcodeGen (for project generation)
