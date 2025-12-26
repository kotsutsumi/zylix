---
title: "C ABI"
weight: 1
---

# C ABI Reference

The C ABI module (`abi.zig`) provides the public interface for platform shells to interact with Zylix Core.

## Constants

### ABI_VERSION

```c
#define ZYLIX_ABI_VERSION 2
```

Current ABI version number. Bumped when breaking changes are made.

## Result Codes

```c
typedef enum {
    ZYLIX_OK = 0,
    ZYLIX_ERR_INVALID_ARG = 1,
    ZYLIX_ERR_OUT_OF_MEMORY = 2,
    ZYLIX_ERR_INVALID_STATE = 3,
    ZYLIX_ERR_NOT_INITIALIZED = 4
} ZylixResult;
```

## Lifecycle Functions

### zylix_init

```c
int32_t zylix_init(void);
```

Initialize Zylix Core. Must be called before any other functions.

**Returns:** `0` on success, error code on failure.

**Example:**

```c
if (zylix_init() != 0) {
    fprintf(stderr, "Failed to initialize: %s\n", zylix_get_last_error());
    return 1;
}
```

### zylix_deinit

```c
int32_t zylix_deinit(void);
```

Shutdown Zylix Core and release resources.

**Returns:** `0` on success.

### zylix_get_abi_version

```c
uint32_t zylix_get_abi_version(void);
```

Get the ABI version number.

**Returns:** ABI version (currently `2`).

## State Access

### zylix_get_state

```c
const ABIState* zylix_get_state(void);
```

Get a read-only pointer to the current state.

**Returns:** Pointer to `ABIState` structure, or `NULL` if not initialized.

**ABIState Structure:**

```c
typedef struct {
    uint64_t version;           // State version (monotonically increasing)
    uint32_t screen;            // Current screen ID
    bool loading;               // Loading indicator
    const char* error_message;  // Last error message (null-terminated)
    const void* view_data;      // Application-specific view data
    size_t view_data_size;      // Size of view_data
} ABIState;
```

### zylix_get_state_version

```c
uint64_t zylix_get_state_version(void);
```

Get the current state version.

**Returns:** State version number, or `0` if not initialized.

## Event Dispatch

### zylix_dispatch

```c
int32_t zylix_dispatch(
    uint32_t event_type,
    const void* payload,
    size_t payload_len
);
```

Dispatch an event immediately.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `event_type` | `uint32_t` | Event type identifier (see Events) |
| `payload` | `const void*` | Event payload data (can be `NULL`) |
| `payload_len` | `size_t` | Payload length in bytes |

**Returns:** `0` on success, error code on failure.

**Example:**

```c
// Dispatch counter increment
zylix_dispatch(0x1000, NULL, 0);

// Dispatch button press with payload
ButtonEvent btn = { .button_id = 1 };
zylix_dispatch(0x0100, &btn, sizeof(btn));
```

## Event Queue (Phase 2)

### zylix_queue_event

```c
int32_t zylix_queue_event(
    uint32_t event_type,
    const void* payload,
    size_t payload_len,
    uint8_t priority
);
```

Queue an event for later processing.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `event_type` | `uint32_t` | Event type identifier |
| `payload` | `const void*` | Event payload data |
| `payload_len` | `size_t` | Payload length (max 256 bytes) |
| `priority` | `uint8_t` | Priority level (0-3) |

**Priority Levels:**

| Value | Name | Description |
|-------|------|-------------|
| 0 | Low | Background events |
| 1 | Normal | Standard UI events |
| 2 | High | Important events |
| 3 | Immediate | Bypasses queue, processed immediately |

**Returns:** `0` on success.

### zylix_process_events

```c
uint32_t zylix_process_events(uint32_t max_events);
```

Process queued events.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `max_events` | `uint32_t` | Maximum events to process |

**Returns:** Number of events actually processed.

### zylix_queue_depth

```c
uint32_t zylix_queue_depth(void);
```

Get the number of events in the queue.

**Returns:** Number of queued events.

### zylix_queue_clear

```c
void zylix_queue_clear(void);
```

Clear all queued events.

## Diff Functions (Phase 2)

### zylix_get_diff

```c
const ABIDiff* zylix_get_diff(void);
```

Get the diff since the last state change.

**Returns:** Pointer to `ABIDiff` structure, or `NULL` if not initialized.

**ABIDiff Structure:**

```c
typedef struct {
    uint64_t changed_mask;  // Bitmask of changed fields
    uint16_t change_count;  // Number of fields changed
    uint64_t version;       // State version at time of diff
} ABIDiff;
```

### zylix_field_changed

```c
bool zylix_field_changed(uint16_t field_id);
```

Check if a specific field changed.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `field_id` | `uint16_t` | Field identifier (0-63) |

**Returns:** `true` if the field changed.

**Field IDs for AppState:**

| ID | Field | Description |
|----|-------|-------------|
| 0 | `counter` | Counter value |
| 1 | `input_text` | Input text buffer |
| 2 | `input_len` | Input text length |

## Haptics API

### zylix_haptics_pulse

```c
int32_t zylix_haptics_pulse(void);
```

Trigger a simple haptic pulse with medium intensity.

**Returns:** `0` on success.

### zylix_haptics_pulse_with_intensity

```c
int32_t zylix_haptics_pulse_with_intensity(uint8_t intensity);
```

Trigger a haptic pulse with preset intensity.

**Parameters:**

| Value | Intensity |
|-------|-----------|
| 0 | Soft |
| 1 | Light |
| 2 | Medium |
| 3 | Strong |
| 4 | Heavy |

### zylix_haptics_tick

```c
int32_t zylix_haptics_tick(void);
```

Quick tick pulse for UI interactions.

### zylix_haptics_success / warning / error

```c
int32_t zylix_haptics_success(void);
int32_t zylix_haptics_warning(void);
int32_t zylix_haptics_error(void);
```

Notification feedback haptics.

### zylix_haptics_set_enabled

```c
void zylix_haptics_set_enabled(bool enabled);
```

Enable or disable haptics globally.

### zylix_haptics_is_available

```c
bool zylix_haptics_is_available(void);
```

Check if haptics are available on this platform.

## Error Handling

### zylix_get_last_error

```c
const char* zylix_get_last_error(void);
```

Get the last error message.

**Returns:** Null-terminated error message string.

## Utility Functions

### zylix_copy_string

```c
size_t zylix_copy_string(
    const char* src,
    size_t src_len,
    char* dst,
    size_t dst_len
);
```

Safely copy a string from Zylix memory to a shell buffer.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `src` | `const char*` | Source string pointer |
| `src_len` | `size_t` | Source string length |
| `dst` | `char*` | Destination buffer |
| `dst_len` | `size_t` | Destination buffer size |

**Returns:** Number of bytes copied (excluding null terminator).

The destination is always null-terminated if `dst_len > 0`.
