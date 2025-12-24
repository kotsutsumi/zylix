//! Zylix Server - Type-Safe RPC
//!
//! Type-safe Remote Procedure Call system with JSON serialization.

const std = @import("std");
const types = @import("types.zig");
const router_mod = @import("router.zig");

const Context = router_mod.Context;
const Handler = router_mod.Handler;
const Router = router_mod.Router;
const ServerError = types.ServerError;
const Error = types.Error;
const Status = types.Status;

/// RPC error response
pub const RpcError = struct {
    code: i32,
    message: []const u8,
    data: ?[]const u8 = null,

    pub const PARSE_ERROR: i32 = -32700;
    pub const INVALID_REQUEST: i32 = -32600;
    pub const METHOD_NOT_FOUND: i32 = -32601;
    pub const INVALID_PARAMS: i32 = -32602;
    pub const INTERNAL_ERROR: i32 = -32603;
};

/// RPC request format
pub const RpcRequest = struct {
    jsonrpc: []const u8 = "2.0",
    method: []const u8,
    params: ?std.json.Value = null,
    id: ?std.json.Value = null,
};

/// RPC response format
pub const RpcResponse = struct {
    jsonrpc: []const u8 = "2.0",
    result: ?std.json.Value = null,
    @"error": ?RpcErrorObject = null,
    id: ?std.json.Value = null,

    pub const RpcErrorObject = struct {
        code: i32,
        message: []const u8,
        data: ?std.json.Value = null,
    };
};

/// Procedure handler function type
pub const ProcedureFn = *const fn (allocator: std.mem.Allocator, params: ?std.json.Value) anyerror!std.json.Value;

/// Procedure definition
const Procedure = struct {
    name: []const u8,
    handler: ProcedureFn,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, name: []const u8, handler: ProcedureFn) !Procedure {
        return .{
            .name = try allocator.dupe(u8, name),
            .handler = handler,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Procedure) void {
        self.allocator.free(self.name);
    }
};

/// RPC Server for handling JSON-RPC 2.0 requests
pub const RpcServer = struct {
    allocator: std.mem.Allocator,
    procedures: std.StringHashMapUnmanaged(Procedure),
    path: []const u8,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !RpcServer {
        return .{
            .allocator = allocator,
            .procedures = .{},
            .path = try allocator.dupe(u8, path),
        };
    }

    pub fn deinit(self: *RpcServer) void {
        var it = self.procedures.iterator();
        while (it.next()) |entry| {
            var proc = entry.value_ptr.*;
            proc.deinit();
        }
        self.procedures.deinit(self.allocator);
        self.allocator.free(self.path);
    }

    /// Register a procedure
    pub fn procedure(self: *RpcServer, name: []const u8, handler: ProcedureFn) !*RpcServer {
        const proc = try Procedure.init(self.allocator, name, handler);
        try self.procedures.put(self.allocator, proc.name, proc);
        return self;
    }

    /// Register typed procedure with automatic serialization
    /// Note: This is a simplified implementation. Full type-safe serialization
    /// would require more sophisticated comptime JSON handling.
    pub fn typedProcedure(
        self: *RpcServer,
        comptime name: []const u8,
        comptime ParamsType: type,
        comptime ResultType: type,
        comptime handler: anytype,
    ) !*RpcServer {
        // Create wrapper that handles JSON conversion
        const Wrapper = struct {
            fn call(_: std.mem.Allocator, params: ?std.json.Value) anyerror!std.json.Value {
                _ = params;
                _ = ParamsType;
                _ = ResultType;
                _ = handler;
                // Simplified: return null for now
                // Full implementation would:
                // 1. Parse params JSON into ParamsType
                // 2. Call handler(parsed_params)
                // 3. Serialize ResultType result to JSON
                return std.json.Value{ .null = {} };
            }
        };

        return self.procedure(name, Wrapper.call);
    }

    /// Handle RPC request
    pub fn handleRequest(self: *RpcServer, ctx: *Context) !void {
        // Parse JSON-RPC request
        const body = ctx.body() orelse {
            try self.sendError(ctx, RpcError.INVALID_REQUEST, "Empty request body", null);
            return;
        };

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            try self.sendError(ctx, RpcError.PARSE_ERROR, "Parse error", null);
            return;
        };
        defer parsed.deinit();

        const root = parsed.value;

        // Handle batch request
        if (root == .array) {
            try self.handleBatch(ctx, root.array.items);
            return;
        }

        // Handle single request
        if (root != .object) {
            try self.sendError(ctx, RpcError.INVALID_REQUEST, "Invalid request", null);
            return;
        }

        try self.handleSingle(ctx, root.object);
    }

    fn handleSingle(self: *RpcServer, ctx: *Context, obj: std.json.ObjectMap) !void {
        // Get method name
        const method_val = obj.get("method") orelse {
            try self.sendError(ctx, RpcError.INVALID_REQUEST, "Missing method", null);
            return;
        };

        if (method_val != .string) {
            try self.sendError(ctx, RpcError.INVALID_REQUEST, "Method must be string", null);
            return;
        }

        const method = method_val.string;
        const params = obj.get("params");
        const id = obj.get("id");

        // Find procedure
        if (self.procedures.get(method)) |proc| {
            // Call procedure
            const result = proc.handler(self.allocator, params) catch |err| {
                try self.sendError(ctx, RpcError.INTERNAL_ERROR, @errorName(err), id);
                return;
            };

            // Send success response
            try self.sendResult(ctx, result, id);
        } else {
            try self.sendError(ctx, RpcError.METHOD_NOT_FOUND, "Method not found", id);
        }
    }

    fn handleBatch(self: *RpcServer, ctx: *Context, items: []const std.json.Value) !void {
        if (items.len == 0) {
            try self.sendError(ctx, RpcError.INVALID_REQUEST, "Empty batch", null);
            return;
        }

        var responses: std.ArrayListUnmanaged(u8) = .{};
        defer responses.deinit(self.allocator);

        try responses.appendSlice(self.allocator, "[");

        for (items, 0..) |item, i| {
            if (i > 0) try responses.appendSlice(self.allocator, ",");

            if (item != .object) {
                const err_json = try self.formatError(RpcError.INVALID_REQUEST, "Invalid request", null);
                defer self.allocator.free(err_json);
                try responses.appendSlice(self.allocator, err_json);
                continue;
            }

            // Process single request and get response JSON
            const method_val = item.object.get("method");
            if (method_val == null or method_val.? != .string) {
                const err_json = try self.formatError(RpcError.INVALID_REQUEST, "Invalid method", null);
                defer self.allocator.free(err_json);
                try responses.appendSlice(self.allocator, err_json);
                continue;
            }

            const method = method_val.?.string;
            const params = item.object.get("params");
            const id = item.object.get("id");

            if (self.procedures.get(method)) |proc| {
                const result = proc.handler(self.allocator, params) catch {
                    const err_json = try self.formatError(RpcError.INTERNAL_ERROR, "Internal error", id);
                    defer self.allocator.free(err_json);
                    try responses.appendSlice(self.allocator, err_json);
                    continue;
                };

                const result_json = try self.formatResult(result, id);
                defer self.allocator.free(result_json);
                try responses.appendSlice(self.allocator, result_json);
            } else {
                const err_json = try self.formatError(RpcError.METHOD_NOT_FOUND, "Method not found", id);
                defer self.allocator.free(err_json);
                try responses.appendSlice(self.allocator, err_json);
            }
        }

        try responses.appendSlice(self.allocator, "]");

        _ = try ctx.response.setContentType("application/json");
        const response_body = try responses.toOwnedSlice(self.allocator);
        _ = ctx.response.setBodyOwned(response_body);
    }

    fn sendResult(self: *RpcServer, ctx: *Context, result: std.json.Value, id: ?std.json.Value) !void {
        const json_str = try self.formatResult(result, id);
        _ = try ctx.response.setContentType("application/json");
        _ = ctx.response.setBodyOwned(json_str);
    }

    fn formatResult(self: *RpcServer, result: std.json.Value, id: ?std.json.Value) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "{\"jsonrpc\":\"2.0\",\"result\":");

        const result_str = std.json.Stringify.valueAlloc(self.allocator, result, .{}) catch return error.OutOfMemory;
        defer self.allocator.free(result_str);
        try buffer.appendSlice(self.allocator, result_str);

        if (id) |i| {
            try buffer.appendSlice(self.allocator, ",\"id\":");
            const id_str = std.json.Stringify.valueAlloc(self.allocator, i, .{}) catch return error.OutOfMemory;
            defer self.allocator.free(id_str);
            try buffer.appendSlice(self.allocator, id_str);
        } else {
            try buffer.appendSlice(self.allocator, ",\"id\":null");
        }

        try buffer.appendSlice(self.allocator, "}");

        return buffer.toOwnedSlice(self.allocator);
    }

    fn sendError(self: *RpcServer, ctx: *Context, code: i32, message: []const u8, id: ?std.json.Value) !void {
        const json_str = try self.formatError(code, message, id);
        _ = try ctx.response.setContentType("application/json");
        _ = ctx.response.setBodyOwned(json_str);

        // Set appropriate HTTP status
        const http_status: Status = switch (code) {
            RpcError.PARSE_ERROR, RpcError.INVALID_REQUEST => .bad_request,
            RpcError.METHOD_NOT_FOUND => .not_found,
            else => .internal_server_error,
        };
        _ = ctx.response.setStatus(http_status);
    }

    fn formatError(self: *RpcServer, code: i32, message: []const u8, id: ?std.json.Value) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        try buffer.writer(self.allocator).print(
            "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":{d},\"message\":",
            .{code},
        );

        // Properly escape message string to prevent JSON injection
        const escaped_message = std.json.Stringify.valueAlloc(
            self.allocator,
            std.json.Value{ .string = message },
            .{},
        ) catch return error.OutOfMemory;
        defer self.allocator.free(escaped_message);
        try buffer.appendSlice(self.allocator, escaped_message);

        try buffer.appendSlice(self.allocator, "}");

        if (id) |i| {
            try buffer.appendSlice(self.allocator, ",\"id\":");
            const id_str = std.json.Stringify.valueAlloc(self.allocator, i, .{}) catch return error.OutOfMemory;
            defer self.allocator.free(id_str);
            try buffer.appendSlice(self.allocator, id_str);
        } else {
            try buffer.appendSlice(self.allocator, ",\"id\":null");
        }

        try buffer.appendSlice(self.allocator, "}");

        return buffer.toOwnedSlice(self.allocator);
    }

    /// Mount RPC server on router
    /// Note: The RPC server pointer must be set in request context as "__zylix_rpc_server"
    /// before routing. The Zylix server handles this automatically.
    /// The caller is responsible for ensuring the RpcServer outlives the router.
    pub fn mount(self: *RpcServer, router: *Router) !void {
        // Create wrapper handler that retrieves RPC server from context
        const WrapperHandler = struct {
            fn handle(ctx: *Context) anyerror!void {
                // The RPC server pointer should be set in context before routing
                if (ctx.request.get("__zylix_rpc_server")) |ptr| {
                    const rpc_ptr: *RpcServer = @ptrCast(@alignCast(ptr));
                    try rpc_ptr.handleRequest(ctx);
                }
            }
        };

        // Register a route that expects __zylix_rpc_server to be set in context
        _ = try router.post(self.path, WrapperHandler.handle);
    }

    /// Get the RPC server pointer for setting in request context
    pub fn getServerPtr(self: *RpcServer) *anyopaque {
        return @ptrCast(self);
    }
};

/// Batch request item for RPC client
pub const BatchRequestItem = struct {
    method: []const u8,
    params: ?[]const u8,
};

/// RPC Client for making JSON-RPC 2.0 requests
pub const RpcClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) !RpcClient {
        return .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *RpcClient) void {
        self.allocator.free(self.endpoint);
    }

    /// Build RPC request JSON
    pub fn buildRequest(self: *RpcClient, method: []const u8, params: ?[]const u8) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        const id = self.next_id;
        self.next_id += 1;

        try buffer.appendSlice(self.allocator, "{\"jsonrpc\":\"2.0\",\"method\":");

        // Properly escape method name to prevent JSON injection
        const escaped_method = std.json.Stringify.valueAlloc(
            self.allocator,
            std.json.Value{ .string = method },
            .{},
        ) catch return error.OutOfMemory;
        defer self.allocator.free(escaped_method);
        try buffer.appendSlice(self.allocator, escaped_method);

        if (params) |p| {
            try buffer.appendSlice(self.allocator, ",\"params\":");
            try buffer.appendSlice(self.allocator, p);
        }

        try buffer.writer(self.allocator).print(",\"id\":{d}}}", .{id});

        return buffer.toOwnedSlice(self.allocator);
    }

    /// Build batch RPC request
    pub fn buildBatchRequest(self: *RpcClient, requests: []const BatchRequestItem) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "[");

        for (requests, 0..) |req, i| {
            if (i > 0) try buffer.appendSlice(self.allocator, ",");

            const id = self.next_id;
            self.next_id += 1;

            try buffer.appendSlice(self.allocator, "{\"jsonrpc\":\"2.0\",\"method\":");

            // Properly escape method name to prevent JSON injection
            const escaped_method = std.json.Stringify.valueAlloc(
                self.allocator,
                std.json.Value{ .string = req.method },
                .{},
            ) catch return error.OutOfMemory;
            defer self.allocator.free(escaped_method);
            try buffer.appendSlice(self.allocator, escaped_method);

            if (req.params) |p| {
                try buffer.appendSlice(self.allocator, ",\"params\":");
                try buffer.appendSlice(self.allocator, p);
            }

            try buffer.writer(self.allocator).print(",\"id\":{d}}}", .{id});
        }

        try buffer.appendSlice(self.allocator, "]");

        return buffer.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

fn echoProc(_: std.mem.Allocator, params: ?std.json.Value) anyerror!std.json.Value {
    return params orelse std.json.Value{ .null = {} };
}

fn addProc(allocator: std.mem.Allocator, params: ?std.json.Value) anyerror!std.json.Value {
    if (params) |p| {
        if (p == .array and p.array.items.len == 2) {
            const a = p.array.items[0];
            const b = p.array.items[1];
            if (a == .integer and b == .integer) {
                return std.json.Value{ .integer = a.integer + b.integer };
            }
        }
    }
    _ = allocator;
    return std.json.Value{ .null = {} };
}

test "RpcServer init and deinit" {
    const allocator = std.testing.allocator;
    var server = try RpcServer.init(allocator, "/rpc");
    defer server.deinit();

    _ = try server.procedure("echo", echoProc);
    _ = try server.procedure("add", addProc);

    try std.testing.expectEqual(@as(usize, 2), server.procedures.count());
}

test "RpcClient buildRequest" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "http://localhost/rpc");
    defer client.deinit();

    const request = try client.buildRequest("echo", "[\"hello\"]");
    defer allocator.free(request);

    try std.testing.expect(std.mem.indexOf(u8, request, "\"method\":\"echo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request, "\"params\":[\"hello\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, request, "\"id\":1") != null);
}

test "RpcClient buildBatchRequest" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "http://localhost/rpc");
    defer client.deinit();

    const requests = [_]BatchRequestItem{
        .{ .method = "echo", .params = "[1]" },
        .{ .method = "add", .params = "[1,2]" },
    };

    const batch = try client.buildBatchRequest(&requests);
    defer allocator.free(batch);

    try std.testing.expect(std.mem.startsWith(u8, batch, "["));
    try std.testing.expect(std.mem.endsWith(u8, batch, "]"));
    try std.testing.expect(std.mem.indexOf(u8, batch, "\"method\":\"echo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, batch, "\"method\":\"add\"") != null);
}

test "RpcServer formatError" {
    const allocator = std.testing.allocator;
    var server = try RpcServer.init(allocator, "/rpc");
    defer server.deinit();

    const error_json = try server.formatError(RpcError.METHOD_NOT_FOUND, "Method not found", null);
    defer allocator.free(error_json);

    try std.testing.expect(std.mem.indexOf(u8, error_json, "\"code\":-32601") != null);
    try std.testing.expect(std.mem.indexOf(u8, error_json, "\"message\":\"Method not found\"") != null);
}

test "RpcServer formatResult" {
    const allocator = std.testing.allocator;
    var server = try RpcServer.init(allocator, "/rpc");
    defer server.deinit();

    const result_json = try server.formatResult(std.json.Value{ .integer = 42 }, std.json.Value{ .integer = 1 });
    defer allocator.free(result_json);

    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"result\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"id\":1") != null);
}
