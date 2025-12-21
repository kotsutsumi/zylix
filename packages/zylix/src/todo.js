/**
 * Zylix Todo - TodoMVC State Management
 *
 * Provides a complete Todo application API backed by the Zig core.
 * All state is managed in WASM - this module just provides the JS interface.
 */

import { getWasm, isInitialized, writeString, readString, freeScratch } from './core.js';

/**
 * Filter modes
 */
export const Filter = Object.freeze({
    ALL: 0,
    ACTIVE: 1,
    COMPLETED: 2,
});

/**
 * Event IDs for todo operations
 */
export const TodoEvents = Object.freeze({
    ADD: 1,
    TOGGLE: 2,
    REMOVE: 3,
    TOGGLE_ALL: 4,
    CLEAR_COMPLETED: 5,
    FILTER_ALL: 6,
    FILTER_ACTIVE: 7,
    FILTER_COMPLETED: 8,
});

/**
 * Initialize the todo state
 */
export function init() {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) {
        throw new Error('Zylix core not initialized');
    }
    if (wasm.zigdom_todo_init) {
        wasm.zigdom_todo_init();
    }
}

/**
 * Add a new todo item
 * @param {string} text - Todo text
 * @returns {number} Item ID (0 if failed)
 */
export function add(text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_todo_add) return 0;

    const { ptr, len } = writeString(text);
    const id = wasm.zigdom_todo_add(ptr, len);
    freeScratch();
    return id;
}

/**
 * Remove a todo item
 * @param {number} id - Item ID
 * @returns {boolean} Success
 */
export function remove(id) {
    const wasm = getWasm();
    return wasm?.zigdom_todo_remove?.(id) ?? false;
}

/**
 * Toggle a todo item's completion status
 * @param {number} id - Item ID
 * @returns {boolean} Success
 */
export function toggle(id) {
    const wasm = getWasm();
    return wasm?.zigdom_todo_toggle?.(id) ?? false;
}

/**
 * Toggle all todos
 */
export function toggleAll() {
    const wasm = getWasm();
    wasm?.zigdom_todo_toggle_all?.();
}

/**
 * Clear all completed todos
 * @returns {number} Number of items removed
 */
export function clearCompleted() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_clear_completed?.() ?? 0;
}

/**
 * Set the filter mode
 * @param {number} filter - Filter.ALL, Filter.ACTIVE, or Filter.COMPLETED
 */
export function setFilter(filter) {
    const wasm = getWasm();
    wasm?.zigdom_todo_set_filter?.(filter);
}

/**
 * Get the current filter mode
 * @returns {number}
 */
export function getFilter() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_filter?.() ?? 0;
}

/**
 * Get total todo count
 * @returns {number}
 */
export function getCount() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_count?.() ?? 0;
}

/**
 * Get active (not completed) count
 * @returns {number}
 */
export function getActiveCount() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_active_count?.() ?? 0;
}

/**
 * Get completed count
 * @returns {number}
 */
export function getCompletedCount() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_completed_count?.() ?? 0;
}

/**
 * Get visible count based on current filter
 * @returns {number}
 */
export function getVisibleCount() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_visible_count?.() ?? 0;
}

/**
 * Get item text by ID
 * @param {number} id - Item ID
 * @returns {string | null}
 */
export function getItemText(id) {
    const wasm = getWasm();
    if (!wasm?.zigdom_todo_get_item_text) return null;

    const ptr = wasm.zigdom_todo_get_item_text(id);
    const len = wasm.zigdom_todo_get_item_text_len(id);
    if (!ptr || len === 0) return null;

    return readString(ptr, len);
}

/**
 * Get item completion status
 * @param {number} id - Item ID
 * @returns {boolean}
 */
export function getItemCompleted(id) {
    const wasm = getWasm();
    return wasm?.zigdom_todo_get_item_completed?.(id) ?? false;
}

/**
 * Update item text
 * @param {number} id - Item ID
 * @param {string} text - New text
 * @returns {boolean} Success
 */
export function updateText(id, text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_todo_update_text) return false;

    const { ptr, len } = writeString(text);
    const result = wasm.zigdom_todo_update_text(id, ptr, len);
    freeScratch();
    return result;
}

/**
 * Dispatch a todo event by callback ID
 * @param {number} callbackId - Event callback ID
 * @returns {boolean} Whether the event was handled
 */
export function dispatch(callbackId) {
    const wasm = getWasm();
    return wasm?.zigdom_todo_dispatch?.(callbackId) ?? false;
}

/**
 * Render the todo app to VDOM
 */
export function render() {
    const wasm = getWasm();
    wasm?.zigdom_todo_render?.();
}

/**
 * Render and commit changes
 * @returns {number} Patch count
 */
export function renderAndCommit() {
    const wasm = getWasm();
    return wasm?.zigdom_todo_render_and_commit?.() ?? 0;
}

/**
 * Get all visible todo items
 * @returns {Array<{ id: number, text: string, completed: boolean }>}
 */
export function getVisibleItems() {
    const items = [];
    const count = getCount();
    const filter = getFilter();

    for (let id = 1; id <= count * 2; id++) {
        const text = getItemText(id);
        if (text === null) continue;

        const completed = getItemCompleted(id);

        // Apply filter
        if (filter === Filter.ACTIVE && completed) continue;
        if (filter === Filter.COMPLETED && !completed) continue;

        items.push({ id, text, completed });
    }

    return items;
}

/**
 * Get all todo items regardless of filter
 * @returns {Array<{ id: number, text: string, completed: boolean }>}
 */
export function getAllItems() {
    const items = [];
    const count = getCount();

    for (let id = 1; id <= count * 2; id++) {
        const text = getItemText(id);
        if (text === null) continue;

        items.push({
            id,
            text,
            completed: getItemCompleted(id),
        });
    }

    return items;
}

// Default export
export default {
    Filter,
    TodoEvents,
    init,
    add,
    remove,
    toggle,
    toggleAll,
    clearCompleted,
    setFilter,
    getFilter,
    getCount,
    getActiveCount,
    getCompletedCount,
    getVisibleCount,
    getItemText,
    getItemCompleted,
    updateText,
    dispatch,
    render,
    renderAndCommit,
    getVisibleItems,
    getAllItems,
};
