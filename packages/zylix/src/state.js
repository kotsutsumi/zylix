/**
 * Zylix State - Application State Management
 *
 * Provides reactive state management with the Zig core handling
 * all state storage and updates.
 */

import { getWasm, isInitialized, freeScratch } from './core.js';

/**
 * Event type constants (must match core/src/events.zig)
 */
export const Events = Object.freeze({
    INCREMENT: 0x1000,
    DECREMENT: 0x1001,
    RESET: 0x1002,
});

/**
 * Dispatch an event to the Zylix core
 * @param {number} eventType - Event type constant
 * @param {ArrayBuffer | Uint8Array | null} [payload] - Optional payload data
 * @returns {number} Result code (0 = success)
 */
export function dispatch(eventType, payload = null) {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) {
        console.error('Zylix not initialized');
        return -1;
    }

    let ptr = 0;
    let len = 0;

    if (payload) {
        const bytes = payload instanceof Uint8Array ? payload : new Uint8Array(payload);
        len = bytes.length;
        ptr = wasm.zylix_wasm_alloc?.(len) ?? 0;

        if (ptr && len > 0) {
            const memory = wasm.memory;
            const dest = new Uint8Array(memory.buffer, ptr, len);
            dest.set(bytes);
        }
    }

    const result = wasm.zylix_dispatch(eventType, ptr, len);
    freeScratch();
    return result;
}

/**
 * Get the current counter value
 * @returns {number}
 */
export function getCounter() {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) return 0;

    if (wasm.zylix_wasm_get_counter) {
        return Number(wasm.zylix_wasm_get_counter());
    }
    return 0;
}

/**
 * Get the state version number
 * @returns {number}
 */
export function getStateVersion() {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) return 0;

    if (wasm.zylix_get_state_version) {
        return Number(wasm.zylix_get_state_version());
    }
    return 0;
}

/**
 * Increment the counter
 * @returns {number} Result code
 */
export function increment() {
    return dispatch(Events.INCREMENT);
}

/**
 * Decrement the counter
 * @returns {number} Result code
 */
export function decrement() {
    return dispatch(Events.DECREMENT);
}

/**
 * Reset the counter to zero
 * @returns {number} Result code
 */
export function reset() {
    return dispatch(Events.RESET);
}

/**
 * Create a reactive store
 * @template T
 * @param {T} initialValue
 * @returns {{ get: () => T, set: (value: T) => void, subscribe: (fn: (value: T) => void) => () => void }}
 */
export function createStore(initialValue) {
    let value = initialValue;
    const subscribers = new Set();

    return {
        get() {
            return value;
        },
        set(newValue) {
            value = newValue;
            subscribers.forEach(fn => fn(value));
        },
        subscribe(fn) {
            subscribers.add(fn);
            fn(value); // Call immediately with current value
            return () => subscribers.delete(fn);
        },
    };
}

// Default export
export default {
    Events,
    dispatch,
    getCounter,
    getStateVersion,
    increment,
    decrement,
    reset,
    createStore,
};
