//
//  Zylix-Bridging-Header.h
//  Zylix
//
//  Bridging header for Zylix Core C ABI
//

#ifndef Zylix_Bridging_Header_h
#define Zylix_Bridging_Header_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// === Result Codes ===
#define ZYLIX_OK 0
#define ZYLIX_ERR_INVALID_ARG 1
#define ZYLIX_ERR_OUT_OF_MEMORY 2
#define ZYLIX_ERR_INVALID_STATE 3
#define ZYLIX_ERR_NOT_INITIALIZED 4

// === Event Priority ===
#define ZYLIX_PRIORITY_LOW       0
#define ZYLIX_PRIORITY_NORMAL    1
#define ZYLIX_PRIORITY_HIGH      2
#define ZYLIX_PRIORITY_IMMEDIATE 3

// === Event Types ===
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

// Counter PoC events (0x1000+)
#define ZYLIX_EVENT_COUNTER_INCREMENT 0x1000
#define ZYLIX_EVENT_COUNTER_DECREMENT 0x1001
#define ZYLIX_EVENT_COUNTER_RESET     0x1002

// === State Structure ===
typedef struct {
    uint64_t version;
    uint32_t screen;
    bool loading;
    const char* error_message;
    const void* view_data;
    size_t view_data_size;
} zylix_state_t;

// === Counter App State (matches Zig AppState) ===
typedef struct {
    int64_t counter;
    char input_text[256];
    size_t input_len;
} zylix_app_state_t;

// === Diff Structure ===
typedef struct {
    uint64_t changed_mask;
    uint8_t change_count;
    uint64_t version;
} zylix_diff_t;

// === Lifecycle Functions ===
int32_t zylix_init(void);
int32_t zylix_deinit(void);
uint32_t zylix_get_abi_version(void);

// === State Access ===
const zylix_state_t* zylix_get_state(void);
uint64_t zylix_get_state_version(void);

// === Event Dispatch ===
int32_t zylix_dispatch(uint32_t event_type, const void* payload, size_t payload_len);

// === Event Queue ===
int32_t zylix_queue_event(uint32_t event_type, const void* payload, size_t payload_len, uint8_t priority);
uint32_t zylix_process_events(uint32_t max_events);
uint32_t zylix_queue_depth(void);
void zylix_queue_clear(void);

// === Diff Functions ===
const zylix_diff_t* zylix_get_diff(void);
bool zylix_field_changed(uint16_t field_id);

// === Error Handling ===
const char* zylix_get_last_error(void);

// === Utility ===
size_t zylix_copy_string(const char* src, size_t src_len, char* dst, size_t dst_len);

#endif /* Zylix_Bridging_Header_h */
