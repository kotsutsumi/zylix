/**
 * Zylix Component Showcase - JavaScript Bridge
 *
 * Demonstrates v0.7.0 Component Library features:
 * - Layout Components: VStack, HStack, Card, Divider, Spacer
 * - Form Components: Checkbox, Toggle, Select, Textarea
 * - Feedback Components: Alert, Progress, Spinner
 * - Data Display: Badge, Tag, Accordion
 */

const ZylixShowcase = {
    wasm: null,
    memory: null,
    initialized: false,

    /**
     * Alert styles (must match component.zig AlertStyle)
     */
    AlertStyle: {
        INFO: 0,
        SUCCESS: 1,
        WARNING: 2,
        ERROR: 3,
    },

    /**
     * Progress styles (must match component.zig ProgressStyle)
     */
    ProgressStyle: {
        LINEAR: 0,
        CIRCULAR: 1,
    },

    /**
     * Stack alignment (must match component.zig StackAlignment)
     */
    StackAlignment: {
        START: 0,
        CENTER: 1,
        END: 2,
        STRETCH: 3,
        SPACE_BETWEEN: 4,
        SPACE_AROUND: 5,
        SPACE_EVENLY: 6,
    },

    /**
     * Initialize Zylix WASM module
     * @param {string} wasmPath - Path to the zylix.wasm file
     * @returns {Promise<void>}
     */
    async init(wasmPath) {
        if (this.initialized) {
            console.warn('ZylixShowcase already initialized');
            return;
        }

        const response = await fetch(wasmPath);
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status} ${response.statusText}`);
        }

        const wasmBuffer = await response.arrayBuffer();

        const imports = {
            env: {
                js_console_log: (ptr, len) => {
                    console.log('[Zylix]', this.readString(ptr, len));
                },
            },
        };

        try {
            const result = await WebAssembly.instantiate(wasmBuffer, imports);
            this.wasm = result.instance.exports;
            this.memory = this.wasm.memory;
        } catch (error) {
            throw new Error(`WASM instantiation failed: ${error.message}`);
        }

        const initResult = this.wasm.zylix_init();
        if (initResult !== 0) {
            throw new Error(`Zylix initialization failed with code: ${initResult}`);
        }

        // Initialize component tree
        this.wasm.zigdom_component_init();

        this.initialized = true;
        console.log('ZylixShowcase initialized successfully');
        console.log('ABI Version:', this.wasm.zylix_get_abi_version?.() ?? 'N/A');
    },

    /**
     * Shutdown Zylix core
     */
    deinit() {
        if (!this.initialized) return;

        this.wasm.zigdom_component_reset();
        this.wasm.zylix_deinit();
        this.initialized = false;
        console.log('ZylixShowcase deinitialized');
    },

    // =========================================================================
    // String Utilities
    // =========================================================================

    readString(ptr, len) {
        if (!this.memory || ptr === 0 || len === 0) return '';
        const bytes = new Uint8Array(this.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    },

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

    freeScratch() {
        this.wasm.zylix_wasm_free_scratch?.();
    },

    // =========================================================================
    // Layout Components (v0.7.0)
    // =========================================================================

    createVStack() {
        return this.wasm.zigdom_component_create_vstack?.() ?? 0;
    },

    createHStack() {
        return this.wasm.zigdom_component_create_hstack?.() ?? 0;
    },

    createZStack() {
        return this.wasm.zigdom_component_create_zstack?.() ?? 0;
    },

    createCard() {
        return this.wasm.zigdom_component_create_card?.() ?? 0;
    },

    createDivider() {
        return this.wasm.zigdom_component_create_divider?.() ?? 0;
    },

    createSpacer() {
        return this.wasm.zigdom_component_create_spacer?.() ?? 0;
    },

    createGrid() {
        return this.wasm.zigdom_component_create_grid?.() ?? 0;
    },

    createScrollView() {
        return this.wasm.zigdom_component_create_scroll_view?.() ?? 0;
    },

    setStackSpacing(id, spacing) {
        this.wasm.zigdom_component_set_stack_spacing?.(id, spacing);
    },

    setStackAlignment(id, alignment) {
        this.wasm.zigdom_component_set_stack_alignment?.(id, alignment);
    },

    // =========================================================================
    // Basic Components
    // =========================================================================

    createContainer() {
        return this.wasm.zigdom_component_create_container?.() ?? 0;
    },

    createText(text) {
        const { ptr, len } = this.writeString(text);
        const id = this.wasm.zigdom_component_create_text?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createButton(label) {
        const { ptr, len } = this.writeString(label);
        const id = this.wasm.zigdom_component_create_button?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createHeading(level, text) {
        const { ptr, len } = this.writeString(text);
        const id = this.wasm.zigdom_component_create_heading?.(level, ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    // =========================================================================
    // Form Components (v0.7.0)
    // =========================================================================

    createCheckbox(label) {
        const { ptr, len } = this.writeString(label);
        const id = this.wasm.zigdom_component_create_checkbox?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createToggleSwitch(label) {
        const { ptr, len } = this.writeString(label);
        const id = this.wasm.zigdom_component_create_toggle_switch?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createSelect(placeholder) {
        const { ptr, len } = this.writeString(placeholder);
        const id = this.wasm.zigdom_component_create_select?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createTextarea(placeholder) {
        const { ptr, len } = this.writeString(placeholder);
        const id = this.wasm.zigdom_component_create_textarea?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createRadio(label, group) {
        const labelStr = this.writeString(label);
        const groupStr = this.writeString(group);
        const id = this.wasm.zigdom_component_create_radio?.(
            labelStr.ptr, labelStr.len,
            groupStr.ptr, groupStr.len
        ) ?? 0;
        this.freeScratch();
        return id;
    },

    setChecked(id, checked) {
        this.wasm.zigdom_component_set_checked?.(id, checked);
    },

    getChecked(id) {
        return this.wasm.zigdom_component_get_checked?.(id) ?? false;
    },

    // =========================================================================
    // Feedback Components (v0.7.0)
    // =========================================================================

    createAlert(message, style = 0) {
        const { ptr, len } = this.writeString(message);
        const id = this.wasm.zigdom_component_create_alert?.(ptr, len, style) ?? 0;
        this.freeScratch();
        return id;
    },

    createProgress(style = 0) {
        return this.wasm.zigdom_component_create_progress?.(style) ?? 0;
    },

    createSpinner() {
        return this.wasm.zigdom_component_create_spinner?.() ?? 0;
    },

    setProgressValue(id, value) {
        this.wasm.zigdom_component_set_progress_value?.(id, value);
    },

    createModal(title) {
        const { ptr, len } = this.writeString(title);
        const id = this.wasm.zigdom_component_create_modal?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createToast(message, position = 0) {
        const { ptr, len } = this.writeString(message);
        const id = this.wasm.zigdom_component_create_toast?.(ptr, len, position) ?? 0;
        this.freeScratch();
        return id;
    },

    // =========================================================================
    // Data Display Components (v0.7.0)
    // =========================================================================

    createBadge(count) {
        return this.wasm.zigdom_component_create_badge?.(BigInt(count)) ?? 0;
    },

    createTag(label) {
        const { ptr, len } = this.writeString(label);
        const id = this.wasm.zigdom_component_create_tag?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createAccordion(title) {
        const { ptr, len } = this.writeString(title);
        const id = this.wasm.zigdom_component_create_accordion?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createIcon(name) {
        const { ptr, len } = this.writeString(name);
        const id = this.wasm.zigdom_component_create_icon?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createAvatar(src, alt) {
        const srcStr = this.writeString(src);
        const altStr = this.writeString(alt);
        const id = this.wasm.zigdom_component_create_avatar?.(
            srcStr.ptr, srcStr.len,
            altStr.ptr, altStr.len
        ) ?? 0;
        this.freeScratch();
        return id;
    },

    setExpanded(id, expanded) {
        this.wasm.zigdom_component_set_expanded?.(id, expanded);
    },

    getExpanded(id) {
        return this.wasm.zigdom_component_get_expanded?.(id) ?? false;
    },

    // =========================================================================
    // Navigation Components (v0.7.0)
    // =========================================================================

    createNavBar(title) {
        const { ptr, len } = this.writeString(title);
        const id = this.wasm.zigdom_component_create_nav_bar?.(ptr, len) ?? 0;
        this.freeScratch();
        return id;
    },

    createTabBar() {
        return this.wasm.zigdom_component_create_tab_bar?.() ?? 0;
    },

    // =========================================================================
    // Component Tree Operations
    // =========================================================================

    addChild(parentId, childId) {
        return this.wasm.zigdom_component_add_child?.(parentId, childId) ?? false;
    },

    remove(id, recursive = true) {
        this.wasm.zigdom_component_remove?.(id, recursive);
    },

    setText(id, text) {
        const { ptr, len } = this.writeString(text);
        this.wasm.zigdom_component_set_text?.(id, ptr, len);
        this.freeScratch();
    },

    setClass(id, className) {
        const { ptr, len } = this.writeString(className);
        this.wasm.zigdom_component_set_class?.(id, ptr, len);
        this.freeScratch();
    },

    setAriaLabel(id, label) {
        const { ptr, len } = this.writeString(label);
        this.wasm.zigdom_component_set_aria_label?.(id, ptr, len);
        this.freeScratch();
    },

    setTabIndex(id, index) {
        this.wasm.zigdom_component_set_tab_index?.(id, index);
    },

    setVisible(id, visible) {
        this.wasm.zigdom_component_set_visible?.(id, visible);
    },

    setDisabled(id, disabled) {
        this.wasm.zigdom_component_set_disabled?.(id, disabled);
    },

    // =========================================================================
    // Component Info
    // =========================================================================

    getComponentCount() {
        return this.wasm.zigdom_component_get_count?.() ?? 0;
    },

    getComponentType(id) {
        return this.wasm.zigdom_component_get_type?.(id) ?? 0;
    },

    getText(id) {
        const ptr = this.wasm.zigdom_component_get_text?.(id);
        const len = this.wasm.zigdom_component_get_text_len?.(id) ?? 0;
        if (!ptr || len === 0) return '';
        return this.readString(ptr, len);
    },

    // =========================================================================
    // Memory Info
    // =========================================================================

    getMemoryUsed() {
        return this.wasm.zylix_wasm_memory_used?.() ?? 0;
    },

    getMemoryPeak() {
        return this.wasm.zylix_wasm_memory_peak?.() ?? 0;
    },
};

// Freeze enums
Object.freeze(ZylixShowcase.AlertStyle);
Object.freeze(ZylixShowcase.ProgressStyle);
Object.freeze(ZylixShowcase.StackAlignment);

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZylixShowcase;
}
