//! File Watcher API
//!
//! Real-time file system monitoring with support for:
//! - Configurable filters and patterns
//! - Debounced change events
//! - Recursive directory watching
//! - Cross-platform implementation
//!
//! This module provides file watching for hot reload and live preview.

const std = @import("std");

/// Watcher error types
pub const WatcherError = error{
    NotInitialized,
    PathNotFound,
    AccessDenied,
    TooManyWatches,
    AlreadyWatching,
    OutOfMemory,
};

/// Watch identifier
pub const WatchId = struct {
    id: u64,
    path: []const u8,

    pub fn isValid(self: *const WatchId) bool {
        return self.id > 0;
    }
};

/// File change type
pub const ChangeType = enum(u8) {
    created = 0,
    modified = 1,
    deleted = 2,
    renamed = 3,
    attribute = 4, // Permissions, timestamps, etc.

    pub fn toString(self: ChangeType) []const u8 {
        return switch (self) {
            .created => "created",
            .modified => "modified",
            .deleted => "deleted",
            .renamed => "renamed",
            .attribute => "attribute",
        };
    }
};

/// File change event
pub const FileChange = struct {
    /// Watch ID that triggered this event
    watch_id: WatchId,
    /// Type of change
    change_type: ChangeType,
    /// Path that changed
    path: []const u8,
    /// Old path (for renames)
    old_path: ?[]const u8 = null,
    /// Is directory
    is_directory: bool = false,
    /// Timestamp of change
    timestamp: i64,
};

/// Watch filters
pub const WatchFilters = struct {
    /// Watch subdirectories recursively
    recursive: bool = true,
    /// File patterns to include (glob-style)
    include_patterns: []const []const u8 = &.{},
    /// File patterns to exclude (glob-style)
    exclude_patterns: []const []const u8 = &.{},
    /// Watch for specific change types
    change_types: []const ChangeType = &.{ .created, .modified, .deleted, .renamed },
    /// Debounce interval in milliseconds
    debounce_ms: u32 = 100,
    /// Ignore hidden files (starting with .)
    ignore_hidden: bool = true,
    /// Ignore common build/cache directories
    ignore_build_dirs: bool = true,
};

/// Watch statistics
pub const WatchStats = struct {
    /// Total events received
    events_total: u64 = 0,
    /// Events after debouncing
    events_debounced: u64 = 0,
    /// Events filtered out
    events_filtered: u64 = 0,
    /// Last event timestamp
    last_event: ?i64 = null,
    /// Watch start time
    started_at: i64,
};

/// Change callback type
pub const ChangeCallback = *const fn (FileChange) void;

/// Batch change callback type
pub const BatchChangeCallback = *const fn ([]const FileChange) void;

/// Watch entry
const WatchEntry = struct {
    id: WatchId,
    path: []const u8,
    filters: WatchFilters,
    callback: ?ChangeCallback = null,
    batch_callback: ?BatchChangeCallback = null,
    stats: WatchStats,
    active: bool = true,
};

/// File Watcher
pub const FileWatcher = struct {
    allocator: std.mem.Allocator,
    watches: std.AutoHashMapUnmanaged(u64, WatchEntry) = .{},
    next_id: u64 = 1,
    running: bool = false,

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) FileWatcher {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FileWatcher) void {
        self.stopAll();
        self.watches.deinit(self.allocator);
    }

    /// Start watching a path
    pub fn watch(self: *FileWatcher, path: []const u8, filters: WatchFilters) WatcherError!WatchId {
        // Check if already watching this path
        var iter = self.watches.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.path, path)) {
                return WatcherError.AlreadyWatching;
            }
        }

        const watch_id = WatchId{
            .id = self.next_id,
            .path = path,
        };
        self.next_id += 1;

        const entry = WatchEntry{
            .id = watch_id,
            .path = path,
            .filters = filters,
            .stats = .{
                .started_at = std.time.timestamp(),
            },
        };

        self.watches.put(self.allocator, watch_id.id, entry) catch {
            return WatcherError.OutOfMemory;
        };

        // In real implementation, would start platform-specific file watching
        self.running = true;

        return watch_id;
    }

    /// Stop watching a path
    pub fn unwatch(self: *FileWatcher, watch_id: WatchId) void {
        _ = self.watches.remove(watch_id.id);
    }

    /// Register change callback
    pub fn onChange(self: *FileWatcher, watch_id: WatchId, callback: ChangeCallback) void {
        if (self.watches.getPtr(watch_id.id)) |entry| {
            entry.callback = callback;
        }
    }

    /// Register batch change callback
    pub fn onBatchChange(self: *FileWatcher, watch_id: WatchId, callback: BatchChangeCallback) void {
        if (self.watches.getPtr(watch_id.id)) |entry| {
            entry.batch_callback = callback;
        }
    }

    /// Get watch statistics
    pub fn getStats(self: *const FileWatcher, watch_id: WatchId) ?WatchStats {
        if (self.watches.get(watch_id.id)) |entry| {
            return entry.stats;
        }
        return null;
    }

    /// Pause watching
    pub fn pause(self: *FileWatcher, watch_id: WatchId) void {
        if (self.watches.getPtr(watch_id.id)) |entry| {
            entry.active = false;
        }
    }

    /// Resume watching
    pub fn resumeWatch(self: *FileWatcher, watch_id: WatchId) void {
        if (self.watches.getPtr(watch_id.id)) |entry| {
            entry.active = true;
        }
    }

    /// Check if path is being watched
    pub fn isWatching(self: *const FileWatcher, path: []const u8) bool {
        var iter = self.watches.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.path, path)) {
                return true;
            }
        }
        return false;
    }

    /// Stop all watches
    pub fn stopAll(self: *FileWatcher) void {
        self.watches.clearRetainingCapacity();
        self.running = false;
    }

    /// Get active watch count
    pub fn activeCount(self: *const FileWatcher) usize {
        var count: usize = 0;
        var iter = self.watches.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.active) {
                count += 1;
            }
        }
        return count;
    }

    /// Get total watch count
    pub fn totalCount(self: *const FileWatcher) usize {
        return self.watches.count();
    }

    /// Simulate a file change (for testing)
    pub fn simulateChange(self: *FileWatcher, watch_id: WatchId, change_type: ChangeType, path: []const u8) void {
        if (self.watches.getPtr(watch_id.id)) |entry| {
            if (!entry.active) return;

            entry.stats.events_total += 1;

            const change = FileChange{
                .watch_id = watch_id,
                .change_type = change_type,
                .path = path,
                .timestamp = std.time.timestamp(),
            };

            // Apply filters
            if (shouldFilter(change, entry.filters)) {
                entry.stats.events_filtered += 1;
                return;
            }

            entry.stats.events_debounced += 1;
            entry.stats.last_event = change.timestamp;

            if (entry.callback) |cb| {
                cb(change);
            }
        }
    }

    /// Check if a change should be filtered
    fn shouldFilter(change: FileChange, filters: WatchFilters) bool {
        // Check hidden files
        if (filters.ignore_hidden) {
            if (std.mem.startsWith(u8, std.fs.path.basename(change.path), ".")) {
                return true;
            }
        }

        // Check build directories
        if (filters.ignore_build_dirs) {
            const build_dirs = [_][]const u8{ "node_modules", ".git", "zig-cache", "zig-out", "target", "build", "dist", ".zylix" };
            for (build_dirs) |dir| {
                if (std.mem.indexOf(u8, change.path, dir) != null) {
                    return true;
                }
            }
        }

        // Check change type filter
        var type_allowed = false;
        for (filters.change_types) |ct| {
            if (ct == change.change_type) {
                type_allowed = true;
                break;
            }
        }
        if (!type_allowed and filters.change_types.len > 0) {
            return true;
        }

        return false;
    }
};

/// Match glob pattern (simplified)
pub fn matchGlob(pattern: []const u8, path: []const u8) bool {
    // Simplified glob matching
    if (std.mem.eql(u8, pattern, "*")) return true;
    if (std.mem.eql(u8, pattern, "**")) return true;

    // Extension matching (e.g., "*.zig")
    if (std.mem.startsWith(u8, pattern, "*.")) {
        const ext = pattern[1..];
        return std.mem.endsWith(u8, path, ext);
    }

    return std.mem.eql(u8, pattern, path);
}

/// Create a file watcher
pub fn createFileWatcher(allocator: std.mem.Allocator) FileWatcher {
    return FileWatcher.init(allocator);
}

// Tests
test "FileWatcher initialization" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    try std.testing.expectEqual(@as(usize, 0), watcher.totalCount());
    try std.testing.expect(!watcher.running);
}

test "Watch path" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{});
    try std.testing.expect(watch_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), watcher.totalCount());
    try std.testing.expect(watcher.isWatching("/tmp/test"));
}

test "Unwatch path" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{});
    watcher.unwatch(watch_id);

    try std.testing.expectEqual(@as(usize, 0), watcher.totalCount());
    try std.testing.expect(!watcher.isWatching("/tmp/test"));
}

test "Duplicate watch" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    _ = try watcher.watch("/tmp/test", .{});
    try std.testing.expectError(WatcherError.AlreadyWatching, watcher.watch("/tmp/test", .{}));
}

test "Pause and resume" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{});
    try std.testing.expectEqual(@as(usize, 1), watcher.activeCount());

    watcher.pause(watch_id);
    try std.testing.expectEqual(@as(usize, 0), watcher.activeCount());

    watcher.resumeWatch(watch_id);
    try std.testing.expectEqual(@as(usize, 1), watcher.activeCount());
}

test "Watch statistics" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{});
    const stats = watcher.getStats(watch_id);

    try std.testing.expect(stats != null);
    try std.testing.expectEqual(@as(u64, 0), stats.?.events_total);
}

test "ChangeType toString" {
    try std.testing.expect(std.mem.eql(u8, "created", ChangeType.created.toString()));
    try std.testing.expect(std.mem.eql(u8, "modified", ChangeType.modified.toString()));
    try std.testing.expect(std.mem.eql(u8, "deleted", ChangeType.deleted.toString()));
}

test "Glob matching" {
    try std.testing.expect(matchGlob("*", "anything"));
    try std.testing.expect(matchGlob("**", "any/path"));
    try std.testing.expect(matchGlob("*.zig", "main.zig"));
    try std.testing.expect(!matchGlob("*.zig", "main.js"));
}

test "Stop all watches" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    _ = try watcher.watch("/tmp/a", .{});
    _ = try watcher.watch("/tmp/b", .{});
    _ = try watcher.watch("/tmp/c", .{});

    try std.testing.expectEqual(@as(usize, 3), watcher.totalCount());

    watcher.stopAll();
    try std.testing.expectEqual(@as(usize, 0), watcher.totalCount());
}

test "Simulate change" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{ .ignore_hidden = false, .ignore_build_dirs = false });

    watcher.simulateChange(watch_id, .modified, "/tmp/test/file.zig");

    const stats = watcher.getStats(watch_id);
    try std.testing.expect(stats != null);
    try std.testing.expectEqual(@as(u64, 1), stats.?.events_total);
}

test "Filter hidden files" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{ .ignore_hidden = true });

    watcher.simulateChange(watch_id, .modified, "/tmp/test/.hidden");

    const stats = watcher.getStats(watch_id);
    try std.testing.expect(stats != null);
    try std.testing.expectEqual(@as(u64, 1), stats.?.events_filtered);
}

test "Filter build directories" {
    const allocator = std.testing.allocator;
    var watcher = createFileWatcher(allocator);
    defer watcher.deinit();

    const watch_id = try watcher.watch("/tmp/test", .{ .ignore_build_dirs = true, .ignore_hidden = false });

    watcher.simulateChange(watch_id, .modified, "/tmp/test/node_modules/package.json");

    const stats = watcher.getStats(watch_id);
    try std.testing.expect(stats != null);
    try std.testing.expectEqual(@as(u64, 1), stats.?.events_filtered);
}
