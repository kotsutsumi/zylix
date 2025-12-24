//! API Server Demo - API Handlers

const std = @import("std");
const models = @import("models.zig");

pub const Method = enum(u8) {
    GET = 0,
    POST = 1,
    PUT = 2,
    DELETE = 3,
    PATCH = 4,
    OPTIONS = 5,
};

pub const StatusCode = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    too_many_requests = 429,
    internal_error = 500,

    pub fn message(self: StatusCode) []const u8 {
        return switch (self) {
            .ok => "OK",
            .created => "Created",
            .no_content => "No Content",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .conflict => "Conflict",
            .too_many_requests => "Too Many Requests",
            .internal_error => "Internal Server Error",
        };
    }
};

pub const Request = struct {
    method: Method = .GET,
    path: [256]u8 = undefined,
    path_len: usize = 0,
    body: [4096]u8 = undefined,
    body_len: usize = 0,
    auth_token: [256]u8 = undefined,
    auth_token_len: usize = 0,

    pub fn getPath(self: *const Request) []const u8 {
        return self.path[0..self.path_len];
    }

    pub fn getBody(self: *const Request) []const u8 {
        return self.body[0..self.body_len];
    }

    pub fn setPath(self: *Request, path: []const u8) void {
        const len = @min(path.len, self.path.len);
        @memcpy(self.path[0..len], path[0..len]);
        self.path_len = len;
    }

    pub fn setBody(self: *Request, body: []const u8) void {
        const len = @min(body.len, self.body.len);
        @memcpy(self.body[0..len], body[0..len]);
        self.body_len = len;
    }
};

pub const Response = struct {
    status: StatusCode = .ok,
    body: [8192]u8 = undefined,
    body_len: usize = 0,
    content_type: []const u8 = "application/json",

    pub fn getBody(self: *const Response) []const u8 {
        return self.body[0..self.body_len];
    }

    pub fn setBody(self: *Response, body: []const u8) void {
        const len = @min(body.len, self.body.len);
        @memcpy(self.body[0..len], body[0..len]);
        self.body_len = len;
    }

    pub fn setJson(self: *Response, json: []const u8) void {
        self.setBody(json);
        self.content_type = "application/json";
    }

    pub fn setError(self: *Response, status: StatusCode, message: []const u8) void {
        self.status = status;
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"error\":\"{s}\",\"status\":{d}}}", .{
            message,
            @intFromEnum(status),
        }) catch "{\"error\":\"Internal error\"}";
        self.setJson(json);
    }
};

const MAX_USERS: usize = 50;
const MAX_POSTS: usize = 100;

pub const ApiState = struct {
    initialized: bool = false,

    // Data stores
    users: [MAX_USERS]models.User = undefined,
    user_count: usize = 0,
    next_user_id: u32 = 1,

    posts: [MAX_POSTS]models.Post = undefined,
    post_count: usize = 0,
    next_post_id: u32 = 1,

    // Configuration
    rate_limit: u32 = 100, // requests per minute
    request_count: u32 = 0,
    last_reset: i64 = 0,

    // Auth
    auth_token: [256]u8 = undefined,
    auth_token_len: usize = 0,
    require_auth: bool = false,

    // Current request/response
    current_request: Request = .{},
    current_response: Response = .{},
};

var api_state: ApiState = .{};

pub fn init() void {
    api_state = .{ .initialized = true };
    loadSampleData();
}

pub fn deinit() void {
    api_state.initialized = false;
}

pub fn getState() *const ApiState {
    return &api_state;
}

fn loadSampleData() void {
    // Sample users
    api_state.users[0] = models.User{ .id = 1, .role = .admin };
    api_state.users[0].setName("Admin");
    api_state.users[0].setEmail("admin@example.com");

    api_state.users[1] = models.User{ .id = 2, .role = .user };
    api_state.users[1].setName("Alice");
    api_state.users[1].setEmail("alice@example.com");

    api_state.users[2] = models.User{ .id = 3, .role = .user };
    api_state.users[2].setName("Bob");
    api_state.users[2].setEmail("bob@example.com");

    api_state.user_count = 3;
    api_state.next_user_id = 4;

    // Sample posts
    api_state.posts[0] = models.Post{ .id = 1, .author_id = 1, .published = true };
    api_state.posts[0].setTitle("Welcome Post");
    api_state.posts[0].setContent("Welcome to the API demo!");

    api_state.posts[1] = models.Post{ .id = 2, .author_id = 2, .published = true };
    api_state.posts[1].setTitle("Hello World");
    api_state.posts[1].setContent("This is my first post.");

    api_state.post_count = 2;
    api_state.next_post_id = 3;
}

// Request handling
pub fn handleRequest(method: Method, path: []const u8, body: []const u8) void {
    api_state.current_request = .{};
    api_state.current_request.method = method;
    api_state.current_request.setPath(path);
    api_state.current_request.setBody(body);

    api_state.current_response = .{};

    // Rate limiting check
    api_state.request_count += 1;
    if (api_state.request_count > api_state.rate_limit) {
        api_state.current_response.setError(.too_many_requests, "Rate limit exceeded");
        return;
    }

    // Route request
    if (startsWith(path, "/api/users")) {
        handleUsers(method, path);
    } else if (startsWith(path, "/api/posts")) {
        handlePosts(method, path);
    } else if (std.mem.eql(u8, path, "/api/health")) {
        handleHealth();
    } else {
        api_state.current_response.setError(.not_found, "Endpoint not found");
    }
}

fn startsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    return std.mem.eql(u8, str[0..prefix.len], prefix);
}

fn handleHealth() void {
    api_state.current_response.status = .ok;
    api_state.current_response.setJson("{\"status\":\"healthy\",\"version\":\"1.0.0\"}");
}

fn handleUsers(method: Method, path: []const u8) void {
    // Parse ID from path if present
    const id = parseIdFromPath(path, "/api/users/");

    switch (method) {
        .GET => {
            if (id) |user_id| {
                getUserById(user_id);
            } else {
                listUsers();
            }
        },
        .POST => createUser(),
        .PUT => {
            if (id) |user_id| {
                updateUser(user_id);
            } else {
                api_state.current_response.setError(.bad_request, "User ID required");
            }
        },
        .DELETE => {
            if (id) |user_id| {
                deleteUser(user_id);
            } else {
                api_state.current_response.setError(.bad_request, "User ID required");
            }
        },
        else => api_state.current_response.setError(.method_not_allowed, "Method not allowed"),
    }
}

fn handlePosts(method: Method, path: []const u8) void {
    const id = parseIdFromPath(path, "/api/posts/");

    switch (method) {
        .GET => {
            if (id) |post_id| {
                getPostById(post_id);
            } else {
                listPosts();
            }
        },
        .POST => createPost(),
        .DELETE => {
            if (id) |post_id| {
                deletePost(post_id);
            } else {
                api_state.current_response.setError(.bad_request, "Post ID required");
            }
        },
        else => api_state.current_response.setError(.method_not_allowed, "Method not allowed"),
    }
}

fn parseIdFromPath(path: []const u8, prefix: []const u8) ?u32 {
    if (path.len <= prefix.len) return null;
    if (!startsWith(path, prefix)) return null;

    const id_str = path[prefix.len..];
    return std.fmt.parseInt(u32, id_str, 10) catch null;
}

// User handlers
fn listUsers() void {
    const S = struct {
        var buf: [4096]u8 = undefined;
    };

    var pos: usize = 0;
    pos += (std.fmt.bufPrint(S.buf[pos..], "{{\"users\":[", .{}) catch return).len;

    for (api_state.users[0..api_state.user_count], 0..) |*user, i| {
        if (i > 0) {
            S.buf[pos] = ',';
            pos += 1;
        }
        const json = std.fmt.bufPrint(S.buf[pos..], "{{\"id\":{d},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{
            user.id,
            user.getName(),
            user.getEmail(),
        }) catch return;
        pos += json.len;
    }

    pos += (std.fmt.bufPrint(S.buf[pos..], "],\"total\":{d}}}", .{api_state.user_count}) catch return).len;

    api_state.current_response.status = .ok;
    api_state.current_response.setJson(S.buf[0..pos]);
}

fn getUserById(id: u32) void {
    const S = struct {
        var buf: [512]u8 = undefined;
    };

    for (api_state.users[0..api_state.user_count]) |*user| {
        if (user.id == id) {
            const json = std.fmt.bufPrint(&S.buf, "{{\"id\":{d},\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}", .{
                user.id,
                user.getName(),
                user.getEmail(),
                @tagName(user.role),
            }) catch return;
            api_state.current_response.status = .ok;
            api_state.current_response.setJson(json);
            return;
        }
    }

    api_state.current_response.setError(.not_found, "User not found");
}

fn createUser() void {
    if (api_state.user_count >= MAX_USERS) {
        api_state.current_response.setError(.conflict, "User limit reached");
        return;
    }

    const S = struct {
        var buf: [256]u8 = undefined;
    };

    var user = models.User{ .id = api_state.next_user_id };
    user.setName("New User");
    user.setEmail("new@example.com");

    api_state.users[api_state.user_count] = user;
    api_state.user_count += 1;
    api_state.next_user_id += 1;

    const json = std.fmt.bufPrint(&S.buf, "{{\"id\":{d},\"message\":\"User created\"}}", .{user.id}) catch return;
    api_state.current_response.status = .created;
    api_state.current_response.setJson(json);
}

fn updateUser(id: u32) void {
    for (api_state.users[0..api_state.user_count]) |*user| {
        if (user.id == id) {
            // Would parse body and update fields
            api_state.current_response.status = .ok;
            api_state.current_response.setJson("{\"message\":\"User updated\"}");
            return;
        }
    }

    api_state.current_response.setError(.not_found, "User not found");
}

fn deleteUser(id: u32) void {
    for (api_state.users[0..api_state.user_count], 0..) |*user, i| {
        if (user.id == id) {
            // Shift remaining users
            var j = i;
            while (j < api_state.user_count - 1) : (j += 1) {
                api_state.users[j] = api_state.users[j + 1];
            }
            api_state.user_count -= 1;

            api_state.current_response.status = .no_content;
            return;
        }
    }

    api_state.current_response.setError(.not_found, "User not found");
}

// Post handlers
fn listPosts() void {
    const S = struct {
        var buf: [4096]u8 = undefined;
    };

    var pos: usize = 0;
    pos += (std.fmt.bufPrint(S.buf[pos..], "{{\"posts\":[", .{}) catch return).len;

    for (api_state.posts[0..api_state.post_count], 0..) |*post, i| {
        if (i > 0) {
            S.buf[pos] = ',';
            pos += 1;
        }
        const json = std.fmt.bufPrint(S.buf[pos..], "{{\"id\":{d},\"title\":\"{s}\",\"author_id\":{d}}}", .{
            post.id,
            post.getTitle(),
            post.author_id,
        }) catch return;
        pos += json.len;
    }

    pos += (std.fmt.bufPrint(S.buf[pos..], "],\"total\":{d}}}", .{api_state.post_count}) catch return).len;

    api_state.current_response.status = .ok;
    api_state.current_response.setJson(S.buf[0..pos]);
}

fn getPostById(id: u32) void {
    const S = struct {
        var buf: [2048]u8 = undefined;
    };

    for (api_state.posts[0..api_state.post_count]) |*post| {
        if (post.id == id) {
            const json = std.fmt.bufPrint(&S.buf, "{{\"id\":{d},\"title\":\"{s}\",\"content\":\"{s}\",\"author_id\":{d},\"published\":{}}}", .{
                post.id,
                post.getTitle(),
                post.getContent(),
                post.author_id,
                post.published,
            }) catch return;
            api_state.current_response.status = .ok;
            api_state.current_response.setJson(json);
            return;
        }
    }

    api_state.current_response.setError(.not_found, "Post not found");
}

fn createPost() void {
    if (api_state.post_count >= MAX_POSTS) {
        api_state.current_response.setError(.conflict, "Post limit reached");
        return;
    }

    const S = struct {
        var buf: [256]u8 = undefined;
    };

    var post = models.Post{ .id = api_state.next_post_id, .author_id = 1 };
    post.setTitle("New Post");
    post.setContent("Post content here.");

    api_state.posts[api_state.post_count] = post;
    api_state.post_count += 1;
    api_state.next_post_id += 1;

    const json = std.fmt.bufPrint(&S.buf, "{{\"id\":{d},\"message\":\"Post created\"}}", .{post.id}) catch return;
    api_state.current_response.status = .created;
    api_state.current_response.setJson(json);
}

fn deletePost(id: u32) void {
    for (api_state.posts[0..api_state.post_count], 0..) |*post, i| {
        if (post.id == id) {
            var j = i;
            while (j < api_state.post_count - 1) : (j += 1) {
                api_state.posts[j] = api_state.posts[j + 1];
            }
            api_state.post_count -= 1;

            api_state.current_response.status = .no_content;
            return;
        }
    }

    api_state.current_response.setError(.not_found, "Post not found");
}

// Configuration
pub fn setRateLimit(limit: u32) void {
    api_state.rate_limit = limit;
}

pub fn resetRateLimit() void {
    api_state.request_count = 0;
}

pub fn getResponse() *const Response {
    return &api_state.current_response;
}

// Tests
test "api init" {
    init();
    defer deinit();
    try std.testing.expect(api_state.initialized);
    try std.testing.expect(api_state.user_count > 0);
}

test "health check" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/health", "");
    try std.testing.expectEqual(StatusCode.ok, api_state.current_response.status);
}

test "list users" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/users", "");
    try std.testing.expectEqual(StatusCode.ok, api_state.current_response.status);
}

test "get user by id" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/users/1", "");
    try std.testing.expectEqual(StatusCode.ok, api_state.current_response.status);
}

test "user not found" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/users/999", "");
    try std.testing.expectEqual(StatusCode.not_found, api_state.current_response.status);
}

test "create user" {
    init();
    defer deinit();

    const initial_count = api_state.user_count;
    handleRequest(.POST, "/api/users", "{}");
    try std.testing.expectEqual(StatusCode.created, api_state.current_response.status);
    try std.testing.expectEqual(initial_count + 1, api_state.user_count);
}

test "delete user" {
    init();
    defer deinit();

    const initial_count = api_state.user_count;
    handleRequest(.DELETE, "/api/users/2", "");
    try std.testing.expectEqual(StatusCode.no_content, api_state.current_response.status);
    try std.testing.expectEqual(initial_count - 1, api_state.user_count);
}

test "list posts" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/posts", "");
    try std.testing.expectEqual(StatusCode.ok, api_state.current_response.status);
}

test "create post" {
    init();
    defer deinit();

    const initial_count = api_state.post_count;
    handleRequest(.POST, "/api/posts", "{}");
    try std.testing.expectEqual(StatusCode.created, api_state.current_response.status);
    try std.testing.expectEqual(initial_count + 1, api_state.post_count);
}

test "not found endpoint" {
    init();
    defer deinit();

    handleRequest(.GET, "/api/unknown", "");
    try std.testing.expectEqual(StatusCode.not_found, api_state.current_response.status);
}
