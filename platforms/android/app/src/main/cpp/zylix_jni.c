/**
 * JNI Bridge for Zylix Core
 *
 * Maps Kotlin native methods to Zylix C ABI functions.
 */

#include <jni.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// Zylix state structure (from core/include/zylix.h)
typedef struct {
    uint64_t version;
    uint32_t screen;
    bool loading;
    const char* error_message;
    const void* view_data;
    size_t view_data_size;
} zylix_state_t;

// AppState structure (matches core/src/state.zig AppState)
// counter is the first field, which is what we need
typedef struct {
    int64_t counter;
    // Followed by input_text and input_len, but we only need counter
} app_state_t;

// Zylix C ABI declarations (from core/include/zylix.h)
extern int32_t zylix_init(void);
extern int32_t zylix_deinit(void);
extern uint32_t zylix_get_abi_version(void);
extern const zylix_state_t* zylix_get_state(void);
extern uint64_t zylix_get_state_version(void);
extern int32_t zylix_dispatch(uint32_t event_type, const void* payload, size_t payload_len);
extern const char* zylix_get_last_error(void);

// JNI method implementations

JNIEXPORT jint JNICALL
Java_com_zylix_app_ZylixBridge_nativeInit(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    return (jint)zylix_init();
}

JNIEXPORT void JNICALL
Java_com_zylix_app_ZylixBridge_nativeDeinit(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    zylix_deinit();
}

JNIEXPORT jint JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetAbiVersion(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    return (jint)zylix_get_abi_version();
}

JNIEXPORT jstring JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetState(JNIEnv *env, jobject thiz) {
    (void)thiz;
    const zylix_state_t* state = zylix_get_state();
    if (state == NULL) {
        return NULL;
    }

    // Extract counter value from view_data (AppState struct)
    int64_t counter_value = 0;
    if (state->view_data != NULL && state->view_data_size >= sizeof(int64_t)) {
        const app_state_t* app_state = (const app_state_t*)state->view_data;
        counter_value = app_state->counter;
    }

    // Build JSON string
    char json_buffer[256];
    snprintf(json_buffer, sizeof(json_buffer),
        "{\"version\":%llu,\"screen\":%u,\"loading\":%s,\"counter\":%lld}",
        (unsigned long long)state->version,
        state->screen,
        state->loading ? "true" : "false",
        (long long)counter_value);

    return (*env)->NewStringUTF(env, json_buffer);
}

JNIEXPORT jlong JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetStateVersion(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    return (jlong)zylix_get_state_version();
}

JNIEXPORT jint JNICALL
Java_com_zylix_app_ZylixBridge_nativeDispatch(JNIEnv *env, jobject thiz, jint event_type, jint payload) {
    (void)env;
    (void)thiz;
    // For counter events, we don't need payload data
    return (jint)zylix_dispatch((uint32_t)event_type, NULL, 0);
}

JNIEXPORT jstring JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetLastError(JNIEnv *env, jobject thiz) {
    (void)thiz;
    const char* error = zylix_get_last_error();
    if (error == NULL) {
        return (*env)->NewStringUTF(env, "Unknown error");
    }
    return (*env)->NewStringUTF(env, error);
}
