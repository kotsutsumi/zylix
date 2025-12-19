/**
 * JNI Bridge for Zylix Core
 *
 * Maps Kotlin native methods to Zylix C ABI functions.
 */

#include <jni.h>
#include <string.h>
#include <stdlib.h>

// Zylix C ABI declarations (from core/include/zylix.h)
extern int zylix_init(void);
extern void zylix_deinit(void);
extern int zylix_get_abi_version(void);
extern const char* zylix_get_state(void);
extern unsigned long zylix_get_state_version(void);
extern int zylix_dispatch(int event_type, int payload);
extern int zylix_get_last_error(void);
extern int zylix_copy_string(const char* src, char* dst, int dst_len);

// JNI method implementations

JNIEXPORT jint JNICALL
Java_com_zylix_app_ZylixBridge_nativeInit(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    return zylix_init();
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
    return zylix_get_abi_version();
}

JNIEXPORT jstring JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetState(JNIEnv *env, jobject thiz) {
    (void)thiz;
    const char* state = zylix_get_state();
    if (state == NULL) {
        return NULL;
    }
    return (*env)->NewStringUTF(env, state);
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
    return zylix_dispatch(event_type, payload);
}

JNIEXPORT jint JNICALL
Java_com_zylix_app_ZylixBridge_nativeGetLastError(JNIEnv *env, jobject thiz) {
    (void)env;
    (void)thiz;
    return zylix_get_last_error();
}
