# Zylix Compatibility Reference

> **Note**: This is the single source of truth for version compatibility, platform maturity, and ABI specifications. All other documents should reference this file.

## Version Information

| Component | Version | Notes |
|-----------|---------|-------|
| **Zylix Framework** | 0.25.0 | Current stable release |
| **ABI Version** | 2 | Breaking changes from v1 |
| **Zig Required** | 0.15.0+ | CI uses 0.15.2 |

## Zig Compatibility

### Supported Versions

| Zig Version | Status | Notes |
|-------------|--------|-------|
| 0.15.x | **Recommended** | CI tested, production ready |
| 0.14.x | Compatible | May work, not officially tested |
| < 0.14.0 | Unsupported | Breaking changes in language |

### Installation

```bash
# Verify installation
zig version
# Expected: 0.15.0 or higher

# Download from https://ziglang.org/download/
```

## Platform Maturity Matrix

| Platform | Framework | Status | Integration | Notes |
|----------|-----------|--------|-------------|-------|
| Web/WASM | HTML/JavaScript | Production Ready | Full | JavaScript SDK available |
| iOS | SwiftUI | Production Ready | Full | ZylixSwift package with C FFI |
| macOS | SwiftUI | Production Ready | Full | Shares ZylixSwift with iOS |
| watchOS | SwiftUI | In Development | Partial | Companion app and driver support |
| Android | Jetpack Compose | In Development | Partial | UI demo only, JNI pending |
| Linux | GTK4 | In Development | Partial | Build infrastructure ready |
| Windows | WinUI 3 | In Development | Partial | Build infrastructure ready |

### Status Definitions

- **Production Ready**: Full Zig core integration, tested in production scenarios
- **In Development**: Build infrastructure ready, core integration pending

## ABI Specification

### Current ABI Version: 2

The ABI version is defined in `core/src/abi.zig`:

```zig
pub const ABI_VERSION: u32 = 2;
```

### ABI Version History

| Version | Changes | Zylix Version |
|---------|---------|---------------|
| 2 | Added event queue, diff API, priority system | v0.8.0+ |
| 1 | Initial release: lifecycle, state, dispatch | v0.1.0 - v0.7.x |

### Exported Functions (ABI v2)

#### Phase 1 Functions (ABI v1+)

| Function | Signature | Description |
|----------|-----------|-------------|
| `zylix_init` | `() -> i32` | Initialize Zylix Core |
| `zylix_deinit` | `() -> i32` | Shutdown Zylix Core |
| `zylix_get_abi_version` | `() -> u32` | Get ABI version |
| `zylix_get_state` | `() -> *const State` | Get current state snapshot |
| `zylix_get_state_version` | `() -> u64` | Get state version |
| `zylix_dispatch` | `(u32, *void, usize) -> i32` | Dispatch event synchronously |
| `zylix_get_last_error` | `() -> *const u8` | Get last error message |
| `zylix_copy_string` | `(*u8, usize, *u8, usize) -> usize` | Copy string safely |

#### Phase 2 Functions (ABI v2+)

| Function | Signature | Description |
|----------|-----------|-------------|
| `zylix_queue_event` | `(u32, *void, usize, u8) -> i32` | Queue event with priority |
| `zylix_process_events` | `(u32) -> u32` | Process queued events |
| `zylix_queue_depth` | `() -> u32` | Get queue depth |
| `zylix_queue_clear` | `() -> void` | Clear event queue |
| `zylix_get_diff` | `() -> *const Diff` | Get state diff |
| `zylix_field_changed` | `(u16) -> bool` | Check if field changed |

### Result Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | `ZYLIX_OK` | Success |
| 1 | `ZYLIX_ERR_INVALID_ARG` | Invalid argument passed |
| 2 | `ZYLIX_ERR_OUT_OF_MEMORY` | Memory allocation failed |
| 3 | `ZYLIX_ERR_INVALID_STATE` | Invalid internal state |
| 4 | `ZYLIX_ERR_NOT_INITIALIZED` | Called before init |

### Event Priority (ABI v2)

| Value | Priority | Behavior |
|-------|----------|----------|
| 0 | Low | Processed after normal events |
| 1 | Normal | Default priority |
| 2 | High | Processed before normal events |
| 3 | Immediate | Bypasses queue, processed synchronously |

## API Compatibility

### JavaScript SDK

```javascript
import { init, state, todo } from 'zylix';

// Initialize with WASM
await init('path/to/zylix.wasm');

// State operations
state.increment();
console.log(state.getCounter());

// Todo operations
todo.init();
todo.add('Task');
```

### Swift (iOS/macOS)

```swift
import ZylixSwift

// Initialize
ZylixCore.initialize()

// Dispatch event
ZylixCore.dispatch(.counterIncrement)

// Get state
let state = ZylixCore.getState()
```

### Kotlin (Android)

```kotlin
import dev.zylix.core.ZylixCore

// Initialize
ZylixCore.init()

// Dispatch event
ZylixCore.dispatch(ZylixEvent.COUNTER_INCREMENT)

// Get state
val state = ZylixCore.getState()
```

## Breaking Changes

### v0.8.0 (ABI v2)

- ABI version bumped from 1 to 2
- Added event queue system with priority support
- Added diff API for efficient state change detection
- `zylix_copy_string` signature updated (added src_len parameter)

### Migration from ABI v1 to v2

#### zylix_copy_string Migration

The signature changed to include source length:

```c
// ABI v1 (old)
size_t zylix_copy_string(const char* src, char* dst, size_t dst_len);

// ABI v2 (new)
size_t zylix_copy_string(const char* src, size_t src_len, char* dst, size_t dst_len);
```

**Platform binding updates required:**

```swift
// Swift (iOS/macOS) - Before
let copied = zylix_copy_string(src, dst, dstLen)

// Swift (iOS/macOS) - After
let copied = zylix_copy_string(src, srcLen, dst, dstLen)
```

```kotlin
// Kotlin (Android) - Before
val copied = ZylixNative.copyString(src, dst, dstLen)

// Kotlin (Android) - After
val copied = ZylixNative.copyString(src, srcLen, dst, dstLen)
```

#### ABI Version Check

```c
// Check ABI version at startup
uint32_t abi = zylix_get_abi_version();
if (abi < 2) {
    // Legacy mode: no event queue, no diff
}
```

## Related Documents

- [ABI.md](./ABI.md) - Detailed C ABI specification
- [API_REFERENCE.md](./API_REFERENCE.md) - Complete API documentation
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [ROADMAP.md](./ROADMAP.md) - Development roadmap
