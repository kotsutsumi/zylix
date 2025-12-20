package com.zylix

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Result codes returned by Zylix functions.
 */
enum class ZylixResult(val code: Int) {
    OK(0),
    INVALID_ARGUMENT(1),
    OUT_OF_MEMORY(2),
    INVALID_STATE(3),
    NOT_INITIALIZED(4);

    companion object {
        fun fromCode(code: Int): ZylixResult =
            entries.find { it.code == code } ?: INVALID_STATE
    }
}

/**
 * Event priority levels.
 */
enum class ZylixPriority(val value: Int) {
    LOW(0),
    NORMAL(1),
    HIGH(2),
    IMMEDIATE(3)
}

/**
 * Exception thrown by Zylix operations.
 */
class ZylixException(
    val result: ZylixResult,
    message: String = result.name
) : Exception(message)

/**
 * Main interface to Zylix Core.
 *
 * ZylixCore provides a Kotlin-friendly API for interacting with the
 * Zig-compiled Zylix engine.
 *
 * Example usage:
 * ```kotlin
 * val zylix = ZylixCore.instance
 * zylix.initialize()
 *
 * // Dispatch an event
 * zylix.dispatch(0x1000)
 *
 * // Check state version
 * println("Version: ${zylix.stateVersion}")
 *
 * zylix.shutdown()
 * ```
 */
class ZylixCore private constructor() {

    companion object {
        /**
         * Singleton instance of ZylixCore.
         */
        val instance: ZylixCore by lazy { ZylixCore() }

        /**
         * ABI version number.
         */
        val abiVersion: Int
            get() = ZylixNative.zylix_get_abi_version()
    }

    private val _isInitialized = MutableStateFlow(false)

    /**
     * Whether the core has been initialized.
     */
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    private val _stateVersion = MutableStateFlow(0L)

    /**
     * Current state version as a Flow for reactive updates.
     */
    val stateVersionFlow: StateFlow<Long> = _stateVersion.asStateFlow()

    /**
     * Current state version.
     */
    val stateVersion: Long
        get() = ZylixNative.zylix_get_state_version()

    /**
     * Number of events in the queue.
     */
    val queueDepth: Int
        get() = ZylixNative.zylix_queue_depth()

    /**
     * Last error message.
     */
    val lastError: String
        get() = ZylixNative.zylix_get_last_error()

    /**
     * Initialize Zylix Core.
     *
     * Must be called before using any other ZylixCore methods.
     *
     * @throws ZylixException if initialization fails
     */
    fun initialize() {
        val result = ZylixNative.zylix_init()
        if (result != ZylixResult.OK.code) {
            throw ZylixException(ZylixResult.fromCode(result))
        }
        _isInitialized.value = true
        updateStateVersion()
    }

    /**
     * Shutdown Zylix Core.
     *
     * @throws ZylixException if shutdown fails
     */
    fun shutdown() {
        val result = ZylixNative.zylix_deinit()
        if (result != ZylixResult.OK.code) {
            throw ZylixException(ZylixResult.fromCode(result))
        }
        _isInitialized.value = false
    }

    /**
     * Dispatch an event immediately.
     *
     * @param eventType Event type identifier
     * @throws ZylixException if dispatch fails
     */
    fun dispatch(eventType: Int) {
        val result = ZylixNative.zylix_dispatch(eventType)
        if (result != ZylixResult.OK.code) {
            throw ZylixException(ZylixResult.fromCode(result))
        }
        updateStateVersion()
    }

    /**
     * Dispatch an event with payload.
     *
     * @param eventType Event type identifier
     * @param payload Payload data
     * @throws ZylixException if dispatch fails
     */
    fun dispatch(eventType: Int, payload: ByteArray) {
        val result = ZylixNative.zylix_dispatch_with_payload(eventType, payload)
        if (result != ZylixResult.OK.code) {
            throw ZylixException(ZylixResult.fromCode(result))
        }
        updateStateVersion()
    }

    /**
     * Queue an event for later processing.
     *
     * @param eventType Event type identifier
     * @param priority Event priority
     * @throws ZylixException if queuing fails
     */
    fun queueEvent(eventType: Int, priority: ZylixPriority = ZylixPriority.NORMAL) {
        val result = ZylixNative.zylix_queue_event(eventType, priority.value)
        if (result != ZylixResult.OK.code) {
            throw ZylixException(ZylixResult.fromCode(result))
        }
    }

    /**
     * Process queued events.
     *
     * @param maxEvents Maximum number of events to process
     * @return Number of events actually processed
     */
    fun processEvents(maxEvents: Int = 100): Int {
        val processed = ZylixNative.zylix_process_events(maxEvents)
        if (processed > 0) {
            updateStateVersion()
        }
        return processed
    }

    /**
     * Clear all queued events.
     */
    fun clearQueue() {
        ZylixNative.zylix_queue_clear()
    }

    /**
     * Check if a specific field changed.
     *
     * @param fieldId Field identifier
     * @return true if the field changed
     */
    fun fieldChanged(fieldId: Int): Boolean {
        return ZylixNative.zylix_field_changed(fieldId)
    }

    /**
     * Process events and update state.
     * Call this regularly (e.g., in a frame callback).
     */
    fun tick() {
        if (!_isInitialized.value) return
        processEvents(10)
    }

    private fun updateStateVersion() {
        _stateVersion.value = stateVersion
    }
}
