/**
 * Zylix Todo - JavaScript Bridge for WASM Todo Application
 *
 * This module provides a clean JavaScript API for the Zylix WASM todo implementation.
 * All state management happens in Zig/WASM - JavaScript only handles DOM rendering.
 */

const ZylixTodo = {
    wasm: null,
    memory: null,
    initialized: false,

    /**
     * Initialize the WASM module
     * @param {string} wasmPath - Path to the WASM file
     */
    async init(wasmPath) {
        // Fetch and compile WASM
        const response = await fetch(wasmPath);
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status}`);
        }

        const wasmBuffer = await response.arrayBuffer();

        // WASM imports (minimal - Zig handles most internally)
        const imports = {
            env: {
                // Memory will be exported by WASM
            },
        };

        const result = await WebAssembly.instantiate(wasmBuffer, imports);
        this.wasm = result.instance.exports;
        this.memory = this.wasm.memory;

        // Initialize Zylix core state
        if (this.wasm.zylix_init) {
            this.wasm.zylix_init();
        }

        // Initialize todo state
        if (this.wasm.zigdom_todo_init) {
            this.wasm.zigdom_todo_init();
        }

        // Initialize VDOM if available
        if (this.wasm.zigdom_vdom_init) {
            this.wasm.zigdom_vdom_init();
        }

        this.initialized = true;
        console.log('ZylixTodo initialized');
    },

    /**
     * Encode a JavaScript string to WASM memory
     * @param {string} str - String to encode
     * @returns {{ ptr: number, len: number }}
     */
    encodeString(str) {
        const encoder = new TextEncoder();
        const bytes = encoder.encode(str);

        // Allocate memory in WASM
        const ptr = this.wasm.zylix_wasm_alloc(bytes.length);
        if (!ptr) {
            throw new Error('Failed to allocate WASM memory');
        }

        // Copy bytes to WASM memory
        const view = new Uint8Array(this.memory.buffer, ptr, bytes.length);
        view.set(bytes);

        return { ptr, len: bytes.length };
    },

    /**
     * Decode a string from WASM memory
     * @param {number} ptr - Pointer to string in WASM memory
     * @param {number} len - Length of string
     * @returns {string}
     */
    decodeString(ptr, len) {
        if (!ptr || len === 0) return '';
        const view = new Uint8Array(this.memory.buffer, ptr, len);
        const decoder = new TextDecoder();
        return decoder.decode(view);
    },

    /**
     * Add a new todo item
     * @param {string} text - Todo text
     * @returns {number} - Todo item ID (0 if failed)
     */
    add(text) {
        const { ptr, len } = this.encodeString(text);
        const id = this.wasm.zigdom_todo_add(ptr, len);
        this.wasm.zylix_wasm_free_scratch();
        return id;
    },

    /**
     * Remove a todo item by ID
     * @param {number} id - Todo item ID
     * @returns {boolean}
     */
    remove(id) {
        return this.wasm.zigdom_todo_remove(id);
    },

    /**
     * Toggle a todo item's completion status
     * @param {number} id - Todo item ID
     * @returns {boolean}
     */
    toggle(id) {
        return this.wasm.zigdom_todo_toggle(id);
    },

    /**
     * Toggle all todo items
     */
    toggleAll() {
        this.wasm.zigdom_todo_toggle_all();
    },

    /**
     * Clear all completed todos
     * @returns {number} - Number of items removed
     */
    clearCompleted() {
        return this.wasm.zigdom_todo_clear_completed();
    },

    /**
     * Set the filter mode
     * @param {number} filter - 0=all, 1=active, 2=completed
     */
    setFilter(filter) {
        this.wasm.zigdom_todo_set_filter(filter);
    },

    /**
     * Get the current filter mode
     * @returns {number} - 0=all, 1=active, 2=completed
     */
    getFilter() {
        return this.wasm.zigdom_todo_get_filter();
    },

    /**
     * Get total todo count
     * @returns {number}
     */
    getCount() {
        return this.wasm.zigdom_todo_get_count();
    },

    /**
     * Get count of active (not completed) todos
     * @returns {number}
     */
    getActiveCount() {
        return this.wasm.zigdom_todo_get_active_count();
    },

    /**
     * Get count of completed todos
     * @returns {number}
     */
    getCompletedCount() {
        return this.wasm.zigdom_todo_get_completed_count();
    },

    /**
     * Get count of visible todos (based on current filter)
     * @returns {number}
     */
    getVisibleCount() {
        return this.wasm.zigdom_todo_get_visible_count();
    },

    /**
     * Get a todo item's text by ID
     * @param {number} id - Todo item ID
     * @returns {string|null}
     */
    getItemText(id) {
        const ptr = this.wasm.zigdom_todo_get_item_text(id);
        const len = this.wasm.zigdom_todo_get_item_text_len(id);
        if (!ptr || len === 0) return null;
        return this.decodeString(ptr, len);
    },

    /**
     * Get a todo item's completion status by ID
     * @param {number} id - Todo item ID
     * @returns {boolean}
     */
    getItemCompleted(id) {
        return this.wasm.zigdom_todo_get_item_completed(id);
    },

    /**
     * Update a todo item's text
     * @param {number} id - Todo item ID
     * @param {string} text - New text
     * @returns {boolean}
     */
    updateText(id, text) {
        const { ptr, len } = this.encodeString(text);
        const result = this.wasm.zigdom_todo_update_text(id, ptr, len);
        this.wasm.zylix_wasm_free_scratch();
        return result;
    },

    /**
     * Dispatch an event by callback ID
     * @param {number} callbackId - Event callback ID
     * @returns {boolean}
     */
    dispatch(callbackId) {
        return this.wasm.zigdom_todo_dispatch(callbackId);
    },

    /**
     * Render todo app and get patch count
     * @returns {number} - Number of DOM patches
     */
    renderAndCommit() {
        return this.wasm.zigdom_todo_render_and_commit();
    },

    // Event ID constants
    get EVENT_ADD() { return this.wasm.zigdom_todo_event_add(); },
    get EVENT_TOGGLE_BASE() { return this.wasm.zigdom_todo_event_toggle_base(); },
    get EVENT_REMOVE_BASE() { return this.wasm.zigdom_todo_event_remove_base(); },
    get EVENT_TOGGLE_ALL() { return this.wasm.zigdom_todo_event_toggle_all(); },
    get EVENT_CLEAR_COMPLETED() { return this.wasm.zigdom_todo_event_clear_completed(); },
    get EVENT_FILTER_ALL() { return this.wasm.zigdom_todo_event_filter_all(); },
    get EVENT_FILTER_ACTIVE() { return this.wasm.zigdom_todo_event_filter_active(); },
    get EVENT_FILTER_COMPLETED() { return this.wasm.zigdom_todo_event_filter_completed(); },

    /**
     * Get memory usage in bytes
     * @returns {number}
     */
    getMemoryUsed() {
        return this.wasm.zylix_wasm_memory_used ? this.wasm.zylix_wasm_memory_used() : 0;
    },

    /**
     * Get peak memory usage in bytes
     * @returns {number}
     */
    getMemoryPeak() {
        return this.wasm.zylix_wasm_memory_peak ? this.wasm.zylix_wasm_memory_peak() : 0;
    },
};

// Export for ES modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZylixTodo;
}
