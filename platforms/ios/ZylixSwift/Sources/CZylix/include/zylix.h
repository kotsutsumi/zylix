/**
 * @file zylix.h
 * @brief Zylix Core C ABI Interface for Native Platforms
 *
 * This header provides the public C interface for Zylix Core.
 * Use this header to integrate Zylix with Swift, Objective-C, or other native code.
 */

#ifndef ZYLIX_H
#define ZYLIX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Version Information
// =============================================================================

/**
 * Current ABI version number.
 * Bumped when the ABI changes in incompatible ways.
 */
#define ZYLIX_ABI_VERSION 2

// =============================================================================
// Result Codes
// =============================================================================

/**
 * Result codes returned by Zylix functions.
 */
typedef enum {
    ZYLIX_OK = 0,                    /**< Success */
    ZYLIX_ERR_INVALID_ARG = 1,       /**< Invalid argument provided */
    ZYLIX_ERR_OUT_OF_MEMORY = 2,     /**< Out of memory */
    ZYLIX_ERR_INVALID_STATE = 3,     /**< Invalid state for operation */
    ZYLIX_ERR_NOT_INITIALIZED = 4,   /**< Core not initialized */
} ZylixResult;

// =============================================================================
// Event Priority
// =============================================================================

/**
 * Priority levels for queued events.
 */
typedef enum {
    ZYLIX_PRIORITY_LOW = 0,          /**< Low priority, processed last */
    ZYLIX_PRIORITY_NORMAL = 1,       /**< Normal priority (default) */
    ZYLIX_PRIORITY_HIGH = 2,         /**< High priority */
    ZYLIX_PRIORITY_IMMEDIATE = 3,    /**< Bypass queue, process immediately */
} ZylixPriority;

// =============================================================================
// Data Structures
// =============================================================================

/**
 * ABI-compatible state snapshot.
 *
 * This structure is returned by zylix_get_state() and provides
 * a C-compatible view of the current application state.
 */
typedef struct {
    uint64_t version;                /**< State version number (increments on changes) */
    uint32_t screen;                 /**< Current screen identifier */
    bool loading;                    /**< Whether a loading operation is in progress */
    const char* error_message;       /**< Current error message (null-terminated) or NULL */
    const void* view_data;           /**< Opaque pointer to view-specific data */
} ZylixState;

/**
 * ABI-compatible diff information.
 *
 * This structure describes what changed since the last state update.
 */
typedef struct {
    uint64_t changed_mask;           /**< Bitmask of changed field IDs */
    uint8_t change_count;            /**< Number of fields that changed */
    uint64_t version;                /**< Version when diff was computed */
} ZylixDiff;

// =============================================================================
// Lifecycle Functions
// =============================================================================

/**
 * Initialize Zylix Core.
 *
 * Must be called before any other Zylix functions.
 * Safe to call multiple times (subsequent calls are no-ops).
 *
 * @return ZYLIX_OK on success
 */
int32_t zylix_init(void);

/**
 * Shutdown Zylix Core.
 *
 * Releases all resources held by Zylix.
 * After this call, zylix_init() must be called again before using other functions.
 *
 * @return ZYLIX_OK on success
 */
int32_t zylix_deinit(void);

/**
 * Get the ABI version number.
 *
 * Use this to verify compatibility between the header and library.
 *
 * @return ABI version number
 */
uint32_t zylix_get_abi_version(void);

// =============================================================================
// State Access Functions
// =============================================================================

/**
 * Get current state snapshot.
 *
 * The returned pointer is valid until the next state-modifying call.
 * Do not free the returned pointer.
 *
 * @return Pointer to current state, or NULL if not initialized
 */
const ZylixState* zylix_get_state(void);

/**
 * Get state version number.
 *
 * The version increments each time the state changes.
 * Use this to detect when UI updates are needed.
 *
 * @return Current state version, or 0 if not initialized
 */
uint64_t zylix_get_state_version(void);

// =============================================================================
// Event Dispatch
// =============================================================================

/**
 * Dispatch an event immediately.
 *
 * The event is processed synchronously before this function returns.
 *
 * @param event_type Event type identifier
 * @param payload    Optional payload data (can be NULL)
 * @param payload_len Length of payload in bytes
 * @return ZYLIX_OK on success, error code otherwise
 */
int32_t zylix_dispatch(
    uint32_t event_type,
    const void* payload,
    size_t payload_len
);

// =============================================================================
// Event Queue Functions
// =============================================================================

/**
 * Queue an event for later processing.
 *
 * Events are processed in priority order during zylix_process_events().
 *
 * @param event_type  Event type identifier
 * @param payload     Optional payload data (can be NULL)
 * @param payload_len Length of payload in bytes (max 256 bytes)
 * @param priority    Event priority (see ZylixPriority)
 * @return ZYLIX_OK on success, error code otherwise
 */
int32_t zylix_queue_event(
    uint32_t event_type,
    const void* payload,
    size_t payload_len,
    uint8_t priority
);

/**
 * Process queued events.
 *
 * Processes up to max_events from the queue in priority order.
 * Call this regularly (e.g., once per frame) to process pending events.
 *
 * @param max_events Maximum number of events to process
 * @return Number of events actually processed
 */
uint32_t zylix_process_events(uint32_t max_events);

/**
 * Get number of events in queue.
 *
 * @return Current queue depth
 */
uint32_t zylix_queue_depth(void);

/**
 * Clear all queued events.
 */
void zylix_queue_clear(void);

// =============================================================================
// Diff Functions
// =============================================================================

/**
 * Get diff since last state change.
 *
 * The returned pointer is valid until the next state-modifying call.
 *
 * @return Pointer to diff information, or NULL if not initialized
 */
const ZylixDiff* zylix_get_diff(void);

/**
 * Check if a specific field changed.
 *
 * @param field_id Field identifier to check
 * @return true if the field changed, false otherwise
 */
bool zylix_field_changed(uint16_t field_id);

// =============================================================================
// Error Handling
// =============================================================================

/**
 * Get last error message.
 *
 * Returns a human-readable description of the last error.
 *
 * @return Null-terminated error message string
 */
const char* zylix_get_last_error(void);

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Copy string from Zylix memory to external buffer.
 *
 * Safely copies a string, ensuring null-termination.
 *
 * @param src     Source string pointer
 * @param src_len Source string length
 * @param dst     Destination buffer
 * @param dst_len Destination buffer size
 * @return Number of characters copied (excluding null terminator)
 */
size_t zylix_copy_string(
    const char* src,
    size_t src_len,
    char* dst,
    size_t dst_len
);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_H */
