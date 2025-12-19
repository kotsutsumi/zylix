package com.zylix.app

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Kotlin bridge to Zylix Core via JNI/C ABI
 *
 * This class wraps the native Zylix library and provides a Kotlin-friendly API.
 * The native library is built with Zig and exposes a C ABI.
 */
object ZylixBridge {

    // Event types matching core/include/zylix.h
    object EventType {
        const val INCREMENT = 0x1000   // ZYLIX_EVENT_COUNTER_INCREMENT
        const val DECREMENT = 0x1001   // ZYLIX_EVENT_COUNTER_DECREMENT
        const val RESET = 0x1002       // ZYLIX_EVENT_COUNTER_RESET
    }

    // Result codes matching core/src/abi.zig
    object Result {
        const val OK = 0
        const val ERROR_NOT_INITIALIZED = 1
        const val ERROR_INVALID_EVENT = 2
        const val ERROR_INVALID_ARGUMENT = 3
        const val ERROR_BUFFER_TOO_SMALL = 4
        const val ERROR_SERIALIZATION = 5
        const val ERROR_UNKNOWN = 99
    }

    private var isInitialized = false
    private val _counter = MutableStateFlow(0)
    val counter: StateFlow<Int> = _counter.asStateFlow()

    init {
        try {
            System.loadLibrary("zylix_jni")
            isInitialized = true
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("ZylixBridge", "Failed to load libzylix_jni.so: ${e.message}")
            isInitialized = false
        }
    }

    // Native method declarations
    private external fun nativeInit(): Int
    private external fun nativeDeinit()
    private external fun nativeGetAbiVersion(): Int
    private external fun nativeGetState(): String?
    private external fun nativeGetStateVersion(): Long
    private external fun nativeDispatch(eventType: Int, payload: Int): Int
    private external fun nativeGetLastError(): String?

    /**
     * Initialize Zylix Core
     */
    fun initialize(): Boolean {
        if (!isInitialized) {
            android.util.Log.e("ZylixBridge", "Native library not loaded")
            return false
        }

        val result = nativeInit()
        if (result == Result.OK) {
            syncState()
            return true
        }
        android.util.Log.e("ZylixBridge", "Failed to initialize Zylix Core: $result")
        return false
    }

    /**
     * Cleanup Zylix Core resources
     */
    fun deinitialize() {
        if (isInitialized) {
            nativeDeinit()
        }
    }

    /**
     * Get the ABI version
     */
    fun getAbiVersion(): Int {
        return if (isInitialized) nativeGetAbiVersion() else 0
    }

    /**
     * Increment the counter
     */
    fun increment(): Boolean {
        return dispatch(EventType.INCREMENT, 0)
    }

    /**
     * Decrement the counter
     */
    fun decrement(): Boolean {
        return dispatch(EventType.DECREMENT, 0)
    }

    /**
     * Reset the counter to 0
     */
    fun reset(): Boolean {
        return dispatch(EventType.RESET, 0)
    }

    /**
     * Dispatch an event to Zylix Core
     */
    private fun dispatch(eventType: Int, payload: Int): Boolean {
        if (!isInitialized) return false

        val result = nativeDispatch(eventType, payload)
        if (result == Result.OK) {
            syncState()
            return true
        }
        val errorMsg = nativeGetLastError() ?: "Unknown error"
        android.util.Log.e("ZylixBridge", "Dispatch failed: $result, error: $errorMsg")
        return false
    }

    /**
     * Sync state from Zylix Core to Kotlin StateFlow
     */
    private fun syncState() {
        if (!isInitialized) return

        val stateJson = nativeGetState()
        if (stateJson != null) {
            // Parse JSON state - simple parsing for counter
            // Format: {"counter":N}
            val counterMatch = Regex(""""counter"\s*:\s*(-?\d+)""").find(stateJson)
            counterMatch?.groupValues?.get(1)?.toIntOrNull()?.let { value ->
                _counter.value = value
            }
        }
    }
}
