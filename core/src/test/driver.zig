// Zylix Test Framework - Driver Interface
// Defines the interface for platform-specific test drivers

const std = @import("std");
const selector = @import("selector.zig");

pub const Selector = selector.Selector;

/// Opaque handle to a platform element
pub const ElementHandle = struct {
    id: u64,
    driver_data: ?*anyopaque = null,
};

/// Rectangle representing element bounds
pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn contains(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn center(self: Rect) struct { x: f32, y: f32 } {
        return .{
            .x = self.x + self.width / 2,
            .y = self.y + self.height / 2,
        };
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }
};

/// Swipe direction
pub const SwipeDirection = enum {
    up,
    down,
    left,
    right,
};

/// Scroll direction
pub const ScrollDirection = enum {
    up,
    down,
    left,
    right,
};

/// Key modifier flags
pub const KeyModifiers = packed struct {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    meta: bool = false,
    _padding: u4 = 0,
};

/// Application configuration for launching
pub const AppConfig = struct {
    /// Application identifier (bundle ID, package name, etc.)
    app_id: []const u8,
    /// Target platform (auto-detect if null)
    platform: ?Platform = null,
    /// Launch arguments
    arguments: ?[]const []const u8 = null,
    /// Environment variables
    environment: ?std.StringHashMap([]const u8) = null,
    /// Wait for app to be ready (ms)
    launch_timeout_ms: u32 = 30000,
    /// Reset app state before launch
    reset_state: bool = false,
    /// Device ID for mobile platforms
    device_id: ?[]const u8 = null,
    /// Base URL for web platform
    base_url: ?[]const u8 = null,
};

/// Supported platforms
pub const Platform = enum {
    ios,
    watchos,
    android,
    macos,
    windows,
    linux,
    web,
    auto,

    pub fn current() Platform {
        return switch (@import("builtin").os.tag) {
            .macos => .macos,
            .windows => .windows,
            .linux => .linux,
            .ios => .ios,
            else => .web,
        };
    }

    /// Check if this is an Apple mobile platform (iOS or watchOS)
    pub fn isAppleMobile(self: Platform) bool {
        return self == .ios or self == .watchos;
    }
};

/// Digital Crown rotation direction (watchOS-specific)
pub const CrownRotationDirection = enum {
    up,
    down,
};

/// Screenshot image data
pub const Screenshot = struct {
    width: u32,
    height: u32,
    pixels: []const u8,
    format: ImageFormat,

    pub const ImageFormat = enum {
        rgba,
        rgb,
        png,
        jpeg,
    };
};

/// Screenshot comparison result
pub const CompareResult = struct {
    matches: bool,
    diff_percentage: f32,
    diff_pixels: u32,
    diff_image: ?Screenshot = null,
};

/// Driver error types
pub const DriverError = error{
    ElementNotFound,
    ElementNotVisible,
    ElementNotEnabled,
    ElementNotInteractable,
    Timeout,
    AppNotRunning,
    AppLaunchFailed,
    ConnectionFailed,
    ScreenshotFailed,
    InvalidSelector,
    PlatformNotSupported,
    PermissionDenied,
    OutOfMemory,
    AssertionFailed,
};

/// Driver interface virtual table
pub const DriverVTable = struct {
    // Lifecycle
    launch: *const fn (*anyopaque, AppConfig) DriverError!void,
    terminate: *const fn (*anyopaque) DriverError!void,
    reset: *const fn (*anyopaque) DriverError!void,
    isRunning: *const fn (*anyopaque) bool,

    // Element finding
    findElement: *const fn (*anyopaque, Selector) DriverError!?ElementHandle,
    findElements: *const fn (*anyopaque, Selector, std.mem.Allocator) DriverError![]ElementHandle,
    waitForElement: *const fn (*anyopaque, Selector, u32) DriverError!ElementHandle,
    waitForElementGone: *const fn (*anyopaque, Selector, u32) DriverError!void,

    // Element interactions
    tap: *const fn (*anyopaque, ElementHandle) DriverError!void,
    doubleTap: *const fn (*anyopaque, ElementHandle) DriverError!void,
    longPress: *const fn (*anyopaque, ElementHandle, u32) DriverError!void,
    typeText: *const fn (*anyopaque, ElementHandle, []const u8) DriverError!void,
    clearText: *const fn (*anyopaque, ElementHandle) DriverError!void,
    swipe: *const fn (*anyopaque, ElementHandle, SwipeDirection) DriverError!void,
    scroll: *const fn (*anyopaque, ElementHandle, ScrollDirection, f32) DriverError!void,

    // Element queries
    exists: *const fn (*anyopaque, ElementHandle) bool,
    isVisible: *const fn (*anyopaque, ElementHandle) bool,
    isEnabled: *const fn (*anyopaque, ElementHandle) bool,
    getText: *const fn (*anyopaque, ElementHandle, std.mem.Allocator) DriverError![]const u8,
    getAttribute: *const fn (*anyopaque, ElementHandle, []const u8, std.mem.Allocator) DriverError!?[]const u8,
    getRect: *const fn (*anyopaque, ElementHandle) DriverError!Rect,

    // Screenshots
    takeScreenshot: *const fn (*anyopaque, std.mem.Allocator) DriverError!Screenshot,
    takeElementScreenshot: *const fn (*anyopaque, ElementHandle, std.mem.Allocator) DriverError!Screenshot,

    // Zylix-specific (optional)
    getState: ?*const fn (*anyopaque, std.mem.Allocator) DriverError![]const u8 = null,
    dispatch: ?*const fn (*anyopaque, []const u8) DriverError!void = null,

    // Cleanup
    deinit: *const fn (*anyopaque) void,
};

/// Driver wrapper that provides a unified interface
pub const Driver = struct {
    vtable: *const DriverVTable,
    context: *anyopaque,
    allocator: std.mem.Allocator,
    platform: Platform,

    const Self = @This();

    /// Initialize driver with platform-specific implementation
    pub fn init(
        vtable: *const DriverVTable,
        context: *anyopaque,
        allocator: std.mem.Allocator,
        platform: Platform,
    ) Self {
        return .{
            .vtable = vtable,
            .context = context,
            .allocator = allocator,
            .platform = platform,
        };
    }

    /// Deinitialize the driver
    pub fn deinit(self: *Self) void {
        self.vtable.deinit(self.context);
    }

    // Lifecycle methods

    pub fn launch(self: *Self, config: AppConfig) DriverError!void {
        return self.vtable.launch(self.context, config);
    }

    pub fn terminate(self: *Self) DriverError!void {
        return self.vtable.terminate(self.context);
    }

    pub fn reset(self: *Self) DriverError!void {
        return self.vtable.reset(self.context);
    }

    pub fn isRunning(self: *Self) bool {
        return self.vtable.isRunning(self.context);
    }

    // Element finding methods

    pub fn findElement(self: *Self, sel: Selector) DriverError!?ElementHandle {
        return self.vtable.findElement(self.context, sel);
    }

    pub fn findElements(self: *Self, sel: Selector) DriverError![]ElementHandle {
        return self.vtable.findElements(self.context, sel, self.allocator);
    }

    pub fn waitForElement(self: *Self, sel: Selector, timeout_ms: u32) DriverError!ElementHandle {
        return self.vtable.waitForElement(self.context, sel, timeout_ms);
    }

    pub fn waitForElementGone(self: *Self, sel: Selector, timeout_ms: u32) DriverError!void {
        return self.vtable.waitForElementGone(self.context, sel, timeout_ms);
    }

    // Interaction methods

    pub fn tap(self: *Self, handle: ElementHandle) DriverError!void {
        return self.vtable.tap(self.context, handle);
    }

    pub fn doubleTap(self: *Self, handle: ElementHandle) DriverError!void {
        return self.vtable.doubleTap(self.context, handle);
    }

    pub fn longPress(self: *Self, handle: ElementHandle, duration_ms: u32) DriverError!void {
        return self.vtable.longPress(self.context, handle, duration_ms);
    }

    pub fn typeText(self: *Self, handle: ElementHandle, text: []const u8) DriverError!void {
        return self.vtable.typeText(self.context, handle, text);
    }

    pub fn clearText(self: *Self, handle: ElementHandle) DriverError!void {
        return self.vtable.clearText(self.context, handle);
    }

    pub fn swipe(self: *Self, handle: ElementHandle, direction: SwipeDirection) DriverError!void {
        return self.vtable.swipe(self.context, handle, direction);
    }

    pub fn scroll(self: *Self, handle: ElementHandle, direction: ScrollDirection, amount: f32) DriverError!void {
        return self.vtable.scroll(self.context, handle, direction, amount);
    }

    // Query methods

    pub fn exists(self: *Self, handle: ElementHandle) bool {
        return self.vtable.exists(self.context, handle);
    }

    pub fn isVisible(self: *Self, handle: ElementHandle) bool {
        return self.vtable.isVisible(self.context, handle);
    }

    pub fn isEnabled(self: *Self, handle: ElementHandle) bool {
        return self.vtable.isEnabled(self.context, handle);
    }

    pub fn getText(self: *Self, handle: ElementHandle) DriverError![]const u8 {
        return self.vtable.getText(self.context, handle, self.allocator);
    }

    pub fn getAttribute(self: *Self, handle: ElementHandle, name: []const u8) DriverError!?[]const u8 {
        return self.vtable.getAttribute(self.context, handle, name, self.allocator);
    }

    pub fn getRect(self: *Self, handle: ElementHandle) DriverError!Rect {
        return self.vtable.getRect(self.context, handle);
    }

    // Screenshot methods

    pub fn takeScreenshot(self: *Self) DriverError!Screenshot {
        return self.vtable.takeScreenshot(self.context, self.allocator);
    }

    pub fn takeElementScreenshot(self: *Self, handle: ElementHandle) DriverError!Screenshot {
        return self.vtable.takeElementScreenshot(self.context, handle, self.allocator);
    }

    // Zylix-specific methods

    pub fn getState(self: *Self) DriverError!?[]const u8 {
        if (self.vtable.getState) |getStateFn| {
            return getStateFn(self.context, self.allocator);
        }
        return null;
    }

    pub fn dispatch(self: *Self, event_json: []const u8) DriverError!void {
        if (self.vtable.dispatch) |dispatchFn| {
            return dispatchFn(self.context, event_json);
        }
    }
};

/// Driver registry for managing platform drivers
pub const DriverRegistry = struct {
    drivers: std.StringHashMap(*Driver),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .drivers = std.StringHashMap(*Driver).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.drivers.valueIterator();
        while (iter.next()) |driver| {
            driver.*.deinit();
        }
        self.drivers.deinit();
    }

    pub fn register(self: *Self, name: []const u8, driver: *Driver) !void {
        try self.drivers.put(name, driver);
    }

    pub fn get(self: *Self, name: []const u8) ?*Driver {
        return self.drivers.get(name);
    }

    pub fn getForPlatform(self: *Self, platform: Platform) ?*Driver {
        return self.get(@tagName(platform));
    }
};

// Tests
test "rect operations" {
    const rect = Rect{ .x = 10, .y = 20, .width = 100, .height = 50 };

    try std.testing.expect(rect.contains(50, 40));
    try std.testing.expect(!rect.contains(5, 5));

    const c = rect.center();
    try std.testing.expectApproxEqAbs(@as(f32, 60), c.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 45), c.y, 0.001);
}

test "platform detection" {
    const current = Platform.current();
    try std.testing.expect(current != .auto);
}
