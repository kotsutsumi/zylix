// Zylix Test Framework - App API
// Provides application lifecycle management and high-level test operations

const std = @import("std");
const selector_mod = @import("selector.zig");
const driver_mod = @import("driver.zig");
const element_mod = @import("element.zig");
const screenshot_mod = @import("screenshot.zig");

pub const Selector = selector_mod.Selector;
pub const Driver = driver_mod.Driver;
pub const DriverError = driver_mod.DriverError;
pub const AppConfig = driver_mod.AppConfig;
pub const Platform = driver_mod.Platform;
pub const Screenshot = driver_mod.Screenshot;
pub const CompareResult = driver_mod.CompareResult;
pub const Element = element_mod.Element;
pub const ElementList = element_mod.ElementList;
pub const ElementQuery = element_mod.ElementQuery;

/// Application wrapper for test operations
pub const App = struct {
    driver: *Driver,
    config: AppConfig,
    allocator: std.mem.Allocator,
    launched: bool = false,

    const Self = @This();

    /// Launch application with configuration
    pub fn launch(driver: *Driver, config: AppConfig, allocator: std.mem.Allocator) DriverError!Self {
        try driver.launch(config);
        return Self{
            .driver = driver,
            .config = config,
            .allocator = allocator,
            .launched = true,
        };
    }

    /// Terminate the application
    pub fn terminate(self: *Self) DriverError!void {
        if (self.launched) {
            try self.driver.terminate();
            self.launched = false;
        }
    }

    /// Reset application state
    pub fn reset(self: *Self) DriverError!void {
        return self.driver.reset();
    }

    /// Check if application is running
    pub fn isRunning(self: *Self) bool {
        return self.launched and self.driver.isRunning();
    }

    /// Relaunch the application
    pub fn relaunch(self: *Self) DriverError!void {
        try self.terminate();
        try self.driver.launch(self.config);
        self.launched = true;
    }

    // ============ Element Finding ============

    /// Find single element by selector
    pub fn find(self: *Self, sel: Selector) DriverError!Element {
        const handle = try self.driver.findElement(sel) orelse return DriverError.ElementNotFound;
        return Element.init(self.driver, handle, sel, self.allocator);
    }

    /// Find all elements matching selector
    pub fn findAll(self: *Self, sel: Selector) DriverError!ElementList {
        const handles = try self.driver.findElements(sel);
        return ElementList.init(self.driver, handles, sel, self.allocator);
    }

    /// Wait for element to appear
    pub fn waitFor(self: *Self, sel: Selector, timeout_ms: u32) DriverError!Element {
        const handle = try self.driver.waitForElement(sel, timeout_ms);
        return Element.init(self.driver, handle, sel, self.allocator);
    }

    /// Wait for element to disappear
    pub fn waitForNot(self: *Self, sel: Selector, timeout_ms: u32) DriverError!void {
        return self.driver.waitForElementGone(sel, timeout_ms);
    }

    /// Create element query builder
    pub fn query(self: *Self) ElementQuery {
        return ElementQuery.init(self.driver, self.allocator);
    }

    // ============ Convenience Selectors ============

    /// Find by test ID
    pub fn findByTestId(self: *Self, id: []const u8) DriverError!Element {
        return self.find(Selector.byTestId(id));
    }

    /// Find by text content
    pub fn findByText(self: *Self, text: []const u8) DriverError!Element {
        return self.find(Selector.byText(text));
    }

    /// Find by accessibility ID
    pub fn findByAccessibilityId(self: *Self, id: []const u8) DriverError!Element {
        return self.find(Selector.byAccessibilityId(id));
    }

    /// Wait for test ID
    pub fn waitForTestId(self: *Self, id: []const u8, timeout_ms: u32) DriverError!Element {
        return self.waitFor(Selector.byTestId(id), timeout_ms);
    }

    /// Wait for text
    pub fn waitForText(self: *Self, text: []const u8, timeout_ms: u32) DriverError!Element {
        return self.waitFor(Selector.byText(text), timeout_ms);
    }

    // ============ Screenshots ============

    /// Take screenshot of current screen
    pub fn screenshot(self: *Self) DriverError!Screenshot {
        return self.driver.takeScreenshot();
    }

    /// Compare screenshot with baseline
    pub fn compareScreenshot(self: *Self, baseline_path: []const u8) DriverError!CompareResult {
        const current = try self.screenshot();
        return screenshot_mod.compare(current, baseline_path, self.allocator);
    }

    /// Save screenshot to file
    pub fn saveScreenshot(self: *Self, path: []const u8) DriverError!void {
        const shot = try self.screenshot();
        return screenshot_mod.save(shot, path);
    }

    // ============ Zylix-Specific ============

    /// Get application state (Zylix apps only)
    pub fn getState(self: *Self, comptime T: type) DriverError!T {
        const json = try self.driver.getState() orelse return DriverError.AppNotRunning;
        return std.json.parseFromSlice(T, self.allocator, json, .{}) catch return DriverError.AppNotRunning;
    }

    /// Get raw state JSON (Zylix apps only)
    pub fn getStateJson(self: *Self) DriverError!?[]const u8 {
        return self.driver.getState();
    }

    /// Dispatch event to application (Zylix apps only)
    pub fn dispatch(self: *Self, event: anytype) DriverError!void {
        const json = std.json.stringifyAlloc(self.allocator, event, .{}) catch return DriverError.OutOfMemory;
        defer self.allocator.free(json);
        return self.driver.dispatch(json);
    }

    /// Dispatch raw event JSON (Zylix apps only)
    pub fn dispatchJson(self: *Self, event_json: []const u8) DriverError!void {
        return self.driver.dispatch(event_json);
    }

    // ============ Navigation Helpers ============

    /// Wait for navigation to complete (checks for loading indicators)
    pub fn waitForNavigation(self: *Self, timeout_ms: u32) DriverError!void {
        // Wait for any loading indicators to disappear
        const loading_selectors = [_]Selector{
            Selector.byTestId("loading"),
            Selector.byTestId("spinner"),
            Selector.byAccessibilityId("Loading"),
        };

        for (loading_selectors) |sel| {
            self.waitForNot(sel, timeout_ms) catch |err| switch (err) {
                DriverError.Timeout => {}, // Selector not found, that's fine
                else => return err,
            };
        }
    }

    /// Navigate back (platform back button/gesture)
    pub fn navigateBack(self: *Self) DriverError!void {
        // Platform-specific back navigation
        // This will be implemented by platform drivers
        const back_sel = Selector.byAccessibilityId("Back");
        if (self.find(back_sel)) |*back_btn| {
            try back_btn.tap();
        } else |_| {
            // No back button found, try hardware back
            // This is handled at the driver level
        }
    }

    // ============ Assertions ============

    /// Assert element exists
    pub fn assertExists(self: *Self, sel: Selector) DriverError!void {
        _ = try self.find(sel);
    }

    /// Assert element does not exist
    pub fn assertNotExists(self: *Self, sel: Selector) DriverError!void {
        if (self.driver.findElement(sel)) |maybe| {
            if (maybe != null) {
                return DriverError.AssertionFailed;
            }
        } else |_| {}
    }

    /// Assert screen matches baseline
    pub fn assertScreenshotMatches(self: *Self, baseline_path: []const u8, threshold: f32) DriverError!void {
        const result = try self.compareScreenshot(baseline_path);
        if (result.diff_percentage > threshold) {
            return DriverError.ScreenshotFailed;
        }
    }
};

/// Test context for managing multiple apps
pub const TestContext = struct {
    apps: std.StringHashMap(*App),
    allocator: std.mem.Allocator,
    default_timeout_ms: u32 = 5000,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .apps = std.StringHashMap(*App).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.apps.valueIterator();
        while (iter.next()) |app| {
            app.*.terminate() catch {};
            self.allocator.destroy(app.*);
        }
        self.apps.deinit();
    }

    /// Register an app with a name
    pub fn registerApp(self: *Self, name: []const u8, app: *App) !void {
        try self.apps.put(name, app);
    }

    /// Get app by name
    pub fn getApp(self: *Self, name: []const u8) ?*App {
        return self.apps.get(name);
    }

    /// Terminate all apps
    pub fn terminateAll(self: *Self) void {
        var iter = self.apps.valueIterator();
        while (iter.next()) |app| {
            app.*.terminate() catch {};
        }
    }

    /// Set default timeout for all operations
    pub fn setTimeout(self: *Self, timeout_ms: u32) void {
        self.default_timeout_ms = timeout_ms;
    }
};

/// Fixture for test setup and teardown
pub const TestFixture = struct {
    setup_fn: ?*const fn (*TestContext) anyerror!void = null,
    teardown_fn: ?*const fn (*TestContext) anyerror!void = null,
    context: TestContext,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .context = TestContext.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.context.deinit();
    }

    pub fn onSetup(self: *Self, func: *const fn (*TestContext) anyerror!void) *Self {
        self.setup_fn = func;
        return self;
    }

    pub fn onTeardown(self: *Self, func: *const fn (*TestContext) anyerror!void) *Self {
        self.teardown_fn = func;
        return self;
    }

    pub fn setup(self: *Self) !void {
        if (self.setup_fn) |f| {
            try f(&self.context);
        }
    }

    pub fn teardown(self: *Self) !void {
        if (self.teardown_fn) |f| {
            try f(&self.context);
        }
        self.context.terminateAll();
    }
};

// Tests
test "app launch configuration" {
    const config = AppConfig{
        .app_id = "com.example.app",
        .platform = .auto,
        .launch_timeout_ms = 30000,
    };

    try std.testing.expectEqualStrings("com.example.app", config.app_id);
    try std.testing.expect(config.platform == .auto);
}
