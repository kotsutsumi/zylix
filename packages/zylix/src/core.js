/**
 * Zylix Core - WASM Module Loader and Base API
 *
 * This module handles loading the Zylix WASM module and provides
 * the foundation for all other Zylix modules.
 */

/**
 * Internal state for the WASM module
 * @type {{ wasm: WebAssembly.Instance['exports'] | null, memory: WebAssembly.Memory | null, initialized: boolean }}
 */
const state = {
    wasm: null,
    memory: null,
    initialized: false,
};

/**
 * Get the internal WASM exports
 * @returns {WebAssembly.Instance['exports'] | null}
 */
export function getWasm() {
    return state.wasm;
}

/**
 * Get the WASM memory
 * @returns {WebAssembly.Memory | null}
 */
export function getMemory() {
    return state.memory;
}

/**
 * Check if Zylix is initialized
 * @returns {boolean}
 */
export function isInitialized() {
    return state.initialized;
}

/**
 * Initialize the Zylix WASM module
 * @param {string | ArrayBuffer} wasmSource - Path to WASM file or ArrayBuffer
 * @param {Object} [options] - Initialization options
 * @param {Object} [options.imports] - Additional WASM imports
 * @returns {Promise<void>}
 */
export async function init(wasmSource, options = {}) {
    if (state.initialized) {
        console.warn('Zylix already initialized');
        return;
    }

    let wasmBuffer;

    if (typeof wasmSource === 'string') {
        // Load from URL/path
        const response = await fetch(wasmSource);
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status} ${response.statusText}`);
        }
        wasmBuffer = await response.arrayBuffer();
    } else if (wasmSource instanceof ArrayBuffer) {
        wasmBuffer = wasmSource;
    } else {
        throw new Error('wasmSource must be a URL string or ArrayBuffer');
    }

    // Default imports
    const imports = {
        env: {
            // Console logging from Zig
            js_console_log: (ptr, len) => {
                console.log('[Zylix]', readString(ptr, len));
            },
            ...options.imports?.env,
        },
        ...options.imports,
    };

    // Instantiate WASM module
    try {
        const result = await WebAssembly.instantiate(wasmBuffer, imports);
        state.wasm = result.instance.exports;
        state.memory = state.wasm.memory;
    } catch (error) {
        throw new Error(`WASM instantiation failed: ${error.message}`);
    }

    // Initialize Zylix core
    if (state.wasm.zylix_init) {
        const initResult = state.wasm.zylix_init();
        if (initResult !== 0) {
            throw new Error(`Zylix initialization failed with code: ${initResult}`);
        }
    }

    state.initialized = true;
}

/**
 * Shutdown Zylix core
 */
export function deinit() {
    if (!state.initialized) return;

    if (state.wasm?.zylix_deinit) {
        state.wasm.zylix_deinit();
    }

    state.wasm = null;
    state.memory = null;
    state.initialized = false;
}

/**
 * Allocate memory in WASM
 * @param {number} size - Number of bytes to allocate
 * @returns {number} Pointer to allocated memory (0 if failed)
 */
export function alloc(size) {
    if (!state.initialized || !state.wasm?.zylix_wasm_alloc) {
        return 0;
    }
    return state.wasm.zylix_wasm_alloc(size);
}

/**
 * Free scratch memory
 */
export function freeScratch() {
    if (state.wasm?.zylix_wasm_free_scratch) {
        state.wasm.zylix_wasm_free_scratch();
    }
}

/**
 * Read a string from WASM memory
 * @param {number} ptr - Pointer to string data
 * @param {number} len - String length in bytes
 * @returns {string} Decoded string
 */
export function readString(ptr, len) {
    if (!state.memory || ptr === 0 || len === 0) return '';
    const bytes = new Uint8Array(state.memory.buffer, ptr, len);
    return new TextDecoder().decode(bytes);
}

/**
 * Write a string to WASM memory
 * @param {string} str - String to write
 * @returns {{ ptr: number, len: number }} Pointer and length
 */
export function writeString(str) {
    const bytes = new TextEncoder().encode(str);
    const ptr = alloc(bytes.length);

    if (ptr) {
        const dest = new Uint8Array(state.memory.buffer, ptr, bytes.length);
        dest.set(bytes);
    }

    return { ptr: ptr || 0, len: bytes.length };
}

/**
 * Get memory usage
 * @returns {number} Bytes used
 */
export function getMemoryUsed() {
    if (state.wasm?.zylix_wasm_memory_used) {
        return state.wasm.zylix_wasm_memory_used();
    }
    return state.memory?.buffer.byteLength ?? 0;
}

/**
 * Get peak memory usage
 * @returns {number} Peak bytes used
 */
export function getMemoryPeak() {
    if (state.wasm?.zylix_wasm_memory_peak) {
        return state.wasm.zylix_wasm_memory_peak();
    }
    return 0;
}

/**
 * Get ABI version
 * @returns {number} ABI version number
 */
export function getAbiVersion() {
    if (state.wasm?.zylix_get_abi_version) {
        return state.wasm.zylix_get_abi_version();
    }
    return 0;
}

// Default export for convenience
export default {
    init,
    deinit,
    isInitialized,
    getWasm,
    getMemory,
    alloc,
    freeScratch,
    readString,
    writeString,
    getMemoryUsed,
    getMemoryPeak,
    getAbiVersion,
};
