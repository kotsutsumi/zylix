/*
 * zylix.h
 * C ABI header for Zylix Core (Zig)
 */

#ifndef ZYLIX_H
#define ZYLIX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* === Result Codes === */
#define ZYLIX_OK 0
#define ZYLIX_ERR_INVALID_ARG 1
#define ZYLIX_ERR_OUT_OF_MEMORY 2
#define ZYLIX_ERR_INVALID_STATE 3
#define ZYLIX_ERR_NOT_INITIALIZED 4

/* === Event Types === */
#define ZYLIX_EVENT_COUNTER_INCREMENT 0x1000
#define ZYLIX_EVENT_COUNTER_DECREMENT 0x1001
#define ZYLIX_EVENT_COUNTER_RESET     0x1002

/* === State Structures === */
typedef struct {
    uint64_t version;
    uint32_t screen;
    bool loading;
    const char* error_message;
    const void* view_data;
    size_t view_data_size;
} zylix_state_t;

typedef struct {
    int64_t counter;
    char input_text[256];
    size_t input_len;
} zylix_app_state_t;

/* === Lifecycle Functions === */
int32_t zylix_init(void);
int32_t zylix_deinit(void);
uint32_t zylix_get_abi_version(void);

/* === State Access === */
const zylix_state_t* zylix_get_state(void);
uint64_t zylix_get_state_version(void);

/* === Event Dispatch === */
int32_t zylix_dispatch(uint32_t event_type, const void* payload, size_t payload_len);

/* === Error Handling === */
const char* zylix_get_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_H */
