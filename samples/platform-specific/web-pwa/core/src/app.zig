//! Web PWA - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    cache = 1,
    push = 2,
    install = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "PWA Features",
            .cache => "Cache",
            .push => "Push",
            .install => "Install",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "globe",
            .cache => "folder",
            .push => "bell",
            .install => "download",
        };
    }
};

pub const CacheStrategy = enum(u8) {
    cache_first = 0,
    network_first = 1,
    stale_while_revalidate = 2,

    pub fn name(self: CacheStrategy) []const u8 {
        return switch (self) {
            .cache_first => "Cache First",
            .network_first => "Network First",
            .stale_while_revalidate => "Stale While Revalidate",
        };
    }

    pub fn description(self: CacheStrategy) []const u8 {
        return switch (self) {
            .cache_first => "Serve from cache, fallback to network",
            .network_first => "Fetch from network, fallback to cache",
            .stale_while_revalidate => "Serve cache, update in background",
        };
    }
};

pub const CachedResource = struct {
    url: []const u8 = "",
    size: u32 = 0,
    cached_at: i64 = 0,
    is_stale: bool = false,
};

pub const PushPermission = enum(u8) {
    default = 0,
    granted = 1,
    denied = 2,

    pub fn name(self: PushPermission) []const u8 {
        return switch (self) {
            .default => "Not Asked",
            .granted => "Granted",
            .denied => "Denied",
        };
    }
};

pub const max_cached_resources = 20;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // Service Worker
    sw_registered: bool = false,
    sw_version: []const u8 = "1.0.0",
    sw_update_available: bool = false,

    // Network
    is_online: bool = true,
    connection_type: []const u8 = "4g",

    // Cache
    cache_strategy: CacheStrategy = .cache_first,
    cached_resources: [max_cached_resources]CachedResource = undefined,
    cached_count: usize = 0,
    cache_size_bytes: u32 = 0,

    // Push
    push_permission: PushPermission = .default,
    push_enabled: bool = false,
    pending_notifications: u32 = 0,

    // Install
    can_install: bool = true,
    is_installed: bool = false,
    install_prompted: bool = false,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    app_state.sw_registered = true;

    // Sample cached resources
    addCachedResource("/index.html", 4096);
    addCachedResource("/app.js", 102400);
    addCachedResource("/styles.css", 8192);
    addCachedResource("/manifest.json", 512);
    addCachedResource("/icon-192.png", 16384);

    app_state.pending_notifications = 2;
}

fn addCachedResource(url: []const u8, size: u32) void {
    if (app_state.cached_count >= max_cached_resources) return;
    app_state.cached_resources[app_state.cached_count] = .{
        .url = url,
        .size = size,
        .cached_at = 1700000000,
    };
    app_state.cached_count += 1;
    app_state.cache_size_bytes += size;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Service Worker
pub fn isSwRegistered() bool {
    return app_state.sw_registered;
}

pub fn registerSw() void {
    app_state.sw_registered = true;
}

pub fn updateSw() void {
    app_state.sw_update_available = false;
    app_state.sw_version = "1.0.1";
}

// Network
pub fn setOnline(online: bool) void {
    app_state.is_online = online;
}

// Cache
pub fn setCacheStrategy(strategy: CacheStrategy) void {
    app_state.cache_strategy = strategy;
}

pub fn clearCache() void {
    app_state.cached_count = 0;
    app_state.cache_size_bytes = 0;
}

pub fn getCacheSize() u32 {
    return app_state.cache_size_bytes;
}

// Push
pub fn requestPushPermission() void {
    app_state.push_permission = .granted;
    app_state.push_enabled = true;
}

pub fn setPushEnabled(enabled: bool) void {
    if (app_state.push_permission == .granted) {
        app_state.push_enabled = enabled;
    }
}

pub fn clearPendingNotifications() void {
    app_state.pending_notifications = 0;
}

// Install
pub fn canInstall() bool {
    return app_state.can_install and !app_state.is_installed;
}

pub fn promptInstall() void {
    app_state.install_prompted = true;
}

pub fn markInstalled() void {
    app_state.is_installed = true;
    app_state.can_install = false;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.sw_registered);
}

test "service worker" {
    init();
    defer deinit();
    try std.testing.expect(isSwRegistered());
}

test "cache" {
    init();
    defer deinit();
    try std.testing.expect(app_state.cached_count > 0);
    try std.testing.expect(getCacheSize() > 0);
    clearCache();
    try std.testing.expectEqual(@as(usize, 0), app_state.cached_count);
}

test "push" {
    init();
    defer deinit();
    try std.testing.expectEqual(PushPermission.default, app_state.push_permission);
    requestPushPermission();
    try std.testing.expectEqual(PushPermission.granted, app_state.push_permission);
}

test "install" {
    init();
    defer deinit();
    try std.testing.expect(canInstall());
    markInstalled();
    try std.testing.expect(!canInstall());
}
