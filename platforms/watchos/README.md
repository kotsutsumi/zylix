# Zylix watchOS Platform

watchOS shell for Zylix - A counter PoC demonstration using SwiftUI and Zylix Core.

## Status

**In Development** - Minimal counter implementation with C ABI bridge.

## Architecture

```
┌─────────────────────────────────────────────┐
│              watchOS App                     │
│  ┌────────────────────────────────────────┐ │
│  │           SwiftUI Layer                 │ │
│  │  ContentView → ZylixBridge → C ABI     │ │
│  └─────────────────────┬──────────────────┘ │
│                        │                     │
│  ┌─────────────────────▼──────────────────┐ │
│  │       Zylix Core (libzylix.a)          │ │
│  │  State Management | Event Dispatch     │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Prerequisites

- **macOS** 13.0 or later
- **Xcode** 15.0 or later with watchOS SDK
- **Zig** 0.15.0 or later

```bash
# Verify installations
zig version
xcodebuild -version
xcrun simctl list devices | grep -i watch
```

## Project Structure

```
platforms/watchos/
├── README.md                      # This file
└── ZylixWatch/
    ├── Libraries/
    │   └── libzylix.a             # Zylix static library
    └── Sources/
        ├── ZylixWatchApp.swift    # App entry point
        ├── ContentView.swift      # Main UI with counter
        ├── ZylixBridge.swift      # C ABI wrapper
        └── Zylix-Bridging-Header.h # C function declarations
```

## Build Instructions

### Step 1: Build Zylix Core for watchOS

```bash
cd core

# For watchOS Simulator (recommended for development)
zig build watchos-sim

# For watchOS Device (for deployment)
zig build watchos
```

The library will be output to:
- Simulator: `core/zig-out/watchos-simulator/libzylix.a`
- Device: `core/zig-out/watchos/libzylix.a`

### Step 2: Copy Library (if not already present)

```bash
# Copy to watchOS platform
cp core/zig-out/watchos-simulator/libzylix.a platforms/watchos/ZylixWatch/Libraries/
```

### Step 3: Create Xcode Project

Since watchOS apps require an Xcode project, create one manually:

1. **Open Xcode** → File → New → Project
2. Select **watchOS** → **App**
3. Configure:
   - Product Name: `ZylixWatch`
   - Team: Your Development Team
   - Organization Identifier: Your identifier (e.g., `com.example`)
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save the project in `platforms/watchos/`

### Step 4: Configure Xcode Project

1. **Add Source Files**:
   - Drag `ZylixWatch/Sources/*.swift` into the project
   - Ensure "Copy items if needed" is **unchecked**
   - Target: `ZylixWatch Watch App`

2. **Add Static Library**:
   - Go to project settings → `ZylixWatch Watch App` target
   - Build Phases → Link Binary With Libraries
   - Click "+" → Add Other → Add Files
   - Select `ZylixWatch/Libraries/libzylix.a`

3. **Configure Bridging Header**:
   - Go to Build Settings → Swift Compiler - General
   - Set "Objective-C Bridging Header" to:
     ```
     $(PROJECT_DIR)/ZylixWatch/Sources/Zylix-Bridging-Header.h
     ```

4. **Configure Library Search Paths**:
   - Build Settings → Search Paths → Library Search Paths:
     ```
     $(PROJECT_DIR)/ZylixWatch/Libraries
     ```

5. **Configure Header Search Paths** (optional):
   - Build Settings → Search Paths → Header Search Paths:
     ```
     $(PROJECT_DIR)/ZylixWatch/Sources
     ```

### Step 5: Build and Run

**Option 1: Xcode GUI**
1. Open `ZylixWatch.xcodeproj` in Xcode
2. Select a watchOS Simulator (e.g., "Apple Watch Series 9 (45mm)")
3. Press **Cmd + R** to build and run

**Option 2: Command Line**
```bash
cd platforms/watchos

# Generate project (if not already done)
xcodegen generate

# Build for watchOS Simulator
xcodebuild -project ZylixWatch.xcodeproj \
  -target ZylixWatch \
  -sdk watchsimulator \
  build

# Install on simulator
xcrun simctl install booted build/Debug-watchsimulator/ZylixWatch.app
```

## Features

### Counter UI

The counter demo provides:
- **+ Button**: Increment counter (green)
- **- Button**: Decrement counter (red)
- **Reset Button**: Reset to 0 (orange)
- **Digital Crown**: Rotate to increment/decrement
- **State Display**: Shows initialization status and version

### C ABI Functions Used

| Function | Purpose |
|----------|---------|
| `zylix_init()` | Initialize Zylix Core |
| `zylix_deinit()` | Shutdown Zylix Core |
| `zylix_dispatch()` | Dispatch counter events |
| `zylix_get_state()` | Read current state |
| `zylix_get_abi_version()` | Get ABI version (should be 2) |
| `zylix_get_last_error()` | Get last error message |

### Event Types

| Event | Code | Description |
|-------|------|-------------|
| `ZYLIX_EVENT_COUNTER_INCREMENT` | 0x1000 | Increment counter |
| `ZYLIX_EVENT_COUNTER_DECREMENT` | 0x1001 | Decrement counter |
| `ZYLIX_EVENT_COUNTER_RESET` | 0x1002 | Reset counter to 0 |

## ABI Version

The current ABI version is **2**. Verify compatibility:

```swift
let version = zylix_get_abi_version()
assert(version == 2, "ABI version mismatch")
```

## Troubleshooting

### "undefined symbol: _zylix_init"

The static library is not linked correctly:
1. Verify `libzylix.a` is in Link Binary With Libraries
2. Check Library Search Paths includes the Libraries directory
3. Rebuild the library with `zig build watchos-sim`

### "Bridging header not found"

1. Verify the path in Build Settings is correct
2. Ensure the file exists at the specified path
3. Try using absolute path for testing

### "Simulator not available"

```bash
# List available simulators
xcrun simctl list devices | grep -i watch

# Install watchOS simulator if missing
xcodebuild -downloadPlatform watchOS
```

### "Library architecture mismatch"

Ensure you're using the correct library:
- Simulator: Build with `zig build watchos-sim`
- Device: Build with `zig build watchos`

## Testing

### Manual Testing

1. Launch the app in the watchOS Simulator
2. Verify the counter displays "0"
3. Tap the + button → counter should show "1"
4. Tap the - button → counter should show "0"
5. Tap + several times, then Reset → counter should show "0"
6. Rotate Digital Crown → counter should change

### Verify ABI Version

Check the console output on launch:
```
[ZylixWatch] Core initialized, ABI version: 2
```

## Future Improvements

- [ ] Watch Connectivity for iOS companion sync
- [ ] Complications support
- [ ] Background app refresh
- [ ] Extended runtime sessions

## Related Documentation

- [watchOS Platform Guide](../../site/content/docs/platforms/watchos.md)
- [ABI Documentation](../../docs/ABI.md)
- [iOS Platform](../ios/README.md) (similar architecture)
