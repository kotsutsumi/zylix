//! API Server Demo - Data Models

const std = @import("std");

pub const User = struct {
    id: u32 = 0,
    name: [64]u8 = undefined,
    name_len: usize = 0,
    email: [128]u8 = undefined,
    email_len: usize = 0,
    role: Role = .user,
    active: bool = true,
    created_at: i64 = 0,

    pub const Role = enum(u8) {
        user = 0,
        admin = 1,
        moderator = 2,
    };

    pub fn getName(self: *const User) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getEmail(self: *const User) []const u8 {
        return self.email[0..self.email_len];
    }

    pub fn setName(self: *User, name: []const u8) void {
        const len = @min(name.len, self.name.len);
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn setEmail(self: *User, email: []const u8) void {
        const len = @min(email.len, self.email.len);
        @memcpy(self.email[0..len], email[0..len]);
        self.email_len = len;
    }
};

pub const Post = struct {
    id: u32 = 0,
    author_id: u32 = 0,
    title: [128]u8 = undefined,
    title_len: usize = 0,
    content: [1024]u8 = undefined,
    content_len: usize = 0,
    published: bool = false,
    created_at: i64 = 0,
    updated_at: i64 = 0,

    pub fn getTitle(self: *const Post) []const u8 {
        return self.title[0..self.title_len];
    }

    pub fn getContent(self: *const Post) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn setTitle(self: *Post, title: []const u8) void {
        const len = @min(title.len, self.title.len);
        @memcpy(self.title[0..len], title[0..len]);
        self.title_len = len;
    }

    pub fn setContent(self: *Post, content: []const u8) void {
        const len = @min(content.len, self.content.len);
        @memcpy(self.content[0..len], content[0..len]);
        self.content_len = len;
    }
};

pub const Comment = struct {
    id: u32 = 0,
    post_id: u32 = 0,
    author_id: u32 = 0,
    content: [512]u8 = undefined,
    content_len: usize = 0,
    created_at: i64 = 0,

    pub fn getContent(self: *const Comment) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn setContent(self: *Comment, content: []const u8) void {
        const len = @min(content.len, self.content.len);
        @memcpy(self.content[0..len], content[0..len]);
        self.content_len = len;
    }
};

// Tests
test "user model" {
    var user = User{ .id = 1 };
    user.setName("Alice");
    user.setEmail("alice@example.com");

    try std.testing.expectEqualStrings("Alice", user.getName());
    try std.testing.expectEqualStrings("alice@example.com", user.getEmail());
}

test "post model" {
    var post = Post{ .id = 1 };
    post.setTitle("Hello World");
    post.setContent("This is a test post.");

    try std.testing.expectEqualStrings("Hello World", post.getTitle());
    try std.testing.expectEqualStrings("This is a test post.", post.getContent());
}
