# Zylix C ABI Specification

> **Compatibility Reference**: For version compatibility and platform maturity, see [COMPATIBILITY.md](./COMPATIBILITY.md).

## Overview

Zylix Core exposes its functionality through a stable C ABI.
This document defines the contract between Zylix Core (Zig) and Platform Shells.

**Current ABI Version: 2** (as of v0.8.0)

---

## Design Principles

1. **Simplicity** - Minimal function surface
2. **Stability** - ABI changes require version bump
3. **Safety** - Clear ownership, no hidden allocations
4. **Portability** - Standard C types only

---

## Type Definitions

### Basic Types

```c
// zylix_types.h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Version
#define ZYLIX_ABI_VERSION 2

// Result codes
typedef enum {
    ZYLIX_OK = 0,
    ZYLIX_ERR_INVALID_ARG = 1,
    ZYLIX_ERR_OUT_OF_MEMORY = 2,
    ZYLIX_ERR_INVALID_STATE = 3,
    ZYLIX_ERR_NOT_INITIALIZED = 4,
} zylix_result_t;

// Event types
typedef uint32_t zylix_event_type_t;

// Opaque handle
typedef void* zylix_handle_t;
```

### State Structure

```c
// State representation for Shell consumption
typedef struct {
    uint64_t version;           // State version (monotonic)
    uint32_t screen;            // Current screen enum
    bool loading;               // Loading indicator
    const char* error_message;  // NULL if no error
    const void* view_data;      // Screen-specific data pointer
    size_t view_data_size;      // Size of view_data
} zylix_state_t;
```

---

## Core Functions

### Lifecycle

```c
/**
 * Initialize Zylix Core
 * Must be called once before any other function
 * Thread-safety: NOT thread-safe, call from main thread only
 *
 * @return ZYLIX_OK on success
 */
zylix_result_t zylix_init(void);

/**
 * Shutdown Zylix Core
 * Releases all resources
 * Thread-safety: NOT thread-safe, call from main thread only
 *
 * @return ZYLIX_OK on success
 */
zylix_result_t zylix_deinit(void);

/**
 * Get ABI version
 * Can be called before init
 *
 * @return ABI version number
 */
uint32_t zylix_get_abi_version(void);
```

### State Access

```c
/**
 * Get current state snapshot
 * Returned pointer is valid until next zylix_dispatch call
 * Thread-safety: NOT thread-safe
 *
 * @return Pointer to current state, NULL if not initialized
 */
const zylix_state_t* zylix_get_state(void);

/**
 * Get state version
 * Useful for checking if state changed without full read
 *
 * @return Current state version, 0 if not initialized
 */
uint64_t zylix_get_state_version(void);
```

### Event Dispatch

```c
/**
 * Dispatch an event to Zylix Core
 * Synchronously processes the event and updates state
 * Thread-safety: NOT thread-safe
 *
 * @param event_type  Event type identifier
 * @param payload     Event payload (can be NULL)
 * @param payload_len Payload length in bytes
 * @return ZYLIX_OK on success
 */
zylix_result_t zylix_dispatch(
    zylix_event_type_t event_type,
    const void* payload,
    size_t payload_len
);
```

### Event Queue (Phase 2, ABI v2+)

```c
/**
 * Queue an event for later processing
 * Supports priority levels for event ordering
 * Thread-safety: NOT thread-safe
 *
 * @param event_type  Event type identifier
 * @param payload     Event payload (can be NULL)
 * @param payload_len Payload length in bytes (max 256)
 * @param priority    Event priority (0=low, 1=normal, 2=high, 3=immediate)
 * @return ZYLIX_OK on success
 */
zylix_result_t zylix_queue_event(
    zylix_event_type_t event_type,
    const void* payload,
    size_t payload_len,
    uint8_t priority
);

/**
 * Process queued events
 * Events are processed in priority order (highest first)
 * Thread-safety: NOT thread-safe
 *
 * @param max_events  Maximum number of events to process (0 = all)
 * @return Number of events processed
 */
uint32_t zylix_process_events(uint32_t max_events);

/**
 * Get number of events in queue
 *
 * @return Current queue depth
 */
uint32_t zylix_queue_depth(void);

/**
 * Clear all queued events
 * Thread-safety: NOT thread-safe
 */
void zylix_queue_clear(void);
```

### State Diff (Phase 2, ABI v2+)

```c
// Diff structure
typedef struct {
    uint64_t changed_mask;  // Bitmask of changed fields
    uint32_t change_count;  // Number of changes since last check
    uint64_t version;       // State version when diff was captured
} zylix_diff_t;

/**
 * Get diff since last state change
 * Useful for incremental UI updates
 * Thread-safety: NOT thread-safe
 *
 * @return Pointer to diff, NULL if not initialized
 */
const zylix_diff_t* zylix_get_diff(void);

/**
 * Check if a specific field changed
 * Field IDs are defined per-application
 * Thread-safety: NOT thread-safe
 *
 * @param field_id  Field identifier
 * @return true if field changed since last check
 */
bool zylix_field_changed(uint16_t field_id);
```

---

## Event Types

### Standard Events

```c
// Lifecycle events (0x0000 - 0x00FF)
#define ZYLIX_EVENT_APP_INIT        0x0001
#define ZYLIX_EVENT_APP_TERMINATE   0x0002
#define ZYLIX_EVENT_APP_FOREGROUND  0x0003
#define ZYLIX_EVENT_APP_BACKGROUND  0x0004
#define ZYLIX_EVENT_APP_LOW_MEMORY  0x0005

// User interaction (0x0100 - 0x01FF)
#define ZYLIX_EVENT_BUTTON_PRESS    0x0100
#define ZYLIX_EVENT_TEXT_INPUT      0x0101
#define ZYLIX_EVENT_TEXT_COMMIT     0x0102
#define ZYLIX_EVENT_SELECTION       0x0103
#define ZYLIX_EVENT_SCROLL          0x0104
#define ZYLIX_EVENT_GESTURE         0x0105

// Navigation (0x0200 - 0x02FF)
#define ZYLIX_EVENT_NAVIGATE        0x0200
#define ZYLIX_EVENT_NAVIGATE_BACK   0x0201
#define ZYLIX_EVENT_TAB_SWITCH      0x0202

// Custom events (0x1000+)
#define ZYLIX_EVENT_CUSTOM_BASE     0x1000
```

### Event Payloads

```c
// Button press payload
typedef struct {
    uint32_t button_id;     // Application-defined button ID
} zylix_button_event_t;

// Text input payload
typedef struct {
    const char* text;       // UTF-8 encoded text
    size_t text_len;        // Length in bytes
    uint32_t field_id;      // Target field ID
} zylix_text_event_t;

// Navigation payload
typedef struct {
    uint32_t screen_id;     // Target screen
    const void* params;     // Optional parameters
    size_t params_len;
} zylix_navigate_event_t;
```

---

## Memory Ownership

### Rules

| Data | Owner | Shell Can |
|------|-------|-----------|
| `zylix_state_t*` | Zig | Read only |
| `state->error_message` | Zig | Read only |
| `state->view_data` | Zig | Read only |
| Event payload | Shell | Pass to dispatch |

### Lifetime Guarantees

```c
// State pointer valid until next dispatch
const zylix_state_t* state = zylix_get_state();
// ... use state ...
zylix_dispatch(event, payload, len);  // state pointer may be invalidated
state = zylix_get_state();            // get fresh pointer
```

### String Handling

```c
/**
 * Copy string from Zylix-owned memory to Shell-owned buffer
 * Use when string needs to outlive state snapshot
 *
 * @param src     Source string pointer (from state)
 * @param src_len Source string length in bytes
 * @param dst     Destination buffer (Shell-owned)
 * @param dst_len Destination buffer size
 * @return Number of bytes written (excluding null terminator)
 */
size_t zylix_copy_string(
    const char* src,
    size_t src_len,
    char* dst,
    size_t dst_len
);
```

---

## Error Handling

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | ZYLIX_OK | Success |
| 1 | ZYLIX_ERR_INVALID_ARG | Invalid argument passed |
| 2 | ZYLIX_ERR_OUT_OF_MEMORY | Memory allocation failed |
| 3 | ZYLIX_ERR_INVALID_STATE | Invalid internal state |
| 4 | ZYLIX_ERR_NOT_INITIALIZED | Called before init |

### Error Details

```c
/**
 * Get human-readable error message for last error
 * Thread-safety: NOT thread-safe
 *
 * @return Error message string, never NULL
 */
const char* zylix_get_last_error(void);
```

---

## Platform-Specific Bindings

### Swift (iOS/macOS)

```swift
// ZylixCore.swift

import Foundation

enum ZylixResult: Int32 {
    case ok = 0
    case invalidArg = 1
    case outOfMemory = 2
    case invalidState = 3
    case notInitialized = 4
}

struct ZylixState {
    let version: UInt64
    let screen: UInt32
    let loading: Bool
    let errorMessage: String?

    init(from ptr: UnsafePointer<zylix_state_t>) {
        let raw = ptr.pointee
        self.version = raw.version
        self.screen = raw.screen
        self.loading = raw.loading
        if let msg = raw.error_message {
            self.errorMessage = String(cString: msg)
        } else {
            self.errorMessage = nil
        }
    }
}
```

### Kotlin (Android)

```kotlin
// ZylixCore.kt

object ZylixCore {
    init {
        System.loadLibrary("zylix")
    }

    external fun init(): Int
    external fun deinit(): Int
    external fun getAbiVersion(): Int
    external fun dispatch(eventType: Int, payload: ByteArray?): Int
    external fun getStateVersion(): Long

    // JNI helper to read state into Kotlin object
    external fun getStateNative(): ZylixStateNative
}

data class ZylixState(
    val version: Long,
    val screen: Int,
    val loading: Boolean,
    val errorMessage: String?
)
```

---

## Versioning

### ABI Compatibility

- **Major version** (ZYLIX_ABI_VERSION): Breaking changes
- **State version**: Per-state monotonic counter

### Version Check Pattern

```c
// Shell should verify ABI compatibility at startup
uint32_t abi = zylix_get_abi_version();
if (abi != EXPECTED_ABI_VERSION) {
    // Handle incompatibility
}
```

---

## Thread Safety

**All functions are NOT thread-safe unless noted.**

Recommended pattern:
- Call all Zylix functions from main/UI thread only
- If background processing needed, queue events to main thread

---

## ABI Version History

| Version | Zylix Version | Changes |
|---------|---------------|---------|
| 2 | v0.8.0+ | Event queue, diff API, priority system, updated zylix_copy_string |
| 1 | v0.1.0 - v0.7.x | Initial release: lifecycle, state, dispatch |

## Future Extensions

Reserved for future ABI additions (ABI v3+):

```c
// Callback registration (planned)
typedef void (*zylix_callback_t)(zylix_event_type_t, const void*, size_t);
zylix_result_t zylix_register_callback(zylix_callback_t callback);

// Async operation (planned)
typedef uint64_t zylix_async_id_t;
zylix_async_id_t zylix_dispatch_async(zylix_event_type_t, const void*, size_t);
zylix_result_t zylix_poll_async(zylix_async_id_t);

// Component system (planned)
zylix_result_t zylix_register_component(const char* name, zylix_component_t* component);
```
