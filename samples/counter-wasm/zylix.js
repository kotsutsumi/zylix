/**
 * Zylix JavaScript Bridge
 *
 * Minimal glue code for loading and interacting with the Zylix WASM module.
 * This provides a clean API for JavaScript to communicate with the Zig core.
 */

const Zylix = {
    wasm: null,
    memory: null,
    initialized: false,

    /**
     * Event type constants (must match core/src/events.zig)
     */
    Events: {
        INCREMENT: 0x1000,   // Counter increment
        DECREMENT: 0x1001,   // Counter decrement
        RESET: 0x1002,       // Counter reset
    },

    /**
     * Initialize Zylix WASM module
     * @param {string} wasmPath - Path to the zylix.wasm file
     * @returns {Promise<void>}
     */
    async init(wasmPath) {
        if (this.initialized) {
            console.warn('Zylix already initialized');
            return;
        }

        // Load WASM module
        const response = await fetch(wasmPath);
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status} ${response.statusText}`);
        }

        const wasmBuffer = await response.arrayBuffer();

        // Import object for WASM
        const imports = {
            env: {
                // Console logging from Zig (if needed)
                js_console_log: (ptr, len) => {
                    console.log('[Zylix]', this.readString(ptr, len));
                },
            },
        };

        // Instantiate WASM module
        try {
            const result = await WebAssembly.instantiate(wasmBuffer, imports);
            this.wasm = result.instance.exports;
            this.memory = this.wasm.memory;
        } catch (error) {
            throw new Error(`WASM instantiation failed: ${error.message}`);
        }

        // Initialize Zylix core
        const initResult = this.wasm.zylix_init();
        if (initResult !== 0) {
            throw new Error(`Zylix initialization failed with code: ${initResult}`);
        }

        this.initialized = true;
        console.log('Zylix initialized successfully');
        console.log('ABI Version:', this.wasm.zylix_get_abi_version?.() ?? 'N/A');
    },

    /**
     * Shutdown Zylix core
     */
    deinit() {
        if (!this.initialized) return;

        this.wasm.zylix_deinit();
        this.initialized = false;
        console.log('Zylix deinitialized');
    },

    /**
     * Dispatch an event to Zylix core
     * @param {number} eventType - Event type constant
     * @param {ArrayBuffer|null} payload - Optional payload data
     * @returns {number} Result code (0 = success)
     */
    dispatch(eventType, payload = null) {
        if (!this.initialized) {
            console.error('Zylix not initialized');
            return -1;
        }

        let ptr = 0;
        let len = 0;

        if (payload) {
            // Allocate memory and copy payload
            const bytes = new Uint8Array(payload);
            len = bytes.length;
            ptr = this.wasm.zylix_wasm_alloc?.(len) ?? 0;

            if (ptr && len > 0) {
                const dest = new Uint8Array(this.memory.buffer, ptr, len);
                dest.set(bytes);
            }
        }

        const result = this.wasm.zylix_dispatch(eventType, ptr, len);

        // Free scratch memory after dispatch
        if (ptr && this.wasm.zylix_wasm_free_scratch) {
            this.wasm.zylix_wasm_free_scratch();
        }

        return result;
    },

    /**
     * Get current counter value
     * @returns {number} Counter value
     */
    getCounter() {
        if (!this.initialized) return 0;

        // Use the convenience WASM function
        if (this.wasm.zylix_wasm_get_counter) {
            return Number(this.wasm.zylix_wasm_get_counter());
        }

        // Fallback: read from state
        const statePtr = this.wasm.zylix_get_state();
        if (!statePtr) return 0;

        // ABIState structure: { counter: i64, version: u64, ... }
        // Read counter (i64 at offset 0)
        const view = new DataView(this.memory.buffer);
        return Number(view.getBigInt64(statePtr, true));
    },

    /**
     * Get state version
     * @returns {number} State version number
     */
    getStateVersion() {
        if (!this.initialized) return 0;

        if (this.wasm.zylix_get_state_version) {
            return Number(this.wasm.zylix_get_state_version());
        }

        const statePtr = this.wasm.zylix_get_state();
        if (!statePtr) return 0;

        // Read version (u64 at offset 8)
        const view = new DataView(this.memory.buffer);
        return Number(view.getBigUint64(statePtr + 8, true));
    },

    /**
     * Get WASM memory usage
     * @returns {number} Bytes used
     */
    getMemoryUsed() {
        if (!this.initialized) return 0;

        if (this.wasm.zylix_wasm_memory_used) {
            return this.wasm.zylix_wasm_memory_used();
        }

        // Fallback: report total memory size
        return this.memory?.buffer.byteLength ?? 0;
    },

    /**
     * Read a string from WASM memory
     * @param {number} ptr - Pointer to string data
     * @param {number} len - String length in bytes
     * @returns {string} Decoded string
     */
    readString(ptr, len) {
        if (!this.memory || ptr === 0 || len === 0) return '';

        const bytes = new Uint8Array(this.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    },

    /**
     * Write a string to WASM memory
     * @param {string} str - String to write
     * @returns {{ptr: number, len: number}} Pointer and length
     */
    writeString(str) {
        if (!this.wasm.zylix_wasm_alloc) {
            console.error('WASM allocator not available');
            return { ptr: 0, len: 0 };
        }

        const bytes = new TextEncoder().encode(str);
        const ptr = this.wasm.zylix_wasm_alloc(bytes.length);

        if (ptr) {
            const dest = new Uint8Array(this.memory.buffer, ptr, bytes.length);
            dest.set(bytes);
        }

        return { ptr: ptr || 0, len: bytes.length };
    },
};

// Freeze the API to prevent accidental modifications
Object.freeze(Zylix.Events);

// Export for module systems (if available)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Zylix;
}
