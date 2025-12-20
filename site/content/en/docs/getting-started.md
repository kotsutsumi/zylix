---
title: Getting Started
weight: 1
prev: /docs
next: architecture
---

Get up and running with Zylix in minutes.

## Prerequisites

- [Zig](https://ziglang.org/) 0.13 or later
- Platform-specific tools (see below)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

### 2. Build the Core Library

```bash
cd core
zig build
```

This builds `libzylix.a` for your current platform.

### 3. Build for Specific Platforms

{{< tabs items="Web/WASM,iOS,Android,macOS,Linux,Windows" >}}

{{< tab >}}
```bash
# Build WASM
zig build wasm -Doptimize=ReleaseSmall

# Output: zig-out/lib/zylix.wasm
```
{{< /tab >}}

{{< tab >}}
```bash
# Build for iOS
zig build ios -Doptimize=ReleaseFast

# Open Xcode project
cd platforms/ios
xcodegen generate
open Zylix.xcodeproj
```
{{< /tab >}}

{{< tab >}}
```bash
# Build for Android
zig build android -Doptimize=ReleaseFast

# Open in Android Studio
cd platforms/android/zylix-android
./gradlew assembleDebug
```
{{< /tab >}}

{{< tab >}}
```bash
# Build for macOS
zig build -Doptimize=ReleaseFast

# Open Xcode project
cd platforms/macos
xcodegen generate
open Zylix.xcodeproj
```
{{< /tab >}}

{{< tab >}}
```bash
# Build for Linux
zig build linux -Doptimize=ReleaseFast

# Build GTK app
cd platforms/linux/zylix-gtk
make
./build/zylix-todo
```
{{< /tab >}}

{{< tab >}}
```bash
# Build for Windows
zig build windows-x64 -Doptimize=ReleaseFast

# Build with .NET
cd platforms/windows/Zylix
dotnet build -c Release
dotnet run
```
{{< /tab >}}

{{< /tabs >}}

## Project Structure

```
zylix/
├── core/                 # Zig core library
│   └── src/
│       ├── vdom.zig      # Virtual DOM engine
│       ├── diff.zig      # Diff algorithm
│       ├── component.zig # Component system
│       ├── state.zig     # State management
│       ├── todo.zig      # Todo app logic
│       └── wasm.zig      # WASM bindings
├── platforms/
│   ├── web/              # Web/WASM demos
│   ├── ios/              # iOS/SwiftUI
│   ├── android/          # Android/Kotlin
│   ├── macos/            # macOS/SwiftUI
│   ├── linux/            # Linux/GTK4
│   └── windows/          # Windows/WinUI 3
└── site/                 # This documentation
```

## Next Steps

- [Architecture](architecture) - Learn how Zylix works
- [Platforms](platforms) - Platform-specific guides
- [API Reference](api) - Detailed API documentation
