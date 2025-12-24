//! API Server Demo - Entry Point and C ABI Exports

const std = @import("std");
pub const api = @import("api.zig");
pub const models = @import("models.zig");

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    api.init();
}

pub fn deinit() void {
    api.deinit();
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn api_init() void {
    init();
}

export fn api_deinit() void {
    deinit();
}

// Request handling
export fn api_handle_request(method: u8, path_ptr: [*]const u8, path_len: usize, body_ptr: [*]const u8, body_len: usize) void {
    const method_count = @typeInfo(api.Method).@"enum".fields.len;
    if (method >= method_count) return;

    const path = path_ptr[0..path_len];
    const body = body_ptr[0..body_len];

    api.handleRequest(@enumFromInt(method), path, body);
}

export fn api_get_response_status() u16 {
    return @intFromEnum(api.getResponse().status);
}

export fn api_get_response_body() [*]const u8 {
    const response = api.getResponse();
    return response.body[0..response.body_len].ptr;
}

export fn api_get_response_body_len() usize {
    return api.getResponse().body_len;
}

// Configuration
export fn api_set_rate_limit(limit: u32) void {
    api.setRateLimit(limit);
}

export fn api_reset_rate_limit() void {
    api.resetRateLimit();
}

// Convenience wrappers
export fn api_get(path_ptr: [*]const u8, path_len: usize) void {
    api.handleRequest(.GET, path_ptr[0..path_len], "");
}

export fn api_post(path_ptr: [*]const u8, path_len: usize, body_ptr: [*]const u8, body_len: usize) void {
    api.handleRequest(.POST, path_ptr[0..path_len], body_ptr[0..body_len]);
}

export fn api_put(path_ptr: [*]const u8, path_len: usize, body_ptr: [*]const u8, body_len: usize) void {
    api.handleRequest(.PUT, path_ptr[0..path_len], body_ptr[0..body_len]);
}

export fn api_delete(path_ptr: [*]const u8, path_len: usize) void {
    api.handleRequest(.DELETE, path_ptr[0..path_len], "");
}

// Stats
export fn api_get_user_count() u32 {
    return @as(u32, @intCast(api.getState().user_count));
}

export fn api_get_post_count() u32 {
    return @as(u32, @intCast(api.getState().post_count));
}

// ============================================================================
// Tests
// ============================================================================

test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(api.getState().initialized);
}

test "health endpoint" {
    init();
    defer deinit();

    const path = "/api/health";
    api_get(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 200), api_get_response_status());
}

test "users endpoint" {
    init();
    defer deinit();

    const path = "/api/users";
    api_get(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 200), api_get_response_status());
}

test "create user" {
    init();
    defer deinit();

    const initial_count = api_get_user_count();
    const path = "/api/users";
    const body = "{}";
    api_post(path.ptr, path.len, body.ptr, body.len);
    try std.testing.expectEqual(@as(u16, 201), api_get_response_status());
    try std.testing.expectEqual(initial_count + 1, api_get_user_count());
}

test "posts endpoint" {
    init();
    defer deinit();

    const path = "/api/posts";
    api_get(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 200), api_get_response_status());
}

test "get single post" {
    init();
    defer deinit();

    const path = "/api/posts/1";
    api_get(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 200), api_get_response_status());
}

test "delete user" {
    init();
    defer deinit();

    const initial_count = api_get_user_count();
    const path = "/api/users/2";
    api_delete(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 204), api_get_response_status());
    try std.testing.expectEqual(initial_count - 1, api_get_user_count());
}

test "not found" {
    init();
    defer deinit();

    const path = "/api/unknown";
    api_get(path.ptr, path.len);
    try std.testing.expectEqual(@as(u16, 404), api_get_response_status());
}

test "rate limiting" {
    init();
    defer deinit();

    api_set_rate_limit(5);

    const path = "/api/health";
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        api_get(path.ptr, path.len);
    }

    // Should be rate limited now
    try std.testing.expectEqual(@as(u16, 429), api_get_response_status());
}
