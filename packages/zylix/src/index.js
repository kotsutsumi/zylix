/**
 * Zylix - Cross-platform UI Framework
 *
 * A modern UI framework with a Zig core and JavaScript/WebAssembly bridge.
 * All state management happens in WASM for performance and consistency.
 *
 * @example
 * // Initialize Zylix
 * import { init, state, todo } from 'zylix';
 *
 * await init('zylix.wasm');
 *
 * // Use state management
 * state.increment();
 * console.log(state.getCounter());
 *
 * // Use todo API
 * todo.init();
 * todo.add('Learn Zylix');
 * console.log(todo.getCount());
 */

// Re-export core module
export {
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
} from './core.js';

// Re-export state module
export * as state from './state.js';
export { Events, dispatch, getCounter, getStateVersion, increment, decrement, reset, createStore } from './state.js';

// Re-export todo module
export * as todo from './todo.js';

// Re-export vdom module
export * as vdom from './vdom.js';

// Re-export component module
export * as component from './component.js';

// Version info
export const VERSION = '0.1.0';

/**
 * Quick start helper - initializes everything
 * @param {string} wasmPath - Path to WASM file
 * @param {Object} [options] - Options
 * @param {boolean} [options.initTodo=false] - Initialize todo module
 * @param {boolean} [options.initVdom=false] - Initialize VDOM module
 * @param {boolean} [options.initComponent=false] - Initialize component module
 */
export async function quickStart(wasmPath, options = {}) {
    const { init } = await import('./core.js');
    await init(wasmPath);

    if (options.initTodo) {
        const { init: todoInit } = await import('./todo.js');
        todoInit();
    }

    if (options.initVdom) {
        const { init: vdomInit } = await import('./vdom.js');
        vdomInit();
    }

    if (options.initComponent) {
        const { init: componentInit } = await import('./component.js');
        componentInit();
    }
}

// Default export for convenience
export default {
    VERSION,
    quickStart,
};
