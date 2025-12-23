# Zylix Project - Claude Code Instructions

## Project Overview

Zylix is a cross-platform application runtime built with Zig core and native platform shells (iOS, Android, Web/WASM, Desktop).

## Project Structure

```
zylix/
├── core/                    # Zig core library
│   ├── src/
│   │   ├── main.zig        # Entry point, module exports
│   │   ├── state.zig       # State management
│   │   ├── events.zig      # Event system
│   │   ├── abi.zig         # C ABI exports for FFI
│   │   ├── ai/             # AI module (whisper, etc.)
│   │   └── animation/      # Animation module
│   │       ├── animation.zig    # Module exports
│   │       ├── timeline.zig     # Timeline and keyframe animation
│   │       ├── state_machine.zig # Animation state machine
│   │       ├── lottie.zig       # Lottie format support
│   │       └── live2d.zig       # Live2D format support
│   └── build.zig           # Zig build configuration
├── shells/
│   ├── ios/                # iOS Swift shell
│   ├── android/            # Android Kotlin shell
│   └── web/                # Web/WASM shell
└── site/                   # Documentation site
```

## Quality Verification Requirements

**IMPORTANT**: The following verification steps MUST be performed after any Zig code changes:

### Required Verification Checklist

1. **Zig Compile Check**
   ```bash
   cd core && zig build
   ```
   - Must complete without errors
   - Warnings should be addressed when possible

2. **Zig Unit Tests**
   ```bash
   cd core && zig build test
   ```
   - All tests must pass
   - New features require corresponding tests

3. **Web/WASM Build**
   ```bash
   cd core && zig build -Dtarget=wasm32-freestanding
   ```
   - Must produce valid WASM output

4. **iOS Build**
   ```bash
   cd core && zig build -Dtarget=aarch64-macos
   ```
   - Must compile for iOS target
   - Test on simulator or device when applicable

5. **Android Build**
   ```bash
   cd core && zig build -Dtarget=aarch64-linux-android
   ```
   - Must compile for Android target
   - Test on emulator or device when applicable

### When to Run Verification

- **Always run before commits**: All 5 verification steps
- **During development**: At minimum, steps 1-2 (compile and tests)
- **Before release**: Full verification including device testing

## Zig Version

This project uses **Zig 0.15.x**. Key API differences from older versions:

### ArrayList API (0.15+)
```zig
// Initialization
var list: std.ArrayList(T) = .{};  // NOT .init(allocator)

// Deinitialization
list.deinit(allocator);  // Pass allocator

// Append
list.append(allocator, item) catch {};  // Pass allocator
```

### Memory Management Patterns
- Structs with ArrayList fields should store allocator for cleanup
- Use `allocator.destroy(ptr)` after calling struct's `deinit()` for heap-allocated structs

## Build Commands Reference

```bash
# Native build
cd core && zig build

# Run tests
cd core && zig build test

# WASM build
cd core && zig build -Dtarget=wasm32-freestanding

# iOS build (aarch64)
cd core && zig build -Dtarget=aarch64-macos

# Android build (aarch64)
cd core && zig build -Dtarget=aarch64-linux-android

# Android build (x86_64 emulator)
cd core && zig build -Dtarget=x86_64-linux-android
```

## Code Style

- Follow Zig standard library conventions
- Use meaningful names for functions and variables
- Document public APIs with doc comments (`///`)
- Prefer explicit error handling over `catch {}`
- Keep functions focused and testable
