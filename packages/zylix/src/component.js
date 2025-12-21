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
    // Basic Components (0-9)
    CONTAINER: 0,
    TEXT: 1,
    BUTTON: 2,
    INPUT: 3,
    IMAGE: 4,
    LINK: 5,
    LIST: 6,
    LIST_ITEM: 7,
    HEADING: 8,
    PARAGRAPH: 9,

    // Form Components (10-20)
    SELECT: 10,
    CHECKBOX: 11,
    RADIO: 12,
    TEXTAREA: 13,
    TOGGLE_SWITCH: 14,
    SLIDER: 15,
    DATE_PICKER: 16,
    TIME_PICKER: 17,
    FILE_INPUT: 18,
    COLOR_PICKER: 19,
    FORM: 20,

    // Layout Components (21-28)
    STACK: 21,
    GRID: 22,
    SCROLL_VIEW: 23,
    SPACER: 24,
    DIVIDER: 25,
    CARD: 26,
    ASPECT_RATIO: 27,
    SAFE_AREA: 28,

    // Navigation Components (30-34)
    NAV_BAR: 30,
    TAB_BAR: 31,
    DRAWER: 32,
    BREADCRUMB: 33,
    PAGINATION: 34,

    // Feedback Components (40-46)
    ALERT: 40,
    TOAST: 41,
    MODAL: 42,
    PROGRESS: 43,
    SPINNER: 44,
    SKELETON: 45,
    BADGE: 46,

    // Data Display Components (50-56)
    TABLE: 50,
    AVATAR: 51,
    ICON: 52,
    TAG: 53,
    TOOLTIP: 54,
    ACCORDION: 55,
    CAROUSEL: 56,

    // Reserved
    CUSTOM: 255,
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
 * Stack directions
 */
export const StackDirection = Object.freeze({
    VERTICAL: 0,
    HORIZONTAL: 1,
    Z_STACK: 2,
});

/**
 * Stack alignments
 */
export const StackAlignment = Object.freeze({
    START: 0,
    CENTER: 1,
    END: 2,
    STRETCH: 3,
    SPACE_BETWEEN: 4,
    SPACE_AROUND: 5,
    SPACE_EVENLY: 6,
});

/**
 * Progress styles
 */
export const ProgressStyle = Object.freeze({
    LINEAR: 0,
    CIRCULAR: 1,
    INDETERMINATE: 2,
});

/**
 * Alert styles
 */
export const AlertStyle = Object.freeze({
    INFO: 0,
    SUCCESS: 1,
    WARNING: 2,
    ERROR: 3,
});

/**
 * Toast positions
 */
export const ToastPosition = Object.freeze({
    TOP: 0,
    BOTTOM: 1,
    TOP_LEFT: 2,
    TOP_RIGHT: 3,
    BOTTOM_LEFT: 4,
    BOTTOM_RIGHT: 5,
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

// ============================================================================
// Form Components (v0.7.0)
// ============================================================================

/**
 * Create a select/dropdown component
 * @param {string} [placeholder=''] - Placeholder text
 * @returns {number} Component ID
 */
export function createSelect(placeholder = '') {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_select) return 0;

    const { ptr, len } = writeString(placeholder);
    const id = wasm.zigdom_component_create_select(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a checkbox component
 * @param {string} label - Checkbox label
 * @returns {number} Component ID
 */
export function createCheckbox(label) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_checkbox) return 0;

    const { ptr, len } = writeString(label);
    const id = wasm.zigdom_component_create_checkbox(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a radio button component
 * @param {string} label - Radio button label
 * @param {string} group - Group name
 * @returns {number} Component ID
 */
export function createRadio(label, group) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_radio) return 0;

    const { ptr: labelPtr, len: labelLen } = writeString(label);
    const { ptr: groupPtr, len: groupLen } = writeString(group);
    const id = wasm.zigdom_component_create_radio(labelPtr, labelLen, groupPtr, groupLen);
    freeScratch();
    return id;
}

/**
 * Create a textarea component
 * @param {string} [placeholder=''] - Placeholder text
 * @returns {number} Component ID
 */
export function createTextarea(placeholder = '') {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_textarea) return 0;

    const { ptr, len } = writeString(placeholder);
    const id = wasm.zigdom_component_create_textarea(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a form container component
 * @returns {number} Component ID
 */
export function createForm() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_form?.() ?? 0;
}

/**
 * Create a toggle switch component
 * @param {string} label - Switch label
 * @returns {number} Component ID
 */
export function createToggleSwitch(label) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_toggle_switch) return 0;

    const { ptr, len } = writeString(label);
    const id = wasm.zigdom_component_create_toggle_switch(ptr, len);
    freeScratch();
    return id;
}

/**
 * Set checked state for checkbox/radio
 * @param {number} id - Component ID
 * @param {boolean} checked - Checked state
 */
export function setChecked(id, checked) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_checked?.(id, checked);
}

/**
 * Get checked state for checkbox/radio
 * @param {number} id - Component ID
 * @returns {boolean}
 */
export function getChecked(id) {
    const wasm = getWasm();
    return wasm?.zigdom_component_get_checked?.(id) ?? false;
}

/**
 * Set textarea rows
 * @param {number} id - Component ID
 * @param {number} rows - Number of rows
 */
export function setTextareaRows(id, rows) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_textarea_rows?.(id, rows);
}

/**
 * Set textarea cols
 * @param {number} id - Component ID
 * @param {number} cols - Number of columns
 */
export function setTextareaCols(id, cols) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_textarea_cols?.(id, cols);
}

// ============================================================================
// Layout Components (v0.7.0)
// ============================================================================

/**
 * Create a vertical stack component
 * @returns {number} Component ID
 */
export function createVStack() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_vstack?.() ?? 0;
}

/**
 * Create a horizontal stack component
 * @returns {number} Component ID
 */
export function createHStack() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_hstack?.() ?? 0;
}

/**
 * Create a z-stack (overlay) component
 * @returns {number} Component ID
 */
export function createZStack() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_zstack?.() ?? 0;
}

/**
 * Create a grid component
 * @returns {number} Component ID
 */
export function createGrid() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_grid?.() ?? 0;
}

/**
 * Create a scroll view component
 * @returns {number} Component ID
 */
export function createScrollView() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_scroll_view?.() ?? 0;
}

/**
 * Create a spacer component
 * @returns {number} Component ID
 */
export function createSpacer() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_spacer?.() ?? 0;
}

/**
 * Create a divider component
 * @returns {number} Component ID
 */
export function createDivider() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_divider?.() ?? 0;
}

/**
 * Create a card component
 * @returns {number} Component ID
 */
export function createCard() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_card?.() ?? 0;
}

/**
 * Set stack spacing
 * @param {number} id - Component ID
 * @param {number} spacing - Spacing in pixels
 */
export function setStackSpacing(id, spacing) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_stack_spacing?.(id, spacing);
}

/**
 * Set stack alignment
 * @param {number} id - Component ID
 * @param {number} alignment - StackAlignment value
 */
export function setStackAlignment(id, alignment) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_stack_alignment?.(id, alignment);
}

// ============================================================================
// Navigation Components (v0.7.0)
// ============================================================================

/**
 * Create a navigation bar component
 * @param {string} title - Navigation bar title
 * @returns {number} Component ID
 */
export function createNavBar(title) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_nav_bar) return 0;

    const { ptr, len } = writeString(title);
    const id = wasm.zigdom_component_create_nav_bar(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a tab bar component
 * @returns {number} Component ID
 */
export function createTabBar() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_tab_bar?.() ?? 0;
}

// ============================================================================
// Feedback Components (v0.7.0)
// ============================================================================

/**
 * Create an alert dialog component
 * @param {string} message - Alert message
 * @param {number} [style=AlertStyle.INFO] - Alert style
 * @returns {number} Component ID
 */
export function createAlert(message, style = 0) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_alert) return 0;

    const { ptr, len } = writeString(message);
    const id = wasm.zigdom_component_create_alert(ptr, len, style);
    freeScratch();
    return id;
}

/**
 * Create a toast notification component
 * @param {string} message - Toast message
 * @param {number} [position=ToastPosition.BOTTOM] - Toast position
 * @returns {number} Component ID
 */
export function createToast(message, position = 1) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_toast) return 0;

    const { ptr, len } = writeString(message);
    const id = wasm.zigdom_component_create_toast(ptr, len, position);
    freeScratch();
    return id;
}

/**
 * Create a modal dialog component
 * @param {string} title - Modal title
 * @returns {number} Component ID
 */
export function createModal(title) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_modal) return 0;

    const { ptr, len } = writeString(title);
    const id = wasm.zigdom_component_create_modal(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a progress indicator component
 * @param {number} [style=ProgressStyle.LINEAR] - Progress style
 * @returns {number} Component ID
 */
export function createProgress(style = 0) {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_progress?.(style) ?? 0;
}

/**
 * Create a loading spinner component
 * @returns {number} Component ID
 */
export function createSpinner() {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_spinner?.() ?? 0;
}

/**
 * Set progress value (0.0 to 1.0)
 * @param {number} id - Component ID
 * @param {number} value - Progress value
 */
export function setProgressValue(id, value) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_progress_value?.(id, value);
}

// ============================================================================
// Data Display Components (v0.7.0)
// ============================================================================

/**
 * Create an icon component
 * @param {string} name - Icon name
 * @returns {number} Component ID
 */
export function createIcon(name) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_icon) return 0;

    const { ptr, len } = writeString(name);
    const id = wasm.zigdom_component_create_icon(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create an avatar component
 * @param {string} src - Avatar image source
 * @param {string} alt - Alt text
 * @returns {number} Component ID
 */
export function createAvatar(src, alt) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_avatar) return 0;

    const { ptr: srcPtr, len: srcLen } = writeString(src);
    const { ptr: altPtr, len: altLen } = writeString(alt);
    const id = wasm.zigdom_component_create_avatar(srcPtr, srcLen, altPtr, altLen);
    freeScratch();
    return id;
}

/**
 * Create a tag component
 * @param {string} label - Tag label
 * @returns {number} Component ID
 */
export function createTag(label) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_tag) return 0;

    const { ptr, len } = writeString(label);
    const id = wasm.zigdom_component_create_tag(ptr, len);
    freeScratch();
    return id;
}

/**
 * Create a badge component with count
 * @param {number} count - Badge count
 * @returns {number} Component ID
 */
export function createBadge(count) {
    const wasm = getWasm();
    return wasm?.zigdom_component_create_badge?.(BigInt(count)) ?? 0;
}

/**
 * Create an accordion component
 * @param {string} title - Accordion title
 * @returns {number} Component ID
 */
export function createAccordion(title) {
    const wasm = getWasm();
    if (!wasm?.zigdom_component_create_accordion) return 0;

    const { ptr, len } = writeString(title);
    const id = wasm.zigdom_component_create_accordion(ptr, len);
    freeScratch();
    return id;
}

/**
 * Set expanded state (for accordion, etc.)
 * @param {number} id - Component ID
 * @param {boolean} expanded - Expanded state
 */
export function setExpanded(id, expanded) {
    const wasm = getWasm();
    wasm?.zigdom_component_set_expanded?.(id, expanded);
}

/**
 * Get expanded state
 * @param {number} id - Component ID
 * @returns {boolean}
 */
export function getExpanded(id) {
    const wasm = getWasm();
    return wasm?.zigdom_component_get_expanded?.(id) ?? false;
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
    // Enums
    ComponentType,
    InputType,
    EventType,
    HeadingLevel,
    StackDirection,
    StackAlignment,
    ProgressStyle,
    AlertStyle,
    ToastPosition,

    // Core
    init,
    reset,

    // Basic Components
    createContainer,
    createText,
    createButton,
    createInput,
    createHeading,
    createParagraph,
    createLink,
    createImage,

    // Form Components (v0.7.0)
    createSelect,
    createCheckbox,
    createRadio,
    createTextarea,
    createForm,
    createToggleSwitch,
    setChecked,
    getChecked,
    setTextareaRows,
    setTextareaCols,

    // Layout Components (v0.7.0)
    createVStack,
    createHStack,
    createZStack,
    createGrid,
    createScrollView,
    createSpacer,
    createDivider,
    createCard,
    setStackSpacing,
    setStackAlignment,

    // Navigation Components (v0.7.0)
    createNavBar,
    createTabBar,

    // Feedback Components (v0.7.0)
    createAlert,
    createToast,
    createModal,
    createProgress,
    createSpinner,
    setProgressValue,

    // Data Display Components (v0.7.0)
    createIcon,
    createAvatar,
    createTag,
    createBadge,
    createAccordion,
    setExpanded,
    getExpanded,

    // Tree Operations
    addChild,
    remove,

    // Property Setters
    setStyle,
    setText,
    setClass,
    setPlaceholder,
    setValue,

    // Event Handlers
    onClick,
    onInput,
    onChange,

    // State
    setDisabled,
    setVisible,
    dispatchEvent,

    // Queries
    getCount,
    getRoot,

    // Rendering
    render,
    getRenderCommandCount,
};
