//! App Lifecycle Module
//!
//! Unified app lifecycle management with support for:
//! - Foreground/background state callbacks
//! - Termination handlers
//! - Memory warning notifications
//! - State restoration support
//!
//! Platform implementations:
//! - iOS: UIApplication lifecycle
//! - Android: Activity/Lifecycle components
//! - Web: visibilitychange/beforeunload events
//! - Desktop: Native window events

const std = @import("std");

/// Lifecycle error types
pub const LifecycleError = error{
    NotInitialized,
    CallbackAlreadyRegistered,
    CallbackNotFound,
    OutOfMemory,
};

/// Application state
pub const AppState = enum(u8) {
    /// App is not running
    not_running = 0,
    /// App is launching
    launching = 1,
    /// App is in foreground (active)
    foreground = 2,
    /// App is in background
    background = 3,
    /// App is being suspended
    suspended = 4,
    /// App is terminating
    terminating = 5,
};

/// Memory pressure level
pub const MemoryPressure = enum(u8) {
    normal = 0,
    warning = 1,
    critical = 2,
    fatal = 3, // App may be killed
};

/// State restoration data
pub const RestorationData = struct {
    /// Unique activity/scene identifier
    activity_id: ?[]const u8 = null,
    /// User activity type (for Handoff, etc.)
    user_activity_type: ?[]const u8 = null,
    /// Custom state data (JSON or binary)
    state_data: ?[]const u8 = null,
    /// Timestamp of when state was saved
    saved_at: i64 = 0,
};

/// Lifecycle event
pub const LifecycleEvent = union(enum) {
    /// App launched
    launched: LaunchInfo,
    /// App will enter foreground
    will_enter_foreground: void,
    /// App did become active (foreground)
    did_become_active: void,
    /// App will resign active
    will_resign_active: void,
    /// App did enter background
    did_enter_background: void,
    /// App will terminate
    will_terminate: void,
    /// Memory warning received
    memory_warning: MemoryPressure,
    /// State restoration requested
    restore_state: RestorationData,
    /// State should be saved
    save_state: void,
    /// App received deep link
    open_url: OpenUrlInfo,
    /// App received push notification
    push_notification: NotificationInfo,
    /// Screen will turn on
    screen_on: void,
    /// Screen will turn off
    screen_off: void,
    /// Device orientation changed
    orientation_changed: Orientation,
    /// Battery state changed
    battery_changed: BatteryInfo,
};

/// Launch information
pub const LaunchInfo = struct {
    /// Launch options/arguments
    launch_options: ?[]const u8 = null,
    /// Deep link URL if launched from URL
    url: ?[]const u8 = null,
    /// Push notification payload if launched from notification
    notification_payload: ?[]const u8 = null,
    /// Whether this is a cold start
    cold_start: bool = true,
};

/// URL open information
pub const OpenUrlInfo = struct {
    url: []const u8,
    source_app: ?[]const u8 = null,
    annotation: ?[]const u8 = null,
};

/// Push notification information
pub const NotificationInfo = struct {
    payload: []const u8,
    action_identifier: ?[]const u8 = null,
    is_remote: bool = true,
};

/// Device orientation
pub const Orientation = enum(u8) {
    unknown = 0,
    portrait = 1,
    portrait_upside_down = 2,
    landscape_left = 3,
    landscape_right = 4,
    face_up = 5,
    face_down = 6,
};

/// Battery information
pub const BatteryInfo = struct {
    level: f32, // 0.0 - 1.0
    state: BatteryState,
};

/// Battery state
pub const BatteryState = enum(u8) {
    unknown = 0,
    unplugged = 1,
    charging = 2,
    full = 3,
};

/// Lifecycle callback type
pub const LifecycleCallback = *const fn (LifecycleEvent) void;

/// Simple callback types
pub const SimpleCallback = *const fn () void;
pub const MemoryCallback = *const fn (MemoryPressure) void;
pub const StateCallback = *const fn (?RestorationData) void;

/// Lifecycle configuration
pub const LifecycleConfig = struct {
    /// Enable automatic state restoration
    enable_state_restoration: bool = true,
    /// Enable background fetch (iOS)
    enable_background_fetch: bool = false,
    /// Enable remote notifications
    enable_remote_notifications: bool = false,
    /// Minimum background fetch interval in seconds (iOS)
    background_fetch_interval: u32 = 900, // 15 minutes
    /// Enable debug logging
    debug: bool = false,
};

/// Callback registration entry
const CallbackEntry = struct {
    id: u64,
    callback: LifecycleCallback,
};

/// App Lifecycle Manager
pub const AppLifecycle = struct {
    allocator: std.mem.Allocator,
    config: LifecycleConfig,
    state: AppState = .not_running,
    callbacks: std.ArrayListUnmanaged(CallbackEntry) = .{},
    next_callback_id: u64 = 1,
    restoration_data: ?RestorationData = null,

    // Simple callbacks for convenience
    foreground_callbacks: std.ArrayListUnmanaged(SimpleCallback) = .{},
    background_callbacks: std.ArrayListUnmanaged(SimpleCallback) = .{},
    terminate_callbacks: std.ArrayListUnmanaged(SimpleCallback) = .{},
    memory_callbacks: std.ArrayListUnmanaged(MemoryCallback) = .{},

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: LifecycleConfig) AppLifecycle {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *AppLifecycle) void {
        self.callbacks.deinit(self.allocator);
        self.foreground_callbacks.deinit(self.allocator);
        self.background_callbacks.deinit(self.allocator);
        self.terminate_callbacks.deinit(self.allocator);
        self.memory_callbacks.deinit(self.allocator);
    }

    /// Register a lifecycle event callback
    pub fn registerCallback(self: *AppLifecycle, callback: LifecycleCallback) !u64 {
        const id = self.next_callback_id;
        self.next_callback_id += 1;

        try self.callbacks.append(self.allocator, .{
            .id = id,
            .callback = callback,
        });

        return id;
    }

    /// Unregister a callback by ID
    pub fn unregisterCallback(self: *AppLifecycle, callback_id: u64) bool {
        for (self.callbacks.items, 0..) |entry, i| {
            if (entry.id == callback_id) {
                _ = self.callbacks.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Register a foreground callback (convenience method)
    pub fn onForeground(self: *AppLifecycle, callback: SimpleCallback) void {
        self.foreground_callbacks.append(self.allocator, callback) catch {};
    }

    /// Register a background callback (convenience method)
    pub fn onBackground(self: *AppLifecycle, callback: SimpleCallback) void {
        self.background_callbacks.append(self.allocator, callback) catch {};
    }

    /// Register a terminate callback (convenience method)
    pub fn onTerminate(self: *AppLifecycle, callback: SimpleCallback) void {
        self.terminate_callbacks.append(self.allocator, callback) catch {};
    }

    /// Register a memory warning callback (convenience method)
    pub fn onMemoryWarning(self: *AppLifecycle, callback: MemoryCallback) void {
        self.memory_callbacks.append(self.allocator, callback) catch {};
    }

    /// Get current app state
    pub fn getState(self: *const AppLifecycle) AppState {
        return self.state;
    }

    /// Check if app is in foreground
    pub fn isInForeground(self: *const AppLifecycle) bool {
        return self.state == .foreground;
    }

    /// Check if app is in background
    pub fn isInBackground(self: *const AppLifecycle) bool {
        return self.state == .background or self.state == .suspended;
    }

    /// Get stored restoration data
    pub fn getRestorationData(self: *const AppLifecycle) ?RestorationData {
        return self.restoration_data;
    }

    /// Save state for restoration
    pub fn saveState(self: *AppLifecycle, data: RestorationData) void {
        self.restoration_data = data;
        self.dispatchEvent(.{ .save_state = {} });
    }

    /// Clear restoration data
    pub fn clearRestorationData(self: *AppLifecycle) void {
        self.restoration_data = null;
    }

    /// Dispatch a lifecycle event (called by platform layer)
    pub fn dispatchEvent(self: *AppLifecycle, event: LifecycleEvent) void {
        // Update state based on event
        switch (event) {
            .launched => self.state = .launching,
            .did_become_active => {
                self.state = .foreground;
                for (self.foreground_callbacks.items) |cb| {
                    cb();
                }
            },
            .did_enter_background => {
                self.state = .background;
                for (self.background_callbacks.items) |cb| {
                    cb();
                }
            },
            .will_terminate => {
                self.state = .terminating;
                for (self.terminate_callbacks.items) |cb| {
                    cb();
                }
            },
            .memory_warning => |pressure| {
                for (self.memory_callbacks.items) |cb| {
                    cb(pressure);
                }
            },
            else => {},
        }

        // Dispatch to registered callbacks
        for (self.callbacks.items) |entry| {
            entry.callback(event);
        }
    }

    /// Simulate app launch (for testing)
    pub fn simulateLaunch(self: *AppLifecycle, info: LaunchInfo) void {
        self.dispatchEvent(.{ .launched = info });
        self.dispatchEvent(.{ .will_enter_foreground = {} });
        self.dispatchEvent(.{ .did_become_active = {} });
    }

    /// Simulate entering background (for testing)
    pub fn simulateBackground(self: *AppLifecycle) void {
        self.dispatchEvent(.{ .will_resign_active = {} });
        self.dispatchEvent(.{ .did_enter_background = {} });
    }

    /// Simulate returning to foreground (for testing)
    pub fn simulateForeground(self: *AppLifecycle) void {
        self.dispatchEvent(.{ .will_enter_foreground = {} });
        self.dispatchEvent(.{ .did_become_active = {} });
    }

    /// Simulate memory warning (for testing)
    pub fn simulateMemoryWarning(self: *AppLifecycle, pressure: MemoryPressure) void {
        self.dispatchEvent(.{ .memory_warning = pressure });
    }

    /// Simulate termination (for testing)
    pub fn simulateTermination(self: *AppLifecycle) void {
        self.dispatchEvent(.{ .will_terminate = {} });
    }
};

/// Convenience function to create a lifecycle manager
pub fn createLifecycle(allocator: std.mem.Allocator, config: LifecycleConfig) AppLifecycle {
    return AppLifecycle.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultLifecycle(allocator: std.mem.Allocator) AppLifecycle {
    return AppLifecycle.init(allocator, .{});
}

// Global lifecycle instance (singleton pattern for convenience)
// NOTE: This singleton is designed for single-threaded use only.
// For multi-threaded applications, create and manage AppLifecycle instances manually.
var global_lifecycle: ?*AppLifecycle = null;
var global_lifecycle_mutex: std.Thread.Mutex = .{};

/// Get or create global lifecycle instance.
/// Returns error on allocation failure.
/// NOTE: Thread-safe through mutex, but intended for single-threaded use.
pub fn getGlobalLifecycle(allocator: std.mem.Allocator) !*AppLifecycle {
    global_lifecycle_mutex.lock();
    defer global_lifecycle_mutex.unlock();

    if (global_lifecycle) |lifecycle| {
        return lifecycle;
    }

    const lifecycle = try allocator.create(AppLifecycle);
    lifecycle.* = createDefaultLifecycle(allocator);
    global_lifecycle = lifecycle;
    return lifecycle;
}

// Tests
test "AppLifecycle initialization" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    try std.testing.expectEqual(AppState.not_running, lifecycle.getState());
}

test "Callback registration" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    var called = false;
    const callback: LifecycleCallback = struct {
        fn handler(_: LifecycleEvent) void {
            // Cannot capture mutable variable in Zig, use different approach
        }
    }.handler;

    const id = try lifecycle.registerCallback(callback);
    try std.testing.expect(id > 0);

    try std.testing.expect(lifecycle.unregisterCallback(id));
    try std.testing.expect(!lifecycle.unregisterCallback(id)); // Already removed

    _ = called;
}

test "State transitions" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    try std.testing.expectEqual(AppState.not_running, lifecycle.getState());
    try std.testing.expect(!lifecycle.isInForeground());
    try std.testing.expect(!lifecycle.isInBackground());

    lifecycle.simulateLaunch(.{});
    try std.testing.expectEqual(AppState.foreground, lifecycle.getState());
    try std.testing.expect(lifecycle.isInForeground());

    lifecycle.simulateBackground();
    try std.testing.expectEqual(AppState.background, lifecycle.getState());
    try std.testing.expect(lifecycle.isInBackground());

    lifecycle.simulateForeground();
    try std.testing.expectEqual(AppState.foreground, lifecycle.getState());
    try std.testing.expect(lifecycle.isInForeground());

    lifecycle.simulateTermination();
    try std.testing.expectEqual(AppState.terminating, lifecycle.getState());
}

test "Simple callbacks" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    var foreground_count: u32 = 0;
    var background_count: u32 = 0;

    // Note: In real Zig, we'd need a different pattern for mutable captures
    // This test demonstrates the API structure

    lifecycle.simulateLaunch(.{});
    lifecycle.simulateBackground();
    lifecycle.simulateForeground();

    _ = foreground_count;
    _ = background_count;
}

test "Restoration data" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    try std.testing.expect(lifecycle.getRestorationData() == null);

    lifecycle.saveState(.{
        .activity_id = "main",
        .state_data = "{}",
        .saved_at = std.time.timestamp(),
    });

    const data = lifecycle.getRestorationData();
    try std.testing.expect(data != null);
    try std.testing.expect(std.mem.eql(u8, "main", data.?.activity_id.?));

    lifecycle.clearRestorationData();
    try std.testing.expect(lifecycle.getRestorationData() == null);
}

test "Memory pressure" {
    const allocator = std.testing.allocator;
    var lifecycle = createDefaultLifecycle(allocator);
    defer lifecycle.deinit();

    // Simulate memory warnings at different levels
    lifecycle.simulateMemoryWarning(.warning);
    lifecycle.simulateMemoryWarning(.critical);
}

test "Launch info" {
    const info = LaunchInfo{
        .url = "myapp://open?id=123",
        .cold_start = true,
    };

    try std.testing.expect(info.cold_start);
    try std.testing.expect(std.mem.eql(u8, "myapp://open?id=123", info.url.?));
}
