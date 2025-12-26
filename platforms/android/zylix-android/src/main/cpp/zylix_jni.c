/**
 * @file zylix_jni.c
 * @brief JNI bridge for Zylix Core
 *
 * Provides JNI bindings for calling Zylix Core functions from Kotlin/Java.
 */

#include <jni.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// Forward declarations for Zylix C ABI functions
extern int32_t zylix_init(void);
extern int32_t zylix_deinit(void);
extern uint32_t zylix_get_abi_version(void);
extern uint64_t zylix_get_state_version(void);
extern int64_t zylix_get_counter(void);
extern int32_t zylix_dispatch(uint32_t event_type, const void* payload, size_t payload_len);
extern int32_t zylix_queue_event(uint32_t event_type, const void* payload, size_t payload_len, uint8_t priority);
extern uint32_t zylix_process_events(uint32_t max_events);
extern uint32_t zylix_queue_depth(void);
extern void zylix_queue_clear(void);
extern bool zylix_field_changed(uint16_t field_id);
extern const char* zylix_get_last_error(void);

// === Lifecycle Functions ===

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1init(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return zylix_init();
}

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1deinit(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return zylix_deinit();
}

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1get_1abi_1version(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jint)zylix_get_abi_version();
}

// === State Access ===

JNIEXPORT jlong JNICALL
Java_com_zylix_ZylixNative_zylix_1get_1state_1version(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jlong)zylix_get_state_version();
}

JNIEXPORT jlong JNICALL
Java_com_zylix_ZylixNative_zylix_1get_1counter(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jlong)zylix_get_counter();
}

// === Event Dispatch ===

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1dispatch(JNIEnv *env, jclass clazz, jint eventType) {
    (void)env;
    (void)clazz;
    return zylix_dispatch((uint32_t)eventType, NULL, 0);
}

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1dispatch_1with_1payload(
    JNIEnv *env,
    jclass clazz,
    jint eventType,
    jbyteArray payload
) {
    (void)clazz;

    if (payload == NULL) {
        return zylix_dispatch((uint32_t)eventType, NULL, 0);
    }

    jsize len = (*env)->GetArrayLength(env, payload);
    jbyte *data = (*env)->GetByteArrayElements(env, payload, NULL);

    if (data == NULL) {
        return -1; // Out of memory
    }

    int32_t result = zylix_dispatch((uint32_t)eventType, data, (size_t)len);

    (*env)->ReleaseByteArrayElements(env, payload, data, JNI_ABORT);

    return result;
}

// === Event Queue ===

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1queue_1event(
    JNIEnv *env,
    jclass clazz,
    jint eventType,
    jint priority
) {
    (void)env;
    (void)clazz;
    return zylix_queue_event((uint32_t)eventType, NULL, 0, (uint8_t)priority);
}

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1process_1events(JNIEnv *env, jclass clazz, jint maxEvents) {
    (void)env;
    (void)clazz;
    return (jint)zylix_process_events((uint32_t)maxEvents);
}

JNIEXPORT jint JNICALL
Java_com_zylix_ZylixNative_zylix_1queue_1depth(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jint)zylix_queue_depth();
}

JNIEXPORT void JNICALL
Java_com_zylix_ZylixNative_zylix_1queue_1clear(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zylix_queue_clear();
}

// === Diff Functions ===

JNIEXPORT jboolean JNICALL
Java_com_zylix_ZylixNative_zylix_1field_1changed(JNIEnv *env, jclass clazz, jint fieldId) {
    (void)env;
    (void)clazz;
    return zylix_field_changed((uint16_t)fieldId) ? JNI_TRUE : JNI_FALSE;
}

// === Error Handling ===

JNIEXPORT jstring JNICALL
Java_com_zylix_ZylixNative_zylix_1get_1last_1error(JNIEnv *env, jclass clazz) {
    (void)clazz;
    const char* error = zylix_get_last_error();
    if (error == NULL) {
        return (*env)->NewStringUTF(env, "Unknown error");
    }
    return (*env)->NewStringUTF(env, error);
}
