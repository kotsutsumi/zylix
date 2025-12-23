//! Live Preview Bridge API
//!
//! Launch and manage preview sessions with support for:
//! - Hot reload integration
//! - Multi-device preview
//! - Debug overlay support
//! - Remote debugging
//!
//! This module provides live preview capabilities for development.

const std = @import("std");
const project = @import("project.zig");

/// Preview error types
pub const PreviewError = error{
    NotInitialized,
    InvalidProject,
    InvalidTarget,
    SessionNotFound,
    DeviceNotAvailable,
    ConnectionFailed,
    HotReloadFailed,
    OutOfMemory,
};

/// Preview identifier
pub const PreviewId = struct {
    id: u64,
    project_name: []const u8,
    target: project.Target,
    started_at: i64,

    pub fn isValid(self: *const PreviewId) bool {
        return self.id > 0;
    }
};

/// Preview device type
pub const DeviceType = enum(u8) {
    simulator = 0,
    emulator = 1,
    physical = 2,
    browser = 3,
    desktop = 4,

    pub fn toString(self: DeviceType) []const u8 {
        return switch (self) {
            .simulator => "Simulator",
            .emulator => "Emulator",
            .physical => "Physical Device",
            .browser => "Browser",
            .desktop => "Desktop",
        };
    }
};

/// Device information
pub const DeviceInfo = struct {
    id: []const u8,
    name: []const u8,
    device_type: DeviceType,
    target: project.Target,
    os_version: ?[]const u8 = null,
    screen_width: u16 = 0,
    screen_height: u16 = 0,
    is_connected: bool = false,
};

/// Preview session state
pub const PreviewState = enum(u8) {
    starting = 0,
    connecting = 1,
    connected = 2,
    loading = 3,
    ready = 4,
    reloading = 5,
    error_state = 6,
    disconnected = 7,

    pub fn isActive(self: PreviewState) bool {
        return switch (self) {
            .connected, .loading, .ready, .reloading => true,
            else => false,
        };
    }

    pub fn toString(self: PreviewState) []const u8 {
        return switch (self) {
            .starting => "Starting",
            .connecting => "Connecting",
            .connected => "Connected",
            .loading => "Loading",
            .ready => "Ready",
            .reloading => "Reloading",
            .error_state => "Error",
            .disconnected => "Disconnected",
        };
    }
};

/// Debug overlay options
pub const DebugOverlay = struct {
    /// Show component bounds
    show_bounds: bool = false,
    /// Show component names
    show_names: bool = false,
    /// Show performance metrics
    show_performance: bool = false,
    /// Show layout guides
    show_guides: bool = false,
    /// Show touch/click visualization
    show_touches: bool = false,
    /// Show network activity
    show_network: bool = false,
    /// Slow animations for debugging
    slow_animations: bool = false,
    /// Animation speed multiplier (0.1 - 10.0)
    animation_speed: f32 = 1.0,
};

/// Preview configuration
pub const PreviewConfig = struct {
    /// Target device (optional, auto-select if null)
    device_id: ?[]const u8 = null,
    /// Port for preview server
    port: u16 = 3000,
    /// Enable hot reload
    hot_reload: bool = true,
    /// Enable debug overlay
    debug_overlay: DebugOverlay = .{},
    /// Auto-open browser (for web target)
    auto_open: bool = true,
    /// Enable remote debugging
    remote_debug: bool = false,
    /// Verbose logging
    verbose: bool = false,
};

/// Preview session information
pub const PreviewSession = struct {
    id: PreviewId,
    state: PreviewState,
    device: ?DeviceInfo = null,
    config: PreviewConfig,
    url: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    reload_count: u32 = 0,
    last_reload: ?i64 = null,
};

/// Hot reload result
pub const ReloadResult = struct {
    success: bool,
    duration_ms: u64,
    changed_files: u32,
    error_message: ?[]const u8 = null,
};

/// Preview event
pub const PreviewEvent = union(enum) {
    state_changed: PreviewState,
    reload_started: void,
    reload_completed: ReloadResult,
    device_connected: DeviceInfo,
    device_disconnected: []const u8,
    error_occurred: []const u8,
    console_log: ConsoleLog,
};

/// Console log from preview
pub const ConsoleLog = struct {
    level: LogLevel,
    message: []const u8,
    source: ?[]const u8 = null,
    line: ?u32 = null,
    timestamp: i64,
};

/// Log level
pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warning = 2,
    err = 3,
};

/// Event callback type
pub const EventCallback = *const fn (PreviewEvent) void;

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?PreviewError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: PreviewError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) PreviewError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return PreviewError.NotInitialized;
        }
    };
}

/// Preview session entry
const SessionEntry = struct {
    session: PreviewSession,
    event_callback: ?EventCallback = null,
};

/// Preview Manager
pub const Preview = struct {
    allocator: std.mem.Allocator,
    sessions: std.AutoHashMapUnmanaged(u64, SessionEntry) = .{},
    devices: std.StringHashMapUnmanaged(DeviceInfo) = .{},
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) Preview {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Preview) void {
        self.sessions.deinit(self.allocator);
        self.devices.deinit(self.allocator);
    }

    /// Open a preview session
    pub fn open(
        self: *Preview,
        project_id: project.ProjectId,
        target: project.Target,
        config: PreviewConfig,
    ) *Future(PreviewId) {
        const future = self.allocator.create(Future(PreviewId)) catch {
            const err_future = self.allocator.create(Future(PreviewId)) catch unreachable;
            err_future.* = Future(PreviewId).init();
            err_future.fail(PreviewError.OutOfMemory);
            return err_future;
        };
        future.* = Future(PreviewId).init();

        if (!project_id.isValid()) {
            future.fail(PreviewError.InvalidProject);
            return future;
        }

        const preview_id = PreviewId{
            .id = self.next_id,
            .project_name = project_id.name,
            .target = target,
            .started_at = std.time.timestamp(),
        };
        self.next_id += 1;

        const session = PreviewSession{
            .id = preview_id,
            .state = .starting,
            .config = config,
        };

        self.sessions.put(self.allocator, preview_id.id, .{
            .session = session,
        }) catch {
            future.fail(PreviewError.OutOfMemory);
            return future;
        };

        // In real implementation, would start preview server
        future.complete(preview_id);
        return future;
    }

    /// Close a preview session
    pub fn close(self: *Preview, preview_id: PreviewId) void {
        _ = self.sessions.remove(preview_id.id);
    }

    /// Refresh/reload preview
    pub fn refresh(self: *Preview, preview_id: PreviewId) void {
        if (self.sessions.getPtr(preview_id.id)) |entry| {
            entry.session.state = .reloading;
            entry.session.reload_count += 1;
            entry.session.last_reload = std.time.timestamp();

            if (entry.event_callback) |cb| {
                cb(.{ .reload_started = {} });
            }

            // Simulate reload completion
            entry.session.state = .ready;
            if (entry.event_callback) |cb| {
                cb(.{ .reload_completed = .{
                    .success = true,
                    .duration_ms = 100,
                    .changed_files = 1,
                } });
            }
        }
    }

    /// Toggle debug overlay
    pub fn setDebugOverlay(self: *Preview, preview_id: PreviewId, enabled: bool) void {
        if (self.sessions.getPtr(preview_id.id)) |entry| {
            entry.session.config.debug_overlay.show_bounds = enabled;
            entry.session.config.debug_overlay.show_names = enabled;
        }
    }

    /// Update debug overlay options
    pub fn updateDebugOverlay(self: *Preview, preview_id: PreviewId, overlay: DebugOverlay) void {
        if (self.sessions.getPtr(preview_id.id)) |entry| {
            entry.session.config.debug_overlay = overlay;
        }
    }

    /// Get session information
    pub fn getSession(self: *const Preview, preview_id: PreviewId) ?PreviewSession {
        if (self.sessions.get(preview_id.id)) |entry| {
            return entry.session;
        }
        return null;
    }

    /// Register event callback
    pub fn onEvent(self: *Preview, preview_id: PreviewId, callback: EventCallback) void {
        if (self.sessions.getPtr(preview_id.id)) |entry| {
            entry.event_callback = callback;
        }
    }

    /// Get available devices for target
    pub fn getAvailableDevices(self: *const Preview, target: project.Target) []const DeviceInfo {
        _ = self;
        // Return static device list based on target
        return switch (target) {
            .ios => &ios_devices,
            .android => &android_devices,
            .web => &web_devices,
            .macos => &macos_devices,
            else => &.{},
        };
    }

    /// Update session state
    pub fn updateState(self: *Preview, preview_id: PreviewId, state: PreviewState) void {
        if (self.sessions.getPtr(preview_id.id)) |entry| {
            entry.session.state = state;
            if (entry.event_callback) |cb| {
                cb(.{ .state_changed = state });
            }
        }
    }

    /// Get active session count
    pub fn activeCount(self: *const Preview) usize {
        var count: usize = 0;
        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.session.state.isActive()) {
                count += 1;
            }
        }
        return count;
    }

    /// Get total session count
    pub fn totalCount(self: *const Preview) usize {
        return self.sessions.count();
    }
};

// Static device data
const ios_devices = [_]DeviceInfo{
    .{ .id = "iphone-15-pro", .name = "iPhone 15 Pro", .device_type = .simulator, .target = .ios, .screen_width = 1179, .screen_height = 2556 },
    .{ .id = "iphone-15", .name = "iPhone 15", .device_type = .simulator, .target = .ios, .screen_width = 1170, .screen_height = 2532 },
    .{ .id = "ipad-pro-12", .name = "iPad Pro 12.9\"", .device_type = .simulator, .target = .ios, .screen_width = 2048, .screen_height = 2732 },
};

const android_devices = [_]DeviceInfo{
    .{ .id = "pixel-8", .name = "Pixel 8", .device_type = .emulator, .target = .android, .screen_width = 1080, .screen_height = 2400 },
    .{ .id = "pixel-tablet", .name = "Pixel Tablet", .device_type = .emulator, .target = .android, .screen_width = 1600, .screen_height = 2560 },
};

const web_devices = [_]DeviceInfo{
    .{ .id = "chrome", .name = "Chrome", .device_type = .browser, .target = .web },
    .{ .id = "firefox", .name = "Firefox", .device_type = .browser, .target = .web },
    .{ .id = "safari", .name = "Safari", .device_type = .browser, .target = .web },
};

const macos_devices = [_]DeviceInfo{
    .{ .id = "macos-native", .name = "macOS Native", .device_type = .desktop, .target = .macos },
};

/// Create a preview manager
pub fn createPreviewManager(allocator: std.mem.Allocator) Preview {
    return Preview.init(allocator);
}

// Tests
test "Preview initialization" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    try std.testing.expectEqual(@as(usize, 0), preview.totalCount());
}

test "PreviewState methods" {
    try std.testing.expect(!PreviewState.starting.isActive());
    try std.testing.expect(PreviewState.connected.isActive());
    try std.testing.expect(PreviewState.ready.isActive());
    try std.testing.expect(!PreviewState.disconnected.isActive());

    try std.testing.expect(std.mem.eql(u8, "Ready", PreviewState.ready.toString()));
}

test "DeviceType toString" {
    try std.testing.expect(std.mem.eql(u8, "Simulator", DeviceType.simulator.toString()));
    try std.testing.expect(std.mem.eql(u8, "Browser", DeviceType.browser.toString()));
}

test "Open preview session" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = preview.open(project_id, .web, .{});
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());

    const preview_id = try future.get();
    try std.testing.expect(preview_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), preview.totalCount());
}

test "Close preview session" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = preview.open(project_id, .ios, .{});
    defer allocator.destroy(future);
    const preview_id = try future.get();

    preview.close(preview_id);
    try std.testing.expectEqual(@as(usize, 0), preview.totalCount());
}

test "Refresh preview" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = preview.open(project_id, .android, .{});
    defer allocator.destroy(future);
    const preview_id = try future.get();

    preview.refresh(preview_id);

    const session = preview.getSession(preview_id);
    try std.testing.expect(session != null);
    try std.testing.expectEqual(@as(u32, 1), session.?.reload_count);
}

test "Debug overlay toggle" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = preview.open(project_id, .web, .{});
    defer allocator.destroy(future);
    const preview_id = try future.get();

    preview.setDebugOverlay(preview_id, true);

    const session = preview.getSession(preview_id);
    try std.testing.expect(session != null);
    try std.testing.expect(session.?.config.debug_overlay.show_bounds);
}

test "Get available devices" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const ios_devs = preview.getAvailableDevices(.ios);
    try std.testing.expect(ios_devs.len > 0);

    const web_devs = preview.getAvailableDevices(.web);
    try std.testing.expect(web_devs.len > 0);
}

test "Update session state" {
    const allocator = std.testing.allocator;
    var preview = createPreviewManager(allocator);
    defer preview.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = preview.open(project_id, .macos, .{});
    defer allocator.destroy(future);
    const preview_id = try future.get();

    preview.updateState(preview_id, .ready);

    const session = preview.getSession(preview_id);
    try std.testing.expect(session != null);
    try std.testing.expectEqual(PreviewState.ready, session.?.state);
}
