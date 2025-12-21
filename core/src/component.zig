// ZigDom Component System
// Phase 5.3: React-like component primitives in Zig
//
// Architecture:
// - Component tree with props, state, and children
// - Event system for user interactions
// - Integration with CSS and Layout systems
// - Render commands for JavaScript DOM execution

const std = @import("std");
const css = @import("css.zig");
const layout = @import("layout.zig");

// ============================================================================
// Component Types
// ============================================================================

pub const ComponentType = enum(u8) {
    // Basic Components (0-9)
    container = 0, // div-like container
    text = 1, // text/span element
    button = 2, // clickable button
    input = 3, // text input field
    image = 4, // image element
    link = 5, // anchor link
    list = 6, // ul/ol list
    list_item = 7, // li item
    heading = 8, // h1-h6
    paragraph = 9, // p element

    // Form Components (10-19)
    select = 10, // dropdown/picker
    checkbox = 11, // boolean toggle
    radio = 12, // single selection from group
    textarea = 13, // multi-line text input
    toggle_switch = 14, // toggle switch
    slider = 15, // range input
    date_picker = 16, // date selection
    time_picker = 17, // time selection
    file_input = 18, // file selection
    color_picker = 19, // color selection
    form = 20, // form container with validation

    // Layout Components (21-29)
    stack = 21, // vertical/horizontal stack
    grid = 22, // CSS Grid-like layout
    scroll_view = 23, // scrollable container
    spacer = 24, // flexible space
    divider = 25, // visual separator
    card = 26, // card container with shadow
    aspect_ratio = 27, // fixed aspect ratio container
    safe_area = 28, // safe area insets

    // Navigation Components (30-39)
    nav_bar = 30, // navigation bar
    tab_bar = 31, // tab navigation
    drawer = 32, // side drawer/menu
    breadcrumb = 33, // breadcrumb navigation
    pagination = 34, // page navigation

    // Feedback Components (40-49)
    alert = 40, // alert dialog
    toast = 41, // toast notification
    modal = 42, // modal dialog
    progress = 43, // progress indicator
    spinner = 44, // loading spinner
    skeleton = 45, // loading placeholder
    badge = 46, // notification badge

    // Data Display Components (50-59)
    table = 50, // data table
    avatar = 51, // user avatar
    icon = 52, // icon component
    tag = 53, // label/tag
    tooltip = 54, // hover tooltip
    accordion = 55, // expandable sections
    carousel = 56, // image carousel

    // Reserved
    custom = 255, // custom component
};

pub const HeadingLevel = enum(u8) {
    h1 = 1,
    h2 = 2,
    h3 = 3,
    h4 = 4,
    h5 = 5,
    h6 = 6,
};

pub const InputType = enum(u8) {
    text = 0,
    password = 1,
    email = 2,
    number = 3,
    search = 4,
    tel = 5,
    url = 6,
    checkbox = 7,
    radio = 8,
};

// ============================================================================
// Stack/Layout Types (v0.2.0)
// ============================================================================

pub const StackDirection = enum(u8) {
    vertical = 0, // VStack
    horizontal = 1, // HStack
    z_stack = 2, // ZStack (overlay)
};

pub const StackAlignment = enum(u8) {
    start = 0,
    center = 1,
    end = 2,
    stretch = 3,
    space_between = 4,
    space_around = 5,
    space_evenly = 6,
};

// ============================================================================
// Progress/Feedback Types (v0.2.0)
// ============================================================================

pub const ProgressStyle = enum(u8) {
    linear = 0,
    circular = 1,
    indeterminate = 2,
};

pub const AlertStyle = enum(u8) {
    info = 0,
    success = 1,
    warning = 2,
    error_alert = 3,
};

pub const ToastPosition = enum(u8) {
    top = 0,
    bottom = 1,
    top_left = 2,
    top_right = 3,
    bottom_left = 4,
    bottom_right = 5,
};

// ============================================================================
// Select/Option Types (v0.2.0)
// ============================================================================

pub const MAX_OPTIONS = 32;
pub const MAX_OPTION_TEXT = 64;

pub const SelectOption = struct {
    value: [MAX_OPTION_TEXT]u8 = std.mem.zeroes([MAX_OPTION_TEXT]u8),
    value_len: u8 = 0,
    label: [MAX_OPTION_TEXT]u8 = std.mem.zeroes([MAX_OPTION_TEXT]u8),
    label_len: u8 = 0,
    disabled: bool = false,

    pub fn init(value: []const u8, label: []const u8) SelectOption {
        var opt = SelectOption{};
        opt.setValue(value);
        opt.setLabel(label);
        return opt;
    }

    pub fn setValue(self: *SelectOption, val: []const u8) void {
        const len = @min(val.len, MAX_OPTION_TEXT);
        @memcpy(self.value[0..len], val[0..len]);
        self.value_len = @intCast(len);
    }

    pub fn setLabel(self: *SelectOption, lbl: []const u8) void {
        const len = @min(lbl.len, MAX_OPTION_TEXT);
        @memcpy(self.label[0..len], lbl[0..len]);
        self.label_len = @intCast(len);
    }

    pub fn getValue(self: *const SelectOption) []const u8 {
        return self.value[0..self.value_len];
    }

    pub fn getLabel(self: *const SelectOption) []const u8 {
        return self.label[0..self.label_len];
    }
};

// ============================================================================
// Component State
// ============================================================================

pub const ComponentState = packed struct {
    hover: bool = false,
    focus: bool = false,
    active: bool = false, // pressed/clicked
    disabled: bool = false,
    checked: bool = false, // for checkbox/radio
    expanded: bool = false, // for expandable components
    loading: bool = false,
    error_state: bool = false,
};

// ============================================================================
// Event System
// ============================================================================

pub const EventType = enum(u8) {
    none = 0,
    click = 1,
    double_click = 2,
    mouse_enter = 3,
    mouse_leave = 4,
    mouse_down = 5,
    mouse_up = 6,
    focus = 7,
    blur = 8,
    input = 9,
    change = 10,
    submit = 11,
    key_down = 12,
    key_up = 13,
    key_press = 14,
};

pub const EventHandler = struct {
    event_type: EventType = .none,
    callback_id: u32 = 0, // ID for JavaScript callback lookup
    prevent_default: bool = false,
    stop_propagation: bool = false,
};

pub const MAX_EVENT_HANDLERS = 8;

// ============================================================================
// Text Content
// ============================================================================

pub const MAX_TEXT_LENGTH = 256;
pub const TextBuffer = [MAX_TEXT_LENGTH]u8;

// ============================================================================
// Component Props
// ============================================================================

pub const ComponentProps = extern struct {
    // Common props
    id: u32 = 0, // unique component ID
    class_name: TextBuffer = std.mem.zeroes(TextBuffer),
    class_name_len: u16 = 0,

    // Text content
    text: TextBuffer = std.mem.zeroes(TextBuffer),
    text_len: u16 = 0,

    // Style reference (from css.zig)
    style_id: u32 = 0,
    hover_style_id: u32 = 0,
    focus_style_id: u32 = 0,
    active_style_id: u32 = 0,
    disabled_style_id: u32 = 0,

    // Layout reference (from layout.zig)
    layout_id: u32 = 0,

    // Input-specific props
    input_type: InputType = .text,
    placeholder: TextBuffer = std.mem.zeroes(TextBuffer),
    placeholder_len: u16 = 0,
    value: TextBuffer = std.mem.zeroes(TextBuffer),
    value_len: u16 = 0,
    max_length: u16 = 0,

    // Link-specific props
    href: TextBuffer = std.mem.zeroes(TextBuffer),
    href_len: u16 = 0,
    target_blank: bool = false,

    // Image-specific props
    src: TextBuffer = std.mem.zeroes(TextBuffer),
    src_len: u16 = 0,
    alt: TextBuffer = std.mem.zeroes(TextBuffer),
    alt_len: u16 = 0,

    // Heading-specific props
    heading_level: HeadingLevel = .h1,

    // Accessibility
    aria_label: TextBuffer = std.mem.zeroes(TextBuffer),
    aria_label_len: u16 = 0,
    tab_index: i8 = 0,
    role: TextBuffer = std.mem.zeroes(TextBuffer),
    role_len: u8 = 0,

    // Data attributes (for custom data)
    data_value: i64 = 0,

    // ========================================================================
    // v0.2.0 Component Props
    // ========================================================================

    // Stack/Layout props
    stack_direction: StackDirection = .vertical,
    stack_alignment: StackAlignment = .start,
    stack_spacing: u16 = 0, // spacing between children in pixels

    // Progress/Feedback props
    progress_style: ProgressStyle = .linear,
    progress_value: f32 = 0.0, // 0.0 to 1.0
    alert_style: AlertStyle = .info,
    toast_position: ToastPosition = .bottom,
    toast_duration: u32 = 3000, // milliseconds

    // Slider props
    slider_min: f32 = 0.0,
    slider_max: f32 = 100.0,
    slider_step: f32 = 1.0,
    slider_value: f32 = 0.0,

    // Textarea props
    textarea_rows: u8 = 3,
    textarea_cols: u8 = 40,
    textarea_resize: bool = true,

    // Helper methods
    pub fn setText(self: *ComponentProps, text_str: []const u8) void {
        const len = @min(text_str.len, MAX_TEXT_LENGTH);
        @memcpy(self.text[0..len], text_str[0..len]);
        self.text_len = @intCast(len);
    }

    pub fn getText(self: *const ComponentProps) []const u8 {
        return self.text[0..self.text_len];
    }

    pub fn setClassName(self: *ComponentProps, name: []const u8) void {
        const len = @min(name.len, MAX_TEXT_LENGTH);
        @memcpy(self.class_name[0..len], name[0..len]);
        self.class_name_len = @intCast(len);
    }

    pub fn setPlaceholder(self: *ComponentProps, text_str: []const u8) void {
        const len = @min(text_str.len, MAX_TEXT_LENGTH);
        @memcpy(self.placeholder[0..len], text_str[0..len]);
        self.placeholder_len = @intCast(len);
    }

    pub fn setValue(self: *ComponentProps, val: []const u8) void {
        const len = @min(val.len, MAX_TEXT_LENGTH);
        @memcpy(self.value[0..len], val[0..len]);
        self.value_len = @intCast(len);
    }

    pub fn setHref(self: *ComponentProps, url: []const u8) void {
        const len = @min(url.len, MAX_TEXT_LENGTH);
        @memcpy(self.href[0..len], url[0..len]);
        self.href_len = @intCast(len);
    }

    pub fn setSrc(self: *ComponentProps, url: []const u8) void {
        const len = @min(url.len, MAX_TEXT_LENGTH);
        @memcpy(self.src[0..len], url[0..len]);
        self.src_len = @intCast(len);
    }

    pub fn setAlt(self: *ComponentProps, text_str: []const u8) void {
        const len = @min(text_str.len, MAX_TEXT_LENGTH);
        @memcpy(self.alt[0..len], text_str[0..len]);
        self.alt_len = @intCast(len);
    }

    pub fn setAriaLabel(self: *ComponentProps, label: []const u8) void {
        const len = @min(label.len, MAX_TEXT_LENGTH);
        @memcpy(self.aria_label[0..len], label[0..len]);
        self.aria_label_len = @intCast(len);
    }
};

// ============================================================================
// Component Structure
// ============================================================================

pub const MAX_CHILDREN = 16;
pub const MAX_COMPONENTS = 256;

pub const Component = struct {
    // Identity
    id: u32 = 0,
    component_type: ComponentType = .container,
    active: bool = false,

    // State
    state: ComponentState = .{},

    // Props
    props: ComponentProps = .{},

    // Event handlers
    handlers: [MAX_EVENT_HANDLERS]EventHandler = std.mem.zeroes([MAX_EVENT_HANDLERS]EventHandler),
    handler_count: u8 = 0,

    // Tree structure
    parent_id: u32 = 0,
    children: [MAX_CHILDREN]u32 = std.mem.zeroes([MAX_CHILDREN]u32),
    child_count: u8 = 0,

    // Rendering
    needs_render: bool = true,
    visible: bool = true,

    // Builder pattern methods
    pub fn container() Component {
        return .{ .component_type = .container };
    }

    pub fn text(content: []const u8) Component {
        var c = Component{ .component_type = .text };
        c.props.setText(content);
        return c;
    }

    pub fn button(label: []const u8) Component {
        var c = Component{ .component_type = .button };
        c.props.setText(label);
        return c;
    }

    pub fn input(input_type: InputType) Component {
        var c = Component{ .component_type = .input };
        c.props.input_type = input_type;
        return c;
    }

    pub fn image(src: []const u8, alt_text: []const u8) Component {
        var c = Component{ .component_type = .image };
        c.props.setSrc(src);
        c.props.setAlt(alt_text);
        return c;
    }

    pub fn link(href_url: []const u8, label: []const u8) Component {
        var c = Component{ .component_type = .link };
        c.props.setHref(href_url);
        c.props.setText(label);
        return c;
    }

    pub fn heading(level: HeadingLevel, content: []const u8) Component {
        var c = Component{ .component_type = .heading };
        c.props.heading_level = level;
        c.props.setText(content);
        return c;
    }

    pub fn paragraph(content: []const u8) Component {
        var c = Component{ .component_type = .paragraph };
        c.props.setText(content);
        return c;
    }

    // ========================================================================
    // Form Component Builders (v0.2.0)
    // ========================================================================

    pub fn selectDropdown(placeholder_text: []const u8) Component {
        var c = Component{ .component_type = .select };
        c.props.setPlaceholder(placeholder_text);
        return c;
    }

    pub fn checkbox(label_text: []const u8) Component {
        var c = Component{ .component_type = .checkbox };
        c.props.setText(label_text);
        return c;
    }

    pub fn radio(label_text: []const u8, group_name: []const u8) Component {
        var c = Component{ .component_type = .radio };
        c.props.setText(label_text);
        c.props.setClassName(group_name); // Use className for group name
        return c;
    }

    pub fn textarea(placeholder_text: []const u8) Component {
        var c = Component{ .component_type = .textarea };
        c.props.setPlaceholder(placeholder_text);
        return c;
    }

    pub fn toggleSwitch(label_text: []const u8) Component {
        var c = Component{ .component_type = .toggle_switch };
        c.props.setText(label_text);
        return c;
    }

    pub fn formContainer() Component {
        return .{ .component_type = .form };
    }

    // ========================================================================
    // Layout Component Builders (v0.2.0)
    // ========================================================================

    pub fn vstack() Component {
        var c = Component{ .component_type = .stack };
        c.props.stack_direction = .vertical;
        return c;
    }

    pub fn hstack() Component {
        var c = Component{ .component_type = .stack };
        c.props.stack_direction = .horizontal;
        return c;
    }

    pub fn zstack() Component {
        var c = Component{ .component_type = .stack };
        c.props.stack_direction = .z_stack;
        return c;
    }

    pub fn scrollView() Component {
        return .{ .component_type = .scroll_view };
    }

    pub fn spacerComponent() Component {
        return .{ .component_type = .spacer };
    }

    pub fn dividerComponent() Component {
        return .{ .component_type = .divider };
    }

    pub fn cardContainer() Component {
        return .{ .component_type = .card };
    }

    // ========================================================================
    // Navigation Component Builders (v0.2.0)
    // ========================================================================

    pub fn navBar(title_text: []const u8) Component {
        var c = Component{ .component_type = .nav_bar };
        c.props.setText(title_text);
        return c;
    }

    pub fn tabBar() Component {
        return .{ .component_type = .tab_bar };
    }

    // ========================================================================
    // Feedback Component Builders (v0.2.0)
    // ========================================================================

    pub fn alertDialog(message: []const u8, style: AlertStyle) Component {
        var c = Component{ .component_type = .alert };
        c.props.setText(message);
        c.props.alert_style = style;
        return c;
    }

    pub fn toastNotification(message: []const u8, position: ToastPosition) Component {
        var c = Component{ .component_type = .toast };
        c.props.setText(message);
        c.props.toast_position = position;
        return c;
    }

    pub fn modalDialog(title_text: []const u8) Component {
        var c = Component{ .component_type = .modal };
        c.props.setText(title_text);
        return c;
    }

    pub fn progressIndicator(style: ProgressStyle) Component {
        var c = Component{ .component_type = .progress };
        c.props.progress_style = style;
        return c;
    }

    pub fn loadingSpinner() Component {
        return .{ .component_type = .spinner };
    }

    pub fn badgeComponent(count: i64) Component {
        var c = Component{ .component_type = .badge };
        c.props.data_value = count;
        return c;
    }

    // ========================================================================
    // Data Display Component Builders (v0.2.0)
    // ========================================================================

    pub fn iconComponent(icon_name: []const u8) Component {
        var c = Component{ .component_type = .icon };
        c.props.setText(icon_name);
        return c;
    }

    pub fn avatarComponent(src_url: []const u8, alt_text: []const u8) Component {
        var c = Component{ .component_type = .avatar };
        c.props.setSrc(src_url);
        c.props.setAlt(alt_text);
        return c;
    }

    pub fn tagComponent(label_text: []const u8) Component {
        var c = Component{ .component_type = .tag };
        c.props.setText(label_text);
        return c;
    }

    pub fn accordionComponent(title_text: []const u8) Component {
        var c = Component{ .component_type = .accordion };
        c.props.setText(title_text);
        return c;
    }

    // Chainable setters
    pub fn withStyle(self: Component, style_id: u32) Component {
        var c = self;
        c.props.style_id = style_id;
        return c;
    }

    pub fn withHoverStyle(self: Component, style_id: u32) Component {
        var c = self;
        c.props.hover_style_id = style_id;
        return c;
    }

    pub fn withLayout(self: Component, layout_id: u32) Component {
        var c = self;
        c.props.layout_id = layout_id;
        return c;
    }

    pub fn withClass(self: Component, class_name: []const u8) Component {
        var c = self;
        c.props.setClassName(class_name);
        return c;
    }

    pub fn withPlaceholder(self: Component, placeholder_text: []const u8) Component {
        var c = self;
        c.props.setPlaceholder(placeholder_text);
        return c;
    }

    pub fn withAriaLabel(self: Component, label: []const u8) Component {
        var c = self;
        c.props.setAriaLabel(label);
        return c;
    }

    pub fn withTabIndex(self: Component, index: i8) Component {
        var c = self;
        c.props.tab_index = index;
        return c;
    }

    pub fn withData(self: Component, value: i64) Component {
        var c = self;
        c.props.data_value = value;
        return c;
    }

    pub fn disabled(self: Component) Component {
        var c = self;
        c.state.disabled = true;
        return c;
    }

    pub fn hidden(self: Component) Component {
        var c = self;
        c.visible = false;
        return c;
    }

    // Add event handler
    pub fn on(self: Component, event_type: EventType, callback_id: u32) Component {
        var c = self;
        if (c.handler_count < MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = event_type,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
        return c;
    }

    pub fn onClick(self: Component, callback_id: u32) Component {
        return self.on(.click, callback_id);
    }

    pub fn onInput(self: Component, callback_id: u32) Component {
        return self.on(.input, callback_id);
    }

    pub fn onChange(self: Component, callback_id: u32) Component {
        return self.on(.change, callback_id);
    }

    pub fn onFocus(self: Component, callback_id: u32) Component {
        return self.on(.focus, callback_id);
    }

    pub fn onBlur(self: Component, callback_id: u32) Component {
        return self.on(.blur, callback_id);
    }

    // State updates
    pub fn setHover(self: *Component, is_hover: bool) void {
        if (self.state.hover != is_hover) {
            self.state.hover = is_hover;
            self.needs_render = true;
        }
    }

    pub fn setFocus(self: *Component, is_focus: bool) void {
        if (self.state.focus != is_focus) {
            self.state.focus = is_focus;
            self.needs_render = true;
        }
    }

    pub fn setActive(self: *Component, is_active: bool) void {
        if (self.state.active != is_active) {
            self.state.active = is_active;
            self.needs_render = true;
        }
    }

    pub fn setChecked(self: *Component, is_checked: bool) void {
        if (self.state.checked != is_checked) {
            self.state.checked = is_checked;
            self.needs_render = true;
        }
    }

    pub fn setLoading(self: *Component, is_loading: bool) void {
        if (self.state.loading != is_loading) {
            self.state.loading = is_loading;
            self.needs_render = true;
        }
    }

    // Get effective style based on state
    pub fn getEffectiveStyleId(self: *const Component) u32 {
        if (self.state.disabled and self.props.disabled_style_id != 0) {
            return self.props.disabled_style_id;
        }
        if (self.state.active and self.props.active_style_id != 0) {
            return self.props.active_style_id;
        }
        if (self.state.focus and self.props.focus_style_id != 0) {
            return self.props.focus_style_id;
        }
        if (self.state.hover and self.props.hover_style_id != 0) {
            return self.props.hover_style_id;
        }
        return self.props.style_id;
    }
};

// ============================================================================
// Component Tree (Manager)
// ============================================================================

pub const ComponentTree = struct {
    components: [MAX_COMPONENTS]Component,
    next_id: u32,
    root_id: u32,

    pub fn init() ComponentTree {
        var tree = ComponentTree{
            .components = undefined,
            .next_id = 1,
            .root_id = 0,
        };
        for (&tree.components) |*c| {
            c.* = .{};
        }
        return tree;
    }

    pub fn reset(self: *ComponentTree) void {
        for (&self.components) |*c| {
            c.* = .{};
        }
        self.next_id = 1;
        self.root_id = 0;
    }

    // Create a new component and return its ID
    pub fn create(self: *ComponentTree, template: Component) u32 {
        if (self.next_id >= MAX_COMPONENTS) return 0;

        const id = self.next_id;
        self.next_id += 1;

        var component = template;
        component.id = id;
        component.active = true;
        component.props.id = id;

        self.components[id] = component;

        // Set as root if first component
        if (self.root_id == 0) {
            self.root_id = id;
        }

        return id;
    }

    pub fn get(self: *ComponentTree, id: u32) ?*Component {
        if (id == 0 or id >= MAX_COMPONENTS) return null;
        if (!self.components[id].active) return null;
        return &self.components[id];
    }

    pub fn getConst(self: *const ComponentTree, id: u32) ?*const Component {
        if (id == 0 or id >= MAX_COMPONENTS) return null;
        if (!self.components[id].active) return null;
        return &self.components[id];
    }

    // Add child to parent
    pub fn addChild(self: *ComponentTree, parent_id: u32, child_id: u32) bool {
        const parent = self.get(parent_id) orelse return false;
        const child = self.get(child_id) orelse return false;

        if (parent.child_count >= MAX_CHILDREN) return false;

        parent.children[parent.child_count] = child_id;
        parent.child_count += 1;
        child.parent_id = parent_id;
        parent.needs_render = true;

        return true;
    }

    // Remove component (and optionally its children)
    pub fn remove(self: *ComponentTree, id: u32, recursive: bool) void {
        const component = self.get(id) orelse return;

        // Remove children first if recursive
        if (recursive) {
            for (component.children[0..component.child_count]) |child_id| {
                self.remove(child_id, true);
            }
        }

        // Remove from parent's children list
        if (component.parent_id != 0) {
            if (self.get(component.parent_id)) |parent| {
                var new_count: u8 = 0;
                for (parent.children[0..parent.child_count]) |child_id| {
                    if (child_id != id) {
                        parent.children[new_count] = child_id;
                        new_count += 1;
                    }
                }
                parent.child_count = new_count;
                parent.needs_render = true;
            }
        }

        // Deactivate component
        component.active = false;

        // Update root if needed
        if (self.root_id == id) {
            self.root_id = 0;
        }
    }

    // Dispatch event to component
    pub fn dispatchEvent(self: *ComponentTree, component_id: u32, event_type: EventType) ?u32 {
        const component = self.get(component_id) orelse return null;

        // Check if component handles this event
        for (component.handlers[0..component.handler_count]) |handler| {
            if (handler.event_type == event_type) {
                return handler.callback_id;
            }
        }

        // Bubble up to parent if not handled
        if (component.parent_id != 0) {
            return self.dispatchEvent(component.parent_id, event_type);
        }

        return null;
    }

    // Mark component and ancestors as needing render
    pub fn markDirty(self: *ComponentTree, id: u32) void {
        var current_id = id;
        while (current_id != 0) {
            if (self.get(current_id)) |c| {
                c.needs_render = true;
                current_id = c.parent_id;
            } else {
                break;
            }
        }
    }

    // Count total active components
    pub fn count(self: *const ComponentTree) u32 {
        var total: u32 = 0;
        for (self.components) |c| {
            if (c.active) total += 1;
        }
        return total;
    }

    // Traverse tree depth-first
    pub fn traverse(self: *const ComponentTree, start_id: u32, callback: *const fn (component: *const Component, depth: u32) void, depth: u32) void {
        const component = self.getConst(start_id) orelse return;
        callback(component, depth);

        for (component.children[0..component.child_count]) |child_id| {
            self.traverse(child_id, callback, depth + 1);
        }
    }
};

// ============================================================================
// Render Commands (for JavaScript execution)
// ============================================================================

pub const RenderCommandType = enum(u8) {
    create_element = 0,
    set_text = 1,
    set_attribute = 2,
    set_style = 3,
    append_child = 4,
    remove_child = 5,
    add_event_listener = 6,
    remove_element = 7,
    update_element = 8,
};

pub const RenderCommand = extern struct {
    command_type: RenderCommandType = .create_element,
    component_id: u32 = 0,
    parent_id: u32 = 0,
    component_type: ComponentType = .container,

    // For text/attributes
    data: TextBuffer = std.mem.zeroes(TextBuffer),
    data_len: u16 = 0,

    // For styles
    style_id: u32 = 0,

    // For events
    event_type: EventType = .none,
    callback_id: u32 = 0,

    pub fn setData(self: *RenderCommand, text: []const u8) void {
        const len = @min(text.len, MAX_TEXT_LENGTH);
        @memcpy(self.data[0..len], text[0..len]);
        self.data_len = @intCast(len);
    }
};

pub const MAX_RENDER_COMMANDS = 512;

pub const RenderQueue = struct {
    commands: [MAX_RENDER_COMMANDS]RenderCommand,
    count: u32,

    pub fn init() RenderQueue {
        return .{
            .commands = undefined,
            .count = 0,
        };
    }

    pub fn reset(self: *RenderQueue) void {
        self.count = 0;
    }

    pub fn push(self: *RenderQueue, cmd: RenderCommand) bool {
        if (self.count >= MAX_RENDER_COMMANDS) return false;
        self.commands[self.count] = cmd;
        self.count += 1;
        return true;
    }

    pub fn get(self: *const RenderQueue, index: u32) ?*const RenderCommand {
        if (index >= self.count) return null;
        return &self.commands[index];
    }
};

// ============================================================================
// Renderer
// ============================================================================

pub const Renderer = struct {
    tree: *ComponentTree,
    queue: RenderQueue,

    pub fn init(tree: *ComponentTree) Renderer {
        return .{
            .tree = tree,
            .queue = RenderQueue.init(),
        };
    }

    // Generate render commands for a component and its children
    pub fn render(self: *Renderer, component_id: u32) void {
        self.queue.reset();
        self.renderComponent(component_id, 0);
    }

    fn renderComponent(self: *Renderer, component_id: u32, parent_id: u32) void {
        const component = self.tree.getConst(component_id) orelse return;

        if (!component.visible) return;

        // Create element command
        const create_cmd = RenderCommand{
            .command_type = .create_element,
            .component_id = component.id,
            .parent_id = parent_id,
            .component_type = component.component_type,
        };
        _ = self.queue.push(create_cmd);

        // Set text content if any
        if (component.props.text_len > 0) {
            var text_cmd = RenderCommand{
                .command_type = .set_text,
                .component_id = component.id,
            };
            text_cmd.setData(component.props.getText());
            _ = self.queue.push(text_cmd);
        }

        // Set style
        const style_id = component.getEffectiveStyleId();
        if (style_id != 0) {
            _ = self.queue.push(.{
                .command_type = .set_style,
                .component_id = component.id,
                .style_id = style_id,
            });
        }

        // Add event listeners
        for (component.handlers[0..component.handler_count]) |handler| {
            if (handler.event_type != .none) {
                _ = self.queue.push(.{
                    .command_type = .add_event_listener,
                    .component_id = component.id,
                    .event_type = handler.event_type,
                    .callback_id = handler.callback_id,
                });
            }
        }

        // Render children
        for (component.children[0..component.child_count]) |child_id| {
            self.renderComponent(child_id, component.id);
        }
    }

    pub fn getCommandCount(self: *const Renderer) u32 {
        return self.queue.count;
    }

    pub fn getCommand(self: *const Renderer, index: u32) ?*const RenderCommand {
        return self.queue.get(index);
    }
};

// ============================================================================
// Global State (for WASM exports)
// ============================================================================

var global_tree: ComponentTree = undefined;
var global_renderer: Renderer = undefined;
var global_initialized: bool = false;

pub fn initGlobal() void {
    if (!global_initialized) {
        global_tree = ComponentTree.init();
        global_renderer = Renderer.init(&global_tree);
        global_initialized = true;
    }
}

pub fn getTree() *ComponentTree {
    if (!global_initialized) initGlobal();
    return &global_tree;
}

pub fn getRenderer() *Renderer {
    if (!global_initialized) initGlobal();
    return &global_renderer;
}

// ============================================================================
// Tests
// ============================================================================

test "component creation" {
    var tree = ComponentTree.init();

    const btn_id = tree.create(Component.button("Click me").onClick(1));
    try std.testing.expect(btn_id > 0);

    const btn = tree.get(btn_id).?;
    try std.testing.expectEqual(ComponentType.button, btn.component_type);
    try std.testing.expectEqualStrings("Click me", btn.props.getText());
}

test "component tree hierarchy" {
    var tree = ComponentTree.init();

    const container_id = tree.create(Component.container());
    const text_id = tree.create(Component.text("Hello"));
    const btn_id = tree.create(Component.button("Click"));

    try std.testing.expect(tree.addChild(container_id, text_id));
    try std.testing.expect(tree.addChild(container_id, btn_id));

    const container = tree.get(container_id).?;
    try std.testing.expectEqual(@as(u8, 2), container.child_count);
}

test "event dispatch" {
    var tree = ComponentTree.init();

    const btn_id = tree.create(Component.button("Click").onClick(42));

    const callback_id = tree.dispatchEvent(btn_id, .click);
    try std.testing.expectEqual(@as(?u32, 42), callback_id);

    const no_callback = tree.dispatchEvent(btn_id, .focus);
    try std.testing.expectEqual(@as(?u32, null), no_callback);
}

test "render queue" {
    var tree = ComponentTree.init();

    const container_id = tree.create(Component.container().withStyle(1));
    const text_id = tree.create(Component.text("Hello").withStyle(2));
    _ = tree.addChild(container_id, text_id);

    var renderer = Renderer.init(&tree);
    renderer.render(container_id);

    // Should have: create container, set style, create text, set text, set style
    try std.testing.expect(renderer.getCommandCount() >= 4);
}
