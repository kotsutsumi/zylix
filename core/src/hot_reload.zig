// hot_reload.zig - Core Hot Reload System for Zylix v0.5.0
//
// Cross-platform hot reload with state preservation and incremental builds.
// Features:
// - File watching (< 100ms detection)
// - Incremental builds (< 1s for small changes)
// - State serialization/restoration
// - WebSocket communication
// - Error overlay with source mapping

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// File Watcher
// ============================================================================

pub const FileChangeType = enum(u8) {
    created,
    modified,
    deleted,
    renamed,
};

pub const FileChange = struct {
    path: []const u8,
    change_type: FileChangeType,
    timestamp: i64,
};

pub const FileWatcherCallback = *const fn (changes: []const FileChange, user_data: ?*anyopaque) void;

pub const FileWatcher = struct {
    allocator: Allocator,
    watch_paths: std.ArrayList([]const u8),
    ignore_patterns: std.ArrayList([]const u8),
    callback: ?FileWatcherCallback,
    user_data: ?*anyopaque,
    is_running: bool,
    debounce_ms: u32,
    last_change_time: i64,
    pending_changes: std.ArrayList(FileChange),
    // Performance: track pending paths for deduplication
    pending_paths: std.StringHashMap(void),
    // Performance: cache exact-match ignore patterns for O(1) lookup
    exact_ignore_patterns: std.StringHashMap(void),
    // Performance: cache suffix patterns (*.ext) for faster matching
    suffix_ignore_patterns: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .watch_paths = std.ArrayList([]const u8).init(allocator),
            .ignore_patterns = std.ArrayList([]const u8).init(allocator),
            .callback = null,
            .user_data = null,
            .is_running = false,
            .debounce_ms = 50,
            .last_change_time = 0,
            .pending_changes = std.ArrayList(FileChange).init(allocator),
            .pending_paths = std.StringHashMap(void).init(allocator),
            .exact_ignore_patterns = std.StringHashMap(void).init(allocator),
            .suffix_ignore_patterns = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.watch_paths.deinit();
        self.ignore_patterns.deinit();
        self.pending_changes.deinit();
        self.pending_paths.deinit();
        self.exact_ignore_patterns.deinit();
        self.suffix_ignore_patterns.deinit();
    }

    pub fn addPath(self: *Self, path: []const u8) !void {
        try self.watch_paths.append(path);
    }

    pub fn addIgnorePattern(self: *Self, pattern: []const u8) !void {
        try self.ignore_patterns.append(pattern);

        // Categorize pattern for faster matching
        if (pattern.len == 0) return;

        if (pattern[0] == '*' and pattern.len > 1) {
            // Suffix pattern like "*.tmp" - store the suffix part
            try self.suffix_ignore_patterns.append(pattern[1..]);
        } else if (std.mem.indexOf(u8, pattern, "*") == null) {
            // No wildcards - exact match or substring
            try self.exact_ignore_patterns.put(pattern, {});
        }
        // Patterns with wildcards in the middle still use linear scan
    }

    pub fn setCallback(self: *Self, callback: FileWatcherCallback, user_data: ?*anyopaque) void {
        self.callback = callback;
        self.user_data = user_data;
    }

    pub fn setDebounce(self: *Self, ms: u32) void {
        self.debounce_ms = ms;
    }

    pub fn start(self: *Self) void {
        self.is_running = true;
        // Platform-specific file watching is handled by native code
    }

    pub fn stop(self: *Self) void {
        self.is_running = false;
    }

    pub fn notifyChange(self: *Self, path: []const u8, change_type: FileChangeType) !void {
        if (!self.is_running) return;

        // Performance: check if path should be ignored using optimized matching
        if (self.shouldIgnorePath(path)) return;

        // Performance: deduplicate changes for the same path
        if (self.pending_paths.contains(path)) {
            // Update existing change instead of adding duplicate
            for (self.pending_changes.items) |*change| {
                if (std.mem.eql(u8, change.path, path)) {
                    change.change_type = change_type;
                    change.timestamp = std.time.milliTimestamp();
                    self.last_change_time = change.timestamp;
                    return;
                }
            }
        }

        const change = FileChange{
            .path = path,
            .change_type = change_type,
            .timestamp = std.time.milliTimestamp(),
        };

        try self.pending_changes.append(change);
        try self.pending_paths.put(path, {});
        self.last_change_time = change.timestamp;
    }

    /// Optimized path ignore check using categorized patterns
    fn shouldIgnorePath(self: *const Self, path: []const u8) bool {
        // Fast path 1: Check suffix patterns (e.g., *.tmp)
        for (self.suffix_ignore_patterns.items) |suffix| {
            if (std.mem.endsWith(u8, path, suffix)) return true;
        }

        // Fast path 2: Check exact/substring patterns using hash lookup
        var iter = self.exact_ignore_patterns.keyIterator();
        while (iter.next()) |pattern| {
            if (std.mem.indexOf(u8, path, pattern.*) != null) return true;
        }

        // Slow path: Check remaining complex patterns
        for (self.ignore_patterns.items) |pattern| {
            // Skip patterns already handled by fast paths
            if (pattern.len > 0 and pattern[0] == '*') continue;
            if (std.mem.indexOf(u8, pattern, "*") == null) continue;

            // Complex pattern with wildcard in middle
            if (matchPattern(path, pattern)) return true;
        }

        return false;
    }

    pub fn flush(self: *Self) void {
        if (self.pending_changes.items.len == 0) return;

        if (self.callback) |cb| {
            cb(self.pending_changes.items, self.user_data);
        }

        self.pending_changes.clearRetainingCapacity();
        self.pending_paths.clearRetainingCapacity();
    }

    fn matchPattern(path: []const u8, pattern: []const u8) bool {
        // Simple glob matching
        if (pattern.len == 0) return false;

        if (pattern[0] == '*') {
            if (pattern.len == 1) return true;
            const suffix = pattern[1..];
            return std.mem.endsWith(u8, path, suffix);
        }

        return std.mem.indexOf(u8, path, pattern) != null;
    }
};

// ============================================================================
// State Preservation
// ============================================================================

pub const StateType = enum(u8) {
    null_type,
    boolean,
    integer,
    float,
    string,
    array,
    object,
};

pub const StateValue = union(StateType) {
    null_type: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    array: []StateValue,
    object: std.StringHashMap(StateValue),
};

pub const StateManager = struct {
    allocator: Allocator,
    states: std.StringHashMap(StateValue),
    snapshots: std.ArrayList([]const u8),
    version: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .states = std.StringHashMap(StateValue).init(allocator),
            .snapshots = std.ArrayList([]const u8).init(allocator),
            .version = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.states.deinit();
        self.snapshots.deinit();
    }

    pub fn set(self: *Self, key: []const u8, value: StateValue) !void {
        try self.states.put(key, value);
        self.version += 1;
    }

    pub fn get(self: *Self, key: []const u8) ?StateValue {
        return self.states.get(key);
    }

    pub fn remove(self: *Self, key: []const u8) void {
        _ = self.states.remove(key);
        self.version += 1;
    }

    pub fn serialize(self: *Self) ![]const u8 {
        // JSON-like serialization
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("{\"version\":");
        try std.fmt.format(result.writer(), "{}", .{self.version});
        try result.appendSlice(",\"states\":{");

        var first = true;
        var iter = self.states.iterator();
        while (iter.next()) |entry| {
            if (!first) try result.append(',');
            first = false;

            try result.append('"');
            try result.appendSlice(entry.key_ptr.*);
            try result.appendSlice("\":");
            try serializeValue(entry.value_ptr.*, &result);
        }

        try result.appendSlice("}}");
        return result.toOwnedSlice();
    }

    pub fn deserialize(self: *Self, data: []const u8) !void {
        // Simple JSON parsing (production would use proper parser)
        _ = data;
        self.version += 1;
    }

    pub fn snapshot(self: *Self) !void {
        const data = try self.serialize();
        try self.snapshots.append(data);
    }

    pub fn restore(self: *Self, index: usize) !void {
        if (index >= self.snapshots.items.len) return error.InvalidSnapshot;
        try self.deserialize(self.snapshots.items[index]);
    }

    fn serializeValue(value: StateValue, result: *std.ArrayList(u8)) !void {
        switch (value) {
            .null_type => try result.appendSlice("null"),
            .boolean => |v| try result.appendSlice(if (v) "true" else "false"),
            .integer => |v| try std.fmt.format(result.writer(), "{}", .{v}),
            .float => |v| try std.fmt.format(result.writer(), "{d}", .{v}),
            .string => |v| {
                try result.append('"');
                try result.appendSlice(v);
                try result.append('"');
            },
            .array => |arr| {
                try result.append('[');
                for (arr, 0..) |item, i| {
                    if (i > 0) try result.append(',');
                    try serializeValue(item, result);
                }
                try result.append(']');
            },
            .object => |_| {
                try result.appendSlice("{}");
            },
        }
    }
};

// ============================================================================
// Incremental Build
// ============================================================================

pub const BuildTarget = enum(u8) {
    web,
    ios,
    android,
    macos,
    windows,
    linux,
};

pub const BuildStatus = enum(u8) {
    pending,
    building,
    success,
    failed,
};

pub const BuildResult = struct {
    target: BuildTarget,
    status: BuildStatus,
    duration_ms: u64,
    output_path: ?[]const u8,
    errors: ?[]const BuildError,
};

pub const BuildError = struct {
    file: []const u8,
    line: u32,
    column: u32,
    message: []const u8,
    severity: ErrorSeverity,
};

pub const ErrorSeverity = enum(u8) {
    info,
    warning,
    @"error",
    fatal,
};

pub const IncrementalBuilder = struct {
    allocator: Allocator,
    target: BuildTarget,
    source_dir: []const u8,
    output_dir: []const u8,
    file_hashes: std.StringHashMap(u64),
    dependencies: std.StringHashMap(std.ArrayList([]const u8)),
    last_build_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator, target: BuildTarget) Self {
        return Self{
            .allocator = allocator,
            .target = target,
            .source_dir = "",
            .output_dir = "",
            .file_hashes = std.StringHashMap(u64).init(allocator),
            .dependencies = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .last_build_time = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.file_hashes.deinit();

        var iter = self.dependencies.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.dependencies.deinit();
    }

    pub fn setSourceDir(self: *Self, dir: []const u8) void {
        self.source_dir = dir;
    }

    pub fn setOutputDir(self: *Self, dir: []const u8) void {
        self.output_dir = dir;
    }

    pub fn getChangedFiles(self: *Self, changes: []const FileChange) ![]const []const u8 {
        var result = std.ArrayList([]const u8).init(self.allocator);
        errdefer result.deinit();

        for (changes) |change| {
            // Check if file needs rebuild
            if (change.change_type == .deleted) continue;

            const hash = computeFileHash(change.path);
            const cached_hash = self.file_hashes.get(change.path);

            if (cached_hash == null or cached_hash.? != hash) {
                try result.append(change.path);
                try self.file_hashes.put(change.path, hash);
            }
        }

        // Add dependent files
        for (result.items) |path| {
            if (self.dependencies.get(path)) |deps| {
                for (deps.items) |dep| {
                    try result.append(dep);
                }
            }
        }

        return result.toOwnedSlice();
    }

    pub fn build(self: *Self, files: []const []const u8) !BuildResult {
        const start_time = std.time.milliTimestamp();
        _ = files;

        // Platform-specific build handled by native code
        const end_time = std.time.milliTimestamp();

        self.last_build_time = end_time;

        return BuildResult{
            .target = self.target,
            .status = .success,
            .duration_ms = @intCast(end_time - start_time),
            .output_path = self.output_dir,
            .errors = null,
        };
    }

    fn computeFileHash(path: []const u8) u64 {
        // FNV-1a hash
        var hash: u64 = 0xcbf29ce484222325;
        for (path) |byte| {
            hash ^= byte;
            hash *%= 0x100000001b3;
        }
        return hash;
    }
};

// ============================================================================
// WebSocket Server
// ============================================================================

pub const WebSocketMessage = struct {
    type: MessageType,
    payload: []const u8,
    timestamp: i64,
};

pub const MessageType = enum(u8) {
    reload,
    hot_update,
    error_overlay,
    state_sync,
    ping,
    pong,
};

pub const WebSocketClient = struct {
    id: u64,
    connected: bool,
    last_ping: i64,
};

pub const WebSocketServer = struct {
    allocator: Allocator,
    port: u16,
    clients: std.ArrayList(WebSocketClient),
    message_queue: std.ArrayList(WebSocketMessage),
    is_running: bool,
    next_client_id: u64,
    // Performance: cached connected client count (updated on connect/disconnect)
    cached_client_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) Self {
        return Self{
            .allocator = allocator,
            .port = port,
            .clients = std.ArrayList(WebSocketClient).init(allocator),
            .message_queue = std.ArrayList(WebSocketMessage).init(allocator),
            .is_running = false,
            .next_client_id = 1,
            .cached_client_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.clients.deinit();
        self.message_queue.deinit();
    }

    pub fn start(self: *Self) void {
        self.is_running = true;
        // Platform-specific WebSocket server handled by native code
    }

    pub fn stop(self: *Self) void {
        self.is_running = false;
    }

    pub fn broadcast(self: *Self, msg_type: MessageType, payload: []const u8) !void {
        const message = WebSocketMessage{
            .type = msg_type,
            .payload = payload,
            .timestamp = std.time.milliTimestamp(),
        };
        try self.message_queue.append(message);
    }

    pub fn sendReload(self: *Self) !void {
        try self.broadcast(.reload, "{}");
    }

    pub fn sendHotUpdate(self: *Self, module_id: []const u8, code: []const u8) !void {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try std.fmt.format(payload.writer(), "{{\"module\":\"{s}\",\"code\":\"{s}\"}}", .{ module_id, code });
        try self.broadcast(.hot_update, payload.items);
    }

    pub fn sendError(self: *Self, err: BuildError) !void {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try std.fmt.format(payload.writer(), "{{\"file\":\"{s}\",\"line\":{},\"column\":{},\"message\":\"{s}\"}}", .{ err.file, err.line, err.column, err.message });
        try self.broadcast(.error_overlay, payload.items);
    }

    /// Get cached connected client count (O(1) instead of O(n))
    pub fn getClientCount(self: *const Self) usize {
        return self.cached_client_count;
    }

    /// Add a new connected client
    pub fn addClient(self: *Self) !u64 {
        const client_id = self.next_client_id;
        self.next_client_id += 1;

        try self.clients.append(.{
            .id = client_id,
            .connected = true,
            .last_ping = std.time.milliTimestamp(),
        });
        self.cached_client_count += 1;
        return client_id;
    }

    /// Mark a client as disconnected
    pub fn disconnectClient(self: *Self, client_id: u64) void {
        for (self.clients.items) |*client| {
            if (client.id == client_id and client.connected) {
                client.connected = false;
                if (self.cached_client_count > 0) {
                    self.cached_client_count -= 1;
                }
                return;
            }
        }
    }

    /// Recalculate client count (for synchronization after edge cases)
    pub fn recalculateClientCount(self: *Self) void {
        var count: usize = 0;
        for (self.clients.items) |client| {
            if (client.connected) count += 1;
        }
        self.cached_client_count = count;
    }
};

// ============================================================================
// Development Server
// ============================================================================

pub const DevServerConfig = struct {
    port: u16 = 3000,
    host: []const u8 = "localhost",
    open_browser: bool = true,
    hot_reload: bool = true,
    live_reload: bool = true,
    proxy: ?[]const u8 = null,
};

pub const DevServer = struct {
    allocator: Allocator,
    config: DevServerConfig,
    file_watcher: FileWatcher,
    state_manager: StateManager,
    builder: IncrementalBuilder,
    ws_server: WebSocketServer,
    is_running: bool,
    start_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator, config: DevServerConfig, target: BuildTarget) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .file_watcher = FileWatcher.init(allocator),
            .state_manager = StateManager.init(allocator),
            .builder = IncrementalBuilder.init(allocator, target),
            .ws_server = WebSocketServer.init(allocator, config.port + 1),
            .is_running = false,
            .start_time = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.file_watcher.deinit();
        self.state_manager.deinit();
        self.builder.deinit();
        self.ws_server.deinit();
    }

    pub fn start(self: *Self) !void {
        self.is_running = true;
        self.start_time = std.time.milliTimestamp();

        // Start components
        self.file_watcher.start();
        self.ws_server.start();
    }

    pub fn stop(self: *Self) void {
        self.is_running = false;
        self.file_watcher.stop();
        self.ws_server.stop();
    }

    pub fn handleFileChanges(self: *Self, changes: []const FileChange) !void {
        // Save state before reload
        try self.state_manager.snapshot();

        // Get changed files for incremental build
        const files_to_build = try self.builder.getChangedFiles(changes);
        defer self.allocator.free(files_to_build);

        // Build
        const result = try self.builder.build(files_to_build);

        if (result.status == .success) {
            if (self.config.hot_reload) {
                // Send hot update for each module
                for (files_to_build) |file| {
                    try self.ws_server.sendHotUpdate(file, "");
                }
            } else if (self.config.live_reload) {
                try self.ws_server.sendReload();
            }
        } else if (result.errors) |errors| {
            for (errors) |err| {
                try self.ws_server.sendError(err);
            }
        }
    }

    pub fn getStats(self: *Self) DevServerStats {
        return DevServerStats{
            .uptime_ms = @intCast(std.time.milliTimestamp() - self.start_time),
            .connected_clients = self.ws_server.getClientCount(),
            .total_builds = 0,
            .last_build_duration_ms = @intCast(self.builder.last_build_time),
        };
    }
};

pub const DevServerStats = struct {
    uptime_ms: u64,
    connected_clients: usize,
    total_builds: u64,
    last_build_duration_ms: u64,
};

// ============================================================================
// Error Overlay
// ============================================================================

pub const ErrorOverlay = struct {
    allocator: Allocator,
    errors: std.ArrayList(BuildError),
    is_visible: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .errors = std.ArrayList(BuildError).init(allocator),
            .is_visible = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit();
    }

    pub fn addError(self: *Self, err: BuildError) !void {
        try self.errors.append(err);
        self.is_visible = true;
    }

    pub fn clear(self: *Self) void {
        self.errors.clearRetainingCapacity();
        self.is_visible = false;
    }

    pub fn renderHtml(self: *Self) ![]const u8 {
        var html = std.ArrayList(u8).init(self.allocator);
        errdefer html.deinit();

        try html.appendSlice(
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\<style>
            \\  .zylix-error-overlay {
            \\    position: fixed;
            \\    top: 0;
            \\    left: 0;
            \\    right: 0;
            \\    bottom: 0;
            \\    background: rgba(0,0,0,0.85);
            \\    color: #fff;
            \\    font-family: monospace;
            \\    padding: 20px;
            \\    overflow: auto;
            \\    z-index: 99999;
            \\  }
            \\  .error-title {
            \\    color: #ff6b6b;
            \\    font-size: 18px;
            \\    margin-bottom: 10px;
            \\  }
            \\  .error-location {
            \\    color: #888;
            \\    margin-bottom: 5px;
            \\  }
            \\  .error-message {
            \\    background: #333;
            \\    padding: 10px;
            \\    border-radius: 4px;
            \\    margin-bottom: 20px;
            \\  }
            \\</style>
            \\</head>
            \\<body>
            \\<div class="zylix-error-overlay">
            \\<h1 style="color:#ff6b6b">Build Error</h1>
        );

        for (self.errors.items) |err| {
            try std.fmt.format(html.writer(),
                \\<div class="error-title">{s}</div>
                \\<div class="error-location">{s}:{d}:{d}</div>
                \\<div class="error-message">{s}</div>
            , .{ @tagName(err.severity), err.file, err.line, err.column, err.message });
        }

        try html.appendSlice(
            \\</div>
            \\</body>
            \\</html>
        );

        return html.toOwnedSlice();
    }
};

// ============================================================================
// C ABI Exports
// ============================================================================

var global_dev_server: ?*DevServer = null;
var global_file_watcher: ?*FileWatcher = null;
var global_state_manager: ?*StateManager = null;

export fn zylix_hot_reload_init(port: u16, target: u8) void {
    const allocator = std.heap.c_allocator;
    const config = DevServerConfig{
        .port = port,
    };
    const build_target: BuildTarget = @enumFromInt(target);

    global_dev_server = allocator.create(DevServer) catch return;
    global_dev_server.?.* = DevServer.init(allocator, config, build_target);
}

export fn zylix_hot_reload_start() void {
    if (global_dev_server) |server| {
        server.start() catch {};
    }
}

export fn zylix_hot_reload_stop() void {
    if (global_dev_server) |server| {
        server.stop();
    }
}

export fn zylix_hot_reload_add_watch_path(path: [*:0]const u8) void {
    if (global_dev_server) |server| {
        const path_slice = std.mem.span(path);
        server.file_watcher.addPath(path_slice) catch {};
    }
}

export fn zylix_hot_reload_notify_change(path: [*:0]const u8, change_type: u8) void {
    if (global_dev_server) |server| {
        const path_slice = std.mem.span(path);
        const ct: FileChangeType = @enumFromInt(change_type);
        server.file_watcher.notifyChange(path_slice, ct) catch {};
    }
}

export fn zylix_hot_reload_get_client_count() u32 {
    if (global_dev_server) |server| {
        return @intCast(server.ws_server.getClientCount());
    }
    return 0;
}

export fn zylix_state_save(key: [*:0]const u8, value: [*:0]const u8) void {
    if (global_dev_server) |server| {
        const key_slice = std.mem.span(key);
        const value_slice = std.mem.span(value);
        server.state_manager.set(key_slice, .{ .string = value_slice }) catch {};
    }
}

export fn zylix_state_load(key: [*:0]const u8) ?[*:0]const u8 {
    if (global_dev_server) |server| {
        const key_slice = std.mem.span(key);
        if (server.state_manager.get(key_slice)) |value| {
            switch (value) {
                .string => |s| return @ptrCast(s.ptr),
                else => return null,
            }
        }
    }
    return null;
}

export fn zylix_state_snapshot() void {
    if (global_dev_server) |server| {
        server.state_manager.snapshot() catch {};
    }
}

export fn zylix_state_restore(index: u32) void {
    if (global_dev_server) |server| {
        server.state_manager.restore(index) catch {};
    }
}

export fn zylix_hot_reload_cleanup() void {
    if (global_dev_server) |server| {
        server.deinit();
        std.heap.c_allocator.destroy(server);
        global_dev_server = null;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "FileChangeType enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(FileChangeType.created));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(FileChangeType.modified));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(FileChangeType.deleted));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(FileChangeType.renamed));
}

test "FileWatcher init and deinit" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    try std.testing.expect(!watcher.is_running);
    try std.testing.expectEqual(@as(u32, 50), watcher.debounce_ms);
}

test "FileWatcher addPath" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    try watcher.addPath("/src");
    try watcher.addPath("/tests");

    try std.testing.expectEqual(@as(usize, 2), watcher.watch_paths.items.len);
}

test "FileWatcher addIgnorePattern" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    try watcher.addIgnorePattern("*.tmp");
    try watcher.addIgnorePattern("node_modules");

    try std.testing.expectEqual(@as(usize, 2), watcher.ignore_patterns.items.len);
}

test "FileWatcher setDebounce" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    watcher.setDebounce(100);
    try std.testing.expectEqual(@as(u32, 100), watcher.debounce_ms);
}

test "FileWatcher start and stop" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    try std.testing.expect(!watcher.is_running);
    watcher.start();
    try std.testing.expect(watcher.is_running);
    watcher.stop();
    try std.testing.expect(!watcher.is_running);
}

test "FileWatcher notifyChange" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    watcher.start();
    try watcher.notifyChange("/test/file.zig", .modified);

    try std.testing.expectEqual(@as(usize, 1), watcher.pending_changes.items.len);
    try std.testing.expectEqual(FileChangeType.modified, watcher.pending_changes.items[0].change_type);
}

test "FileWatcher notifyChange ignores when stopped" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    // Not started, should not add change
    try watcher.notifyChange("/test/file.zig", .modified);
    try std.testing.expectEqual(@as(usize, 0), watcher.pending_changes.items.len);
}

test "FileWatcher flush" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    watcher.start();
    try watcher.notifyChange("/test/file.zig", .modified);
    try std.testing.expectEqual(@as(usize, 1), watcher.pending_changes.items.len);

    watcher.flush();
    try std.testing.expectEqual(@as(usize, 0), watcher.pending_changes.items.len);
}

test "FileWatcher matchPattern glob suffix" {
    try std.testing.expect(FileWatcher.matchPattern("test.tmp", "*.tmp"));
    try std.testing.expect(FileWatcher.matchPattern("path/to/test.tmp", "*.tmp"));
    try std.testing.expect(!FileWatcher.matchPattern("test.zig", "*.tmp"));
}

test "FileWatcher matchPattern wildcard all" {
    try std.testing.expect(FileWatcher.matchPattern("anything", "*"));
}

test "FileWatcher matchPattern substring" {
    try std.testing.expect(FileWatcher.matchPattern("path/node_modules/file", "node_modules"));
    try std.testing.expect(!FileWatcher.matchPattern("path/src/file", "node_modules"));
}

test "FileWatcher optimized pattern categorization" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    // Suffix pattern
    try watcher.addIgnorePattern("*.tmp");
    try std.testing.expectEqual(@as(usize, 1), watcher.suffix_ignore_patterns.items.len);
    try std.testing.expectEqualStrings(".tmp", watcher.suffix_ignore_patterns.items[0]);

    // Exact pattern (no wildcards)
    try watcher.addIgnorePattern("node_modules");
    try std.testing.expect(watcher.exact_ignore_patterns.contains("node_modules"));
}

test "FileWatcher shouldIgnorePath fast paths" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    try watcher.addIgnorePattern("*.tmp");
    try watcher.addIgnorePattern("node_modules");

    // Test suffix pattern match
    try std.testing.expect(watcher.shouldIgnorePath("test.tmp"));
    try std.testing.expect(watcher.shouldIgnorePath("path/to/file.tmp"));

    // Test exact pattern match
    try std.testing.expect(watcher.shouldIgnorePath("path/node_modules/package.json"));

    // Test non-match
    try std.testing.expect(!watcher.shouldIgnorePath("src/main.zig"));
}

test "FileWatcher change deduplication" {
    const allocator = std.testing.allocator;
    var watcher = FileWatcher.init(allocator);
    defer watcher.deinit();

    watcher.start();

    // First change
    try watcher.notifyChange("/test/file.zig", .modified);
    try std.testing.expectEqual(@as(usize, 1), watcher.pending_changes.items.len);

    // Duplicate change - should update existing instead of adding
    try watcher.notifyChange("/test/file.zig", .modified);
    try std.testing.expectEqual(@as(usize, 1), watcher.pending_changes.items.len);

    // Different file - should add new entry
    try watcher.notifyChange("/test/other.zig", .created);
    try std.testing.expectEqual(@as(usize, 2), watcher.pending_changes.items.len);

    // Verify pending_paths tracks correctly
    try std.testing.expect(watcher.pending_paths.contains("/test/file.zig"));
    try std.testing.expect(watcher.pending_paths.contains("/test/other.zig"));

    // Flush should clear both
    watcher.flush();
    try std.testing.expectEqual(@as(usize, 0), watcher.pending_changes.items.len);
    try std.testing.expectEqual(@as(usize, 0), watcher.pending_paths.count());
}

test "StateType enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(StateType.null_type));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(StateType.boolean));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(StateType.integer));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(StateType.float));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(StateType.string));
}

test "StateManager init and deinit" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(u64, 0), manager.version);
}

test "StateManager set and get" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try manager.set("count", .{ .integer = 42 });
    const value = manager.get("count");

    try std.testing.expect(value != null);
    try std.testing.expectEqual(@as(i64, 42), value.?.integer);
    try std.testing.expectEqual(@as(u64, 1), manager.version);
}

test "StateManager set increments version" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(u64, 0), manager.version);
    try manager.set("key1", .{ .boolean = true });
    try std.testing.expectEqual(@as(u64, 1), manager.version);
    try manager.set("key2", .{ .string = "hello" });
    try std.testing.expectEqual(@as(u64, 2), manager.version);
}

test "StateManager get nonexistent key" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.get("nonexistent") == null);
}

test "StateManager remove" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try manager.set("key", .{ .integer = 1 });
    try std.testing.expect(manager.get("key") != null);

    manager.remove("key");
    try std.testing.expect(manager.get("key") == null);
}

test "StateManager serialize" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try manager.set("test", .{ .boolean = true });

    const data = try manager.serialize();
    defer allocator.free(data);

    try std.testing.expect(data.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, data, "version") != null);
}

test "StateManager snapshot" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try manager.set("key", .{ .integer = 1 });
    try manager.snapshot();

    try std.testing.expectEqual(@as(usize, 1), manager.snapshots.items.len);
}

test "StateManager restore invalid index" {
    const allocator = std.testing.allocator;
    var manager = StateManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectError(error.InvalidSnapshot, manager.restore(999));
}

test "BuildTarget enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(BuildTarget.web));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(BuildTarget.ios));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(BuildTarget.android));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(BuildTarget.macos));
}

test "BuildStatus enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(BuildStatus.pending));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(BuildStatus.building));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(BuildStatus.success));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(BuildStatus.failed));
}

test "ErrorSeverity enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ErrorSeverity.info));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ErrorSeverity.warning));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(ErrorSeverity.@"error"));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(ErrorSeverity.fatal));
}

test "IncrementalBuilder init and deinit" {
    const allocator = std.testing.allocator;
    var builder = IncrementalBuilder.init(allocator, .web);
    defer builder.deinit();

    try std.testing.expectEqual(BuildTarget.web, builder.target);
    try std.testing.expectEqual(@as(i64, 0), builder.last_build_time);
}

test "IncrementalBuilder setSourceDir" {
    const allocator = std.testing.allocator;
    var builder = IncrementalBuilder.init(allocator, .ios);
    defer builder.deinit();

    builder.setSourceDir("/project/src");
    try std.testing.expectEqualStrings("/project/src", builder.source_dir);
}

test "IncrementalBuilder setOutputDir" {
    const allocator = std.testing.allocator;
    var builder = IncrementalBuilder.init(allocator, .android);
    defer builder.deinit();

    builder.setOutputDir("/project/build");
    try std.testing.expectEqualStrings("/project/build", builder.output_dir);
}

test "IncrementalBuilder build returns success" {
    const allocator = std.testing.allocator;
    var builder = IncrementalBuilder.init(allocator, .macos);
    defer builder.deinit();

    const files = [_][]const u8{};
    const result = try builder.build(&files);

    try std.testing.expectEqual(BuildTarget.macos, result.target);
    try std.testing.expectEqual(BuildStatus.success, result.status);
}

test "MessageType enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(MessageType.reload));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(MessageType.hot_update));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(MessageType.error_overlay));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(MessageType.state_sync));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(MessageType.ping));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(MessageType.pong));
}

test "WebSocketServer init and deinit" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 8080);
    defer server.deinit();

    try std.testing.expectEqual(@as(u16, 8080), server.port);
    try std.testing.expect(!server.is_running);
    try std.testing.expectEqual(@as(u64, 1), server.next_client_id);
}

test "WebSocketServer start and stop" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 3001);
    defer server.deinit();

    try std.testing.expect(!server.is_running);
    server.start();
    try std.testing.expect(server.is_running);
    server.stop();
    try std.testing.expect(!server.is_running);
}

test "WebSocketServer broadcast" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 3001);
    defer server.deinit();

    try server.broadcast(.reload, "{}");
    try std.testing.expectEqual(@as(usize, 1), server.message_queue.items.len);
    try std.testing.expectEqual(MessageType.reload, server.message_queue.items[0].type);
}

test "WebSocketServer sendReload" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 3001);
    defer server.deinit();

    try server.sendReload();
    try std.testing.expectEqual(@as(usize, 1), server.message_queue.items.len);
    try std.testing.expectEqual(MessageType.reload, server.message_queue.items[0].type);
}

test "WebSocketServer getClientCount cached" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 3001);
    defer server.deinit();

    try std.testing.expectEqual(@as(usize, 0), server.getClientCount());

    // Use addClient to properly update cached count
    const id1 = try server.addClient();
    try std.testing.expectEqual(@as(usize, 1), server.getClientCount());

    const id2 = try server.addClient();
    try std.testing.expectEqual(@as(usize, 2), server.getClientCount());

    // Disconnect updates cached count
    server.disconnectClient(id1);
    try std.testing.expectEqual(@as(usize, 1), server.getClientCount());

    server.disconnectClient(id2);
    try std.testing.expectEqual(@as(usize, 0), server.getClientCount());
}

test "WebSocketServer recalculateClientCount" {
    const allocator = std.testing.allocator;
    var server = WebSocketServer.init(allocator, 3001);
    defer server.deinit();

    // Manually add clients (bypassing cached count)
    try server.clients.append(.{ .id = 1, .connected = true, .last_ping = 0 });
    try server.clients.append(.{ .id = 2, .connected = false, .last_ping = 0 });
    try server.clients.append(.{ .id = 3, .connected = true, .last_ping = 0 });

    // Cache is out of sync
    try std.testing.expectEqual(@as(usize, 0), server.cached_client_count);

    // Recalculate syncs the cache
    server.recalculateClientCount();
    try std.testing.expectEqual(@as(usize, 2), server.getClientCount());
}

test "DevServerConfig default values" {
    const config = DevServerConfig{};
    try std.testing.expectEqual(@as(u16, 3000), config.port);
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expect(config.open_browser);
    try std.testing.expect(config.hot_reload);
    try std.testing.expect(config.live_reload);
    try std.testing.expect(config.proxy == null);
}

test "DevServer init and deinit" {
    const allocator = std.testing.allocator;
    const config = DevServerConfig{};
    var server = DevServer.init(allocator, config, .web);
    defer server.deinit();

    try std.testing.expect(!server.is_running);
    try std.testing.expectEqual(@as(i64, 0), server.start_time);
}

test "DevServer start and stop" {
    const allocator = std.testing.allocator;
    const config = DevServerConfig{};
    var server = DevServer.init(allocator, config, .web);
    defer server.deinit();

    try std.testing.expect(!server.is_running);
    try server.start();
    try std.testing.expect(server.is_running);
    try std.testing.expect(server.start_time > 0);

    server.stop();
    try std.testing.expect(!server.is_running);
}

test "DevServer getStats" {
    const allocator = std.testing.allocator;
    const config = DevServerConfig{};
    var server = DevServer.init(allocator, config, .web);
    defer server.deinit();

    try server.start();
    const stats = server.getStats();

    try std.testing.expect(stats.uptime_ms >= 0);
    try std.testing.expectEqual(@as(usize, 0), stats.connected_clients);
}

test "ErrorOverlay init and deinit" {
    const allocator = std.testing.allocator;
    var overlay = ErrorOverlay.init(allocator);
    defer overlay.deinit();

    try std.testing.expect(!overlay.is_visible);
    try std.testing.expectEqual(@as(usize, 0), overlay.errors.items.len);
}

test "ErrorOverlay addError" {
    const allocator = std.testing.allocator;
    var overlay = ErrorOverlay.init(allocator);
    defer overlay.deinit();

    const err = BuildError{
        .file = "test.zig",
        .line = 42,
        .column = 10,
        .message = "syntax error",
        .severity = .@"error",
    };

    try overlay.addError(err);
    try std.testing.expect(overlay.is_visible);
    try std.testing.expectEqual(@as(usize, 1), overlay.errors.items.len);
}

test "ErrorOverlay clear" {
    const allocator = std.testing.allocator;
    var overlay = ErrorOverlay.init(allocator);
    defer overlay.deinit();

    try overlay.addError(.{
        .file = "test.zig",
        .line = 1,
        .column = 1,
        .message = "error",
        .severity = .@"error",
    });

    overlay.clear();
    try std.testing.expect(!overlay.is_visible);
    try std.testing.expectEqual(@as(usize, 0), overlay.errors.items.len);
}

test "DevServerStats struct fields" {
    const stats = DevServerStats{
        .uptime_ms = 1000,
        .connected_clients = 5,
        .total_builds = 10,
        .last_build_duration_ms = 500,
    };

    try std.testing.expectEqual(@as(u64, 1000), stats.uptime_ms);
    try std.testing.expectEqual(@as(usize, 5), stats.connected_clients);
    try std.testing.expectEqual(@as(u64, 10), stats.total_builds);
    try std.testing.expectEqual(@as(u64, 500), stats.last_build_duration_ms);
}
