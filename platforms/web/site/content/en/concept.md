---
title: "Concept"
weight: 1
---

# Concept

## Philosophy

> **"Don't unify UI, unify meaning and decisions"**

Unlike Flutter or React Native that render custom UIs everywhere, Zylix respects each platform's native UI framework while centralizing what truly matters: **state**, **logic**, and **decisions**.

## The Problem with UI Unification

| Approach | Trade-off |
|----------|-----------|
| Flutter | Custom Skia rendering - loses native feel |
| React Native | Bridge overhead - performance issues |
| Electron | Chromium bundle - 150MB+ binaries |
| Tauri | WebView - limited native integration |

## Zylix's Solution

Zylix takes a different approach:

1. **Zig Core**: All state and logic lives in Zig
2. **C ABI Boundary**: Zero-cost FFI to native code
3. **Native UI Shells**: SwiftUI, Compose, etc. render naturally
4. **No Runtime**: Static library, no VM or GC

## Benefits

### For Users
- Native look and feel
- Native accessibility (IME, VoiceOver, TalkBack)
- Smaller app size
- Better battery life

### For Developers
- Single source of truth for logic
- Compile-time type safety
- Cross-compilation from single toolchain
- Predictable memory management

## What Gets Shared?

| Shared (Zig) | Platform-Specific |
|--------------|-------------------|
| Application state | UI components |
| Business logic | Animations |
| Data validation | Platform APIs |
| Event handling | Accessibility |
| Persistence logic | Native gestures |

## Example: Counter App

**Zig Core (shared)**:
```zig
pub const State = struct {
    counter: i64 = 0,
};

pub fn increment(state: *State) void {
    state.counter += 1;
}
```

**SwiftUI (iOS/macOS)**:
```swift
Text("\(zylixState.counter)")
Button("Increment") {
    zylix_dispatch(.increment)
}
```

**Jetpack Compose (Android)**:
```kotlin
Text("${zylixState.counter}")
Button(onClick = { zylixDispatch(INCREMENT) }) {
    Text("Increment")
}
```

Same logic, native UI, zero compromise.
