// router.zig - Cross-platform routing system for Zylix v0.3.0
//
// Features:
// - Path patterns with parameters (/users/:id/posts)
// - Query parameter handling
// - Navigation history (back/forward)
// - Route guards (authentication, permissions)
// - Deep linking support
// - Nested routes

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Route Parameter Types
// ============================================================================

/// A single route parameter extracted from a URL path
pub const RouteParam = struct {
    name: []const u8,
    value: []const u8,
};

/// Query parameter key-value pair
pub const QueryParam = struct {
    key: []const u8,
    value: []const u8,
};

/// Parsed URL components
pub const ParsedUrl = struct {
    path: []const u8,
    params: []RouteParam,
    query: []QueryParam,
    fragment: ?[]const u8,

    pub fn getParam(self: *const ParsedUrl, name: []const u8) ?[]const u8 {
        for (self.params) |param| {
            if (std.mem.eql(u8, param.name, name)) {
                return param.value;
            }
        }
        return null;
    }

    pub fn getQuery(self: *const ParsedUrl, key: []const u8) ?[]const u8 {
        for (self.query) |q| {
            if (std.mem.eql(u8, q.key, key)) {
                return q.value;
            }
        }
        return null;
    }
};

// ============================================================================
// Route Guard Types
// ============================================================================

/// Result of a route guard check
pub const GuardResult = enum {
    allow,
    deny,
    redirect,
};

/// Route guard response with optional redirect path
pub const GuardResponse = struct {
    result: GuardResult,
    redirect_to: ?[]const u8 = null,
    message: ?[]const u8 = null,
};

/// Route guard function type
pub const GuardFn = *const fn (context: *RouteContext) GuardResponse;

/// Built-in guard that always allows
pub fn allowAll(_: *RouteContext) GuardResponse {
    return .{ .result = .allow };
}

/// Built-in guard that always denies
pub fn denyAll(_: *RouteContext) GuardResponse {
    return .{ .result = .deny, .message = "Access denied" };
}

// ============================================================================
// Route Context
// ============================================================================

/// Context passed to route handlers and guards
pub const RouteContext = struct {
    url: ParsedUrl,
    router: *Router,
    user_data: ?*anyopaque = null,

    /// Check if user is authenticated (to be set by platform)
    is_authenticated: bool = false,

    /// User roles for permission checking
    roles: []const []const u8 = &.{},

    pub fn hasRole(self: *const RouteContext, role: []const u8) bool {
        for (self.roles) |r| {
            if (std.mem.eql(u8, r, role)) {
                return true;
            }
        }
        return false;
    }
};

// ============================================================================
// Route Definition
// ============================================================================

/// Component handler function type
pub const ComponentFn = *const fn (context: *RouteContext) void;

/// A single route definition
pub const Route = struct {
    /// Path pattern (e.g., "/users/:id/posts")
    path: []const u8,

    /// Component handler function
    component: ?ComponentFn = null,

    /// Route guards to check before allowing access
    guards: []const GuardFn = &.{},

    /// Child routes for nested routing
    children: []const Route = &.{},

    /// Route metadata
    meta: RouteMeta = .{},

    /// Check if this route matches a given path
    pub fn matches(self: *const Route, path: []const u8, allocator: Allocator) !?[]RouteParam {
        return matchPattern(self.path, path, allocator);
    }
};

/// Route metadata
pub const RouteMeta = struct {
    title: ?[]const u8 = null,
    requires_auth: bool = false,
    permissions: []const []const u8 = &.{},
};

// ============================================================================
// Navigation History
// ============================================================================

/// Navigation history entry
pub const HistoryEntry = struct {
    path: []const u8,
    state: ?*anyopaque = null,
    timestamp: i64,
};

/// Navigation history stack
pub const History = struct {
    entries: std.ArrayList(HistoryEntry),
    current_index: i32 = -1,
    max_size: usize = 100,

    pub fn init(allocator: Allocator) History {
        return .{
            .entries = std.ArrayList(HistoryEntry).init(allocator),
        };
    }

    pub fn deinit(self: *History) void {
        self.entries.deinit();
    }

    pub fn push(self: *History, path: []const u8, state: ?*anyopaque) !void {
        // Remove forward history if we're not at the end
        if (self.current_index >= 0) {
            const idx: usize = @intCast(self.current_index + 1);
            if (idx < self.entries.items.len) {
                self.entries.shrinkRetainingCapacity(idx);
            }
        }

        // Enforce max size
        if (self.entries.items.len >= self.max_size) {
            _ = self.entries.orderedRemove(0);
            self.current_index -= 1;
        }

        try self.entries.append(.{
            .path = path,
            .state = state,
            .timestamp = std.time.timestamp(),
        });
        self.current_index += 1;
    }

    pub fn back(self: *History) ?*const HistoryEntry {
        if (self.current_index > 0) {
            self.current_index -= 1;
            return &self.entries.items[@intCast(self.current_index)];
        }
        return null;
    }

    pub fn forward(self: *History) ?*const HistoryEntry {
        const idx: usize = @intCast(self.current_index + 1);
        if (idx < self.entries.items.len) {
            self.current_index += 1;
            return &self.entries.items[@intCast(self.current_index)];
        }
        return null;
    }

    pub fn current(self: *const History) ?*const HistoryEntry {
        if (self.current_index >= 0 and self.current_index < @as(i32, @intCast(self.entries.items.len))) {
            return &self.entries.items[@intCast(self.current_index)];
        }
        return null;
    }

    pub fn canGoBack(self: *const History) bool {
        return self.current_index > 0;
    }

    pub fn canGoForward(self: *const History) bool {
        const idx: usize = @intCast(self.current_index + 1);
        return idx < self.entries.items.len;
    }

    pub fn length(self: *const History) usize {
        return self.entries.items.len;
    }
};

// ============================================================================
// Router
// ============================================================================

/// Navigation event type
pub const NavigationEvent = enum {
    push,
    replace,
    back,
    forward,
    deep_link,
};

/// Navigation callback type
pub const NavigationCallback = *const fn (event: NavigationEvent, path: []const u8, context: *RouteContext) void;

/// Router errors
pub const RouterError = error{
    RouteNotFound,
    NavigationBlocked,
    InvalidPath,
    OutOfMemory,
};

/// Main router struct
pub const Router = struct {
    allocator: Allocator,
    routes: []const Route,
    history: History,
    not_found_handler: ?ComponentFn = null,
    navigation_callbacks: std.ArrayList(NavigationCallback),
    base_path: []const u8 = "",
    current_context: ?RouteContext = null,

    /// Initialize a new router
    pub fn init(allocator: Allocator, routes: []const Route) Router {
        return .{
            .allocator = allocator,
            .routes = routes,
            .history = History.init(allocator),
            .navigation_callbacks = std.ArrayList(NavigationCallback).init(allocator),
        };
    }

    /// Deinitialize the router
    pub fn deinit(self: *Router) void {
        self.history.deinit();
        self.navigation_callbacks.deinit();
    }

    /// Set base path for all routes (e.g., "/app")
    pub fn setBasePath(self: *Router, base: []const u8) void {
        self.base_path = base;
    }

    /// Set the 404 not found handler
    pub fn setNotFoundHandler(self: *Router, handler: ComponentFn) void {
        self.not_found_handler = handler;
    }

    /// Add a navigation callback
    pub fn onNavigate(self: *Router, callback: NavigationCallback) !void {
        try self.navigation_callbacks.append(callback);
    }

    /// Navigate to a path (push to history)
    pub fn push(self: *Router, path: []const u8) RouterError!void {
        return self.navigate(path, .push);
    }

    /// Replace current path (no history entry)
    pub fn replace(self: *Router, path: []const u8) RouterError!void {
        return self.navigate(path, .replace);
    }

    /// Go back in history
    pub fn back(self: *Router) RouterError!void {
        if (self.history.back()) |entry| {
            return self.navigateToEntry(entry, .back);
        }
    }

    /// Go forward in history
    pub fn forward(self: *Router) RouterError!void {
        if (self.history.forward()) |entry| {
            return self.navigateToEntry(entry, .forward);
        }
    }

    /// Handle deep link from platform
    pub fn handleDeepLink(self: *Router, url: []const u8) RouterError!void {
        return self.navigate(url, .deep_link);
    }

    /// Check if can go back
    pub fn canGoBack(self: *const Router) bool {
        return self.history.canGoBack();
    }

    /// Check if can go forward
    pub fn canGoForward(self: *const Router) bool {
        return self.history.canGoForward();
    }

    /// Get current path
    pub fn currentPath(self: *const Router) ?[]const u8 {
        if (self.history.current()) |entry| {
            return entry.path;
        }
        return null;
    }

    /// Get current route context
    pub fn getContext(self: *const Router) ?RouteContext {
        return self.current_context;
    }

    // Internal navigation logic
    fn navigate(self: *Router, path: []const u8, event: NavigationEvent) RouterError!void {
        const full_path = if (self.base_path.len > 0)
            std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_path, path }) catch return RouterError.OutOfMemory
        else
            path;

        // Parse the URL
        const parsed = parseUrl(full_path, self.allocator) catch return RouterError.InvalidPath;

        // Find matching route
        const matched = self.findRoute(parsed.path) catch return RouterError.OutOfMemory;
        if (matched == null) {
            if (self.not_found_handler) |handler| {
                var context = RouteContext{
                    .url = parsed,
                    .router = self,
                };
                handler(&context);
            }
            return RouterError.RouteNotFound;
        }

        const route = matched.?;

        // Create context
        var context = RouteContext{
            .url = parsed,
            .router = self,
        };

        // Check guards
        for (route.guards) |guard| {
            const response = guard(&context);
            switch (response.result) {
                .allow => continue,
                .deny => return RouterError.NavigationBlocked,
                .redirect => {
                    if (response.redirect_to) |redirect_path| {
                        return self.replace(redirect_path);
                    }
                    return RouterError.NavigationBlocked;
                },
            }
        }

        // Update history
        if (event == .push or event == .deep_link) {
            self.history.push(path, null) catch return RouterError.OutOfMemory;
        }

        // Store current context
        self.current_context = context;

        // Call navigation callbacks
        for (self.navigation_callbacks.items) |callback| {
            callback(event, path, &context);
        }

        // Execute component handler
        if (route.component) |component| {
            component(&context);
        }
    }

    fn navigateToEntry(self: *Router, entry: *const HistoryEntry, event: NavigationEvent) RouterError!void {
        const parsed = parseUrl(entry.path, self.allocator) catch return RouterError.InvalidPath;

        const matched = self.findRoute(parsed.path) catch return RouterError.OutOfMemory;
        if (matched == null) {
            return RouterError.RouteNotFound;
        }

        var context = RouteContext{
            .url = parsed,
            .router = self,
        };

        self.current_context = context;

        for (self.navigation_callbacks.items) |callback| {
            callback(event, entry.path, &context);
        }

        if (matched.?.component) |component| {
            component(&context);
        }
    }

    fn findRoute(self: *Router, path: []const u8) !?*const Route {
        return findRouteRecursive(self.routes, path, "", self.allocator);
    }
};

// ============================================================================
// URL Parsing and Pattern Matching
// ============================================================================

/// Parse a URL into components
pub fn parseUrl(url: []const u8, allocator: Allocator) !ParsedUrl {
    var path: []const u8 = url;
    var fragment: ?[]const u8 = null;
    var query_string: ?[]const u8 = null;

    // Extract fragment
    if (std.mem.indexOf(u8, url, "#")) |hash_idx| {
        fragment = url[hash_idx + 1 ..];
        path = url[0..hash_idx];
    }

    // Extract query string
    if (std.mem.indexOf(u8, path, "?")) |query_idx| {
        query_string = path[query_idx + 1 ..];
        path = path[0..query_idx];
    }

    // Parse query parameters
    var query_params = std.ArrayList(QueryParam).init(allocator);
    if (query_string) |qs| {
        var iter = std.mem.splitScalar(u8, qs, '&');
        while (iter.next()) |pair| {
            if (std.mem.indexOf(u8, pair, "=")) |eq_idx| {
                try query_params.append(.{
                    .key = pair[0..eq_idx],
                    .value = pair[eq_idx + 1 ..],
                });
            }
        }
    }

    return ParsedUrl{
        .path = path,
        .params = &.{},
        .query = try query_params.toOwnedSlice(),
        .fragment = fragment,
    };
}

/// Match a path pattern against an actual path
pub fn matchPattern(pattern: []const u8, path: []const u8, allocator: Allocator) !?[]RouteParam {
    var params = std.ArrayList(RouteParam).init(allocator);

    var pattern_iter = std.mem.splitScalar(u8, pattern, '/');
    var path_iter = std.mem.splitScalar(u8, path, '/');

    while (true) {
        const pattern_part = pattern_iter.next();
        const path_part = path_iter.next();

        if (pattern_part == null and path_part == null) {
            // Both exhausted, match!
            return try params.toOwnedSlice();
        }

        if (pattern_part == null or path_part == null) {
            // One exhausted before the other, no match
            return null;
        }

        const pp = pattern_part.?;
        const actual = path_part.?;

        if (pp.len > 0 and pp[0] == ':') {
            // Parameter segment
            const param_name = pp[1..];
            try params.append(.{
                .name = param_name,
                .value = actual,
            });
        } else if (pp.len > 0 and pp[0] == '*') {
            // Wildcard - matches rest of path
            // For now, just match this segment
            try params.append(.{
                .name = if (pp.len > 1) pp[1..] else "wildcard",
                .value = actual,
            });
        } else if (!std.mem.eql(u8, pp, actual)) {
            // Literal segment doesn't match
            return null;
        }
    }
}

/// Find a route recursively (for nested routes)
fn findRouteRecursive(routes: []const Route, path: []const u8, prefix: []const u8, allocator: Allocator) !?*const Route {
    for (routes) |*route| {
        const full_pattern = if (prefix.len > 0)
            try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, route.path })
        else
            route.path;

        if (try matchPattern(full_pattern, path, allocator)) |_| {
            return route;
        }

        // Check children
        if (route.children.len > 0) {
            if (try findRouteRecursive(route.children, path, full_pattern, allocator)) |child| {
                return child;
            }
        }
    }
    return null;
}

// ============================================================================
// Common Route Guards
// ============================================================================

/// Guard that requires authentication
pub fn requireAuth(context: *RouteContext) GuardResponse {
    if (context.is_authenticated) {
        return .{ .result = .allow };
    }
    return .{
        .result = .redirect,
        .redirect_to = "/login",
        .message = "Please log in to continue",
    };
}

/// Create a guard that requires a specific role
pub fn requireRole(comptime role: []const u8) GuardFn {
    return struct {
        fn guard(context: *RouteContext) GuardResponse {
            if (context.hasRole(role)) {
                return .{ .result = .allow };
            }
            return .{
                .result = .deny,
                .message = "Insufficient permissions",
            };
        }
    }.guard;
}

// ============================================================================
// C ABI Exports
// ============================================================================

var global_router: ?*Router = null;

export fn zylix_router_init() i32 {
    // Router initialization requires routes to be passed
    // This is a placeholder - actual init will be done by platform
    return 0;
}

export fn zylix_router_push(path_ptr: [*]const u8, path_len: usize) i32 {
    if (global_router) |router| {
        const path = path_ptr[0..path_len];
        router.push(path) catch |err| {
            return switch (err) {
                RouterError.RouteNotFound => 1,
                RouterError.NavigationBlocked => 2,
                RouterError.InvalidPath => 3,
                RouterError.OutOfMemory => 4,
            };
        };
        return 0;
    }
    return -1;
}

export fn zylix_router_back() i32 {
    if (global_router) |router| {
        router.back() catch return 1;
        return 0;
    }
    return -1;
}

export fn zylix_router_forward() i32 {
    if (global_router) |router| {
        router.forward() catch return 1;
        return 0;
    }
    return -1;
}

export fn zylix_router_can_go_back() bool {
    if (global_router) |router| {
        return router.canGoBack();
    }
    return false;
}

export fn zylix_router_can_go_forward() bool {
    if (global_router) |router| {
        return router.canGoForward();
    }
    return false;
}

export fn zylix_router_handle_deep_link(url_ptr: [*]const u8, url_len: usize) i32 {
    if (global_router) |router| {
        const url = url_ptr[0..url_len];
        router.handleDeepLink(url) catch return 1;
        return 0;
    }
    return -1;
}

// ============================================================================
// Tests
// ============================================================================

test "URL parsing" {
    const allocator = std.testing.allocator;

    const url = "/users/123?page=1&sort=name#section";
    const parsed = try parseUrl(url, allocator);

    try std.testing.expectEqualStrings("/users/123", parsed.path);
    try std.testing.expectEqualStrings("section", parsed.fragment.?);
    try std.testing.expectEqual(@as(usize, 2), parsed.query.len);

    allocator.free(parsed.query);
}

test "pattern matching" {
    const allocator = std.testing.allocator;

    // Exact match
    const params1 = try matchPattern("/users", "/users", allocator);
    try std.testing.expect(params1 != null);
    try std.testing.expectEqual(@as(usize, 0), params1.?.len);
    allocator.free(params1.?);

    // Parameter match
    const params2 = try matchPattern("/users/:id", "/users/123", allocator);
    try std.testing.expect(params2 != null);
    try std.testing.expectEqual(@as(usize, 1), params2.?.len);
    try std.testing.expectEqualStrings("id", params2.?[0].name);
    try std.testing.expectEqualStrings("123", params2.?[0].value);
    allocator.free(params2.?);

    // No match
    const params3 = try matchPattern("/users/:id", "/posts/123", allocator);
    try std.testing.expect(params3 == null);
}

test "history navigation" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator);
    defer history.deinit();

    try history.push("/", null);
    try history.push("/users", null);
    try history.push("/users/123", null);

    try std.testing.expectEqual(@as(usize, 3), history.length());
    try std.testing.expectEqualStrings("/users/123", history.current().?.path);

    _ = history.back();
    try std.testing.expectEqualStrings("/users", history.current().?.path);

    _ = history.forward();
    try std.testing.expectEqualStrings("/users/123", history.current().?.path);
}
