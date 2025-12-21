/**
 * Zylix VDOM - Virtual DOM Integration
 *
 * Provides a JavaScript interface to the Zig VDOM implementation.
 * The VDOM handles efficient DOM diffing and patching.
 */

import { getWasm, isInitialized, writeString, readString } from './core.js';

/**
 * Element tag constants
 */
export const Tag = Object.freeze({
    DIV: 0,
    SPAN: 1,
    SECTION: 2,
    ARTICLE: 3,
    HEADER: 4,
    FOOTER: 5,
    NAV: 6,
    MAIN: 7,
    H1: 8,
    H2: 9,
    H3: 10,
    H4: 11,
    H5: 12,
    H6: 13,
    P: 14,
    BUTTON: 15,
    A: 16,
    INPUT: 17,
    IMG: 18,
    UL: 19,
    OL: 20,
    LI: 21,
    FORM: 22,
    LABEL: 23,
});

/**
 * Patch type constants
 */
export const PatchType = Object.freeze({
    NONE: 0,
    CREATE: 1,
    REMOVE: 2,
    REPLACE: 3,
    UPDATE_PROPS: 4,
    UPDATE_TEXT: 5,
    REORDER: 6,
    INSERT_CHILD: 7,
    REMOVE_CHILD: 8,
});

/**
 * Initialize the VDOM reconciler
 */
export function init() {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) {
        throw new Error('Zylix core not initialized');
    }
    if (wasm.zigdom_vdom_init) {
        wasm.zigdom_vdom_init();
    }
}

/**
 * Reset the reconciler state
 */
export function reset() {
    const wasm = getWasm();
    wasm?.zigdom_vdom_reset?.();
}

/**
 * Create an element node
 * @param {number} tag - Tag constant from Tag enum
 * @returns {number} Node ID
 */
export function createElement(tag) {
    const wasm = getWasm();
    return wasm?.zigdom_vdom_create_element?.(tag) ?? 0;
}

/**
 * Create a text node
 * @param {string} text - Text content
 * @returns {number} Node ID
 */
export function createText(text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_vdom_create_text) return 0;

    const { ptr, len } = writeString(text);
    return wasm.zigdom_vdom_create_text(ptr, len);
}

/**
 * Set node class
 * @param {number} nodeId - Node ID
 * @param {string} className - CSS class name(s)
 */
export function setClass(nodeId, className) {
    const wasm = getWasm();
    if (!wasm?.zigdom_vdom_set_class) return;

    const { ptr, len } = writeString(className);
    wasm.zigdom_vdom_set_class(nodeId, ptr, len);
}

/**
 * Set node onClick handler
 * @param {number} nodeId - Node ID
 * @param {number} callbackId - Callback ID
 */
export function setOnClick(nodeId, callbackId) {
    const wasm = getWasm();
    wasm?.zigdom_vdom_set_onclick?.(nodeId, callbackId);
}

/**
 * Set node text content
 * @param {number} nodeId - Node ID
 * @param {string} text - Text content
 */
export function setText(nodeId, text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_vdom_set_text) return;

    const { ptr, len } = writeString(text);
    wasm.zigdom_vdom_set_text(nodeId, ptr, len);
}

/**
 * Set node key for list reconciliation
 * @param {number} nodeId - Node ID
 * @param {string} key - Unique key
 */
export function setKey(nodeId, key) {
    const wasm = getWasm();
    if (!wasm?.zigdom_vdom_set_key) return;

    const { ptr, len } = writeString(key);
    wasm.zigdom_vdom_set_key(nodeId, ptr, len);
}

/**
 * Add child to parent node
 * @param {number} parentId - Parent node ID
 * @param {number} childId - Child node ID
 * @returns {boolean} Success
 */
export function addChild(parentId, childId) {
    const wasm = getWasm();
    return wasm?.zigdom_vdom_add_child?.(parentId, childId) ?? false;
}

/**
 * Set root node
 * @param {number} nodeId - Node ID to set as root
 */
export function setRoot(nodeId) {
    const wasm = getWasm();
    wasm?.zigdom_vdom_set_root?.(nodeId);
}

/**
 * Commit changes and generate patches
 * @returns {number} Number of patches generated
 */
export function commit() {
    const wasm = getWasm();
    return wasm?.zigdom_vdom_commit?.() ?? 0;
}

/**
 * Get the number of patches
 * @returns {number}
 */
export function getPatchCount() {
    const wasm = getWasm();
    return wasm?.zigdom_vdom_get_patch_count?.() ?? 0;
}

/**
 * Get a patch at index
 * @param {number} index - Patch index
 * @returns {Object | null} Patch object
 */
export function getPatch(index) {
    const wasm = getWasm();
    if (!wasm) return null;

    const patchType = wasm.zigdom_vdom_get_patch_type?.(index) ?? 0;
    if (patchType === PatchType.NONE) return null;

    const patch = {
        type: patchType,
        nodeId: wasm.zigdom_vdom_get_patch_node_id?.(index) ?? 0,
        domId: wasm.zigdom_vdom_get_patch_dom_id?.(index) ?? 0,
        parentId: wasm.zigdom_vdom_get_patch_parent_id?.(index) ?? 0,
        tag: wasm.zigdom_vdom_get_patch_tag?.(index) ?? 0,
        nodeType: wasm.zigdom_vdom_get_patch_node_type?.(index) ?? 0,
        index: wasm.zigdom_vdom_get_patch_index?.(index) ?? 0,
    };

    // Get text if present
    const textPtr = wasm.zigdom_vdom_get_patch_text?.(index);
    const textLen = wasm.zigdom_vdom_get_patch_text_len?.(index) ?? 0;
    if (textPtr && textLen > 0) {
        patch.text = readString(textPtr, textLen);
    }

    // Get class if present
    const classPtr = wasm.zigdom_vdom_get_patch_class?.(index);
    const classLen = wasm.zigdom_vdom_get_patch_class_len?.(index) ?? 0;
    if (classPtr && classLen > 0) {
        patch.className = readString(classPtr, classLen);
    }

    // Get onClick if present
    patch.onClick = wasm.zigdom_vdom_get_patch_onclick?.(index) ?? 0;
    patch.styleId = wasm.zigdom_vdom_get_patch_style_id?.(index) ?? 0;

    return patch;
}

/**
 * Get all patches as an array
 * @returns {Array<Object>}
 */
export function getPatches() {
    const patches = [];
    const count = getPatchCount();

    for (let i = 0; i < count; i++) {
        const patch = getPatch(i);
        if (patch) {
            patches.push(patch);
        }
    }

    return patches;
}

/**
 * Get current tree node count
 * @returns {number}
 */
export function getNodeCount() {
    const wasm = getWasm();
    return wasm?.zigdom_vdom_get_node_count?.() ?? 0;
}

/**
 * Apply patches to the DOM
 * @param {Element} container - DOM container element
 * @param {Map<number, Element>} [domMap] - Map of node IDs to DOM elements
 * @returns {Map<number, Element>} Updated DOM map
 */
export function applyPatches(container, domMap = new Map()) {
    const patches = getPatches();

    for (const patch of patches) {
        switch (patch.type) {
            case PatchType.CREATE: {
                const element = createDomElement(patch);
                if (element) {
                    const parent = patch.parentId ? domMap.get(patch.parentId) : container;
                    if (parent) {
                        parent.appendChild(element);
                    }
                    domMap.set(patch.nodeId, element);
                }
                break;
            }

            case PatchType.REMOVE: {
                const element = domMap.get(patch.nodeId);
                if (element && element.parentNode) {
                    element.parentNode.removeChild(element);
                }
                domMap.delete(patch.nodeId);
                break;
            }

            case PatchType.UPDATE_TEXT: {
                const element = domMap.get(patch.nodeId);
                if (element && patch.text !== undefined) {
                    element.textContent = patch.text;
                }
                break;
            }

            case PatchType.UPDATE_PROPS: {
                const element = domMap.get(patch.nodeId);
                if (element) {
                    if (patch.className !== undefined) {
                        element.className = patch.className;
                    }
                }
                break;
            }
        }
    }

    return domMap;
}

/**
 * Create a DOM element from a patch
 * @param {Object} patch - Patch object
 * @returns {Element | Text | null}
 */
function createDomElement(patch) {
    const tagNames = [
        'div', 'span', 'section', 'article', 'header', 'footer', 'nav', 'main',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'button', 'a', 'input', 'img',
        'ul', 'ol', 'li', 'form', 'label'
    ];

    if (patch.nodeType === 1) { // Text node
        return document.createTextNode(patch.text || '');
    }

    const tagName = tagNames[patch.tag] || 'div';
    const element = document.createElement(tagName);

    if (patch.className) {
        element.className = patch.className;
    }

    if (patch.text) {
        element.textContent = patch.text;
    }

    return element;
}

// Default export
export default {
    Tag,
    PatchType,
    init,
    reset,
    createElement,
    createText,
    setClass,
    setOnClick,
    setText,
    setKey,
    addChild,
    setRoot,
    commit,
    getPatchCount,
    getPatch,
    getPatches,
    getNodeCount,
    applyPatches,
};
