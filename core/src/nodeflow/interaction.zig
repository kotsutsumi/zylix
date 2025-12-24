//! Interaction Features API
//!
//! Handle user interactions in node graphs:
//! - Context menus
//! - Keyboard shortcuts
//! - Touch/gesture support
//! - Drag and drop
//! - Selection box (lasso)
//! - Mouse/pointer events
//!
//! This module provides interaction handling for React Flow-style node graphs.

const std = @import("std");
const nodes = @import("nodes.zig");
const edges = @import("edges.zig");

/// Interaction error types
pub const InteractionError = error{
    InvalidTarget,
    ActionNotAllowed,
    ShortcutConflict,
    GestureNotRecognized,
    OutOfMemory,
};

/// Mouse/pointer button
pub const PointerButton = enum(u8) {
    none = 0,
    left = 1,
    middle = 2,
    right = 3,

    pub fn isPrimary(self: PointerButton) bool {
        return self == .left;
    }

    pub fn isSecondary(self: PointerButton) bool {
        return self == .right;
    }
};

/// Modifier keys
pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    meta: bool = false, // Command on Mac, Windows key on Windows

    pub fn none() Modifiers {
        return .{};
    }

    pub fn hasAny(self: Modifiers) bool {
        return self.shift or self.ctrl or self.alt or self.meta;
    }

    pub fn eql(self: Modifiers, other: Modifiers) bool {
        return self.shift == other.shift and
            self.ctrl == other.ctrl and
            self.alt == other.alt and
            self.meta == other.meta;
    }
};

/// Pointer event type
pub const PointerEventType = enum(u8) {
    down = 0,
    up = 1,
    move = 2,
    enter = 3,
    leave = 4,
    cancel = 5,
};

/// Pointer event
pub const PointerEvent = struct {
    event_type: PointerEventType,
    x: f32,
    y: f32,
    button: PointerButton = .none,
    modifiers: Modifiers = .{},
    pointer_id: u32 = 0, // For multi-touch
    is_touch: bool = false,
    pressure: f32 = 0.5, // 0.0 to 1.0
    timestamp: i64 = 0,

    pub fn isPrimary(self: PointerEvent) bool {
        return self.pointer_id == 0;
    }
};

/// Wheel/scroll event
pub const WheelEvent = struct {
    delta_x: f32,
    delta_y: f32,
    x: f32,
    y: f32,
    modifiers: Modifiers = .{},
    mode: WheelMode = .pixel,
};

/// Wheel scroll mode
pub const WheelMode = enum(u8) {
    pixel = 0,
    line = 1,
    page = 2,
};

/// Keyboard event type
pub const KeyEventType = enum(u8) {
    down = 0,
    up = 1,
    press = 2,
};

/// Keyboard event
pub const KeyEvent = struct {
    event_type: KeyEventType,
    key: Key,
    modifiers: Modifiers = .{},
    repeat: bool = false,
};

/// Common key codes
pub const Key = enum(u16) {
    // Letters
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,

    // Numbers
    digit_0 = 48,
    digit_1 = 49,
    digit_2 = 50,
    digit_3 = 51,
    digit_4 = 52,
    digit_5 = 53,
    digit_6 = 54,
    digit_7 = 55,
    digit_8 = 56,
    digit_9 = 57,

    // Special
    space = 32,
    enter = 13,
    tab = 9,
    escape = 27,
    backspace = 8,
    delete = 46,

    // Arrows
    arrow_up = 38,
    arrow_down = 40,
    arrow_left = 37,
    arrow_right = 39,

    // Modifiers (for detection)
    shift = 16,
    ctrl = 17,
    alt = 18,
    meta = 91,

    // Function keys
    f1 = 112,
    f2 = 113,
    f3 = 114,
    f4 = 115,
    f5 = 116,
    f6 = 117,
    f7 = 118,
    f8 = 119,
    f9 = 120,
    f10 = 121,
    f11 = 122,
    f12 = 123,

    // Other
    home = 36,
    end = 35,
    page_up = 33,
    page_down = 34,
    insert = 45,

    // Symbols
    equal = 187, // = key (+ with shift)
    minus = 189, // - key
    bracket_left = 219,
    bracket_right = 221,
    semicolon = 186,
    quote = 222,
    comma = 188,
    period = 190,
    slash = 191,
    backslash = 220,
    backtick = 192,

    unknown = 0,

    pub fn isAlphanumeric(self: Key) bool {
        const code = @intFromEnum(self);
        return (code >= 65 and code <= 90) or (code >= 48 and code <= 57);
    }

    pub fn isArrow(self: Key) bool {
        return self == .arrow_up or self == .arrow_down or
            self == .arrow_left or self == .arrow_right;
    }

    pub fn isModifier(self: Key) bool {
        return self == .shift or self == .ctrl or self == .alt or self == .meta;
    }
};

/// Keyboard shortcut
pub const Shortcut = struct {
    key: Key,
    modifiers: Modifiers = .{},

    pub fn matches(self: Shortcut, event: KeyEvent) bool {
        return self.key == event.key and self.modifiers.eql(event.modifiers);
    }

    pub fn ctrlKey(key: Key) Shortcut {
        return .{ .key = key, .modifiers = .{ .ctrl = true } };
    }

    pub fn shiftKey(key: Key) Shortcut {
        return .{ .key = key, .modifiers = .{ .shift = true } };
    }

    pub fn ctrlShiftKey(key: Key) Shortcut {
        return .{ .key = key, .modifiers = .{ .ctrl = true, .shift = true } };
    }
};

/// Interaction action
pub const Action = enum(u8) {
    // Selection
    select_all = 0,
    deselect_all = 1,
    invert_selection = 2,

    // Edit
    delete = 10,
    copy = 11,
    cut = 12,
    paste = 13,
    duplicate = 14,

    // History
    undo = 20,
    redo = 21,

    // View
    zoom_in = 30,
    zoom_out = 31,
    zoom_reset = 32,
    fit_view = 33,
    toggle_minimap = 34,
    toggle_grid = 35,

    // Layout
    auto_layout = 40,
    align_left = 41,
    align_center = 42,
    align_right = 43,
    align_top = 44,
    align_middle = 45,
    align_bottom = 46,

    // Navigation
    focus_next = 50,
    focus_previous = 51,

    // Custom
    custom = 255,

    pub fn toString(self: Action) []const u8 {
        return switch (self) {
            .select_all => "Select All",
            .deselect_all => "Deselect All",
            .invert_selection => "Invert Selection",
            .delete => "Delete",
            .copy => "Copy",
            .cut => "Cut",
            .paste => "Paste",
            .duplicate => "Duplicate",
            .undo => "Undo",
            .redo => "Redo",
            .zoom_in => "Zoom In",
            .zoom_out => "Zoom Out",
            .zoom_reset => "Reset Zoom",
            .fit_view => "Fit View",
            .toggle_minimap => "Toggle Minimap",
            .toggle_grid => "Toggle Grid",
            .auto_layout => "Auto Layout",
            .align_left => "Align Left",
            .align_center => "Align Center",
            .align_right => "Align Right",
            .align_top => "Align Top",
            .align_middle => "Align Middle",
            .align_bottom => "Align Bottom",
            .focus_next => "Focus Next",
            .focus_previous => "Focus Previous",
            .custom => "Custom",
        };
    }
};

/// Context menu item
pub const MenuItem = struct {
    id: []const u8,
    label: []const u8,
    shortcut: ?Shortcut = null,
    icon: ?[]const u8 = null,
    enabled: bool = true,
    visible: bool = true,
    action: ?Action = null,
    submenu: []const MenuItem = &.{},
    is_separator: bool = false,

    pub fn separator() MenuItem {
        return .{
            .id = "separator",
            .label = "",
            .is_separator = true,
        };
    }
};

/// Context menu
pub const ContextMenu = struct {
    items: []const MenuItem,
    x: f32,
    y: f32,
    target_type: TargetType,
    target_id: ?u64 = null,
};

/// Interaction target type
pub const TargetType = enum(u8) {
    none = 0,
    canvas = 1,
    node = 2,
    edge = 3,
    handle = 4,
    selection = 5,
    minimap = 6,

    pub fn isElement(self: TargetType) bool {
        return self == .node or self == .edge or self == .handle;
    }
};

/// Drag state
pub const DragState = enum(u8) {
    idle = 0,
    dragging = 1,
    connecting = 2, // Dragging new connection
    selecting = 3, // Selection box
    panning = 4, // Pan viewport
};

/// Selection box
pub const SelectionBox = struct {
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    active: bool = false,

    pub fn bounds(self: SelectionBox) struct { x: f32, y: f32, width: f32, height: f32 } {
        return .{
            .x = @min(self.start_x, self.end_x),
            .y = @min(self.start_y, self.end_y),
            .width = @abs(self.end_x - self.start_x),
            .height = @abs(self.end_y - self.start_y),
        };
    }

    pub fn containsPoint(self: SelectionBox, x: f32, y: f32) bool {
        const b = self.bounds();
        return x >= b.x and x <= b.x + b.width and
            y >= b.y and y <= b.y + b.height;
    }
};

/// Touch gesture type
pub const GestureType = enum(u8) {
    none = 0,
    tap = 1,
    double_tap = 2,
    long_press = 3,
    pan = 4,
    pinch = 5,
    rotate = 6,
};

/// Touch gesture state
pub const GestureState = struct {
    gesture_type: GestureType = .none,
    touch_count: u8 = 0,
    center_x: f32 = 0,
    center_y: f32 = 0,
    scale: f32 = 1.0,
    rotation: f32 = 0,
    velocity_x: f32 = 0,
    velocity_y: f32 = 0,
};

/// Interaction state manager
pub const InteractionManager = struct {
    allocator: std.mem.Allocator,

    // State
    drag_state: DragState = .idle,
    drag_start_x: f32 = 0,
    drag_start_y: f32 = 0,
    drag_current_x: f32 = 0,
    drag_current_y: f32 = 0,
    drag_target: ?u64 = null,
    selection_box: SelectionBox = .{ .start_x = 0, .start_y = 0, .end_x = 0, .end_y = 0 },
    gesture_state: GestureState = .{},

    // Configuration
    enable_pan: bool = true,
    enable_zoom: bool = true,
    enable_selection: bool = true,
    enable_drag: bool = true,
    enable_connect: bool = true,
    enable_context_menu: bool = true,
    enable_shortcuts: bool = true,
    enable_touch: bool = true,

    // Settings
    double_click_time: u32 = 300, // ms
    long_press_time: u32 = 500, // ms
    drag_threshold: f32 = 5.0, // pixels
    zoom_sensitivity: f32 = 0.1,
    pan_sensitivity: f32 = 1.0,

    // Shortcuts
    shortcuts: std.StringHashMapUnmanaged(Action) = .{},

    // Context menu builder
    context_menu_callback: ?*const fn (TargetType, ?u64) []const MenuItem = null,

    // Event callbacks
    on_node_click: ?*const fn (nodes.NodeId, Modifiers) void = null,
    on_node_double_click: ?*const fn (nodes.NodeId) void = null,
    on_edge_click: ?*const fn (edges.EdgeId, Modifiers) void = null,
    on_canvas_click: ?*const fn (f32, f32, Modifiers) void = null,
    on_action: ?*const fn (Action) void = null,

    pub fn init(allocator: std.mem.Allocator) InteractionManager {
        var manager = InteractionManager{
            .allocator = allocator,
        };
        manager.registerDefaultShortcuts() catch {};
        return manager;
    }

    pub fn deinit(self: *InteractionManager) void {
        self.shortcuts.deinit(self.allocator);
    }

    /// Register default keyboard shortcuts
    pub fn registerDefaultShortcuts(self: *InteractionManager) !void {
        // Selection
        try self.registerShortcut("ctrl+a", .select_all);
        try self.registerShortcut("escape", .deselect_all);

        // Edit
        try self.registerShortcut("delete", .delete);
        try self.registerShortcut("backspace", .delete);
        try self.registerShortcut("ctrl+c", .copy);
        try self.registerShortcut("ctrl+x", .cut);
        try self.registerShortcut("ctrl+v", .paste);
        try self.registerShortcut("ctrl+d", .duplicate);

        // History
        try self.registerShortcut("ctrl+z", .undo);
        try self.registerShortcut("ctrl+shift+z", .redo);
        try self.registerShortcut("ctrl+y", .redo);

        // View
        try self.registerShortcut("ctrl+plus", .zoom_in);
        try self.registerShortcut("ctrl+minus", .zoom_out);
        try self.registerShortcut("ctrl+0", .zoom_reset);
        try self.registerShortcut("ctrl+1", .fit_view);
    }

    /// Register a keyboard shortcut
    pub fn registerShortcut(self: *InteractionManager, shortcut_str: []const u8, action: Action) !void {
        try self.shortcuts.put(self.allocator, shortcut_str, action);
    }

    /// Unregister a keyboard shortcut
    pub fn unregisterShortcut(self: *InteractionManager, shortcut_str: []const u8) bool {
        return self.shortcuts.remove(shortcut_str);
    }

    /// Handle pointer down
    pub fn handlePointerDown(self: *InteractionManager, event: PointerEvent, target_type: TargetType, target_id: ?u64) void {
        self.drag_start_x = event.x;
        self.drag_start_y = event.y;
        self.drag_current_x = event.x;
        self.drag_current_y = event.y;
        self.drag_target = target_id;

        if (event.button.isPrimary()) {
            switch (target_type) {
                .canvas => {
                    if (self.enable_selection and !event.modifiers.hasAny()) {
                        self.drag_state = .selecting;
                        self.selection_box = .{
                            .start_x = event.x,
                            .start_y = event.y,
                            .end_x = event.x,
                            .end_y = event.y,
                            .active = true,
                        };
                    } else if (self.enable_pan) {
                        self.drag_state = .panning;
                    }
                },
                .node => {
                    if (self.enable_drag) {
                        self.drag_state = .dragging;
                    }
                },
                .handle => {
                    if (self.enable_connect) {
                        self.drag_state = .connecting;
                    }
                },
                else => {},
            }
        } else if (event.button == .middle and self.enable_pan) {
            self.drag_state = .panning;
        }
    }

    /// Handle pointer move
    pub fn handlePointerMove(self: *InteractionManager, event: PointerEvent) struct { dx: f32, dy: f32 } {
        const dx = event.x - self.drag_current_x;
        const dy = event.y - self.drag_current_y;

        self.drag_current_x = event.x;
        self.drag_current_y = event.y;

        if (self.drag_state == .selecting) {
            self.selection_box.end_x = event.x;
            self.selection_box.end_y = event.y;
        }

        return .{ .dx = dx, .dy = dy };
    }

    /// Handle pointer up
    pub fn handlePointerUp(self: *InteractionManager, event: PointerEvent, target_type: TargetType, target_id: ?u64) void {
        const was_dragging = self.drag_state != .idle;
        const drag_distance = @sqrt(std.math.pow(f32, self.drag_current_x - self.drag_start_x, 2) +
            std.math.pow(f32, self.drag_current_y - self.drag_start_y, 2));

        // Check if it was a click (not a drag)
        if (drag_distance < self.drag_threshold and was_dragging) {
            // It's a click
            switch (target_type) {
                .node => {
                    if (self.on_node_click) |callback| {
                        if (target_id) |id| {
                            callback(.{ .id = id }, event.modifiers);
                        }
                    }
                },
                .edge => {
                    if (self.on_edge_click) |callback| {
                        if (target_id) |id| {
                            callback(.{ .id = id }, event.modifiers);
                        }
                    }
                },
                .canvas => {
                    if (self.on_canvas_click) |callback| {
                        callback(self.drag_start_x, self.drag_start_y, event.modifiers);
                    }
                },
                else => {},
            }
        }

        // Reset state
        self.drag_state = .idle;
        self.selection_box.active = false;
        self.drag_target = null;
    }

    /// Handle wheel event
    pub fn handleWheel(self: *InteractionManager, event: WheelEvent) struct { zoom_delta: f32, pan_x: f32, pan_y: f32 } {
        if (!self.enable_zoom and !self.enable_pan) {
            return .{ .zoom_delta = 0, .pan_x = 0, .pan_y = 0 };
        }

        // Ctrl + wheel = zoom, otherwise pan
        if (event.modifiers.ctrl and self.enable_zoom) {
            const zoom_delta = -event.delta_y * self.zoom_sensitivity;
            return .{ .zoom_delta = zoom_delta, .pan_x = 0, .pan_y = 0 };
        } else if (self.enable_pan) {
            return .{
                .zoom_delta = 0,
                .pan_x = -event.delta_x * self.pan_sensitivity,
                .pan_y = -event.delta_y * self.pan_sensitivity,
            };
        }

        return .{ .zoom_delta = 0, .pan_x = 0, .pan_y = 0 };
    }

    /// Handle key event
    pub fn handleKeyDown(self: *InteractionManager, event: KeyEvent) ?Action {
        if (!self.enable_shortcuts or event.key.isModifier()) {
            return null;
        }

        // Build shortcut string and look up action
        var buf: [32]u8 = undefined;
        var len: usize = 0;

        if (event.modifiers.ctrl) {
            const part = "ctrl+";
            @memcpy(buf[len..][0..part.len], part);
            len += part.len;
        }
        if (event.modifiers.shift) {
            const part = "shift+";
            @memcpy(buf[len..][0..part.len], part);
            len += part.len;
        }
        if (event.modifiers.alt) {
            const part = "alt+";
            @memcpy(buf[len..][0..part.len], part);
            len += part.len;
        }

        // Add key name
        const key_name = getKeyName(event.key);
        @memcpy(buf[len..][0..key_name.len], key_name);
        len += key_name.len;

        if (self.shortcuts.get(buf[0..len])) |action| {
            if (self.on_action) |callback| {
                callback(action);
            }
            return action;
        }

        return null;
    }

    /// Build context menu for target
    pub fn buildContextMenu(self: *InteractionManager, x: f32, y: f32, target_type: TargetType, target_id: ?u64) ?ContextMenu {
        if (!self.enable_context_menu) return null;

        if (self.context_menu_callback) |builder| {
            const items = builder(target_type, target_id);
            return .{
                .items = items,
                .x = x,
                .y = y,
                .target_type = target_type,
                .target_id = target_id,
            };
        }

        // Default menu
        return .{
            .items = getDefaultContextMenu(target_type),
            .x = x,
            .y = y,
            .target_type = target_type,
            .target_id = target_id,
        };
    }

    /// Check if currently dragging
    pub fn isDragging(self: *const InteractionManager) bool {
        return self.drag_state != .idle;
    }

    /// Get current drag delta
    pub fn getDragDelta(self: *const InteractionManager) struct { dx: f32, dy: f32 } {
        return .{
            .dx = self.drag_current_x - self.drag_start_x,
            .dy = self.drag_current_y - self.drag_start_y,
        };
    }
};

// Helper functions

fn getKeyName(key: Key) []const u8 {
    return switch (key) {
        .a => "a",
        .b => "b",
        .c => "c",
        .d => "d",
        .e => "e",
        .f => "f",
        .g => "g",
        .h => "h",
        .i => "i",
        .j => "j",
        .k => "k",
        .l => "l",
        .m => "m",
        .n => "n",
        .o => "o",
        .p => "p",
        .q => "q",
        .r => "r",
        .s => "s",
        .t => "t",
        .u => "u",
        .v => "v",
        .w => "w",
        .x => "x",
        .y => "y",
        .z => "z",
        .digit_0 => "0",
        .digit_1 => "1",
        .digit_2 => "2",
        .digit_3 => "3",
        .digit_4 => "4",
        .digit_5 => "5",
        .digit_6 => "6",
        .digit_7 => "7",
        .digit_8 => "8",
        .digit_9 => "9",
        .space => "space",
        .enter => "enter",
        .escape => "escape",
        .delete => "delete",
        .backspace => "backspace",
        .tab => "tab",
        .arrow_up => "up",
        .arrow_down => "down",
        .arrow_left => "left",
        .arrow_right => "right",
        .equal => "plus", // = key maps to "plus" for shortcuts
        .minus => "minus",
        .comma => "comma",
        .period => "period",
        .slash => "slash",
        else => "unknown",
    };
}

fn getDefaultContextMenu(target_type: TargetType) []const MenuItem {
    return switch (target_type) {
        .node => &node_context_menu,
        .edge => &edge_context_menu,
        .canvas => &canvas_context_menu,
        else => &.{},
    };
}

const node_context_menu = [_]MenuItem{
    .{ .id = "copy", .label = "Copy", .action = .copy, .shortcut = Shortcut.ctrlKey(.c) },
    .{ .id = "cut", .label = "Cut", .action = .cut, .shortcut = Shortcut.ctrlKey(.x) },
    .{ .id = "duplicate", .label = "Duplicate", .action = .duplicate, .shortcut = Shortcut.ctrlKey(.d) },
    MenuItem.separator(),
    .{ .id = "delete", .label = "Delete", .action = .delete },
};

const edge_context_menu = [_]MenuItem{
    .{ .id = "delete", .label = "Delete Edge", .action = .delete },
};

const canvas_context_menu = [_]MenuItem{
    .{ .id = "paste", .label = "Paste", .action = .paste, .shortcut = Shortcut.ctrlKey(.v) },
    MenuItem.separator(),
    .{ .id = "select_all", .label = "Select All", .action = .select_all, .shortcut = Shortcut.ctrlKey(.a) },
    .{ .id = "fit_view", .label = "Fit View", .action = .fit_view },
    .{ .id = "auto_layout", .label = "Auto Layout", .action = .auto_layout },
};

/// Create an interaction manager
pub fn createInteractionManager(allocator: std.mem.Allocator) InteractionManager {
    return InteractionManager.init(allocator);
}

// Tests
test "InteractionManager initialization" {
    const allocator = std.testing.allocator;
    var manager = createInteractionManager(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.enable_pan);
    try std.testing.expect(manager.enable_zoom);
    try std.testing.expect(!manager.isDragging());
}

test "Modifiers" {
    const none = Modifiers.none();
    try std.testing.expect(!none.hasAny());

    const ctrl = Modifiers{ .ctrl = true };
    try std.testing.expect(ctrl.hasAny());
    try std.testing.expect(!ctrl.eql(none));
}

test "Key properties" {
    try std.testing.expect(Key.a.isAlphanumeric());
    try std.testing.expect(Key.digit_5.isAlphanumeric());
    try std.testing.expect(!Key.space.isAlphanumeric());

    try std.testing.expect(Key.arrow_up.isArrow());
    try std.testing.expect(!Key.a.isArrow());

    try std.testing.expect(Key.ctrl.isModifier());
    try std.testing.expect(!Key.a.isModifier());
}

test "Shortcut matching" {
    const shortcut = Shortcut.ctrlKey(.c);
    const event = KeyEvent{
        .event_type = .down,
        .key = .c,
        .modifiers = .{ .ctrl = true },
    };

    try std.testing.expect(shortcut.matches(event));

    const wrong_event = KeyEvent{
        .event_type = .down,
        .key = .c,
        .modifiers = .{},
    };
    try std.testing.expect(!shortcut.matches(wrong_event));
}

test "PointerButton" {
    try std.testing.expect(PointerButton.left.isPrimary());
    try std.testing.expect(!PointerButton.right.isPrimary());
    try std.testing.expect(PointerButton.right.isSecondary());
}

test "SelectionBox bounds" {
    const box = SelectionBox{
        .start_x = 100,
        .start_y = 100,
        .end_x = 50,
        .end_y = 200,
        .active = true,
    };

    const bounds = box.bounds();
    try std.testing.expectEqual(@as(f32, 50), bounds.x);
    try std.testing.expectEqual(@as(f32, 100), bounds.y);
    try std.testing.expectEqual(@as(f32, 50), bounds.width);
    try std.testing.expectEqual(@as(f32, 100), bounds.height);

    try std.testing.expect(box.containsPoint(75, 150));
    try std.testing.expect(!box.containsPoint(0, 0));
}

test "Action toString" {
    try std.testing.expect(std.mem.eql(u8, "Copy", Action.copy.toString()));
    try std.testing.expect(std.mem.eql(u8, "Undo", Action.undo.toString()));
}

test "TargetType" {
    try std.testing.expect(TargetType.node.isElement());
    try std.testing.expect(TargetType.edge.isElement());
    try std.testing.expect(!TargetType.canvas.isElement());
}

test "MenuItem separator" {
    const sep = MenuItem.separator();
    try std.testing.expect(sep.is_separator);
    try std.testing.expect(std.mem.eql(u8, "separator", sep.id));
}

test "Pointer event primary" {
    const event = PointerEvent{
        .event_type = .down,
        .x = 0,
        .y = 0,
        .pointer_id = 0,
    };
    try std.testing.expect(event.isPrimary());
}

test "Drag state management" {
    const allocator = std.testing.allocator;
    var manager = createInteractionManager(allocator);
    defer manager.deinit();

    manager.handlePointerDown(.{
        .event_type = .down,
        .x = 100,
        .y = 100,
        .button = .left,
    }, .node, 1);

    try std.testing.expect(manager.isDragging());
    try std.testing.expectEqual(DragState.dragging, manager.drag_state);

    _ = manager.handlePointerMove(.{
        .event_type = .move,
        .x = 150,
        .y = 120,
    });

    const delta = manager.getDragDelta();
    try std.testing.expectEqual(@as(f32, 50), delta.dx);
    try std.testing.expectEqual(@as(f32, 20), delta.dy);
}
