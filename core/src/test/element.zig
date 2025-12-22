// Zylix Test Framework - Element API
// Provides high-level element interaction and querying

const std = @import("std");
const selector_mod = @import("selector.zig");
const driver_mod = @import("driver.zig");

pub const Selector = selector_mod.Selector;
pub const Driver = driver_mod.Driver;
pub const ElementHandle = driver_mod.ElementHandle;
pub const Rect = driver_mod.Rect;
pub const SwipeDirection = driver_mod.SwipeDirection;
pub const ScrollDirection = driver_mod.ScrollDirection;
pub const DriverError = driver_mod.DriverError;
pub const Screenshot = driver_mod.Screenshot;

/// UI Element wrapper that provides fluent API for interactions
pub const Element = struct {
    driver: *Driver,
    handle: ElementHandle,
    selector: Selector,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create element from driver and handle
    pub fn init(driver: *Driver, handle: ElementHandle, sel: Selector, allocator: std.mem.Allocator) Self {
        return .{
            .driver = driver,
            .handle = handle,
            .selector = sel,
            .allocator = allocator,
        };
    }

    // ============ Actions ============

    /// Tap on the element
    pub fn tap(self: *Self) DriverError!void {
        return self.driver.tap(self.handle);
    }

    /// Double tap on the element
    pub fn doubleTap(self: *Self) DriverError!void {
        return self.driver.doubleTap(self.handle);
    }

    /// Long press on the element
    pub fn longPress(self: *Self, duration_ms: u32) DriverError!void {
        return self.driver.longPress(self.handle, duration_ms);
    }

    /// Type text into the element (for input fields)
    pub fn typeText(self: *Self, text: []const u8) DriverError!void {
        return self.driver.typeText(self.handle, text);
    }

    /// Clear text from the element
    pub fn clear(self: *Self) DriverError!void {
        return self.driver.clearText(self.handle);
    }

    /// Clear and type new text
    pub fn replaceText(self: *Self, text: []const u8) DriverError!void {
        try self.clear();
        return self.typeText(text);
    }

    /// Swipe on the element
    pub fn swipe(self: *Self, direction: SwipeDirection) DriverError!void {
        return self.driver.swipe(self.handle, direction);
    }

    /// Scroll the element
    pub fn scroll(self: *Self, direction: ScrollDirection, amount: f32) DriverError!void {
        return self.driver.scroll(self.handle, direction, amount);
    }

    /// Scroll until another element becomes visible
    pub fn scrollUntilVisible(self: *Self, target: Selector, direction: ScrollDirection, max_scrolls: u32) DriverError!Element {
        var scrolls: u32 = 0;
        while (scrolls < max_scrolls) : (scrolls += 1) {
            if (self.driver.findElement(target)) |maybe_handle| {
                if (maybe_handle) |h| {
                    if (self.driver.isVisible(h)) {
                        return Element.init(self.driver, h, target, self.allocator);
                    }
                }
            } else |_| {}

            try self.scroll(direction, 0.5);
            std.time.sleep(200 * std.time.ns_per_ms);
        }
        return DriverError.ElementNotFound;
    }

    // ============ Queries ============

    /// Check if element exists
    pub fn exists(self: *Self) bool {
        return self.driver.exists(self.handle);
    }

    /// Check if element is visible
    pub fn isVisible(self: *Self) bool {
        return self.driver.isVisible(self.handle);
    }

    /// Check if element is enabled
    pub fn isEnabled(self: *Self) bool {
        return self.driver.isEnabled(self.handle);
    }

    /// Get element text content
    pub fn getText(self: *Self) DriverError![]const u8 {
        return self.driver.getText(self.handle);
    }

    /// Get element attribute value
    pub fn getAttribute(self: *Self, name: []const u8) DriverError!?[]const u8 {
        return self.driver.getAttribute(self.handle, name);
    }

    /// Get element bounds rectangle
    pub fn getRect(self: *Self) DriverError!Rect {
        return self.driver.getRect(self.handle);
    }

    /// Get element center point
    pub fn getCenter(self: *Self) DriverError!struct { x: f32, y: f32 } {
        const rect = try self.getRect();
        return rect.center();
    }

    /// Check if element contains text
    pub fn containsText(self: *Self, text: []const u8) DriverError!bool {
        const element_text = try self.getText();
        return std.mem.indexOf(u8, element_text, text) != null;
    }

    /// Take screenshot of this element
    pub fn screenshot(self: *Self) DriverError!Screenshot {
        return self.driver.takeElementScreenshot(self.handle);
    }

    // ============ Chaining ============

    /// Find child element matching selector
    pub fn find(self: *Self, sel: Selector) DriverError!Element {
        // Create nested selector
        var nested = sel;
        nested.parent = &self.selector;

        const handle = try self.driver.findElement(nested) orelse return DriverError.ElementNotFound;
        return Element.init(self.driver, handle, nested, self.allocator);
    }

    /// Find all child elements matching selector
    pub fn findAll(self: *Self, sel: Selector) DriverError!ElementList {
        var nested = sel;
        nested.parent = &self.selector;

        const handles = try self.driver.findElements(nested);
        return ElementList.init(self.driver, handles, nested, self.allocator);
    }

    /// Wait for child element to appear
    pub fn waitFor(self: *Self, sel: Selector, timeout_ms: u32) DriverError!Element {
        var nested = sel;
        nested.parent = &self.selector;

        const handle = try self.driver.waitForElement(nested, timeout_ms);
        return Element.init(self.driver, handle, nested, self.allocator);
    }

    /// Wait for child element to disappear
    pub fn waitForNot(self: *Self, sel: Selector, timeout_ms: u32) DriverError!void {
        var nested = sel;
        nested.parent = &self.selector;
        return self.driver.waitForElementGone(nested, timeout_ms);
    }

    // ============ Assertions ============

    /// Assert element is visible
    pub fn assertVisible(self: *Self) DriverError!void {
        if (!self.isVisible()) {
            return DriverError.ElementNotVisible;
        }
    }

    /// Assert element is enabled
    pub fn assertEnabled(self: *Self) DriverError!void {
        if (!self.isEnabled()) {
            return DriverError.ElementNotEnabled;
        }
    }

    /// Assert element has specific text
    pub fn assertText(self: *Self, expected: []const u8) DriverError!void {
        const actual = try self.getText();
        if (!std.mem.eql(u8, actual, expected)) {
            return DriverError.ElementNotFound; // TODO: Add assertion error
        }
    }

    /// Assert element contains text
    pub fn assertContainsText(self: *Self, text: []const u8) DriverError!void {
        if (!try self.containsText(text)) {
            return DriverError.ElementNotFound; // TODO: Add assertion error
        }
    }
};

/// List of elements for batch operations
pub const ElementList = struct {
    driver: *Driver,
    handles: []ElementHandle,
    selector: Selector,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(driver: *Driver, handles: []ElementHandle, sel: Selector, allocator: std.mem.Allocator) Self {
        return .{
            .driver = driver,
            .handles = handles,
            .selector = sel,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.handles);
    }

    /// Get number of elements
    pub fn count(self: *Self) usize {
        return self.handles.len;
    }

    /// Check if list is empty
    pub fn isEmpty(self: *Self) bool {
        return self.handles.len == 0;
    }

    /// Get element at index
    pub fn at(self: *Self, index: usize) ?Element {
        if (index >= self.handles.len) return null;
        return Element.init(self.driver, self.handles[index], self.selector, self.allocator);
    }

    /// Get first element
    pub fn first(self: *Self) ?Element {
        return self.at(0);
    }

    /// Get last element
    pub fn last(self: *Self) ?Element {
        if (self.handles.len == 0) return null;
        return self.at(self.handles.len - 1);
    }

    /// Filter elements by predicate
    pub fn filter(self: *Self, predicate: *const fn (*Element) bool) DriverError!ElementList {
        var filtered = std.ArrayList(ElementHandle).init(self.allocator);

        for (self.handles) |handle| {
            var element = Element.init(self.driver, handle, self.selector, self.allocator);
            if (predicate(&element)) {
                try filtered.append(handle);
            }
        }

        return ElementList.init(self.driver, try filtered.toOwnedSlice(), self.selector, self.allocator);
    }

    /// Map function over all elements
    pub fn forEach(self: *Self, func: *const fn (*Element) void) void {
        for (self.handles) |handle| {
            var element = Element.init(self.driver, handle, self.selector, self.allocator);
            func(&element);
        }
    }

    /// Tap on all elements
    pub fn tapAll(self: *Self) DriverError!void {
        for (self.handles) |handle| {
            try self.driver.tap(handle);
        }
    }

    /// Get text from all elements
    pub fn getAllText(self: *Self) DriverError![][]const u8 {
        var texts = try self.allocator.alloc([]const u8, self.handles.len);
        for (self.handles, 0..) |handle, i| {
            texts[i] = try self.driver.getText(handle);
        }
        return texts;
    }

    /// Iterator for elements
    pub fn iterator(self: *Self) Iterator {
        return Iterator{
            .list = self,
            .index = 0,
        };
    }

    pub const Iterator = struct {
        list: *ElementList,
        index: usize,

        pub fn next(self: *Iterator) ?Element {
            if (self.index >= self.list.handles.len) return null;
            const element = self.list.at(self.index);
            self.index += 1;
            return element;
        }
    };
};

/// Element query builder for complex finds
pub const ElementQuery = struct {
    driver: *Driver,
    selector: Selector,
    timeout_ms: ?u32 = null,
    poll_interval_ms: u32 = 100,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(driver: *Driver, allocator: std.mem.Allocator) Self {
        return .{
            .driver = driver,
            .selector = Selector{},
            .allocator = allocator,
        };
    }

    pub fn byTestId(self: *Self, id: []const u8) *Self {
        self.selector = Selector.byTestId(id);
        return self;
    }

    pub fn byText(self: *Self, text: []const u8) *Self {
        self.selector = Selector.byText(text);
        return self;
    }

    pub fn byAccessibilityId(self: *Self, id: []const u8) *Self {
        self.selector = Selector.byAccessibilityId(id);
        return self;
    }

    pub fn withTimeout(self: *Self, timeout_ms: u32) *Self {
        self.timeout_ms = timeout_ms;
        return self;
    }

    pub fn withPolling(self: *Self, poll_interval_ms: u32) *Self {
        self.poll_interval_ms = poll_interval_ms;
        return self;
    }

    /// Execute query and return single element
    pub fn one(self: *Self) DriverError!Element {
        if (self.timeout_ms) |timeout| {
            const handle = try self.driver.waitForElement(self.selector, timeout);
            return Element.init(self.driver, handle, self.selector, self.allocator);
        } else {
            const handle = try self.driver.findElement(self.selector) orelse return DriverError.ElementNotFound;
            return Element.init(self.driver, handle, self.selector, self.allocator);
        }
    }

    /// Execute query and return all matching elements
    pub fn all(self: *Self) DriverError!ElementList {
        const handles = try self.driver.findElements(self.selector);
        return ElementList.init(self.driver, handles, self.selector, self.allocator);
    }

    /// Check if any matching element exists
    pub fn anyExists(self: *Self) DriverError!bool {
        const maybe = try self.driver.findElement(self.selector);
        return maybe != null;
    }
};

// Tests
test "element creation" {
    // Note: These tests require a mock driver
    // Just testing compilation for now
}
