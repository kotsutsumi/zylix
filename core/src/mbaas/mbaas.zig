//! Zylix mBaaS Module
//!
//! Unified mBaaS (mobile Backend as a Service) integration supporting
//! Firebase, Supabase, and AWS Amplify with consistent APIs.
//!
//! Features:
//! - Unified authentication API across providers
//! - Consistent database/document operations
//! - Cross-platform file storage
//! - Real-time subscriptions
//! - Push notifications
//! - Offline support with sync
//!
//! Supported Providers:
//! - Firebase (Authentication, Firestore, Storage, FCM, Analytics)
//! - Supabase (Auth, PostgreSQL, Storage, Realtime, Edge Functions)
//! - AWS Amplify (Cognito, DataStore, S3, AppSync, Lambda)

const std = @import("std");

// Re-export submodules
pub const types = @import("types.zig");
pub const firebase = @import("firebase.zig");
pub const supabase = @import("supabase.zig");
pub const amplify = @import("amplify.zig");

// Re-export common types
pub const Provider = types.Provider;
pub const MbaasError = types.MbaasError;
pub const Error = types.Error;

// Authentication types
pub const User = types.User;
pub const AuthProvider = types.AuthProvider;
pub const AuthState = types.AuthState;
pub const SignInOptions = types.SignInOptions;
pub const PasswordResetOptions = types.PasswordResetOptions;

// Database types
pub const Value = types.Value;
pub const Document = types.Document;
pub const GeoPoint = types.GeoPoint;
pub const Filter = types.Filter;
pub const FilterOperator = types.FilterOperator;
pub const OrderBy = types.OrderBy;
pub const SortDirection = types.SortDirection;
pub const QueryOptions = types.QueryOptions;
pub const WriteOperation = types.WriteOperation;
pub const BatchOperation = types.BatchOperation;
pub const TransactionOptions = types.TransactionOptions;

// Storage types
pub const FileMetadata = types.FileMetadata;
pub const UploadOptions = types.UploadOptions;
pub const UploadProgress = types.UploadProgress;
pub const UploadState = types.UploadState;
pub const DownloadOptions = types.DownloadOptions;
pub const ListOptions = types.ListOptions;
pub const ListResult = types.ListResult;

// Realtime types
pub const Subscription = types.Subscription;
pub const RealtimeEventType = types.RealtimeEventType;
pub const RealtimeChange = types.RealtimeChange;

// Push notification types
pub const NotificationMessage = types.NotificationMessage;
pub const AndroidNotificationConfig = types.AndroidNotificationConfig;
pub const AndroidPriority = types.AndroidPriority;
pub const ApnsNotificationConfig = types.ApnsNotificationConfig;
pub const WebPushConfig = types.WebPushConfig;

// Configuration types
pub const FirebaseConfig = types.FirebaseConfig;
pub const SupabaseConfig = types.SupabaseConfig;
pub const AmplifyConfig = types.AmplifyConfig;
pub const AmplifyAuthType = types.AmplifyAuthType;

// Callback types
pub const AuthStateCallback = types.AuthStateCallback;
pub const RealtimeCallback = types.RealtimeCallback;
pub const UploadProgressCallback = types.UploadProgressCallback;
pub const ErrorCallback = types.ErrorCallback;

// Re-export client types
pub const FirebaseClient = firebase.FirebaseClient;
pub const SupabaseClient = supabase.SupabaseClient;
pub const AmplifyClient = amplify.AmplifyClient;

/// Unified mBaaS client that wraps all providers
pub const Client = union(Provider) {
    firebase: *FirebaseClient,
    supabase: *SupabaseClient,
    amplify: *AmplifyClient,

    // ========================================================================
    // Authentication
    // ========================================================================

    /// Sign in with email and password
    pub fn signInWithEmail(self: Client, email: []const u8, password: []const u8) Error!User {
        return switch (self) {
            .firebase => |c| c.signInWithEmail(email, password),
            .supabase => |c| c.signInWithEmail(email, password),
            .amplify => |c| blk: {
                const result = try c.signIn(email, password);
                if (result.is_signed_in) {
                    break :blk c.getCurrentUser() orelse return MbaasError.AuthenticationFailed;
                }
                return MbaasError.AuthenticationFailed;
            },
        };
    }

    /// Sign out current user
    pub fn signOut(self: Client) Error!void {
        switch (self) {
            .firebase => |c| c.signOut(),
            .supabase => |c| try c.signOut(),
            .amplify => |c| try c.signOut(.{}),
        }
    }

    /// Get current authenticated user
    pub fn getCurrentUser(self: Client) ?User {
        return switch (self) {
            .firebase => |c| c.getCurrentUser(),
            .supabase => |c| c.getCurrentUser(),
            .amplify => |c| c.getCurrentUser(),
        };
    }

    // ========================================================================
    // Database
    // ========================================================================

    /// Get a document by path
    pub fn getDocument(self: Client, path: []const u8) Error!?Document {
        return switch (self) {
            .firebase => |c| c.getDocument(path),
            .supabase => |c| blk: {
                // Parse table/id from path
                const slash_pos = std.mem.indexOf(u8, path, "/");
                if (slash_pos) |pos| {
                    const table = path[0..pos];
                    const id = path[pos + 1 ..];
                    var query = c.from(table);
                    defer query.deinit();
                    _ = query.eq("id", id).single();
                    const docs = try query.execute();
                    defer c.allocator.free(docs);

                    if (docs.len > 0) {
                        const first = docs[0];
                        // Deinit remaining docs (ownership of first transfers to caller)
                        for (docs[1..]) |*d| {
                            var doc = d.*;
                            doc.deinit(c.allocator);
                        }
                        break :blk first;
                    }
                }
                break :blk null;
            },
            .amplify => |c| blk: {
                const slash_pos = std.mem.indexOf(u8, path, "/");
                if (slash_pos) |pos| {
                    const model = path[0..pos];
                    const docs = try c.dataStore().query(model, null);
                    defer c.allocator.free(docs);

                    if (docs.len > 0) {
                        const first = docs[0];
                        // Deinit remaining docs (ownership of first transfers to caller)
                        for (docs[1..]) |*d| {
                            var doc = d.*;
                            doc.deinit(c.allocator);
                        }
                        break :blk first;
                    }
                }
                break :blk null;
            },
        };
    }

    // ========================================================================
    // Storage
    // ========================================================================

    /// Upload file
    pub fn uploadFile(self: Client, path: []const u8, data: []const u8) Error!FileMetadata {
        return switch (self) {
            .firebase => |c| c.uploadBytes(path, data, .{}),
            .supabase => |c| blk: {
                const slash_pos = std.mem.indexOf(u8, path, "/");
                if (slash_pos) |pos| {
                    const bucket = path[0..pos];
                    const file_path = path[pos + 1 ..];
                    break :blk c.storage().from(bucket).upload(file_path, data, .{});
                }
                return MbaasError.InvalidPath;
            },
            .amplify => |c| blk: {
                const result = try c.storage().uploadFile(path, data, .{});
                break :blk FileMetadata{
                    .name = result.key,
                    .path = result.key,
                    .size = data.len,
                    .created_at = std.time.milliTimestamp(),
                };
            },
        };
    }

    /// Download file
    pub fn downloadFile(self: Client, path: []const u8) Error![]u8 {
        return switch (self) {
            .firebase => |c| c.downloadBytes(path, .{}),
            .supabase => |c| blk: {
                const slash_pos = std.mem.indexOf(u8, path, "/");
                if (slash_pos) |pos| {
                    const bucket = path[0..pos];
                    const file_path = path[pos + 1 ..];
                    break :blk c.storage().from(bucket).download(file_path);
                }
                return MbaasError.InvalidPath;
            },
            .amplify => |c| c.storage().downloadFile(path, .{}),
        };
    }

    // ========================================================================
    // Realtime
    // ========================================================================

    /// Subscribe to document/record changes
    pub fn subscribe(self: Client, path: []const u8, callback: RealtimeCallback) Error!Subscription {
        return switch (self) {
            .firebase => |c| c.onSnapshot(path, callback),
            .supabase => |c| c.subscribe(path, .all, callback),
            .amplify => |c| c.dataStore().observe(path, callback),
        };
    }

    /// Unsubscribe from changes
    pub fn unsubscribe(self: Client, subscription: Subscription) void {
        switch (self) {
            .firebase => |c| c.unsubscribe(subscription),
            .supabase => |c| c.unsubscribe(subscription),
            .amplify => |c| {
                if (c.subscriptions.fetchRemove(subscription.id)) |kv| {
                    c.allocator.free(kv.value.model);
                }
            },
        }
    }

    /// Clean up client resources
    pub fn deinit(self: Client) void {
        switch (self) {
            .firebase => |c| c.deinit(),
            .supabase => |c| c.deinit(),
            .amplify => |c| c.deinit(),
        }
    }
};

// ============================================================================
// Factory Functions
// ============================================================================

/// Create a Firebase client
pub fn createFirebaseClient(allocator: std.mem.Allocator, config: FirebaseConfig) !Client {
    const client = try FirebaseClient.init(allocator, config);
    return .{ .firebase = client };
}

/// Create a Supabase client
pub fn createSupabaseClient(allocator: std.mem.Allocator, config: SupabaseConfig) !Client {
    const client = try SupabaseClient.init(allocator, config);
    return .{ .supabase = client };
}

/// Create an Amplify client
pub fn createAmplifyClient(allocator: std.mem.Allocator, config: AmplifyConfig) !Client {
    const client = try AmplifyClient.init(allocator, config);
    return .{ .amplify = client };
}

/// Create a client from a provider and configuration
pub fn createClient(allocator: std.mem.Allocator, provider: Provider, config: anytype) !Client {
    return switch (provider) {
        .firebase => createFirebaseClient(allocator, config),
        .supabase => createSupabaseClient(allocator, config),
        .amplify => createAmplifyClient(allocator, config),
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "unified client with Firebase" {
    const allocator = std.testing.allocator;

    var client = try createFirebaseClient(allocator, .{
        .project_id = "test-project",
        .api_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expect(client.getCurrentUser() == null);
}

test "unified client with Supabase" {
    const allocator = std.testing.allocator;

    var client = try createSupabaseClient(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expect(client.getCurrentUser() == null);
}

test "unified client with Amplify" {
    const allocator = std.testing.allocator;

    var client = try createAmplifyClient(allocator, .{
        .region = "us-east-1",
    });
    defer client.deinit();

    try std.testing.expect(client.getCurrentUser() == null);
}

test "sign in with unified client" {
    const allocator = std.testing.allocator;

    var client = try createFirebaseClient(allocator, .{
        .project_id = "test-project",
        .api_key = "test-key",
    });
    defer client.deinit();

    const user = try client.signInWithEmail("test@example.com", "password123");
    try std.testing.expectEqualStrings("test@example.com", user.email.?);

    try client.signOut();
    try std.testing.expect(client.getCurrentUser() == null);
}

test "provider enum" {
    try std.testing.expectEqual(Provider.firebase, Provider.firebase);
    try std.testing.expectEqual(Provider.supabase, Provider.supabase);
    try std.testing.expectEqual(Provider.amplify, Provider.amplify);
}
