const std = @import("std");
const vdom = @import("vdom.zig");

// =============================================================================
// Todo Application State Management
// =============================================================================
// Demonstrates integration of all ZigDom features:
// - VDOM for efficient UI updates
// - CSS utilities for styling
// - Layout for flexbox
// - Component patterns
// =============================================================================

pub const MAX_TODOS = 100;
pub const MAX_TODO_TEXT_LEN = 256;

/// Filter mode for displaying todos
pub const FilterMode = enum(u8) {
    all = 0,
    active = 1,
    completed = 2,
};

/// A single todo item
pub const TodoItem = struct {
    id: u32 = 0,
    text: [MAX_TODO_TEXT_LEN]u8 = undefined,
    text_len: u16 = 0,
    completed: bool = false,
    active: bool = false,

    pub fn init(id: u32, text: []const u8) TodoItem {
        var item = TodoItem{
            .id = id,
            .active = true,
        };
        const len = @min(text.len, MAX_TODO_TEXT_LEN);
        @memcpy(item.text[0..len], text[0..len]);
        item.text_len = @intCast(len);
        return item;
    }

    pub fn getText(self: *const TodoItem) []const u8 {
        return self.text[0..self.text_len];
    }
};

/// Todo application state
pub const TodoState = struct {
    items: [MAX_TODOS]TodoItem = undefined,
    item_count: u32 = 0,
    next_id: u32 = 1,
    filter: FilterMode = .all,
    editing_id: u32 = 0, // ID of item being edited, 0 = none

    pub fn init() TodoState {
        return TodoState{};
    }

    pub fn reset(self: *TodoState) void {
        self.item_count = 0;
        self.next_id = 1;
        self.filter = .all;
        self.editing_id = 0;
    }

    /// Add a new todo item
    pub fn add(self: *TodoState, text: []const u8) ?u32 {
        if (self.item_count >= MAX_TODOS) return null;
        if (text.len == 0) return null;

        const id = self.next_id;
        self.items[self.item_count] = TodoItem.init(id, text);
        self.item_count += 1;
        self.next_id += 1;
        return id;
    }

    /// Remove a todo by ID
    pub fn remove(self: *TodoState, id: u32) bool {
        for (0..self.item_count) |i| {
            if (self.items[i].id == id and self.items[i].active) {
                // Shift remaining items
                var j = i;
                while (j + 1 < self.item_count) : (j += 1) {
                    self.items[j] = self.items[j + 1];
                }
                self.item_count -= 1;
                return true;
            }
        }
        return false;
    }

    /// Toggle completion status
    pub fn toggle(self: *TodoState, id: u32) bool {
        for (0..self.item_count) |i| {
            if (self.items[i].id == id and self.items[i].active) {
                self.items[i].completed = !self.items[i].completed;
                return true;
            }
        }
        return false;
    }

    /// Toggle all items
    pub fn toggleAll(self: *TodoState) void {
        // If all are completed, uncomplete all. Otherwise, complete all.
        const all_completed = self.getCompletedCount() == self.item_count;
        for (0..self.item_count) |i| {
            if (self.items[i].active) {
                self.items[i].completed = !all_completed;
            }
        }
    }

    /// Clear all completed items
    pub fn clearCompleted(self: *TodoState) u32 {
        var removed: u32 = 0;
        var i: u32 = 0;
        while (i < self.item_count) {
            if (self.items[i].completed) {
                // Shift remaining items
                var j = i;
                while (j + 1 < self.item_count) : (j += 1) {
                    self.items[j] = self.items[j + 1];
                }
                self.item_count -= 1;
                removed += 1;
            } else {
                i += 1;
            }
        }
        return removed;
    }

    /// Set filter mode
    pub fn setFilter(self: *TodoState, filter: FilterMode) void {
        self.filter = filter;
    }

    /// Get active (not completed) count
    pub fn getActiveCount(self: *const TodoState) u32 {
        var count: u32 = 0;
        for (0..self.item_count) |i| {
            if (self.items[i].active and !self.items[i].completed) {
                count += 1;
            }
        }
        return count;
    }

    /// Get completed count
    pub fn getCompletedCount(self: *const TodoState) u32 {
        var count: u32 = 0;
        for (0..self.item_count) |i| {
            if (self.items[i].active and self.items[i].completed) {
                count += 1;
            }
        }
        return count;
    }

    /// Check if item should be visible with current filter
    pub fn isVisible(self: *const TodoState, item: *const TodoItem) bool {
        if (!item.active) return false;
        return switch (self.filter) {
            .all => true,
            .active => !item.completed,
            .completed => item.completed,
        };
    }

    /// Get visible items count
    pub fn getVisibleCount(self: *const TodoState) u32 {
        var count: u32 = 0;
        for (0..self.item_count) |i| {
            if (self.isVisible(&self.items[i])) {
                count += 1;
            }
        }
        return count;
    }

    /// Get item by ID
    pub fn getItem(self: *TodoState, id: u32) ?*TodoItem {
        for (0..self.item_count) |i| {
            if (self.items[i].id == id and self.items[i].active) {
                return &self.items[i];
            }
        }
        return null;
    }

    /// Update item text
    pub fn updateText(self: *TodoState, id: u32, text: []const u8) bool {
        if (self.getItem(id)) |item| {
            const len = @min(text.len, MAX_TODO_TEXT_LEN);
            @memcpy(item.text[0..len], text[0..len]);
            item.text_len = @intCast(len);
            return true;
        }
        return false;
    }
};

// =============================================================================
// VDOM Rendering
// =============================================================================

/// Event callback IDs
pub const EventId = struct {
    pub const ADD_TODO: u32 = 1;
    pub const TOGGLE_TODO: u32 = 2; // + item_id * 1000
    pub const REMOVE_TODO: u32 = 3; // + item_id * 1000
    pub const TOGGLE_ALL: u32 = 4;
    pub const CLEAR_COMPLETED: u32 = 5;
    pub const FILTER_ALL: u32 = 6;
    pub const FILTER_ACTIVE: u32 = 7;
    pub const FILTER_COMPLETED: u32 = 8;
};

/// Render the complete Todo app UI using VDOM
pub fn renderTodoApp(state: *const TodoState) void {
    vdom.resetGlobal();

    // Main container
    const app = vdom.createElement(.div);
    vdom.setClass(app, "todo-app");

    // Header with title and input
    const header = renderHeader();
    _ = vdom.addChild(app, header);

    // Todo list (only if items exist)
    if (state.item_count > 0) {
        const main_section = renderMain(state);
        _ = vdom.addChild(app, main_section);

        // Footer with counts and filters
        const footer = renderFooter(state);
        _ = vdom.addChild(app, footer);
    }

    vdom.setRoot(app);
}

fn renderHeader() u32 {
    const header = vdom.createElement(.header);
    vdom.setClass(header, "header");

    // Title
    const title = vdom.createElement(.h1);
    const title_text = vdom.createText("todos");
    _ = vdom.addChild(title, title_text);
    _ = vdom.addChild(header, title);

    // Input (placeholder - actual input handled by JS)
    const input = vdom.createElement(.input);
    vdom.setClass(input, "new-todo");
    vdom.setOnClick(input, EventId.ADD_TODO);
    _ = vdom.addChild(header, input);

    return header;
}

fn renderMain(state: *const TodoState) u32 {
    const main_section = vdom.createElement(.section);
    vdom.setClass(main_section, "main");

    // Toggle all checkbox
    const toggle_all = vdom.createElement(.input);
    vdom.setClass(toggle_all, "toggle-all");
    vdom.setOnClick(toggle_all, EventId.TOGGLE_ALL);
    _ = vdom.addChild(main_section, toggle_all);

    // Todo list
    const list = vdom.createElement(.ul);
    vdom.setClass(list, "todo-list");

    for (0..state.item_count) |i| {
        const item = &state.items[i];
        if (state.isVisible(item)) {
            const li = renderTodoItem(item);
            _ = vdom.addChild(list, li);
        }
    }

    _ = vdom.addChild(main_section, list);
    return main_section;
}

fn renderTodoItem(item: *const TodoItem) u32 {
    const li = vdom.createElement(.li);

    // Set key for efficient reconciliation
    var key_buf: [16]u8 = undefined;
    const key_len = formatU32(item.id, &key_buf);
    vdom.setKey(li, key_buf[0..key_len]);

    // Set class based on completed state
    if (item.completed) {
        vdom.setClass(li, "completed");
    }

    // Checkbox
    const checkbox = vdom.createElement(.input);
    vdom.setClass(checkbox, "toggle");
    vdom.setOnClick(checkbox, EventId.TOGGLE_TODO + item.id * 1000);
    _ = vdom.addChild(li, checkbox);

    // Label with text
    const label = vdom.createElement(.label);
    const text = vdom.createText(item.getText());
    _ = vdom.addChild(label, text);
    _ = vdom.addChild(li, label);

    // Delete button
    const delete_btn = vdom.createElement(.button);
    vdom.setClass(delete_btn, "destroy");
    vdom.setOnClick(delete_btn, EventId.REMOVE_TODO + item.id * 1000);
    _ = vdom.addChild(li, delete_btn);

    return li;
}

fn renderFooter(state: *const TodoState) u32 {
    const footer = vdom.createElement(.footer);
    vdom.setClass(footer, "footer");

    // Item count
    const count_span = vdom.createElement(.span);
    vdom.setClass(count_span, "todo-count");

    var count_buf: [32]u8 = undefined;
    const active_count = state.getActiveCount();
    const count_text = formatCount(active_count, &count_buf);
    const count_text_node = vdom.createText(count_text);
    _ = vdom.addChild(count_span, count_text_node);
    _ = vdom.addChild(footer, count_span);

    // Filters
    const filters = vdom.createElement(.ul);
    vdom.setClass(filters, "filters");

    // All filter
    const all_li = createFilterButton("All", EventId.FILTER_ALL, state.filter == .all);
    _ = vdom.addChild(filters, all_li);

    // Active filter
    const active_li = createFilterButton("Active", EventId.FILTER_ACTIVE, state.filter == .active);
    _ = vdom.addChild(filters, active_li);

    // Completed filter
    const completed_li = createFilterButton("Completed", EventId.FILTER_COMPLETED, state.filter == .completed);
    _ = vdom.addChild(filters, completed_li);

    _ = vdom.addChild(footer, filters);

    // Clear completed button (only if there are completed items)
    if (state.getCompletedCount() > 0) {
        const clear_btn = vdom.createElement(.button);
        vdom.setClass(clear_btn, "clear-completed");
        vdom.setOnClick(clear_btn, EventId.CLEAR_COMPLETED);
        const clear_text = vdom.createText("Clear completed");
        _ = vdom.addChild(clear_btn, clear_text);
        _ = vdom.addChild(footer, clear_btn);
    }

    return footer;
}

fn createFilterButton(text: []const u8, event_id: u32, selected: bool) u32 {
    const li = vdom.createElement(.li);
    const a = vdom.createElement(.a);
    if (selected) {
        vdom.setClass(a, "selected");
    }
    vdom.setOnClick(a, event_id);
    const text_node = vdom.createText(text);
    _ = vdom.addChild(a, text_node);
    _ = vdom.addChild(li, a);
    return li;
}

// =============================================================================
// Helper Functions
// =============================================================================

fn formatU32(value: u32, buf: []u8) usize {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    var v = value;
    var len: usize = 0;

    // Count digits
    var temp = v;
    while (temp > 0) : (temp /= 10) {
        len += 1;
    }

    // Write digits in reverse
    var i = len;
    while (v > 0) : (v /= 10) {
        i -= 1;
        buf[i] = @intCast((v % 10) + '0');
    }

    return len;
}

fn formatCount(count: u32, buf: []u8) []const u8 {
    var pos: usize = 0;

    // Write count
    const count_len = formatU32(count, buf[pos..]);
    pos += count_len;

    // Write " item" or " items"
    const suffix = if (count == 1) " item left" else " items left";
    for (suffix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    return buf[0..pos];
}

// =============================================================================
// Global State
// =============================================================================

var global_state: TodoState = TodoState.init();

pub fn getState() *TodoState {
    return &global_state;
}

// =============================================================================
// Tests
// =============================================================================

test "TodoItem basic operations" {
    var item = TodoItem.init(1, "Test todo");
    try std.testing.expectEqual(@as(u32, 1), item.id);
    try std.testing.expectEqualStrings("Test todo", item.getText());
    try std.testing.expect(!item.completed);
}

test "TodoState add and remove" {
    var state = TodoState.init();

    const id1 = state.add("First todo").?;
    const id2 = state.add("Second todo").?;

    try std.testing.expectEqual(@as(u32, 2), state.item_count);
    try std.testing.expectEqual(@as(u32, 2), state.getActiveCount());

    try std.testing.expect(state.remove(id1));
    try std.testing.expectEqual(@as(u32, 1), state.item_count);

    try std.testing.expect(!state.remove(999)); // Non-existent
    try std.testing.expect(state.remove(id2));
    try std.testing.expectEqual(@as(u32, 0), state.item_count);
}

test "TodoState toggle" {
    var state = TodoState.init();

    const id = state.add("Toggle test").?;
    try std.testing.expect(!state.items[0].completed);

    try std.testing.expect(state.toggle(id));
    try std.testing.expect(state.items[0].completed);

    try std.testing.expect(state.toggle(id));
    try std.testing.expect(!state.items[0].completed);
}

test "TodoState filter" {
    var state = TodoState.init();

    _ = state.add("Active todo");
    const id2 = state.add("Completed todo").?;
    _ = state.toggle(id2);

    state.setFilter(.all);
    try std.testing.expectEqual(@as(u32, 2), state.getVisibleCount());

    state.setFilter(.active);
    try std.testing.expectEqual(@as(u32, 1), state.getVisibleCount());

    state.setFilter(.completed);
    try std.testing.expectEqual(@as(u32, 1), state.getVisibleCount());
}

test "TodoState clearCompleted" {
    var state = TodoState.init();

    _ = state.add("Keep this");
    const id2 = state.add("Remove this").?;
    const id3 = state.add("Remove this too").?;

    _ = state.toggle(id2);
    _ = state.toggle(id3);

    const removed = state.clearCompleted();
    try std.testing.expectEqual(@as(u32, 2), removed);
    try std.testing.expectEqual(@as(u32, 1), state.item_count);
}

test "TodoItem text truncation" {
    // Create text longer than MAX_TODO_TEXT_LEN
    var long_text: [MAX_TODO_TEXT_LEN + 100]u8 = undefined;
    @memset(&long_text, 'A');

    var item = TodoItem.init(1, &long_text);

    // Text should be truncated to MAX_TODO_TEXT_LEN
    try std.testing.expectEqual(@as(u16, MAX_TODO_TEXT_LEN), item.text_len);
    try std.testing.expectEqual(MAX_TODO_TEXT_LEN, item.getText().len);
}

test "TodoState add empty text returns null" {
    var state = TodoState.init();

    const result = state.add("");
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), state.item_count);
}

test "TodoState add when full returns null" {
    var state = TodoState.init();

    // Fill the state
    var i: u32 = 0;
    while (i < MAX_TODOS) : (i += 1) {
        _ = state.add("Item");
    }

    // Should be full now
    try std.testing.expectEqual(@as(u32, MAX_TODOS), state.item_count);

    // Next add should fail
    const result = state.add("One more");
    try std.testing.expect(result == null);
}

test "TodoState toggleAll with all active" {
    var state = TodoState.init();

    _ = state.add("Item 1");
    _ = state.add("Item 2");
    _ = state.add("Item 3");

    // All should be active
    try std.testing.expectEqual(@as(u32, 3), state.getActiveCount());
    try std.testing.expectEqual(@as(u32, 0), state.getCompletedCount());

    // Toggle all should complete all
    state.toggleAll();
    try std.testing.expectEqual(@as(u32, 0), state.getActiveCount());
    try std.testing.expectEqual(@as(u32, 3), state.getCompletedCount());
}

test "TodoState toggleAll with all completed" {
    var state = TodoState.init();

    const id1 = state.add("Item 1").?;
    const id2 = state.add("Item 2").?;

    _ = state.toggle(id1);
    _ = state.toggle(id2);

    // All should be completed
    try std.testing.expectEqual(@as(u32, 0), state.getActiveCount());
    try std.testing.expectEqual(@as(u32, 2), state.getCompletedCount());

    // Toggle all should uncomplete all
    state.toggleAll();
    try std.testing.expectEqual(@as(u32, 2), state.getActiveCount());
    try std.testing.expectEqual(@as(u32, 0), state.getCompletedCount());
}

test "TodoState toggleAll with empty state" {
    var state = TodoState.init();

    // Should not crash with empty state
    state.toggleAll();
    try std.testing.expectEqual(@as(u32, 0), state.item_count);
}

test "TodoState toggle non-existent item" {
    var state = TodoState.init();

    _ = state.add("Item");

    // Toggle non-existent ID
    const result = state.toggle(999);
    try std.testing.expect(!result);
}

test "TodoState updateText" {
    var state = TodoState.init();

    const id = state.add("Original text").?;

    const updated = state.updateText(id, "New text");
    try std.testing.expect(updated);

    const item = state.getItem(id).?;
    try std.testing.expectEqualStrings("New text", item.getText());
}

test "TodoState updateText non-existent item" {
    var state = TodoState.init();

    _ = state.add("Item");

    const updated = state.updateText(999, "New text");
    try std.testing.expect(!updated);
}

test "TodoState getItem" {
    var state = TodoState.init();

    const id = state.add("Test item").?;

    const item = state.getItem(id);
    try std.testing.expect(item != null);
    try std.testing.expectEqualStrings("Test item", item.?.getText());
}

test "TodoState getItem non-existent" {
    var state = TodoState.init();

    _ = state.add("Item");

    const item = state.getItem(999);
    try std.testing.expect(item == null);
}

test "TodoState reset" {
    var state = TodoState.init();

    _ = state.add("Item 1");
    _ = state.add("Item 2");
    state.setFilter(.completed);

    try std.testing.expectEqual(@as(u32, 2), state.item_count);
    try std.testing.expectEqual(FilterMode.completed, state.filter);

    state.reset();

    try std.testing.expectEqual(@as(u32, 0), state.item_count);
    try std.testing.expectEqual(@as(u32, 1), state.next_id);
    try std.testing.expectEqual(FilterMode.all, state.filter);
}

test "TodoState isVisible with inactive item" {
    var state = TodoState.init();

    var inactive_item = TodoItem.init(1, "Inactive");
    inactive_item.active = false;

    // Inactive items should not be visible regardless of filter
    state.setFilter(.all);
    try std.testing.expect(!state.isVisible(&inactive_item));

    state.setFilter(.active);
    try std.testing.expect(!state.isVisible(&inactive_item));

    state.setFilter(.completed);
    try std.testing.expect(!state.isVisible(&inactive_item));
}

test "TodoState clearCompleted with no completed items" {
    var state = TodoState.init();

    _ = state.add("Active 1");
    _ = state.add("Active 2");

    const removed = state.clearCompleted();
    try std.testing.expectEqual(@as(u32, 0), removed);
    try std.testing.expectEqual(@as(u32, 2), state.item_count);
}

test "TodoState clearCompleted with all completed" {
    var state = TodoState.init();

    const id1 = state.add("Completed 1").?;
    const id2 = state.add("Completed 2").?;

    _ = state.toggle(id1);
    _ = state.toggle(id2);

    const removed = state.clearCompleted();
    try std.testing.expectEqual(@as(u32, 2), removed);
    try std.testing.expectEqual(@as(u32, 0), state.item_count);
}
