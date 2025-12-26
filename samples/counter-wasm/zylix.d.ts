/**
 * Zylix TypeScript Type Definitions
 *
 * Type-safe interface for the Zylix JavaScript bridge.
 */

declare namespace Zylix {
    /**
     * Event type constants matching core/src/events.zig
     */
    interface EventTypes {
        readonly INCREMENT: 0x1000;
        readonly DECREMENT: 0x1001;
        readonly RESET: 0x1002;
    }

    /**
     * WASM module exports
     */
    interface WasmExports {
        memory: WebAssembly.Memory;
        zylix_init(): number;
        zylix_deinit(): void;
        zylix_dispatch(eventType: number, ptr: number, len: number): number;
        zylix_get_state(): number;
        zylix_get_state_version?(): bigint;
        zylix_get_abi_version?(): number;
        zylix_wasm_get_counter?(): bigint;
        zylix_wasm_memory_used?(): number;
        zylix_wasm_alloc?(size: number): number;
        zylix_wasm_free_scratch?(): void;
    }

    /**
     * String write result
     */
    interface StringWriteResult {
        ptr: number;
        len: number;
    }

    /**
     * Zylix API
     */
    interface ZylixAPI {
        /** WASM module instance */
        readonly wasm: WasmExports | null;

        /** WASM memory */
        readonly memory: WebAssembly.Memory | null;

        /** Whether the module is initialized */
        readonly initialized: boolean;

        /** Event type constants */
        readonly Events: EventTypes;

        /**
         * Initialize Zylix WASM module
         * @param wasmPath - Path to the zylix.wasm file
         * @throws Error if initialization fails
         */
        init(wasmPath: string): Promise<void>;

        /**
         * Shutdown Zylix core
         */
        deinit(): void;

        /**
         * Dispatch an event to Zylix core
         * @param eventType - Event type constant from Zylix.Events
         * @param payload - Optional payload data
         * @returns Result code (0 = success)
         */
        dispatch(eventType: number, payload?: ArrayBuffer | null): number;

        /**
         * Get current counter value
         * @returns Counter value
         */
        getCounter(): number;

        /**
         * Get state version
         * @returns State version number
         */
        getStateVersion(): number;

        /**
         * Get WASM memory usage
         * @returns Bytes used
         */
        getMemoryUsed(): number;

        /**
         * Read a string from WASM memory
         * @param ptr - Pointer to string data
         * @param len - String length in bytes
         * @returns Decoded string
         */
        readString(ptr: number, len: number): string;

        /**
         * Write a string to WASM memory
         * @param str - String to write
         * @returns Pointer and length
         */
        writeString(str: string): StringWriteResult;
    }
}

declare const Zylix: Zylix.ZylixAPI;

export = Zylix;
export as namespace Zylix;
