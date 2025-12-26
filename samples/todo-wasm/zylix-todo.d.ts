/**
 * ZylixTodo TypeScript Type Definitions
 *
 * Type-safe interface for the Zylix Todo JavaScript bridge.
 */

declare namespace ZylixTodo {
    /**
     * Filter type constants
     */
    type FilterType = 0 | 1 | 2; // all | active | completed

    /**
     * WASM module exports
     */
    interface WasmExports {
        memory: WebAssembly.Memory;
        zylix_init(): number;
        zylix_deinit(): void;
        zylix_todo_add(ptr: number, len: number): number;
        zylix_todo_remove(id: number): number;
        zylix_todo_toggle(id: number): number;
        zylix_todo_toggle_all(): void;
        zylix_todo_clear_completed(): void;
        zylix_todo_set_filter(filter: number): void;
        zylix_todo_get_filter(): number;
        zylix_todo_get_count(): number;
        zylix_todo_get_active_count(): number;
        zylix_todo_get_completed_count(): number;
        zylix_todo_get_visible_count(): number;
        zylix_todo_get_item_text(id: number): number;
        zylix_todo_get_item_text_len(id: number): number;
        zylix_todo_get_item_completed(id: number): boolean;
        zylix_todo_update_text?(id: number, ptr: number, len: number): number;
        zylix_wasm_alloc?(size: number): number;
        zylix_wasm_free_scratch?(): void;
    }

    /**
     * ZylixTodo API
     */
    interface ZylixTodoAPI {
        /** WASM module instance */
        readonly wasm: WasmExports | null;

        /** WASM memory */
        readonly memory: WebAssembly.Memory | null;

        /** Whether the module is initialized */
        readonly initialized: boolean;

        /**
         * Initialize ZylixTodo WASM module
         * @param wasmPath - Path to the zylix.wasm file
         * @throws Error if initialization fails
         */
        init(wasmPath: string): Promise<void>;

        /**
         * Shutdown the module
         */
        deinit(): void;

        /**
         * Add a new todo item
         * @param text - Todo text
         * @returns ID of the new item or -1 on error
         */
        add(text: string): number;

        /**
         * Remove a todo item
         * @param id - Todo item ID
         * @returns 0 on success
         */
        remove(id: number): number;

        /**
         * Toggle a todo item's completed state
         * @param id - Todo item ID
         * @returns 0 on success
         */
        toggle(id: number): number;

        /**
         * Toggle all todo items
         */
        toggleAll(): void;

        /**
         * Clear all completed items
         */
        clearCompleted(): void;

        /**
         * Set the current filter
         * @param filter - 0=all, 1=active, 2=completed
         */
        setFilter(filter: FilterType): void;

        /**
         * Get the current filter
         * @returns Current filter value
         */
        getFilter(): FilterType;

        /**
         * Get total number of todos
         * @returns Total count
         */
        getCount(): number;

        /**
         * Get number of active (uncompleted) todos
         * @returns Active count
         */
        getActiveCount(): number;

        /**
         * Get number of completed todos
         * @returns Completed count
         */
        getCompletedCount(): number;

        /**
         * Get number of visible todos (based on current filter)
         * @returns Visible count
         */
        getVisibleCount(): number;

        /**
         * Get a todo item's text
         * @param id - Todo item ID
         * @returns Todo text or null if not found
         */
        getItemText(id: number): string | null;

        /**
         * Get whether a todo item is completed
         * @param id - Todo item ID
         * @returns true if completed
         */
        getItemCompleted(id: number): boolean;

        /**
         * Update a todo item's text
         * @param id - Todo item ID
         * @param text - New text
         * @returns 0 on success
         */
        updateText(id: number, text: string): number;

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
        writeString(str: string): { ptr: number; len: number };
    }
}

declare const ZylixTodo: ZylixTodo.ZylixTodoAPI;

export = ZylixTodo;
export as namespace ZylixTodo;
