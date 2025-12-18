/**
 * Zylix Core - C ABI Header
 *
 * This header provides the C interface for integrating Zylix Core
 * with platform shells (iOS/Android/Desktop).
 */

#ifndef ZYLIX_H
#define ZYLIX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* === Version === */

#define ZYLIX_ABI_VERSION 1

/* === Result Codes === */

typedef enum {
    ZYLIX_OK = 0,
    ZYLIX_ERR_INVALID_ARG = 1,
    ZYLIX_ERR_OUT_OF_MEMORY = 2,
    ZYLIX_ERR_INVALID_STATE = 3,
    ZYLIX_ERR_NOT_INITIALIZED = 4,
} zylix_result_t;

/* === Event Types === */

/* Lifecycle events */
#define ZYLIX_EVENT_APP_INIT        0x0001
#define ZYLIX_EVENT_APP_TERMINATE   0x0002
#define ZYLIX_EVENT_APP_FOREGROUND  0x0003
#define ZYLIX_EVENT_APP_BACKGROUND  0x0004
#define ZYLIX_EVENT_APP_LOW_MEMORY  0x0005

/* User interaction */
#define ZYLIX_EVENT_BUTTON_PRESS    0x0100
#define ZYLIX_EVENT_TEXT_INPUT      0x0101
#define ZYLIX_EVENT_TEXT_COMMIT     0x0102
#define ZYLIX_EVENT_SELECTION       0x0103
#define ZYLIX_EVENT_SCROLL          0x0104
#define ZYLIX_EVENT_GESTURE         0x0105

/* Navigation */
#define ZYLIX_EVENT_NAVIGATE        0x0200
#define ZYLIX_EVENT_NAVIGATE_BACK   0x0201
#define ZYLIX_EVENT_TAB_SWITCH      0x0202

/* Counter PoC events */
#define ZYLIX_EVENT_COUNTER_INCREMENT 0x1000
#define ZYLIX_EVENT_COUNTER_DECREMENT 0x1001
#define ZYLIX_EVENT_COUNTER_RESET     0x1002

/* Custom events base */
#define ZYLIX_EVENT_CUSTOM_BASE     0x2000

/* === State Structure === */

typedef struct {
    uint64_t version;           /* State version (monotonic) */
    uint32_t screen;            /* Current screen enum */
    bool loading;               /* Loading indicator */
    const char* error_message;  /* NULL if no error */
    const void* view_data;      /* Screen-specific data pointer */
    size_t view_data_size;      /* Size of view_data */
} zylix_state_t;

/* === Event Payloads === */

typedef struct {
    uint32_t button_id;
} zylix_button_event_t;

typedef struct {
    const char* text;
    size_t text_len;
    uint32_t field_id;
} zylix_text_event_t;

typedef struct {
    uint32_t screen_id;
    const void* params;
    size_t params_len;
} zylix_navigate_event_t;

/* === Lifecycle Functions === */

/**
 * Initialize Zylix Core.
 * Must be called once before any other function.
 *
 * @return ZYLIX_OK on success
 */
int32_t zylix_init(void);

/**
 * Shutdown Zylix Core.
 * Releases all resources.
 *
 * @return ZYLIX_OK on success
 */
int32_t zylix_deinit(void);

/**
 * Get ABI version.
 * Can be called before init.
 *
 * @return ABI version number
 */
uint32_t zylix_get_abi_version(void);

/* === State Access Functions === */

/**
 * Get current state snapshot.
 * Returned pointer is valid until next zylix_dispatch call.
 *
 * @return Pointer to current state, NULL if not initialized
 */
const zylix_state_t* zylix_get_state(void);

/**
 * Get state version.
 * Useful for checking if state changed.
 *
 * @return Current state version, 0 if not initialized
 */
uint64_t zylix_get_state_version(void);

/* === Event Dispatch === */

/**
 * Dispatch an event to Zylix Core.
 * Synchronously processes the event and updates state.
 *
 * @param event_type  Event type identifier
 * @param payload     Event payload (can be NULL)
 * @param payload_len Payload length in bytes
 * @return ZYLIX_OK on success
 */
int32_t zylix_dispatch(
    uint32_t event_type,
    const void* payload,
    size_t payload_len
);

/* === Error Handling === */

/**
 * Get human-readable error message for last error.
 *
 * @return Error message string, never NULL
 */
const char* zylix_get_last_error(void);

/* === Utility Functions === */

/**
 * Copy string from Zylix memory to shell buffer.
 *
 * @param src     Source string pointer
 * @param src_len Source length
 * @param dst     Destination buffer
 * @param dst_len Destination buffer size
 * @return Number of bytes written
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
