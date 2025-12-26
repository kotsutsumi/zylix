package com.zylix

import java.nio.ByteBuffer

/**
 * Native JNI interface to Zylix Core.
 *
 * This object provides low-level access to the Zig-compiled Zylix library.
 * For most use cases, prefer using [ZylixCore] instead.
 */
object ZylixNative {

    init {
        // Load the Zig-compiled core library first
        System.loadLibrary("zylix")
        // Then load the JNI bridge
        System.loadLibrary("zylix-jni")
    }

    // === Lifecycle Functions ===

    /**
     * Initialize Zylix Core.
     * @return 0 on success, error code otherwise
     */
    @JvmStatic
    external fun zylix_init(): Int

    /**
     * Shutdown Zylix Core.
     * @return 0 on success, error code otherwise
     */
    @JvmStatic
    external fun zylix_deinit(): Int

    /**
     * Get ABI version.
     * @return ABI version number
     */
    @JvmStatic
    external fun zylix_get_abi_version(): Int

    // === State Access ===

    /**
     * Get state version number.
     * @return Current state version
     */
    @JvmStatic
    external fun zylix_get_state_version(): Long

    /**
     * Get counter value.
     * @return Current counter value
     */
    @JvmStatic
    external fun zylix_get_counter(): Long

    // === Event Dispatch ===

    /**
     * Dispatch an event.
     * @param eventType Event type identifier
     * @return 0 on success, error code otherwise
     */
    @JvmStatic
    external fun zylix_dispatch(eventType: Int): Int

    /**
     * Dispatch an event with payload.
     * @param eventType Event type identifier
     * @param payload Payload data
     * @return 0 on success, error code otherwise
     */
    @JvmStatic
    external fun zylix_dispatch_with_payload(eventType: Int, payload: ByteArray): Int

    // === Event Queue ===

    /**
     * Queue an event.
     * @param eventType Event type identifier
     * @param priority Priority (0=low, 1=normal, 2=high, 3=immediate)
     * @return 0 on success, error code otherwise
     */
    @JvmStatic
    external fun zylix_queue_event(eventType: Int, priority: Int): Int

    /**
     * Process queued events.
     * @param maxEvents Maximum events to process
     * @return Number of events processed
     */
    @JvmStatic
    external fun zylix_process_events(maxEvents: Int): Int

    /**
     * Get queue depth.
     * @return Number of events in queue
     */
    @JvmStatic
    external fun zylix_queue_depth(): Int

    /**
     * Clear event queue.
     */
    @JvmStatic
    external fun zylix_queue_clear()

    // === Diff Functions ===

    /**
     * Check if field changed.
     * @param fieldId Field identifier
     * @return true if field changed
     */
    @JvmStatic
    external fun zylix_field_changed(fieldId: Int): Boolean

    // === Error Handling ===

    /**
     * Get last error message.
     * @return Error message string
     */
    @JvmStatic
    external fun zylix_get_last_error(): String
}
