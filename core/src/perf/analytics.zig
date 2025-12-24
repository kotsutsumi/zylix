//! Analytics and Crash Reporting
//!
//! Performance analytics, crash reporting, and A/B testing support
//! for production applications.

const std = @import("std");

/// Event types for analytics
pub const EventType = enum {
    /// Page/screen view
    page_view,
    /// User action (click, tap, etc.)
    user_action,
    /// Performance metric
    performance,
    /// Error/crash
    @"error",
    /// Custom event
    custom,
};

/// Analytics event
pub const AnalyticsEvent = struct {
    event_type: EventType,
    name: []const u8,
    timestamp: i64,
    properties: ?std.json.Value,
    user_id: ?[]const u8,
    session_id: ?[]const u8,
    /// Numeric value for performance metrics (nanoseconds)
    metric_value_ns: ?u64,

    pub fn init(event_type: EventType, name: []const u8) AnalyticsEvent {
        return .{
            .event_type = event_type,
            .name = name,
            .timestamp = std.time.milliTimestamp(),
            .properties = null,
            .user_id = null,
            .session_id = null,
            .metric_value_ns = null,
        };
    }

    pub fn initWithMetric(event_type: EventType, name: []const u8, value_ns: u64) AnalyticsEvent {
        return .{
            .event_type = event_type,
            .name = name,
            .timestamp = std.time.milliTimestamp(),
            .properties = null,
            .user_id = null,
            .session_id = null,
            .metric_value_ns = value_ns,
        };
    }

    pub fn withProperties(self: AnalyticsEvent, props: std.json.Value) AnalyticsEvent {
        var event = self;
        event.properties = props;
        return event;
    }

    pub fn withUserId(self: AnalyticsEvent, user_id: []const u8) AnalyticsEvent {
        var event = self;
        event.user_id = user_id;
        return event;
    }
};

/// Analytics hook for custom tracking
pub const AnalyticsHook = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayListUnmanaged(AnalyticsEvent),
    handlers: std.ArrayListUnmanaged(*const fn (*const AnalyticsEvent) void),
    session_id: []const u8,
    user_id: ?[]const u8,
    enabled: bool,
    batch_size: usize,
    flush_interval_ms: u64,
    last_flush: i64,

    pub fn init(allocator: std.mem.Allocator) !*AnalyticsHook {
        const hook = try allocator.create(AnalyticsHook);
        hook.* = .{
            .allocator = allocator,
            .events = .{},
            .handlers = .{},
            .session_id = try generateSessionId(allocator),
            .user_id = null,
            .enabled = true,
            .batch_size = 50,
            .flush_interval_ms = 30000,
            .last_flush = std.time.milliTimestamp(),
        };
        return hook;
    }

    pub fn deinit(self: *AnalyticsHook) void {
        self.events.deinit(self.allocator);
        self.handlers.deinit(self.allocator);
        self.allocator.free(self.session_id);
        if (self.user_id) |id| self.allocator.free(id);
        self.allocator.destroy(self);
    }

    fn generateSessionId(allocator: std.mem.Allocator) ![]const u8 {
        var buf: [32]u8 = undefined;
        const timestamp = std.time.milliTimestamp();
        const result = std.fmt.bufPrint(&buf, "{x}", .{@as(u64, @intCast(timestamp))}) catch return allocator.dupe(u8, "session");
        return try allocator.dupe(u8, result);
    }

    /// Set user ID
    pub fn setUserId(self: *AnalyticsHook, user_id: []const u8) !void {
        if (self.user_id) |old| self.allocator.free(old);
        self.user_id = try self.allocator.dupe(u8, user_id);
    }

    /// Add event handler
    pub fn addHandler(self: *AnalyticsHook, handler: *const fn (*const AnalyticsEvent) void) !void {
        try self.handlers.append(self.allocator, handler);
    }

    /// Track event
    pub fn track(self: *AnalyticsHook, event: AnalyticsEvent) !void {
        if (!self.enabled) return;

        var tracked = event;
        tracked.session_id = self.session_id;
        tracked.user_id = self.user_id;

        try self.events.append(self.allocator, tracked);

        // Notify handlers
        for (self.handlers.items) |handler| {
            handler(&tracked);
        }

        // Auto-flush if needed
        if (self.events.items.len >= self.batch_size) {
            try self.flush();
        }
    }

    /// Track page view
    pub fn trackPageView(self: *AnalyticsHook, page_name: []const u8) !void {
        try self.track(AnalyticsEvent.init(.page_view, page_name));
    }

    /// Track user action
    pub fn trackAction(self: *AnalyticsHook, action_name: []const u8) !void {
        try self.track(AnalyticsEvent.init(.user_action, action_name));
    }

    /// Track performance metric
    pub fn trackPerformance(self: *AnalyticsHook, metric_name: []const u8, value_ns: u64) !void {
        try self.track(AnalyticsEvent.initWithMetric(.performance, metric_name, value_ns));
    }

    /// Flush events
    pub fn flush(self: *AnalyticsHook) !void {
        // In production, this would send events to analytics service
        self.events.clearRetainingCapacity();
        self.last_flush = std.time.milliTimestamp();
    }

    /// Enable/disable analytics
    pub fn setEnabled(self: *AnalyticsHook, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Get event count
    pub fn eventCount(self: *const AnalyticsHook) usize {
        return self.events.items.len;
    }
};

/// Crash report data
pub const CrashReport = struct {
    /// Error message (owned)
    message: []const u8,
    /// Stack trace (owned)
    stack_trace: ?[]const u8,
    /// Timestamp
    timestamp: i64,
    /// App version
    app_version: ?[]const u8,
    /// Platform info
    platform: ?[]const u8,
    /// User ID if available
    user_id: ?[]const u8,
    /// Session ID
    session_id: ?[]const u8,
    /// Custom data
    custom_data: ?std.json.Value,
    /// Breadcrumbs (recent actions)
    breadcrumbs: []const Breadcrumb,
    /// Whether message/stack_trace are owned (need freeing)
    owns_strings: bool,

    pub const Breadcrumb = struct {
        timestamp: i64,
        message: []const u8,
        category: []const u8,
        /// Whether strings are owned
        owns_strings: bool,
    };

    pub fn init(message: []const u8) CrashReport {
        return .{
            .message = message,
            .stack_trace = null,
            .timestamp = std.time.milliTimestamp(),
            .app_version = null,
            .platform = null,
            .user_id = null,
            .session_id = null,
            .custom_data = null,
            .breadcrumbs = &.{},
            .owns_strings = false,
        };
    }

    pub fn initOwned(allocator: std.mem.Allocator, message: []const u8) !CrashReport {
        return .{
            .message = try allocator.dupe(u8, message),
            .stack_trace = null,
            .timestamp = std.time.milliTimestamp(),
            .app_version = null,
            .platform = null,
            .user_id = null,
            .session_id = null,
            .custom_data = null,
            .breadcrumbs = &.{},
            .owns_strings = true,
        };
    }

    pub fn deinitStrings(self: *CrashReport, allocator: std.mem.Allocator) void {
        if (self.owns_strings) {
            allocator.free(self.message);
            if (self.stack_trace) |trace| allocator.free(trace);
        }
    }
};

/// Crash reporter for error tracking
pub const CrashReporter = struct {
    allocator: std.mem.Allocator,
    reports: std.ArrayListUnmanaged(CrashReport),
    breadcrumbs: std.ArrayListUnmanaged(CrashReport.Breadcrumb),
    max_breadcrumbs: usize,
    handlers: std.ArrayListUnmanaged(*const fn (*const CrashReport) void),
    app_version: ?[]const u8,
    enabled: bool,

    pub fn init(allocator: std.mem.Allocator) !*CrashReporter {
        const reporter = try allocator.create(CrashReporter);
        reporter.* = .{
            .allocator = allocator,
            .reports = .{},
            .breadcrumbs = .{},
            .max_breadcrumbs = 50,
            .handlers = .{},
            .app_version = null,
            .enabled = true,
        };
        return reporter;
    }

    pub fn deinit(self: *CrashReporter) void {
        // Free owned strings in reports
        for (self.reports.items) |*report| {
            report.deinitStrings(self.allocator);
        }
        self.reports.deinit(self.allocator);
        // Free owned strings in breadcrumbs
        for (self.breadcrumbs.items) |bc| {
            if (bc.owns_strings) {
                self.allocator.free(bc.message);
                self.allocator.free(bc.category);
            }
        }
        self.breadcrumbs.deinit(self.allocator);
        self.handlers.deinit(self.allocator);
        if (self.app_version) |v| self.allocator.free(v);
        self.allocator.destroy(self);
    }

    /// Set app version
    pub fn setAppVersion(self: *CrashReporter, version: []const u8) !void {
        if (self.app_version) |old| self.allocator.free(old);
        self.app_version = try self.allocator.dupe(u8, version);
    }

    /// Add crash handler
    pub fn addHandler(self: *CrashReporter, handler: *const fn (*const CrashReport) void) !void {
        try self.handlers.append(self.allocator, handler);
    }

    /// Add breadcrumb
    pub fn addBreadcrumb(self: *CrashReporter, message: []const u8, category: []const u8) !void {
        if (self.breadcrumbs.items.len >= self.max_breadcrumbs) {
            const removed = self.breadcrumbs.orderedRemove(0);
            if (removed.owns_strings) {
                self.allocator.free(removed.message);
                self.allocator.free(removed.category);
            }
        }

        const duped_message = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(duped_message);
        const duped_category = try self.allocator.dupe(u8, category);

        try self.breadcrumbs.append(self.allocator, .{
            .timestamp = std.time.milliTimestamp(),
            .message = duped_message,
            .category = duped_category,
            .owns_strings = true,
        });
    }

    /// Report crash
    pub fn reportCrash(self: *CrashReporter, message: []const u8) !void {
        if (!self.enabled) return;

        var report = try CrashReport.initOwned(self.allocator, message);
        report.app_version = self.app_version;
        report.breadcrumbs = self.breadcrumbs.items;

        try self.reports.append(self.allocator, report);

        // Notify handlers
        for (self.handlers.items) |handler| {
            handler(&report);
        }
    }

    /// Report crash with stack trace
    pub fn reportCrashWithTrace(self: *CrashReporter, message: []const u8, stack_trace: []const u8) !void {
        if (!self.enabled) return;

        var report = try CrashReport.initOwned(self.allocator, message);
        report.stack_trace = try self.allocator.dupe(u8, stack_trace);
        report.app_version = self.app_version;
        report.breadcrumbs = self.breadcrumbs.items;

        try self.reports.append(self.allocator, report);

        for (self.handlers.items) |handler| {
            handler(&report);
        }
    }

    /// Get crash count
    pub fn crashCount(self: *const CrashReporter) usize {
        return self.reports.items.len;
    }

    /// Enable/disable crash reporting
    pub fn setEnabled(self: *CrashReporter, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Clear all reports
    pub fn clear(self: *CrashReporter) void {
        // Free owned strings in reports
        for (self.reports.items) |*report| {
            report.deinitStrings(self.allocator);
        }
        self.reports.clearRetainingCapacity();
        // Free owned strings in breadcrumbs
        for (self.breadcrumbs.items) |bc| {
            if (bc.owns_strings) {
                self.allocator.free(bc.message);
                self.allocator.free(bc.category);
            }
        }
        self.breadcrumbs.clearRetainingCapacity();
    }
};

/// A/B test variant
pub const Variant = struct {
    name: []const u8,
    weight: f64,
};

/// A/B testing support
pub const ABTest = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    variants: std.ArrayListUnmanaged(Variant),
    assignments: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*ABTest {
        const test_inst = try allocator.create(ABTest);
        test_inst.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .variants = .{},
            .assignments = std.StringHashMap([]const u8).init(allocator),
        };
        return test_inst;
    }

    pub fn deinit(self: *ABTest) void {
        self.variants.deinit(self.allocator);
        // Free duplicated strings in assignments
        var it = self.assignments.iterator();
        while (it.next()) |entry| {
            self.allocator.free(@constCast(entry.key_ptr.*));
            self.allocator.free(@constCast(entry.value_ptr.*));
        }
        self.assignments.deinit();
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Add variant
    pub fn addVariant(self: *ABTest, name: []const u8, weight: f64) !void {
        try self.variants.append(self.allocator, .{ .name = name, .weight = weight });
    }

    /// Get variant for user (deterministic based on user ID)
    pub fn getVariant(self: *ABTest, user_id: []const u8) ?[]const u8 {
        // Check cache
        if (self.assignments.get(user_id)) |variant| {
            return variant;
        }

        if (self.variants.items.len == 0) return null;

        // Hash user ID for deterministic assignment
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(user_id);
        hasher.update(self.name);
        const hash = hasher.final();

        // Convert to 0-1 range
        const value = @as(f64, @floatFromInt(hash % 10000)) / 10000.0;

        // Find variant based on weights
        var cumulative: f64 = 0.0;
        for (self.variants.items) |variant| {
            cumulative += variant.weight;
            if (value < cumulative) {
                return variant.name;
            }
        }

        return self.variants.items[self.variants.items.len - 1].name;
    }

    /// Force variant for user
    pub fn forceVariant(self: *ABTest, user_id: []const u8, variant: []const u8) !void {
        // Check if user already has an assignment and free it
        if (self.assignments.get(user_id)) |_| {
            const removed = self.assignments.fetchRemove(user_id);
            if (removed) |kv| {
                self.allocator.free(@constCast(kv.key));
                self.allocator.free(@constCast(kv.value));
            }
        }
        const duped_user = try self.allocator.dupe(u8, user_id);
        errdefer self.allocator.free(duped_user);
        const duped_variant = try self.allocator.dupe(u8, variant);
        try self.assignments.put(duped_user, duped_variant);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "AnalyticsEvent creation" {
    const event = AnalyticsEvent.init(.page_view, "home");

    try std.testing.expectEqual(EventType.page_view, event.event_type);
    try std.testing.expectEqualStrings("home", event.name);
    try std.testing.expect(event.timestamp > 0);
}

test "AnalyticsHook track events" {
    const allocator = std.testing.allocator;

    var hook = try AnalyticsHook.init(allocator);
    defer hook.deinit();

    try hook.trackPageView("home");
    try hook.trackAction("button_click");

    try std.testing.expectEqual(@as(usize, 2), hook.eventCount());
}

test "AnalyticsHook flush" {
    const allocator = std.testing.allocator;

    var hook = try AnalyticsHook.init(allocator);
    defer hook.deinit();

    try hook.trackPageView("home");
    try hook.flush();

    try std.testing.expectEqual(@as(usize, 0), hook.eventCount());
}

test "CrashReporter basic usage" {
    const allocator = std.testing.allocator;

    var reporter = try CrashReporter.init(allocator);
    defer reporter.deinit();

    try reporter.addBreadcrumb("User clicked button", "ui");
    try reporter.addBreadcrumb("API request started", "network");
    try reporter.reportCrash("Null pointer exception");

    try std.testing.expectEqual(@as(usize, 1), reporter.crashCount());
}

test "CrashReporter breadcrumbs" {
    const allocator = std.testing.allocator;

    var reporter = try CrashReporter.init(allocator);
    defer reporter.deinit();

    try reporter.addBreadcrumb("Action 1", "ui");
    try reporter.addBreadcrumb("Action 2", "network");

    try std.testing.expectEqual(@as(usize, 2), reporter.breadcrumbs.items.len);
}

test "ABTest variant assignment" {
    const allocator = std.testing.allocator;

    var ab_test = try ABTest.init(allocator, "button_color");
    defer ab_test.deinit();

    try ab_test.addVariant("red", 0.5);
    try ab_test.addVariant("blue", 0.5);

    // Same user should get same variant
    const variant1 = ab_test.getVariant("user123");
    const variant2 = ab_test.getVariant("user123");

    try std.testing.expect(variant1 != null);
    try std.testing.expectEqualStrings(variant1.?, variant2.?);
}

test "ABTest force variant" {
    const allocator = std.testing.allocator;

    var ab_test = try ABTest.init(allocator, "feature_test");
    defer ab_test.deinit();

    try ab_test.addVariant("control", 0.5);
    try ab_test.addVariant("treatment", 0.5);
    try ab_test.forceVariant("test_user", "treatment");

    const variant = ab_test.getVariant("test_user");
    try std.testing.expectEqualStrings("treatment", variant.?);
}
