//! Zylix mBaaS - Firebase Client
//!
//! Firebase integration for authentication, Firestore database,
//! Cloud Storage, and Firebase Cloud Messaging (FCM).
//!
//! Features:
//! - Firebase Authentication (Email, Social, Phone, Anonymous)
//! - Cloud Firestore (Real-time database)
//! - Firebase Storage (File storage)
//! - Firebase Cloud Messaging (Push notifications)
//! - Firebase Analytics (Event tracking)
//! - Firebase Remote Config

const std = @import("std");
const types = @import("types.zig");

const User = types.User;
const AuthProvider = types.AuthProvider;
const SignInOptions = types.SignInOptions;
const Document = types.Document;
const Value = types.Value;
const Filter = types.Filter;
const QueryOptions = types.QueryOptions;
const FileMetadata = types.FileMetadata;
const UploadOptions = types.UploadOptions;
const UploadProgress = types.UploadProgress;
const DownloadOptions = types.DownloadOptions;
const ListOptions = types.ListOptions;
const ListResult = types.ListResult;
const NotificationMessage = types.NotificationMessage;
const Subscription = types.Subscription;
const RealtimeChange = types.RealtimeChange;
const FirebaseConfig = types.FirebaseConfig;
const AuthStateCallback = types.AuthStateCallback;
const RealtimeCallback = types.RealtimeCallback;
const UploadProgressCallback = types.UploadProgressCallback;
const MbaasError = types.MbaasError;
const Error = types.Error;

/// Firebase client for all Firebase services
pub const FirebaseClient = struct {
    allocator: std.mem.Allocator,
    config: FirebaseConfig,

    /// Current authenticated user
    current_user: ?User = null,

    /// Auth state listeners
    auth_listeners: std.ArrayListUnmanaged(AuthStateCallback),

    /// Active subscriptions
    subscriptions: std.AutoHashMapUnmanaged(u64, SubscriptionInfo),
    next_subscription_id: u64 = 1,

    /// HTTP client state (simulated for cross-platform)
    base_url: []const u8,
    auth_token: ?[]const u8 = null,

    const SubscriptionInfo = struct {
        path: []const u8,
        callback: RealtimeCallback,
        active: bool,
    };

    /// Initialize Firebase client with configuration
    pub fn init(allocator: std.mem.Allocator, config: FirebaseConfig) !*FirebaseClient {
        const client = try allocator.create(FirebaseClient);
        errdefer allocator.destroy(client);

        const base_url = try std.fmt.allocPrint(
            allocator,
            "https://firestore.googleapis.com/v1/projects/{s}/databases/(default)/documents",
            .{config.project_id},
        );

        client.* = .{
            .allocator = allocator,
            .config = config,
            .auth_listeners = .{},
            .subscriptions = .{},
            .base_url = base_url,
        };

        return client;
    }

    /// Clean up resources
    pub fn deinit(self: *FirebaseClient) void {
        if (self.current_user) |*user| {
            user.deinit(self.allocator);
        }

        self.auth_listeners.deinit(self.allocator);

        var sub_it = self.subscriptions.iterator();
        while (sub_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.path);
        }
        self.subscriptions.deinit(self.allocator);

        self.allocator.free(self.base_url);
        if (self.auth_token) |token| {
            self.allocator.free(token);
        }

        self.allocator.destroy(self);
    }

    // ========================================================================
    // Authentication
    // ========================================================================

    /// Sign in with email and password
    pub fn signInWithEmail(self: *FirebaseClient, email: []const u8, password: []const u8) Error!User {
        _ = password;

        // Build authentication request
        // In real implementation, this would call Firebase Auth REST API
        // POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}

        const user = User{
            .uid = try self.allocator.dupe(u8, "firebase-user-123"),
            .email = try self.allocator.dupe(u8, email),
            .email_verified = true,
            .is_anonymous = false,
            .created_at = std.time.milliTimestamp(),
            .last_sign_in = std.time.milliTimestamp(),
        };

        // Store current user
        if (self.current_user) |*old_user| {
            old_user.deinit(self.allocator);
        }
        self.current_user = user;

        // Notify listeners
        self.notifyAuthStateChange();

        return user;
    }

    /// Sign in with OAuth provider
    pub fn signInWithProvider(self: *FirebaseClient, provider: AuthProvider, options: SignInOptions) Error!User {
        _ = options;

        const provider_name = switch (provider) {
            .google => "google.com",
            .apple => "apple.com",
            .facebook => "facebook.com",
            .twitter => "twitter.com",
            .github => "github.com",
            .microsoft => "microsoft.com",
            else => "unknown",
        };

        const user = User{
            .uid = try self.allocator.dupe(u8, "oauth-user-456"),
            .email = try std.fmt.allocPrint(self.allocator, "user@{s}", .{provider_name}),
            .display_name = try self.allocator.dupe(u8, "OAuth User"),
            .email_verified = true,
            .is_anonymous = false,
            .provider_data = try self.allocator.dupe(u8, provider_name),
            .created_at = std.time.milliTimestamp(),
            .last_sign_in = std.time.milliTimestamp(),
        };

        if (self.current_user) |*old_user| {
            old_user.deinit(self.allocator);
        }
        self.current_user = user;
        self.notifyAuthStateChange();

        return user;
    }

    /// Sign in anonymously
    pub fn signInAnonymously(self: *FirebaseClient) Error!User {
        const user = User{
            .uid = try self.allocator.dupe(u8, "anon-user-789"),
            .is_anonymous = true,
            .created_at = std.time.milliTimestamp(),
            .last_sign_in = std.time.milliTimestamp(),
        };

        if (self.current_user) |*old_user| {
            old_user.deinit(self.allocator);
        }
        self.current_user = user;
        self.notifyAuthStateChange();

        return user;
    }

    /// Create user with email and password
    pub fn createUserWithEmail(self: *FirebaseClient, email: []const u8, password: []const u8) Error!User {
        // Validate password strength
        if (password.len < 6) {
            return MbaasError.WeakPassword;
        }

        // Validate email format
        if (std.mem.indexOf(u8, email, "@") == null) {
            return MbaasError.InvalidEmail;
        }

        const user = User{
            .uid = try self.allocator.dupe(u8, "new-user-abc"),
            .email = try self.allocator.dupe(u8, email),
            .email_verified = false,
            .is_anonymous = false,
            .created_at = std.time.milliTimestamp(),
            .last_sign_in = std.time.milliTimestamp(),
        };

        if (self.current_user) |*old_user| {
            old_user.deinit(self.allocator);
        }
        self.current_user = user;
        self.notifyAuthStateChange();

        return user;
    }

    /// Sign out current user
    pub fn signOut(self: *FirebaseClient) void {
        if (self.current_user) |*user| {
            user.deinit(self.allocator);
            self.current_user = null;
        }

        if (self.auth_token) |token| {
            self.allocator.free(token);
            self.auth_token = null;
        }

        self.notifyAuthStateChange();
    }

    /// Get current user
    pub fn getCurrentUser(self: *const FirebaseClient) ?User {
        return self.current_user;
    }

    /// Add auth state listener
    pub fn onAuthStateChanged(self: *FirebaseClient, callback: AuthStateCallback) !void {
        try self.auth_listeners.append(self.allocator, callback);
    }

    /// Send password reset email
    pub fn sendPasswordResetEmail(self: *FirebaseClient, email: []const u8) Error!void {
        _ = self;
        // Validate email
        if (std.mem.indexOf(u8, email, "@") == null) {
            return MbaasError.InvalidEmail;
        }
        // In real implementation, call Firebase Auth REST API
    }

    /// Verify email
    pub fn sendEmailVerification(self: *FirebaseClient) Error!void {
        if (self.current_user == null) {
            return MbaasError.UserNotFound;
        }
        // In real implementation, call Firebase Auth REST API
    }

    fn notifyAuthStateChange(self: *FirebaseClient) void {
        for (self.auth_listeners.items) |callback| {
            callback(self.current_user);
        }
    }

    // ========================================================================
    // Firestore Database
    // ========================================================================

    /// Get a document by path
    pub fn getDocument(self: *FirebaseClient, path: []const u8) Error!?Document {
        // Build Firestore REST API URL
        // GET {base_url}/{path}
        _ = self.base_url;

        var doc = try Document.init(self.allocator, path);

        // Simulate document data
        const name_key = try self.allocator.dupe(u8, "name");
        const name_value = try self.allocator.dupe(u8, "Sample Document");
        try doc.data.put(self.allocator, name_key, .{ .string = name_value });

        return doc;
    }

    /// Set a document (create or overwrite)
    pub fn setDocument(self: *FirebaseClient, path: []const u8, data: std.StringHashMapUnmanaged(Value)) Error!void {
        _ = self;
        _ = path;
        _ = data;
        // In real implementation, call Firestore REST API
        // PATCH {base_url}/{path}
    }

    /// Update specific fields in a document
    pub fn updateDocument(self: *FirebaseClient, path: []const u8, data: std.StringHashMapUnmanaged(Value)) Error!void {
        _ = self;
        _ = path;
        _ = data;
        // In real implementation, call Firestore REST API with update mask
    }

    /// Delete a document
    pub fn deleteDocument(self: *FirebaseClient, path: []const u8) Error!void {
        _ = self;
        _ = path;
        // DELETE {base_url}/{path}
    }

    /// Query documents in a collection
    pub fn queryDocuments(self: *FirebaseClient, collection: []const u8, options: QueryOptions) Error![]Document {
        _ = options;

        var docs: std.ArrayListUnmanaged(Document) = .{};
        errdefer {
            for (docs.items) |*d| d.deinit(self.allocator);
            docs.deinit(self.allocator);
        }

        // Simulate query results
        const doc_id = try std.fmt.allocPrint(self.allocator, "{s}/doc1", .{collection});
        const doc = try Document.init(self.allocator, doc_id);
        self.allocator.free(doc_id);

        try docs.append(self.allocator, doc);

        return docs.toOwnedSlice(self.allocator);
    }

    /// Subscribe to real-time updates
    pub fn onSnapshot(self: *FirebaseClient, path: []const u8, callback: RealtimeCallback) Error!Subscription {
        const id = self.next_subscription_id;
        self.next_subscription_id += 1;

        const path_copy = try self.allocator.dupe(u8, path);

        try self.subscriptions.put(self.allocator, id, .{
            .path = path_copy,
            .callback = callback,
            .active = true,
        });

        return .{ .id = id, .active = true };
    }

    /// Unsubscribe from real-time updates
    pub fn unsubscribe(self: *FirebaseClient, subscription: Subscription) void {
        if (self.subscriptions.fetchRemove(subscription.id)) |kv| {
            self.allocator.free(kv.value.path);
        }
    }

    /// Run a transaction
    pub fn runTransaction(
        self: *FirebaseClient,
        comptime T: type,
        context: anytype,
        transaction_fn: fn (@TypeOf(context), *TransactionContext) Error!T,
    ) Error!T {
        var tx_context = TransactionContext{
            .client = self,
            .reads = .{},
            .writes = .{},
        };
        defer tx_context.deinit();

        const result = try transaction_fn(context, &tx_context);

        // Commit transaction
        try tx_context.commit();

        return result;
    }

    /// Batch write multiple documents
    pub fn batchWrite(self: *FirebaseClient, operations: []const types.BatchOperation) Error!void {
        _ = self;
        for (operations) |op| {
            _ = op;
            // Process each operation
        }
    }

    // ========================================================================
    // Cloud Storage
    // ========================================================================

    /// Upload data to storage
    pub fn uploadBytes(self: *FirebaseClient, path: []const u8, data: []const u8, options: UploadOptions) Error!FileMetadata {
        _ = options;

        const name = std.fs.path.basename(path);

        return FileMetadata{
            .name = try self.allocator.dupe(u8, name),
            .path = try self.allocator.dupe(u8, path),
            .size = data.len,
            .created_at = std.time.milliTimestamp(),
            .download_url = try std.fmt.allocPrint(
                self.allocator,
                "https://firebasestorage.googleapis.com/v0/b/{s}/o/{s}",
                .{ self.config.storage_bucket orelse "default", path },
            ),
        };
    }

    /// Upload with progress tracking
    pub fn uploadBytesWithProgress(
        self: *FirebaseClient,
        path: []const u8,
        data: []const u8,
        options: UploadOptions,
        progress_callback: UploadProgressCallback,
    ) Error!FileMetadata {
        const total = data.len;
        var transferred: u64 = 0;
        const chunk_size: u64 = 65536; // 64KB chunks

        // Simulate chunked upload with progress
        while (transferred < total) {
            const remaining = total - transferred;
            const chunk = @min(chunk_size, remaining);
            transferred += chunk;

            progress_callback(.{
                .bytes_transferred = transferred,
                .total_bytes = total,
                .percentage = @as(f32, @floatFromInt(transferred)) / @as(f32, @floatFromInt(total)) * 100,
                .state = if (transferred >= total) .success else .running,
            });
        }

        return try self.uploadBytes(path, data, options);
    }

    /// Download file from storage
    pub fn downloadBytes(self: *FirebaseClient, path: []const u8, options: DownloadOptions) Error![]u8 {
        _ = options;
        _ = path;

        // In real implementation, call Firebase Storage REST API
        return try self.allocator.dupe(u8, "file content placeholder");
    }

    /// Get file metadata
    pub fn getMetadata(self: *FirebaseClient, path: []const u8) Error!FileMetadata {
        const name = std.fs.path.basename(path);

        return FileMetadata{
            .name = try self.allocator.dupe(u8, name),
            .path = try self.allocator.dupe(u8, path),
            .size = 0,
            .content_type = try self.allocator.dupe(u8, "application/octet-stream"),
        };
    }

    /// Get download URL
    pub fn getDownloadUrl(self: *FirebaseClient, path: []const u8) Error![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "https://firebasestorage.googleapis.com/v0/b/{s}/o/{s}?alt=media",
            .{ self.config.storage_bucket orelse "default", path },
        );
    }

    /// Delete file from storage
    pub fn deleteFile(self: *FirebaseClient, path: []const u8) Error!void {
        _ = self;
        _ = path;
        // DELETE request to Firebase Storage
    }

    /// List files in a directory
    pub fn listFiles(self: *FirebaseClient, path: []const u8, options: ListOptions) Error!ListResult {
        _ = options;
        _ = path;

        return ListResult{
            .items = try self.allocator.alloc(FileMetadata, 0),
            .prefixes = try self.allocator.alloc([]const u8, 0),
            .next_page_token = null,
        };
    }

    // ========================================================================
    // Cloud Messaging (FCM)
    // ========================================================================

    /// Get FCM registration token
    pub fn getMessagingToken(self: *FirebaseClient) Error![]u8 {
        // In real implementation, get token from platform-specific FCM SDK
        return try self.allocator.dupe(u8, "fcm-token-placeholder");
    }

    /// Subscribe to a topic
    pub fn subscribeToTopic(self: *FirebaseClient, topic: []const u8) Error!void {
        _ = self;
        _ = topic;
        // POST to FCM topic subscription API
    }

    /// Unsubscribe from a topic
    pub fn unsubscribeFromTopic(self: *FirebaseClient, topic: []const u8) Error!void {
        _ = self;
        _ = topic;
        // DELETE from FCM topic subscription API
    }

    /// Send notification (server-side only)
    pub fn sendNotification(self: *FirebaseClient, message: NotificationMessage) Error![]u8 {
        _ = message;
        // POST to FCM send API
        return try self.allocator.dupe(u8, "message-id-123");
    }

    // ========================================================================
    // Analytics
    // ========================================================================

    /// Log an analytics event
    pub fn logEvent(self: *FirebaseClient, event_name: []const u8, params: ?std.StringHashMapUnmanaged(Value)) Error!void {
        _ = self;
        _ = event_name;
        _ = params;
        // In real implementation, send to Firebase Analytics
    }

    /// Set user property
    pub fn setUserProperty(self: *FirebaseClient, name: []const u8, value: []const u8) Error!void {
        _ = self;
        _ = name;
        _ = value;
    }

    /// Set user ID for analytics
    pub fn setAnalyticsUserId(self: *FirebaseClient, user_id: []const u8) Error!void {
        _ = self;
        _ = user_id;
    }

    // ========================================================================
    // Remote Config
    // ========================================================================

    /// Fetch remote config
    pub fn fetchRemoteConfig(self: *FirebaseClient) Error!void {
        _ = self;
        // Fetch from Firebase Remote Config API
    }

    /// Get remote config value
    pub fn getRemoteConfigValue(self: *FirebaseClient, key: []const u8) Error!?[]const u8 {
        _ = self;
        _ = key;
        return null;
    }

    /// Activate fetched config
    pub fn activateRemoteConfig(self: *FirebaseClient) Error!bool {
        _ = self;
        return true;
    }
};

/// Transaction context for atomic operations
pub const TransactionContext = struct {
    client: *FirebaseClient,
    reads: std.ArrayListUnmanaged([]const u8),
    writes: std.ArrayListUnmanaged(types.BatchOperation),

    pub fn deinit(self: *TransactionContext) void {
        self.reads.deinit(self.client.allocator);
        self.writes.deinit(self.client.allocator);
    }

    /// Get a document within transaction
    pub fn get(self: *TransactionContext, path: []const u8) Error!?Document {
        try self.reads.append(self.client.allocator, path);
        return self.client.getDocument(path);
    }

    /// Set a document within transaction
    pub fn set(self: *TransactionContext, path: []const u8, data: std.StringHashMapUnmanaged(Value)) Error!void {
        try self.writes.append(self.client.allocator, .{
            .operation = .set,
            .path = path,
            .data = data,
        });
    }

    /// Update a document within transaction
    pub fn update(self: *TransactionContext, path: []const u8, data: std.StringHashMapUnmanaged(Value)) Error!void {
        try self.writes.append(self.client.allocator, .{
            .operation = .update,
            .path = path,
            .data = data,
        });
    }

    /// Delete a document within transaction
    pub fn delete(self: *TransactionContext, path: []const u8) Error!void {
        try self.writes.append(self.client.allocator, .{
            .operation = .delete,
            .path = path,
            .data = null,
        });
    }

    /// Commit the transaction
    pub fn commit(self: *TransactionContext) Error!void {
        // In real implementation, send batch commit to Firestore
        _ = self;
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Create a Firebase client with configuration
pub fn createClient(allocator: std.mem.Allocator, config: FirebaseConfig) !*FirebaseClient {
    return FirebaseClient.init(allocator, config);
}

// ============================================================================
// Unit Tests
// ============================================================================

test "FirebaseClient initialization" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    try std.testing.expect(client.current_user == null);
}

test "FirebaseClient email authentication" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    const user = try client.signInWithEmail("test@example.com", "password123");
    try std.testing.expectEqualStrings("test@example.com", user.email.?);

    client.signOut();
    try std.testing.expect(client.current_user == null);
}

test "FirebaseClient anonymous authentication" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    const user = try client.signInAnonymously();
    try std.testing.expect(user.is_anonymous);
}

test "FirebaseClient create user with weak password" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    const result = client.createUserWithEmail("test@example.com", "123");
    try std.testing.expectError(MbaasError.WeakPassword, result);
}

test "FirebaseClient get document" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    var doc = (try client.getDocument("users/user123")).?;
    defer doc.deinit(allocator);

    try std.testing.expectEqualStrings("users/user123", doc.id);
}

test "FirebaseClient storage upload" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
        .storage_bucket = "test-bucket",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    var meta = try client.uploadBytes("uploads/test.txt", "Hello, World!", .{});
    defer meta.deinit(allocator);

    try std.testing.expectEqualStrings("test.txt", meta.name);
    try std.testing.expectEqual(@as(u64, 13), meta.size);
}

test "FirebaseClient realtime subscription" {
    const allocator = std.testing.allocator;

    const config = FirebaseConfig{
        .project_id = "test-project",
        .api_key = "test-api-key",
    };

    var client = try FirebaseClient.init(allocator, config);
    defer client.deinit();

    const callback = struct {
        fn cb(_: RealtimeChange) void {}
    }.cb;

    const subscription = try client.onSnapshot("users/user123", callback);
    try std.testing.expect(subscription.active);

    client.unsubscribe(subscription);
}
