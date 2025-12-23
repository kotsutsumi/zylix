//! Zylix Gesture - Drag and Drop
//!
//! Cross-platform drag and drop support with platform-aware initiation.
//! - iOS/Android: Long-press to initiate drag
//! - macOS/Windows/Linux/Web: Standard drag initiation

const std = @import("std");
const types = @import("types.zig");

pub const Point = types.Point;
pub const Touch = types.Touch;
pub const TouchEvent = types.TouchEvent;
pub const TouchPhase = types.TouchPhase;
pub const GestureState = types.GestureState;

// === Drag Data Types ===

/// Drag data type
pub const DragDataType = enum(u8) {
    text = 0,
    url = 1,
    image = 2,
    file = 3,
    custom = 255,
};

/// Drag data item
pub const DragItem = struct {
    data_type: DragDataType = .text,
    data: [2048]u8 = undefined,
    data_len: usize = 0,
    mime_type: [128]u8 = undefined,
    mime_type_len: usize = 0,

    pub fn setText(self: *DragItem, text: []const u8) void {
        self.data_type = .text;
        const len = @min(text.len, 2048);
        @memcpy(self.data[0..len], text[0..len]);
        self.data_len = len;
        self.setMimeType("text/plain");
    }

    pub fn setUrl(self: *DragItem, url: []const u8) void {
        self.data_type = .url;
        const len = @min(url.len, 2048);
        @memcpy(self.data[0..len], url[0..len]);
        self.data_len = len;
        self.setMimeType("text/uri-list");
    }

    pub fn setFilePath(self: *DragItem, path: []const u8) void {
        self.data_type = .file;
        const len = @min(path.len, 2048);
        @memcpy(self.data[0..len], path[0..len]);
        self.data_len = len;
        self.setMimeType("application/octet-stream");
    }

    pub fn setMimeType(self: *DragItem, mime: []const u8) void {
        const len = @min(mime.len, 128);
        @memcpy(self.mime_type[0..len], mime[0..len]);
        self.mime_type_len = len;
    }

    pub fn getData(self: *const DragItem) []const u8 {
        return self.data[0..self.data_len];
    }

    pub fn getMimeType(self: *const DragItem) []const u8 {
        return self.mime_type[0..self.mime_type_len];
    }
};

// === Drop Operation ===

/// Drop operation type
pub const DropOperation = enum(u8) {
    none = 0, // Drop not allowed
    copy = 1, // Copy data
    move = 2, // Move data
    link = 3, // Create link/reference
};

/// Drop target info
pub const DropTarget = struct {
    id: u32 = 0,
    accepts_types: [8]DragDataType = [_]DragDataType{.text} ** 8,
    accepts_count: usize = 1,
    operation: DropOperation = .copy,

    pub fn accepts(self: *const DropTarget, data_type: DragDataType) bool {
        for (self.accepts_types[0..self.accepts_count]) |t| {
            if (t == data_type) return true;
        }
        return false;
    }

    pub fn addAcceptedType(self: *DropTarget, data_type: DragDataType) bool {
        if (self.accepts_count >= 8) return false;
        self.accepts_types[self.accepts_count] = data_type;
        self.accepts_count += 1;
        return true;
    }
};

// === Drag Session ===

/// Drag session state
pub const DragState = enum(u8) {
    idle = 0,
    preparing = 1, // Long press in progress (mobile)
    dragging = 2,
    over_target = 3,
    ended = 4,
    cancelled = 5,
};

/// Drag session
pub const DragSession = struct {
    state: DragState = .idle,
    items: [5]?DragItem = [_]?DragItem{null} ** 5,
    item_count: usize = 0,
    source_id: u32 = 0,
    current_target: ?*DropTarget = null,
    location: Point = .{},
    start_location: Point = .{},
    preview_offset: Point = .{}, // Offset for drag preview

    pub fn addItem(self: *DragSession, item: DragItem) bool {
        if (self.item_count >= 5) return false;
        self.items[self.item_count] = item;
        self.item_count += 1;
        return true;
    }

    pub fn clear(self: *DragSession) void {
        for (&self.items) |*item| item.* = null;
        self.item_count = 0;
        self.state = .idle;
        self.current_target = null;
    }

    pub fn getItems(self: *const DragSession) []const ?DragItem {
        return self.items[0..self.item_count];
    }
};

// === Drag and Drop Manager ===

/// Platform type for drag initiation behavior
pub const DragPlatform = enum(u8) {
    mobile = 0, // Long-press to drag (iOS, Android)
    desktop = 1, // Direct drag (macOS, Windows, Linux, Web)
};

/// Drag and drop configuration
pub const DragDropConfig = struct {
    platform: DragPlatform = .desktop,
    long_press_duration_ms: u32 = 500, // For mobile
    min_drag_distance: f64 = 10, // Min movement to start drag
    show_preview: bool = true,
    haptic_feedback: bool = true, // On mobile
};

/// Drag event callback
pub const DragCallback = *const fn (session: *const DragSession, event: DragEvent) void;

/// Drag events
pub const DragEvent = enum(u8) {
    drag_started = 0,
    drag_moved = 1,
    drag_entered_target = 2,
    drag_exited_target = 3,
    drag_ended = 4,
    drag_cancelled = 5,
    drop_performed = 6,
};

/// Drag and drop manager
pub const DragDropManager = struct {
    config: DragDropConfig = .{},
    session: DragSession = .{},

    // Drop targets
    targets: [32]?DropTarget = [_]?DropTarget{null} ** 32,
    target_count: usize = 0,

    // Long press tracking (mobile)
    press_start_time: i64 = 0,
    press_start_location: Point = .{},

    // Callbacks
    callback: ?DragCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(config: DragDropConfig) Self {
        return .{ .config = config };
    }

    pub fn deinit(self: *Self) void {
        self.cancelDrag();
        self.platform_handle = null;
    }

    /// Register a drop target
    pub fn registerDropTarget(self: *Self, target: DropTarget) bool {
        if (self.target_count >= 32) return false;
        self.targets[self.target_count] = target;
        self.target_count += 1;
        return true;
    }

    /// Unregister a drop target
    pub fn unregisterDropTarget(self: *Self, target_id: u32) bool {
        for (&self.targets, 0..) |*slot, i| {
            if (slot.*) |target| {
                if (target.id == target_id) {
                    // Shift remaining targets
                    var j = i;
                    while (j < self.target_count - 1) : (j += 1) {
                        self.targets[j] = self.targets[j + 1];
                    }
                    self.targets[self.target_count - 1] = null;
                    self.target_count -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    /// Start drag with items
    pub fn startDrag(self: *Self, source_id: u32, items: []const DragItem, location: Point) bool {
        if (self.session.state != .idle) return false;

        self.session.clear();
        self.session.source_id = source_id;
        self.session.start_location = location;
        self.session.location = location;

        for (items) |item| {
            if (!self.session.addItem(item)) break;
        }

        self.session.state = .dragging;
        self.notifyCallback(.drag_started);
        return true;
    }

    /// Begin long press (mobile platforms)
    pub fn beginLongPress(self: *Self, location: Point, timestamp: i64) void {
        if (self.config.platform != .mobile) return;
        self.press_start_time = timestamp;
        self.press_start_location = location;
        self.session.state = .preparing;
    }

    /// Update long press (call periodically)
    pub fn updateLongPress(self: *Self, current_time: i64, current_location: Point) bool {
        if (self.session.state != .preparing) return false;

        // Check if moved too far
        if (self.press_start_location.distance(current_location) > self.config.min_drag_distance) {
            self.session.state = .idle;
            return false;
        }

        // Check if long press duration reached
        const duration = current_time - self.press_start_time;
        if (duration >= self.config.long_press_duration_ms) {
            self.session.state = .dragging;
            self.session.start_location = self.press_start_location;
            self.session.location = current_location;
            self.notifyCallback(.drag_started);
            return true;
        }

        return false;
    }

    /// Cancel long press
    pub fn cancelLongPress(self: *Self) void {
        if (self.session.state == .preparing) {
            self.session.state = .idle;
        }
    }

    /// Update drag position
    pub fn updateDrag(self: *Self, location: Point) void {
        if (self.session.state != .dragging and self.session.state != .over_target) return;

        self.session.location = location;

        // Check if over any target
        const prev_target = self.session.current_target;
        self.session.current_target = self.findTargetAtLocation(location);

        if (self.session.current_target != prev_target) {
            if (prev_target != null) {
                self.notifyCallback(.drag_exited_target);
            }
            if (self.session.current_target != null) {
                self.session.state = .over_target;
                self.notifyCallback(.drag_entered_target);
            } else {
                self.session.state = .dragging;
            }
        }

        self.notifyCallback(.drag_moved);
    }

    /// End drag (attempt drop)
    pub fn endDrag(self: *Self) DropOperation {
        if (self.session.state != .dragging and self.session.state != .over_target) {
            return .none;
        }

        var operation: DropOperation = .none;

        if (self.session.current_target) |target| {
            // Check if target accepts any of our items
            for (self.session.getItems()) |item_opt| {
                if (item_opt) |item| {
                    if (target.accepts(item.data_type)) {
                        operation = target.operation;
                        break;
                    }
                }
            }

            if (operation != .none) {
                self.notifyCallback(.drop_performed);
            }
        }

        self.session.state = .ended;
        self.notifyCallback(.drag_ended);
        self.session.clear();

        return operation;
    }

    /// Cancel current drag
    pub fn cancelDrag(self: *Self) void {
        if (self.session.state == .idle) return;

        self.session.state = .cancelled;
        self.notifyCallback(.drag_cancelled);
        self.session.clear();
    }

    /// Find drop target at location
    fn findTargetAtLocation(self: *Self, location: Point) ?*DropTarget {
        _ = location;
        // Platform-specific hit testing would go here
        // For now, return null (actual implementation uses platform hit testing)
        for (&self.targets) |*slot| {
            if (slot.*) |*target| {
                // Check if location is within target bounds
                // This is simplified - actual implementation needs bounds info
                _ = target;
            }
        }
        return null;
    }

    /// Set callback
    pub fn setCallback(self: *Self, callback: ?DragCallback) void {
        self.callback = callback;
    }

    fn notifyCallback(self: *Self, event: DragEvent) void {
        if (self.callback) |cb| cb(&self.session, event);
    }

    /// Handle touch event (unified interface)
    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (event.touch_count == 0) return;
        const touch = event.touches[0] orelse return;

        switch (touch.phase) {
            .began => {
                if (self.config.platform == .mobile) {
                    self.beginLongPress(touch.location, touch.timestamp);
                }
            },
            .moved => {
                if (self.session.state == .preparing) {
                    _ = self.updateLongPress(touch.timestamp, touch.location);
                } else if (self.session.state == .dragging or self.session.state == .over_target) {
                    self.updateDrag(touch.location);
                }
            },
            .ended => {
                if (self.session.state == .preparing) {
                    self.cancelLongPress();
                } else if (self.session.state == .dragging or self.session.state == .over_target) {
                    _ = self.endDrag();
                }
            },
            .cancelled => {
                self.cancelDrag();
            },
            else => {},
        }
    }
};

// === Global Instance ===

var global_manager: ?DragDropManager = null;

pub fn getManager() *DragDropManager {
    if (global_manager == null) {
        global_manager = DragDropManager.init(.{});
    }
    return &global_manager.?;
}

pub fn init() void {
    if (global_manager == null) {
        global_manager = DragDropManager.init(.{});
    }
}

pub fn deinit() void {
    if (global_manager) |*m| m.deinit();
    global_manager = null;
}

// === Tests ===

test "DragItem operations" {
    var item = DragItem{};
    item.setText("Hello, World!");
    try std.testing.expectEqualStrings("Hello, World!", item.getData());
    try std.testing.expectEqualStrings("text/plain", item.getMimeType());
}

test "DropTarget accepts" {
    var target = DropTarget{};
    target.accepts_types[0] = .text;
    target.accepts_types[1] = .url;
    target.accepts_count = 2;

    try std.testing.expect(target.accepts(.text));
    try std.testing.expect(target.accepts(.url));
    try std.testing.expect(!target.accepts(.file));
}

test "DragDropManager initialization" {
    var manager = DragDropManager.init(.{});
    defer manager.deinit();

    try std.testing.expectEqual(DragState.idle, manager.session.state);
    try std.testing.expectEqual(@as(usize, 0), manager.target_count);
}

test "DragSession management" {
    var session = DragSession{};

    var item = DragItem{};
    item.setText("Test");

    try std.testing.expect(session.addItem(item));
    try std.testing.expectEqual(@as(usize, 1), session.item_count);

    session.clear();
    try std.testing.expectEqual(@as(usize, 0), session.item_count);
    try std.testing.expectEqual(DragState.idle, session.state);
}
