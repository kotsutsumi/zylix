//! Error Boundary Components
//!
//! Error isolation and recovery system for graceful degradation
//! when components fail during rendering or event handling.

const std = @import("std");

/// Error severity levels
pub const Severity = enum {
    /// Informational, no action needed
    info,
    /// Warning, may affect functionality
    warning,
    /// Error, functionality impaired
    @"error",
    /// Critical, component cannot render
    critical,
    /// Fatal, application should terminate
    fatal,
};

/// Error context information
pub const ErrorContext = struct {
    /// Error message
    message: []const u8,
    /// Error severity
    severity: Severity,
    /// Component path where error occurred
    component_path: ?[]const u8,
    /// Stack trace if available
    stack_trace: ?[]const u8,
    /// Timestamp when error occurred
    timestamp: i64,
    /// Additional metadata
    metadata: ?std.json.Value,

    pub fn init(message: []const u8, severity: Severity) ErrorContext {
        return .{
            .message = message,
            .severity = severity,
            .component_path = null,
            .stack_trace = null,
            .timestamp = std.time.milliTimestamp(),
            .metadata = null,
        };
    }

    pub fn withComponentPath(self: ErrorContext, path: []const u8) ErrorContext {
        var ctx = self;
        ctx.component_path = path;
        return ctx;
    }

    pub fn withStackTrace(self: ErrorContext, trace: []const u8) ErrorContext {
        var ctx = self;
        ctx.stack_trace = trace;
        return ctx;
    }
};

/// Error handler callback type
pub const ErrorHandler = *const fn (*const ErrorContext) void;

/// Fallback renderer callback type
pub const FallbackRenderer = *const fn (*const ErrorContext) ?[]const u8;

/// Error boundary for isolating component failures
pub const ErrorBoundary = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    has_error: bool,
    error_context: ?ErrorContext,
    error_handler: ?ErrorHandler,
    fallback_renderer: ?FallbackRenderer,
    children_errors: std.ArrayListUnmanaged(ErrorContext),
    max_retries: u32,
    retry_count: u32,
    /// Count of errors that could not be tracked due to allocation failure
    dropped_errors: u64,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*ErrorBoundary {
        const boundary = try allocator.create(ErrorBoundary);
        boundary.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .has_error = false,
            .error_context = null,
            .error_handler = null,
            .fallback_renderer = null,
            .children_errors = .{},
            .max_retries = 3,
            .retry_count = 0,
            .dropped_errors = 0,
        };
        return boundary;
    }

    pub fn deinit(self: *ErrorBoundary) void {
        self.children_errors.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Set error handler
    pub fn onError(self: *ErrorBoundary, handler: ErrorHandler) *ErrorBoundary {
        self.error_handler = handler;
        return self;
    }

    /// Set fallback renderer
    pub fn fallback(self: *ErrorBoundary, renderer: FallbackRenderer) *ErrorBoundary {
        self.fallback_renderer = renderer;
        return self;
    }

    /// Set max retries
    pub fn withMaxRetries(self: *ErrorBoundary, max: u32) *ErrorBoundary {
        self.max_retries = max;
        return self;
    }

    /// Catch an error
    pub fn catchError(self: *ErrorBoundary, context: ErrorContext) void {
        self.has_error = true;
        self.error_context = context;

        // Notify handler
        if (self.error_handler) |handler| {
            handler(&context);
        }

        // Track child errors (increment dropped_errors counter on allocation failure)
        self.children_errors.append(self.allocator, context) catch {
            self.dropped_errors += 1;
        };
    }

    /// Try to recover from error
    pub fn tryRecover(self: *ErrorBoundary) bool {
        if (!self.has_error) return true;

        if (self.retry_count < self.max_retries) {
            self.retry_count += 1;
            self.has_error = false;
            self.error_context = null;
            return true;
        }

        return false;
    }

    /// Reset error state
    pub fn reset(self: *ErrorBoundary) void {
        self.has_error = false;
        self.error_context = null;
        self.retry_count = 0;
        self.dropped_errors = 0;
        self.children_errors.clearRetainingCapacity();
    }

    /// Get count of dropped errors (errors lost due to allocation failure)
    pub fn getDroppedErrors(self: *const ErrorBoundary) u64 {
        return self.dropped_errors;
    }

    /// Render fallback content
    pub fn renderFallback(self: *const ErrorBoundary) ?[]const u8 {
        if (self.fallback_renderer) |renderer| {
            if (self.error_context) |ctx| {
                return renderer(&ctx);
            }
        }
        return null;
    }

    /// Get error summary
    pub fn getErrorSummary(self: *const ErrorBoundary) ErrorSummary {
        return .{
            .boundary_name = self.name,
            .has_error = self.has_error,
            .error_count = self.children_errors.items.len,
            .retry_count = self.retry_count,
            .max_retries = self.max_retries,
        };
    }

    pub const ErrorSummary = struct {
        boundary_name: []const u8,
        has_error: bool,
        error_count: usize,
        retry_count: u32,
        max_retries: u32,
    };
};

/// Error recovery strategies
pub const RecoveryStrategy = enum {
    /// Retry the failed operation
    retry,
    /// Skip the failed component
    skip,
    /// Render fallback content
    fallback,
    /// Propagate error to parent
    propagate,
    /// Ignore error and continue
    ignore,
};

/// Error recovery system
pub const ErrorRecovery = struct {
    allocator: std.mem.Allocator,
    strategies: std.AutoHashMap(Severity, RecoveryStrategy),
    global_handler: ?ErrorHandler,
    error_log: std.ArrayListUnmanaged(ErrorContext),
    max_log_size: usize,

    pub fn init(allocator: std.mem.Allocator) !*ErrorRecovery {
        const recovery = try allocator.create(ErrorRecovery);
        recovery.* = .{
            .allocator = allocator,
            .strategies = std.AutoHashMap(Severity, RecoveryStrategy).init(allocator),
            .global_handler = null,
            .error_log = .{},
            .max_log_size = 100,
        };

        // Set default strategies
        try recovery.strategies.put(.info, .ignore);
        try recovery.strategies.put(.warning, .ignore);
        try recovery.strategies.put(.@"error", .fallback);
        try recovery.strategies.put(.critical, .propagate);
        try recovery.strategies.put(.fatal, .propagate);

        return recovery;
    }

    pub fn deinit(self: *ErrorRecovery) void {
        self.strategies.deinit();
        self.error_log.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Set recovery strategy for severity
    pub fn setStrategy(self: *ErrorRecovery, severity: Severity, strategy: RecoveryStrategy) !void {
        try self.strategies.put(severity, strategy);
    }

    /// Set global error handler
    pub fn setGlobalHandler(self: *ErrorRecovery, handler: ErrorHandler) void {
        self.global_handler = handler;
    }

    /// Handle an error
    pub fn handleError(self: *ErrorRecovery, context: ErrorContext) RecoveryStrategy {
        // Log error
        if (self.error_log.items.len >= self.max_log_size) {
            _ = self.error_log.orderedRemove(0);
        }
        self.error_log.append(self.allocator, context) catch {};

        // Notify global handler
        if (self.global_handler) |handler| {
            handler(&context);
        }

        // Return appropriate strategy
        return self.strategies.get(context.severity) orelse .propagate;
    }

    /// Get error log
    pub fn getErrorLog(self: *const ErrorRecovery) []const ErrorContext {
        return self.error_log.items;
    }

    /// Clear error log
    pub fn clearLog(self: *ErrorRecovery) void {
        self.error_log.clearRetainingCapacity();
    }

    /// Get error count by severity
    pub fn countBySeverity(self: *const ErrorRecovery, severity: Severity) usize {
        var count: usize = 0;
        for (self.error_log.items) |ctx| {
            if (ctx.severity == severity) count += 1;
        }
        return count;
    }
};

/// Safe execution wrapper
pub fn safeExecute(comptime T: type, func: *const fn () T, boundary: *ErrorBoundary) ?T {
    return func() catch |err| {
        boundary.catchError(ErrorContext.init(@errorName(err), .@"error"));
        return null;
    };
}

/// Safe execution with error context
pub fn safeExecuteWithContext(comptime T: type, func: *const fn () T, boundary: *ErrorBoundary, component_path: []const u8) ?T {
    return func() catch |err| {
        boundary.catchError(
            ErrorContext.init(@errorName(err), .@"error").withComponentPath(component_path),
        );
        return null;
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "ErrorContext creation" {
    const ctx = ErrorContext.init("Test error", .@"error");

    try std.testing.expectEqualStrings("Test error", ctx.message);
    try std.testing.expectEqual(Severity.@"error", ctx.severity);
    try std.testing.expect(ctx.timestamp > 0);
}

test "ErrorContext with path" {
    const ctx = ErrorContext.init("Test error", .warning).withComponentPath("App.Header.Logo");

    try std.testing.expectEqualStrings("App.Header.Logo", ctx.component_path.?);
}

test "ErrorBoundary basic usage" {
    const allocator = std.testing.allocator;

    var boundary = try ErrorBoundary.init(allocator, "TestBoundary");
    defer boundary.deinit();

    try std.testing.expect(!boundary.has_error);

    boundary.catchError(ErrorContext.init("Test error", .@"error"));
    try std.testing.expect(boundary.has_error);
    try std.testing.expect(boundary.error_context != null);
}

test "ErrorBoundary recovery" {
    const allocator = std.testing.allocator;

    var boundary = try ErrorBoundary.init(allocator, "TestBoundary");
    defer boundary.deinit();

    _ = boundary.withMaxRetries(2);

    boundary.catchError(ErrorContext.init("Error 1", .@"error"));
    try std.testing.expect(boundary.tryRecover());
    try std.testing.expectEqual(@as(u32, 1), boundary.retry_count);

    boundary.catchError(ErrorContext.init("Error 2", .@"error"));
    try std.testing.expect(boundary.tryRecover());
    try std.testing.expectEqual(@as(u32, 2), boundary.retry_count);

    boundary.catchError(ErrorContext.init("Error 3", .@"error"));
    try std.testing.expect(!boundary.tryRecover()); // Max retries exceeded
}

test "ErrorBoundary reset" {
    const allocator = std.testing.allocator;

    var boundary = try ErrorBoundary.init(allocator, "TestBoundary");
    defer boundary.deinit();

    boundary.catchError(ErrorContext.init("Error", .@"error"));
    try std.testing.expect(boundary.has_error);

    boundary.reset();
    try std.testing.expect(!boundary.has_error);
    try std.testing.expectEqual(@as(u32, 0), boundary.retry_count);
}

test "ErrorRecovery default strategies" {
    const allocator = std.testing.allocator;

    var recovery = try ErrorRecovery.init(allocator);
    defer recovery.deinit();

    try std.testing.expectEqual(RecoveryStrategy.ignore, recovery.strategies.get(.info).?);
    try std.testing.expectEqual(RecoveryStrategy.fallback, recovery.strategies.get(.@"error").?);
    try std.testing.expectEqual(RecoveryStrategy.propagate, recovery.strategies.get(.fatal).?);
}

test "ErrorRecovery handle error" {
    const allocator = std.testing.allocator;

    var recovery = try ErrorRecovery.init(allocator);
    defer recovery.deinit();

    const ctx = ErrorContext.init("Test error", .@"error");
    const strategy = recovery.handleError(ctx);

    try std.testing.expectEqual(RecoveryStrategy.fallback, strategy);
    try std.testing.expectEqual(@as(usize, 1), recovery.error_log.items.len);
}

test "ErrorRecovery count by severity" {
    const allocator = std.testing.allocator;

    var recovery = try ErrorRecovery.init(allocator);
    defer recovery.deinit();

    _ = recovery.handleError(ErrorContext.init("Error 1", .@"error"));
    _ = recovery.handleError(ErrorContext.init("Error 2", .@"error"));
    _ = recovery.handleError(ErrorContext.init("Warning", .warning));

    try std.testing.expectEqual(@as(usize, 2), recovery.countBySeverity(.@"error"));
    try std.testing.expectEqual(@as(usize, 1), recovery.countBySeverity(.warning));
}
