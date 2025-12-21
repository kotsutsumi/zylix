/**
 * Zylix Component - Component System Integration
 *
 * Provides a component-based UI system backed by the Zig core.
 */

import { getWasm, isInitialized, writeString, readString, freeScratch } from './core.js';

/**
 * Component types
 */
export const ComponentType = Object.freeze({
    CONTAINER: 0,
    TEXT: 1,
    BUTTON: 2,
    INPUT: 3,
    HEADING: 4,
    PARAGRAPH: 5,
    LINK: 6,
    IMAGE: 7,
});

/**
 * Input types
 */
export const InputType = Object.freeze({
    TEXT: 0,
    PASSWORD: 1,
    EMAIL: 2,
    NUMBER: 3,
    CHECKBOX: 4,
    RADIO: 5,
    SUBMIT: 6,
});

/**
 * Event types
 */
export const EventType = Object.freeze({
    CLICK: 0,
    INPUT: 1,
    CHANGE: 2,
    FOCUS: 3,
    BLUR: 4,
    SUBMIT: 5,
    KEYDOWN: 6,
    KEYUP: 7,
});

/**
 * Heading levels
 */
export const HeadingLevel = Object.freeze({
    H1: 1,
    H2: 2,
    H3: 3,
    H4: 4,
    H5: 5,
    H6: 6,
});

/**
 * Initialize the component system
 */
export function init() {
    const wasm = getWasm();
    if (!wasm || !isInitialized()) {
        throw new Error('Zylix core not initialized');
    }
    if (wasm.zigdom_component_init) {
        wasm.zigdom_component_init();
    }
}

/**
 * Reset the component tree
 */
export function reset() {
    const wasm = getWasm();
    wasm?.zigdom_component_reset?.();
}

/**
 * Create a container component
 * @returns {number} Component ID
 */
export function createContainer() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_container?.() ?? 0;
}

/**
 * Create a text component
 * @param {string} text - Text content
 * @returns {number} Component ID
 */
export function createText(text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_text) return 0;

    const { ptr, len } = writeString(text);
    const id = wasm.zigdom_component_create_text(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a button component
 * @param {string} label - Button label
 * @returns {number} Component ID
 */
export function createButton(label) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_button) return 0;

    const { ptr, len } = writeString(label);
    const id = wasm.zigdom_component_create_button(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create an input component
 * @param {number} [inputType=InputType.TEXT] - Input type
 * @returns {number} Component ID
 */
export function createInput(inputType = InputType.TEXT) {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_input?.(inputType) ?? 0;
}

/**
 * Create a heading component
 * @param {number} level - Heading level (1-6)
 * @param {string} text - Heading text
 * @returns {number} Component ID
 */
export function createHeading(level, text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_heading) return 0;

    const { ptr, len } = writeString(text);
    const id = wasm.zigdom_component_create_heading(level, ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a paragraph component
 * @param {string} text - Paragraph text
 * @returns {number} Component ID
 */
export function createParagraph(text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_paragraph) return 0;

    const { ptr, len } = writeString(text);
    const id = wasm.zigdom_component_create_paragraph(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a link component
 * @param {string} href - Link URL
 * @param {string} label - Link text
 * @returns {number} Component ID
 */
export function createLink(href, label) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_link) return 0;

    const { ptr: hrefPtr, len: hrefLen } = writeString(href);
    const { ptr: labelPtr, len: labelLen } = writeString(label);
    const id = wasm.zigdom_component_create_link(hrefPtr, hrefLen, labelPtr, labelLen);
    freeScratch();
    return id;
}

/**
 * Create an image component
 * @param {string} src - Image source URL
 * @param {string} alt - Alt text
 * @returns {number} Component ID
 */
export function createImage(src, alt) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_image) return 0;

    const { ptr: srcPtr, len: srcLen } = writeString(src);
    const { ptr: altPtr, len: altLen } = writeString(alt);
    const id = wasm.zigdom_component_create_image(srcPtr, srcLen, altPtr, altLen);
    freeScratch();
    return id;
}

/**
 * Add a child to a parent component
 * @param {number} parentId - Parent component ID
 * @param {number} childId - Child component ID
 * @returns {boolean} Success
 */
export function addChild(parentId, childId) {
    const wasm = getWasm();
    return wasm?.zigdom_component_add_child?.(parentId, childId) ?? false;
}

/**
 * Remove a component
 * @param {number} id - Component ID
 * @param {boolean} [recursive=true] - Remove children too
 */
export function remove(id, recursive = true) {
    const wasm = getWasm();
    wasm?.zigdom_component_remove?.(id, recursive);
}

/**
 * Set component style
 * @param {number} id - Component ID
 * @param {number} styleId - Style ID
 */
export function setStyle(id, styleId) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_style?.(id, styleId);
}

/**
 * Set component text content
 * @param {number} id - Component ID
 * @param {string} text - Text content
 */
export function setText(id, text) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_set_text) return;

    const { ptr, len } = writeString(text);
    wasm.zigdom_component_set_text(id, ptr, len);
    freeScratch();
}

/**
 * Set component class name
 * @param {number} id - Component ID
 * @param {string} className - CSS class name(s)
 */
export function setClass(id, className) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_set_class) return;

    const { ptr, len } = writeString(className);
    wasm.zigdom_component_set_class(id, ptr, len);
    freeScratch();
}

/**
 * Set input placeholder
 * @param {number} id - Component ID
 * @param {string} placeholder - Placeholder text
 */
export function setPlaceholder(id, placeholder) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_set_placeholder) return;

    const { ptr, len } = writeString(placeholder);
    wasm.zigdom_component_set_placeholder(id, ptr, len);
    freeScratch();
}

/**
 * Set input value
 * @param {number} id - Component ID
 * @param {string} value - Input value
 */
export function setValue(id, value) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_set_value) return;

    const { ptr, len } = writeString(value);
    wasm.zigdom_component_set_value(id, ptr, len);
    freeScratch();
}

/**
 * Add click event handler
 * @param {number} id - Component ID
 * @param {number} callbackId - Callback ID
 */
export function onClick(id, callbackId) {
    const wasm = getWasm();
    wasm?.zigdom_component_on_click?.(id, callbackId);
}

/**
 * Add input event handler
 * @param {number} id - Component ID
 * @param {number} callbackId - Callback ID
 */
export function onInput(id, callbackId) {
    const wasm = getWasm();
    wasm?.zigdom_component_on_input?.(id, callbackId);
}

/**
 * Add change event handler
 * @param {number} id - Component ID
 * @param {number} callbackId - Callback ID
 */
export function onChange(id, callbackId) {
    const wasm = getWasm();
    wasm?.zigdom_component_on_change?.(id, callbackId);
}

/**
 * Set disabled state
 * @param {number} id - Component ID
 * @param {boolean} disabled - Disabled state
 */
export function setDisabled(id, disabled) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_disabled?.(id, disabled);
}

/**
 * Set visible state
 * @param {number} id - Component ID
 * @param {boolean} visible - Visible state
 */
export function setVisible(id, visible) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_visible?.(id, visible);
}

/**
 * Dispatch event to component
 * @param {number} id - Component ID
 * @param {number} eventType - Event type
 * @returns {number} Callback ID (0 if not handled)
 */
export function dispatchEvent(id, eventType) {
    const wasm = getWasm();
    return wasm?.zigdom_component_dispatch_event?.(id, eventType) ?? 0;
}

/**
 * Get component count
 * @returns {number}
 */
export function getCount() {
    const wasm = getWasm();
    return wasm?.zigdom_component_get_count?.() ?? 0;
}

/**
 * Get root component ID
 * @returns {number}
 */
export function getRoot() {
    const wasm = getWasm();
    return wasm?.zigdom_component_get_root?.() ?? 0;
}

/**
 * Render component tree
 * @param {number} rootId - Root component ID
 */
export function render(rootId) {
    const wasm = getWasm();
    wasm?.zigdom_component_render?.(rootId);
}

/**
 * Get render command count
 * @returns {number}
 */
export function getRenderCommandCount() {
    const wasm = getWasm();
    return wasm?.zigdom_component_get_render_command_count?.() ?? 0;
}

// Default export
export default {
    ComponentType,
    InputType,
    EventType,
    HeadingLevel,
    init,
    reset,
    createContainer,
    createText,
    createButton,
    createInput,
    createHeading,
    createParagraph,
    createLink,
    createImage,
    addChild,
    remove,
    setStyle,
    setText,
    setClass,
    setPlaceholder,
    setValue,
    onClick,
    onInput,
    onChange,
    setDisabled,
    setVisible,
    dispatchEvent,
    getCount,
    getRoot,
    render,
    getRenderCommandCount,
};
