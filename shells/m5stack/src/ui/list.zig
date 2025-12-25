//! List View Component for M5Stack UI
//!
//! Scrollable list with selectable items.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const touch_input = @import("../touch/input.zig");
const mod = @import("mod.zig");

const Theme = mod.Theme;
const Dimensions = mod.Dimensions;
const Rect = mod.Rect;
const Component = mod.Component;
const ComponentState = mod.ComponentState;

/// List item
pub const ListItem = struct {
    text: []const u8,
    subtext: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    tag: u32 = 0,
    enabled: bool = true,
    selected: bool = false,
    user_data: ?*anyopaque = null,
};

/// List configuration
pub const ListConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 200,
    height: u16 = 200,
    item_height: u16 = Dimensions.list_item_height,
    show_dividers: bool = true,
    show_scrollbar: bool = true,
    background: u16 = Theme.background,
    item_background: u16 = Theme.background,
    selected_background: u16 = Theme.primary_light,
    divider_color: u16 = Theme.border,
    text_color: u16 = Theme.text_primary,
    subtext_color: u16 = Theme.text_secondary,
    on_select: ?*const fn (*ListView, usize) void = null,
};

/// List view component
pub const ListView = struct {
    // Base component
    component: Component,

    // List-specific properties
    item_height: u16,
    show_dividers: bool,
    show_scrollbar: bool,
    background: u16,
    item_background: u16,
    selected_background: u16,
    divider_color: u16,
    text_color: u16,
    subtext_color: u16,

    // Items
    const MAX_ITEMS = 64;
    items: [MAX_ITEMS]?ListItem = [_]?ListItem{null} ** MAX_ITEMS,
    item_count: usize = 0,

    // Selection
    selected_index: ?usize = null,

    // Scrolling
    scroll_offset: i32 = 0,
    max_scroll: i32 = 0,
    scroll_velocity: f32 = 0,

    // Touch tracking
    touch_start_y: i32 = 0,
    touch_start_scroll: i32 = 0,
    is_scrolling: bool = false,

    // Callbacks
    on_select: ?*const fn (*ListView, usize) void,

    /// Create a new list view
    pub fn init(config: ListConfig) ListView {
        return ListView{
            .component = .{
                .bounds = .{
                    .x = config.x,
                    .y = config.y,
                    .width = config.width,
                    .height = config.height,
                },
                .draw_fn = drawList,
                .on_touch_fn = handleListTouch,
            },
            .item_height = config.item_height,
            .show_dividers = config.show_dividers,
            .show_scrollbar = config.show_scrollbar,
            .background = config.background,
            .item_background = config.item_background,
            .selected_background = config.selected_background,
            .divider_color = config.divider_color,
            .text_color = config.text_color,
            .subtext_color = config.subtext_color,
            .on_select = config.on_select,
        };
    }

    /// Get component pointer
    pub fn asComponent(self: *ListView) *Component {
        return &self.component;
    }

    /// Add item to list
    pub fn addItem(self: *ListView, item: ListItem) bool {
        if (self.item_count >= MAX_ITEMS) return false;

        self.items[self.item_count] = item;
        self.item_count += 1;
        self.updateMaxScroll();
        return true;
    }

    /// Add item with text
    pub fn addTextItem(self: *ListView, text: []const u8) bool {
        return self.addItem(.{ .text = text });
    }

    /// Remove item at index
    pub fn removeItem(self: *ListView, index: usize) bool {
        if (index >= self.item_count) return false;

        // Shift items
        var i = index;
        while (i < self.item_count - 1) : (i += 1) {
            self.items[i] = self.items[i + 1];
        }
        self.items[self.item_count - 1] = null;
        self.item_count -= 1;

        // Update selection
        if (self.selected_index) |sel| {
            if (sel == index) {
                self.selected_index = null;
            } else if (sel > index) {
                self.selected_index = sel - 1;
            }
        }

        self.updateMaxScroll();
        return true;
    }

    /// Clear all items
    pub fn clear(self: *ListView) void {
        for (&self.items) |*item| {
            item.* = null;
        }
        self.item_count = 0;
        self.selected_index = null;
        self.scroll_offset = 0;
        self.updateMaxScroll();
    }

    /// Get item at index
    pub fn getItem(self: *ListView, index: usize) ?*ListItem {
        if (index >= self.item_count) return null;
        return if (self.items[index]) |*item| item else null;
    }

    /// Set selected index
    pub fn setSelectedIndex(self: *ListView, index: ?usize) void {
        if (index) |i| {
            if (i < self.item_count) {
                // Deselect previous
                if (self.selected_index) |prev| {
                    if (self.items[prev]) |*item| {
                        item.selected = false;
                    }
                }
                // Select new
                if (self.items[i]) |*item| {
                    item.selected = true;
                }
                self.selected_index = index;
            }
        } else {
            // Deselect all
            if (self.selected_index) |prev| {
                if (self.items[prev]) |*item| {
                    item.selected = false;
                }
            }
            self.selected_index = null;
        }
    }

    /// Scroll to item
    pub fn scrollToItem(self: *ListView, index: usize) void {
        if (index >= self.item_count) return;

        const item_y = @as(i32, @intCast(index)) * @as(i32, self.item_height);
        const visible_height = @as(i32, self.component.bounds.height);

        // Scroll so item is visible
        if (item_y < self.scroll_offset) {
            self.scroll_offset = item_y;
        } else if (item_y + @as(i32, self.item_height) > self.scroll_offset + visible_height) {
            self.scroll_offset = item_y + @as(i32, self.item_height) - visible_height;
        }

        self.scroll_offset = std.math.clamp(self.scroll_offset, 0, self.max_scroll);
    }

    /// Update max scroll value
    fn updateMaxScroll(self: *ListView) void {
        const total_height = @as(i32, @intCast(self.item_count)) * @as(i32, self.item_height);
        const visible_height = @as(i32, self.component.bounds.height);
        self.max_scroll = @max(0, total_height - visible_height);
    }

    /// Get item at point
    fn getItemAtPoint(self: *ListView, y: i32) ?usize {
        const relative_y = y - self.component.bounds.y + self.scroll_offset;
        if (relative_y < 0) return null;

        const index = @as(usize, @intCast(@divTrunc(relative_y, @as(i32, self.item_height))));
        if (index < self.item_count) {
            return index;
        }
        return null;
    }

    /// Draw list (static wrapper)
    fn drawList(comp: *Component, graphics: *graphics_mod.Graphics) void {
        const self: *ListView = @fieldParentPtr("component", comp);
        self.draw(graphics);
    }

    /// Draw the list
    pub fn draw(self: *ListView, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;

        // Draw background
        graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, self.background);

        // Set clipping (conceptual - would be implemented with actual clipping)
        const visible_start = @divTrunc(self.scroll_offset, @as(i32, self.item_height));
        const visible_count = @divTrunc(@as(i32, bounds.height), @as(i32, self.item_height)) + 2;

        // Draw visible items
        var i: usize = @max(0, @as(usize, @intCast(visible_start)));
        const end = @min(self.item_count, i + @as(usize, @intCast(visible_count)));

        while (i < end) : (i += 1) {
            if (self.items[i]) |item| {
                self.drawItem(graphics, item, i);
            }
        }

        // Draw scrollbar
        if (self.show_scrollbar and self.max_scroll > 0) {
            self.drawScrollbar(graphics);
        }
    }

    /// Draw a single item
    fn drawItem(self: *ListView, graphics: *graphics_mod.Graphics, item: ListItem, index: usize) void {
        const bounds = self.component.bounds;
        const item_y = bounds.y + @as(i32, @intCast(index)) * @as(i32, self.item_height) - self.scroll_offset;

        // Check if visible
        if (item_y + @as(i32, self.item_height) < bounds.y or item_y >= bounds.y + @as(i32, bounds.height)) {
            return;
        }

        // Determine background color
        const bg_color = if (item.selected) self.selected_background else self.item_background;
        graphics.fillRect(bounds.x, item_y, bounds.width, self.item_height, bg_color);

        // Draw text
        const text_x = bounds.x + 12;
        const text_color = if (item.enabled) self.text_color else Theme.text_disabled;

        if (item.subtext) |subtext| {
            // Two-line layout
            graphics.drawText(text_x, item_y + 8, item.text, text_color);
            graphics.drawText(text_x, item_y + 24, subtext, self.subtext_color);
        } else {
            // Single-line, vertically centered
            const text_y = item_y + @divTrunc(@as(i32, self.item_height) - 8, 2);
            graphics.drawText(text_x, text_y, item.text, text_color);
        }

        // Draw divider
        if (self.show_dividers and index < self.item_count - 1) {
            const divider_y = item_y + @as(i32, self.item_height) - 1;
            graphics.drawHLine(bounds.x, divider_y, bounds.width, self.divider_color);
        }
    }

    /// Draw scrollbar
    fn drawScrollbar(self: *ListView, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;
        const scrollbar_width: u16 = 4;
        const scrollbar_x = bounds.x + @as(i32, bounds.width) - @as(i32, scrollbar_width) - 2;

        // Calculate scrollbar thumb size and position
        const total_height = @as(i32, @intCast(self.item_count)) * @as(i32, self.item_height);
        const visible_height = @as(i32, bounds.height);

        const thumb_height_ratio = @as(f32, @floatFromInt(visible_height)) / @as(f32, @floatFromInt(total_height));
        const thumb_height: u16 = @intFromFloat(@max(20, thumb_height_ratio * @as(f32, @floatFromInt(visible_height))));

        const scroll_ratio = @as(f32, @floatFromInt(self.scroll_offset)) / @as(f32, @floatFromInt(self.max_scroll));
        const thumb_y_offset: i32 = @intFromFloat(scroll_ratio * @as(f32, @floatFromInt(visible_height - @as(i32, thumb_height))));
        const thumb_y = bounds.y + thumb_y_offset;

        // Draw scrollbar track
        graphics.fillRect(scrollbar_x, bounds.y, scrollbar_width, bounds.height, Theme.secondary_light);

        // Draw scrollbar thumb
        graphics.fillRoundedRect(scrollbar_x, thumb_y, scrollbar_width, thumb_height, 2, Theme.secondary);
    }

    /// Handle touch (static wrapper)
    fn handleListTouch(comp: *Component, touch: touch_input.Touch) void {
        const self: *ListView = @fieldParentPtr("component", comp);
        self.handleTouch(touch);
    }

    /// Handle touch event
    pub fn handleTouch(self: *ListView, touch: touch_input.Touch) void {
        switch (touch.phase) {
            .began => {
                self.touch_start_y = touch.y;
                self.touch_start_scroll = self.scroll_offset;
                self.is_scrolling = false;
                self.scroll_velocity = 0;
            },
            .moved => {
                const delta_y = touch.y - self.touch_start_y;

                // Check if scrolling
                if (@abs(delta_y) > 10) {
                    self.is_scrolling = true;
                    self.scroll_offset = std.math.clamp(
                        self.touch_start_scroll - delta_y,
                        0,
                        self.max_scroll,
                    );
                }
            },
            .ended => {
                if (!self.is_scrolling) {
                    // Handle tap to select
                    if (self.getItemAtPoint(touch.y)) |index| {
                        if (self.items[index]) |item| {
                            if (item.enabled) {
                                self.setSelectedIndex(index);
                                if (self.on_select) |callback| {
                                    callback(self, index);
                                }
                            }
                        }
                    }
                }
                self.is_scrolling = false;
            },
            else => {},
        }
    }

    /// Update scroll inertia
    pub fn update(self: *ListView, delta_time: f32) void {
        if (@abs(self.scroll_velocity) > 0.1) {
            self.scroll_offset += @as(i32, @intFromFloat(self.scroll_velocity * delta_time));
            self.scroll_offset = std.math.clamp(self.scroll_offset, 0, self.max_scroll);

            // Decay velocity
            self.scroll_velocity *= 0.95;
        }
    }
};

// Tests
test "ListView initialization" {
    const list = ListView.init(.{
        .x = 10,
        .y = 20,
        .width = 200,
        .height = 300,
    });

    try std.testing.expectEqual(@as(i32, 10), list.component.bounds.x);
    try std.testing.expectEqual(@as(usize, 0), list.item_count);
}

test "ListView addItem" {
    var list = ListView.init(.{});

    try std.testing.expect(list.addTextItem("Item 1"));
    try std.testing.expect(list.addTextItem("Item 2"));
    try std.testing.expectEqual(@as(usize, 2), list.item_count);
}

test "ListView selection" {
    var list = ListView.init(.{});
    _ = list.addTextItem("Item 1");
    _ = list.addTextItem("Item 2");

    list.setSelectedIndex(0);
    try std.testing.expectEqual(@as(?usize, 0), list.selected_index);

    list.setSelectedIndex(1);
    try std.testing.expectEqual(@as(?usize, 1), list.selected_index);

    list.setSelectedIndex(null);
    try std.testing.expectEqual(@as(?usize, null), list.selected_index);
}
