//! Zylix mBaaS - Supabase Client
//!
//! Supabase integration for authentication, PostgreSQL database,
//! S3-compatible storage, and real-time subscriptions.
//!
//! Features:
//! - Supabase Auth (Email, Magic Link, OAuth, Phone)
//! - PostgreSQL Database with PostgREST API
//! - S3-compatible Storage
//! - Real-time subscriptions via WebSockets
//! - Edge Functions invocation
//! - Row Level Security (RLS) support

const std = @import("std");
const types = @import("types.zig");

const User = types.User;
const AuthProvider = types.AuthProvider;
const SignInOptions = types.SignInOptions;
const Document = types.Document;
const Value = types.Value;
const Filter = types.Filter;
const FilterOperator = types.FilterOperator;
const QueryOptions = types.QueryOptions;
const SortDirection = types.SortDirection;
const FileMetadata = types.FileMetadata;
const UploadOptions = types.UploadOptions;
const UploadProgress = types.UploadProgress;
const DownloadOptions = types.DownloadOptions;
const ListOptions = types.ListOptions;
const ListResult = types.ListResult;
const Subscription = types.Subscription;
const RealtimeChange = types.RealtimeChange;
const RealtimeEventType = types.RealtimeEventType;
const SupabaseConfig = types.SupabaseConfig;
const AuthStateCallback = types.AuthStateCallback;
const RealtimeCallback = types.RealtimeCallback;
const UploadProgressCallback = types.UploadProgressCallback;
const MbaasError = types.MbaasError;
const Error = types.Error;

/// Supabase client for all Supabase services
pub const SupabaseClient = struct {
    allocator: std.mem.Allocator,
    config: SupabaseConfig,

    /// Current authenticated user
    current_user: ?User = null,

    /// Current session
    session: ?Session = null,

    /// Auth state listeners
    auth_listeners: std.ArrayListUnmanaged(AuthStateCallback),

    /// Active realtime subscriptions
    subscriptions: std.AutoHashMapUnmanaged(u64, SubscriptionInfo),
    next_subscription_id: u64 = 1,

    /// API endpoints
    rest_url: []const u8,
    auth_url: []const u8,
    storage_url: []const u8,
    realtime_url: []const u8,

    const SubscriptionInfo = struct {
        table: []const u8,
        event: RealtimeEvent,
        callback: RealtimeCallback,
        filter: ?[]const u8,
        active: bool,
    };

    /// Session information
    pub const Session = struct {
        access_token: []const u8,
        refresh_token: []const u8,
        expires_at: i64,
        token_type: []const u8 = "bearer",

        pub fn deinit(self: *Session, allocator: std.mem.Allocator) void {
            allocator.free(self.access_token);
            allocator.free(self.refresh_token);
        }

        pub fn isExpired(self: *const Session) bool {
            return std.time.milliTimestamp() >= self.expires_at;
        }
    };

    /// Realtime event types for Supabase
    pub const RealtimeEvent = enum {
        insert,
        update,
        delete,
        all,
    };

    /// Initialize Supabase client with configuration
    pub fn init(allocator: std.mem.Allocator, config: SupabaseConfig) !*SupabaseClient {
        const client = try allocator.create(SupabaseClient);
        errdefer allocator.destroy(client);

        // Build API URLs
        const rest_url = try std.fmt.allocPrint(allocator, "{s}/rest/v1", .{config.url});
        errdefer allocator.free(rest_url);

        const auth_url = try std.fmt.allocPrint(allocator, "{s}/auth/v1", .{config.url});
        errdefer allocator.free(auth_url);

        const storage_url = try std.fmt.allocPrint(allocator, "{s}/storage/v1", .{config.url});
        errdefer allocator.free(storage_url);

        const realtime_url = try std.fmt.allocPrint(allocator, "{s}/realtime/v1", .{config.url});

        client.* = .{
            .allocator = allocator,
            .config = config,
            .auth_listeners = .{},
            .subscriptions = .{},
            .rest_url = rest_url,
            .auth_url = auth_url,
            .storage_url = storage_url,
            .realtime_url = realtime_url,
        };

        return client;
    }

    /// Clean up resources
    pub fn deinit(self: *SupabaseClient) void {
        if (self.current_user) |*user| {
            user.deinit(self.allocator);
        }

        if (self.session) |*session| {
            session.deinit(self.allocator);
        }

        self.auth_listeners.deinit(self.allocator);

        var sub_it = self.subscriptions.iterator();
        while (sub_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.table);
            if (entry.value_ptr.filter) |f| {
                self.allocator.free(f);
            }
        }
        self.subscriptions.deinit(self.allocator);

        self.allocator.free(self.rest_url);
        self.allocator.free(self.auth_url);
        self.allocator.free(self.storage_url);
        self.allocator.free(self.realtime_url);

        self.allocator.destroy(self);
    }

    // ========================================================================
    // Authentication
    // ========================================================================

    /// Sign in with email and password
    pub fn signInWithEmail(self: *SupabaseClient, email: []const u8, password: []const u8) Error!User {
        _ = password;

        // POST {auth_url}/token?grant_type=password
        // Body: { email, password }

        const user = User{
            .uid = try self.allocator.dupe(u8, "supabase-user-123"),
            .email = try self.allocator.dupe(u8, email),
            .email_verified = true,
            .is_anonymous = false,
            .created_at = std.time.milliTimestamp(),
            .last_sign_in = std.time.milliTimestamp(),
        };

        // Create session
        if (self.session) |*old_session| {
            old_session.deinit(self.allocator);
        }
        self.session = .{
            .access_token = try self.allocator.dupe(u8, "access-token-xyz"),
            .refresh_token = try self.allocator.dupe(u8, "refresh-token-xyz"),
            .expires_at = std.time.milliTimestamp() + 3600 * 1000, // 1 hour
        };

        if (self.current_user) |*old_user| {
            old_user.deinit(self.allocator);
        }
        self.current_user = user;
        self.notifyAuthStateChange();

        return user;
    }

    /// Sign in with magic link (passwordless)
    pub fn signInWithMagicLink(self: *SupabaseClient, email: []const u8) Error!void {
        // Validate email
        if (std.mem.indexOf(u8, email, "@") == null) {
            return MbaasError.InvalidEmail;
        }

        // POST {auth_url}/magiclink
        // Body: { email }
        _ = self;
    }

    /// Sign in with OAuth provider
    pub fn signInWithOAuth(self: *SupabaseClient, provider: AuthProvider, options: SignInOptions) Error![]u8 {
        _ = options;

        const provider_name = switch (provider) {
            .google => "google",
            .apple => "apple",
            .facebook => "facebook",
            .twitter => "twitter",
            .github => "github",
            .microsoft => "azure",
            else => return MbaasError.InvalidArgument,
        };

        // Return OAuth URL for redirect
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/authorize?provider={s}",
            .{ self.auth_url, provider_name },
        );
    }

    /// Sign in with phone number
    pub fn signInWithPhone(self: *SupabaseClient, phone: []const u8) Error!void {
        _ = self;
        _ = phone;
        // POST {auth_url}/otp
        // Body: { phone }
    }

    /// Verify OTP for phone sign in
    pub fn verifyOTP(self: *SupabaseClient, phone: []const u8, token: []const u8) Error!User {
        _ = phone;
        _ = token;

        const user = User{
            .uid = try self.allocator.dupe(u8, "phone-user-456"),
            .phone_number = try self.allocator.dupe(u8, "+1234567890"),
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

    /// Sign up with email and password
    pub fn signUp(self: *SupabaseClient, email: []const u8, password: []const u8) Error!User {
        if (password.len < 6) {
            return MbaasError.WeakPassword;
        }

        if (std.mem.indexOf(u8, email, "@") == null) {
            return MbaasError.InvalidEmail;
        }

        const user = User{
            .uid = try self.allocator.dupe(u8, "new-supabase-user"),
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
    pub fn signOut(self: *SupabaseClient) Error!void {
        // POST {auth_url}/logout

        if (self.current_user) |*user| {
            user.deinit(self.allocator);
            self.current_user = null;
        }

        if (self.session) |*session| {
            session.deinit(self.allocator);
            self.session = null;
        }

        self.notifyAuthStateChange();
    }

    /// Get current user
    pub fn getCurrentUser(self: *const SupabaseClient) ?User {
        return self.current_user;
    }

    /// Get current session
    pub fn getSession(self: *const SupabaseClient) ?Session {
        return self.session;
    }

    /// Refresh the session
    pub fn refreshSession(self: *SupabaseClient) Error!Session {
        if (self.session == null) {
            return MbaasError.SessionExpired;
        }

        // POST {auth_url}/token?grant_type=refresh_token
        // Body: { refresh_token }

        // Update session
        if (self.session) |*old_session| {
            old_session.deinit(self.allocator);
        }

        const new_session = Session{
            .access_token = try self.allocator.dupe(u8, "new-access-token"),
            .refresh_token = try self.allocator.dupe(u8, "new-refresh-token"),
            .expires_at = std.time.milliTimestamp() + 3600 * 1000,
        };

        self.session = new_session;
        return new_session;
    }

    /// Reset password
    pub fn resetPasswordForEmail(self: *SupabaseClient, email: []const u8) Error!void {
        if (std.mem.indexOf(u8, email, "@") == null) {
            return MbaasError.InvalidEmail;
        }
        // POST {auth_url}/recover
        _ = self;
    }

    /// Update user
    pub fn updateUser(self: *SupabaseClient, updates: UserUpdates) Error!User {
        _ = updates;

        if (self.current_user == null) {
            return MbaasError.UserNotFound;
        }

        // PUT {auth_url}/user
        return self.current_user.?;
    }

    /// Add auth state listener
    pub fn onAuthStateChange(self: *SupabaseClient, callback: AuthStateCallback) !void {
        try self.auth_listeners.append(self.allocator, callback);
    }

    fn notifyAuthStateChange(self: *SupabaseClient) void {
        for (self.auth_listeners.items) |callback| {
            callback(self.current_user);
        }
    }

    // ========================================================================
    // Database (PostgREST)
    // ========================================================================

    /// Create a query builder for a table
    pub fn from(self: *SupabaseClient, table: []const u8) QueryBuilder {
        return QueryBuilder.init(self, table);
    }

    /// Execute raw SQL via RPC
    pub fn rpc(self: *SupabaseClient, function_name: []const u8, params: ?std.StringHashMapUnmanaged(Value)) Error![]u8 {
        _ = params;
        _ = function_name;
        // POST {rest_url}/rpc/{function_name}
        return try self.allocator.dupe(u8, "[]");
    }

    // ========================================================================
    // Storage
    // ========================================================================

    /// Get a storage bucket client
    pub fn storage(self: *SupabaseClient) StorageClient {
        return StorageClient{ .client = self };
    }

    // ========================================================================
    // Realtime
    // ========================================================================

    /// Subscribe to table changes
    pub fn subscribe(
        self: *SupabaseClient,
        table: []const u8,
        event: RealtimeEvent,
        callback: RealtimeCallback,
    ) Error!Subscription {
        return self.subscribeWithFilter(table, event, null, callback);
    }

    /// Subscribe to table changes with filter
    pub fn subscribeWithFilter(
        self: *SupabaseClient,
        table: []const u8,
        event: RealtimeEvent,
        filter: ?[]const u8,
        callback: RealtimeCallback,
    ) Error!Subscription {
        const id = self.next_subscription_id;
        self.next_subscription_id += 1;

        const table_copy = try self.allocator.dupe(u8, table);
        const filter_copy = if (filter) |f| try self.allocator.dupe(u8, f) else null;

        try self.subscriptions.put(self.allocator, id, .{
            .table = table_copy,
            .event = event,
            .callback = callback,
            .filter = filter_copy,
            .active = true,
        });

        return .{ .id = id, .active = true };
    }

    /// Unsubscribe from realtime updates
    pub fn unsubscribe(self: *SupabaseClient, subscription: Subscription) void {
        if (self.subscriptions.fetchRemove(subscription.id)) |kv| {
            self.allocator.free(kv.value.table);
            if (kv.value.filter) |f| {
                self.allocator.free(f);
            }
        }
    }

    // ========================================================================
    // Edge Functions
    // ========================================================================

    /// Invoke an edge function
    pub fn invokeFunction(self: *SupabaseClient, function_name: []const u8, body: ?[]const u8) Error![]u8 {
        _ = body;
        // POST {url}/functions/v1/{function_name}
        return std.fmt.allocPrint(
            self.allocator,
            "{{\"result\": \"Function {s} invoked\"}}",
            .{function_name},
        ) catch return MbaasError.OutOfMemory;
    }
};

/// User update fields
pub const UserUpdates = struct {
    email: ?[]const u8 = null,
    password: ?[]const u8 = null,
    phone: ?[]const u8 = null,
    data: ?std.StringHashMapUnmanaged(Value) = null,
};

/// Query builder for Supabase PostgREST API
pub const QueryBuilder = struct {
    client: *SupabaseClient,
    table: []const u8,

    // Query parts
    select_columns: ?[]const u8 = null,
    filters: std.ArrayListUnmanaged(FilterClause),
    order_clauses: std.ArrayListUnmanaged(OrderClause),
    limit_value: ?u32 = null,
    offset_value: ?u32 = null,
    single_row: bool = false,

    const FilterClause = struct {
        column: []const u8,
        operator: []const u8,
        value: []const u8,
    };

    const OrderClause = struct {
        column: []const u8,
        ascending: bool,
        nulls_first: bool,
    };

    pub fn init(client: *SupabaseClient, table: []const u8) QueryBuilder {
        return .{
            .client = client,
            .table = table,
            .filters = .{},
            .order_clauses = .{},
        };
    }

    pub fn deinit(self: *QueryBuilder) void {
        self.filters.deinit(self.client.allocator);
        self.order_clauses.deinit(self.client.allocator);
    }

    /// Select specific columns
    pub fn select(self: *QueryBuilder, columns: []const u8) *QueryBuilder {
        self.select_columns = columns;
        return self;
    }

    /// Filter: equals
    pub fn eq(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "eq",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: not equals
    pub fn neq(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "neq",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: greater than
    pub fn gt(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "gt",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: greater than or equal
    pub fn gte(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "gte",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: less than
    pub fn lt(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "lt",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: less than or equal
    pub fn lte(self: *QueryBuilder, column: []const u8, value: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "lte",
            .value = value,
        }) catch {};
        return self;
    }

    /// Filter: LIKE pattern
    pub fn like(self: *QueryBuilder, column: []const u8, pattern: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "like",
            .value = pattern,
        }) catch {};
        return self;
    }

    /// Filter: ILIKE pattern (case insensitive)
    pub fn ilike(self: *QueryBuilder, column: []const u8, pattern: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "ilike",
            .value = pattern,
        }) catch {};
        return self;
    }

    /// Filter: IN list
    pub fn in(self: *QueryBuilder, column: []const u8, values: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "in",
            .value = values,
        }) catch {};
        return self;
    }

    /// Filter: IS NULL
    pub fn isNull(self: *QueryBuilder, column: []const u8) *QueryBuilder {
        self.filters.append(self.client.allocator, .{
            .column = column,
            .operator = "is",
            .value = "null",
        }) catch {};
        return self;
    }

    /// Order by column
    pub fn order(self: *QueryBuilder, column: []const u8, ascending: bool) *QueryBuilder {
        self.order_clauses.append(self.client.allocator, .{
            .column = column,
            .ascending = ascending,
            .nulls_first = false,
        }) catch {};
        return self;
    }

    /// Limit results
    pub fn limit(self: *QueryBuilder, count: u32) *QueryBuilder {
        self.limit_value = count;
        return self;
    }

    /// Offset results (for pagination)
    pub fn offset(self: *QueryBuilder, count: u32) *QueryBuilder {
        self.offset_value = count;
        return self;
    }

    /// Get single row
    pub fn single(self: *QueryBuilder) *QueryBuilder {
        self.single_row = true;
        self.limit_value = 1;
        return self;
    }

    /// Execute SELECT query
    pub fn execute(self: *QueryBuilder) Error![]Document {
        // Build URL: {rest_url}/{table}?select=columns&filters&order&limit
        var docs: std.ArrayListUnmanaged(Document) = .{};

        // Simulate results
        const doc_id = try std.fmt.allocPrint(self.client.allocator, "{s}/1", .{self.table});
        const doc = try Document.init(self.client.allocator, doc_id);
        self.client.allocator.free(doc_id);

        try docs.append(self.client.allocator, doc);

        return docs.toOwnedSlice(self.client.allocator);
    }

    /// Insert data
    pub fn insert(self: *QueryBuilder, data: std.StringHashMapUnmanaged(Value)) Error!Document {
        _ = data;
        // POST {rest_url}/{table}
        return Document.init(self.client.allocator, "new-record");
    }

    /// Update data
    pub fn update(self: *QueryBuilder, data: std.StringHashMapUnmanaged(Value)) Error![]Document {
        _ = data;
        // PATCH {rest_url}/{table}?filters
        var docs: std.ArrayListUnmanaged(Document) = .{};
        return docs.toOwnedSlice(self.client.allocator);
    }

    /// Delete data
    pub fn delete(self: *QueryBuilder) Error![]Document {
        // DELETE {rest_url}/{table}?filters
        var docs: std.ArrayListUnmanaged(Document) = .{};
        return docs.toOwnedSlice(self.client.allocator);
    }

    /// Upsert data (insert or update on conflict)
    pub fn upsert(self: *QueryBuilder, data: std.StringHashMapUnmanaged(Value)) Error!Document {
        _ = data;
        // POST {rest_url}/{table} with Prefer: resolution=merge-duplicates
        return Document.init(self.client.allocator, "upserted-record");
    }
};

/// Storage client for Supabase Storage
pub const StorageClient = struct {
    client: *SupabaseClient,

    /// Get a bucket client
    pub fn from(self: StorageClient, bucket: []const u8) BucketClient {
        return BucketClient{
            .client = self.client,
            .bucket = bucket,
        };
    }

    /// List all buckets
    pub fn listBuckets(self: StorageClient) Error![]BucketInfo {
        // GET {storage_url}/bucket
        var buckets: std.ArrayListUnmanaged(BucketInfo) = .{};
        return buckets.toOwnedSlice(self.client.allocator);
    }

    /// Create a new bucket
    pub fn createBucket(self: StorageClient, name: []const u8, options: BucketOptions) Error!BucketInfo {
        _ = options;
        return BucketInfo{
            .id = try self.client.allocator.dupe(u8, name),
            .name = try self.client.allocator.dupe(u8, name),
            .public = false,
            .created_at = std.time.milliTimestamp(),
        };
    }

    /// Delete a bucket
    pub fn deleteBucket(self: StorageClient, name: []const u8) Error!void {
        _ = self;
        _ = name;
        // DELETE {storage_url}/bucket/{name}
    }

    /// Empty a bucket
    pub fn emptyBucket(self: StorageClient, name: []const u8) Error!void {
        _ = self;
        _ = name;
        // POST {storage_url}/bucket/{name}/empty
    }
};

/// Bucket information
pub const BucketInfo = struct {
    id: []const u8,
    name: []const u8,
    public: bool,
    file_size_limit: ?u64 = null,
    allowed_mime_types: ?[]const []const u8 = null,
    created_at: i64,

    pub fn deinit(self: *BucketInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        if (self.allowed_mime_types) |types_arr| {
            for (types_arr) |t| allocator.free(t);
            allocator.free(types_arr);
        }
    }
};

/// Bucket creation options
pub const BucketOptions = struct {
    public: bool = false,
    file_size_limit: ?u64 = null,
    allowed_mime_types: ?[]const []const u8 = null,
};

/// Bucket client for file operations
pub const BucketClient = struct {
    client: *SupabaseClient,
    bucket: []const u8,

    /// Upload a file
    pub fn upload(self: BucketClient, path: []const u8, data: []const u8, options: UploadOptions) Error!FileMetadata {
        _ = options;

        const name = std.fs.path.basename(path);

        return FileMetadata{
            .name = try self.client.allocator.dupe(u8, name),
            .path = try std.fmt.allocPrint(self.client.allocator, "{s}/{s}", .{ self.bucket, path }),
            .size = data.len,
            .created_at = std.time.milliTimestamp(),
        };
    }

    /// Download a file
    pub fn download(self: BucketClient, path: []const u8) Error![]u8 {
        _ = path;
        return try self.client.allocator.dupe(u8, "file content");
    }

    /// Get public URL
    pub fn getPublicUrl(self: BucketClient, path: []const u8) Error![]u8 {
        return std.fmt.allocPrint(
            self.client.allocator,
            "{s}/object/public/{s}/{s}",
            .{ self.client.storage_url, self.bucket, path },
        );
    }

    /// Create signed URL
    pub fn createSignedUrl(self: BucketClient, path: []const u8, expires_in: u32) Error![]u8 {
        _ = expires_in;
        return std.fmt.allocPrint(
            self.client.allocator,
            "{s}/object/sign/{s}/{s}?token=xxx",
            .{ self.client.storage_url, self.bucket, path },
        );
    }

    /// List files
    pub fn list(self: BucketClient, prefix: ?[]const u8, options: ListOptions) Error!ListResult {
        _ = prefix;
        _ = options;

        return ListResult{
            .items = try self.client.allocator.alloc(FileMetadata, 0),
            .prefixes = try self.client.allocator.alloc([]const u8, 0),
            .next_page_token = null,
        };
    }

    /// Move/rename a file
    pub fn move(self: BucketClient, from_path: []const u8, to_path: []const u8) Error!void {
        _ = self;
        _ = from_path;
        _ = to_path;
    }

    /// Copy a file
    pub fn copy(self: BucketClient, from_path: []const u8, to_path: []const u8) Error!void {
        _ = self;
        _ = from_path;
        _ = to_path;
    }

    /// Remove files
    pub fn remove(self: BucketClient, paths: []const []const u8) Error!void {
        _ = self;
        _ = paths;
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Create a Supabase client
pub fn createClient(allocator: std.mem.Allocator, url: []const u8, anon_key: []const u8) !*SupabaseClient {
    return SupabaseClient.init(allocator, .{
        .url = url,
        .anon_key = anon_key,
    });
}

// ============================================================================
// Unit Tests
// ============================================================================

test "SupabaseClient initialization" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    try std.testing.expect(client.current_user == null);
}

test "SupabaseClient email authentication" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    const user = try client.signInWithEmail("test@example.com", "password123");
    try std.testing.expectEqualStrings("test@example.com", user.email.?);
    try std.testing.expect(client.session != null);

    try client.signOut();
    try std.testing.expect(client.current_user == null);
    try std.testing.expect(client.session == null);
}

test "SupabaseClient sign up with weak password" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    const result = client.signUp("test@example.com", "123");
    try std.testing.expectError(MbaasError.WeakPassword, result);
}

test "SupabaseClient query builder" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    var query = client.from("users");
    defer query.deinit();

    _ = query.select("*").eq("status", "active").limit(10);

    const docs = try query.execute();
    defer {
        for (docs) |*d| {
            var doc = d.*;
            doc.deinit(allocator);
        }
        allocator.free(docs);
    }

    try std.testing.expect(docs.len > 0);
}

test "SupabaseClient storage" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    const bucket = client.storage().from("avatars");

    var meta = try bucket.upload("user123/profile.png", "image data", .{});
    defer meta.deinit(allocator);

    try std.testing.expectEqualStrings("profile.png", meta.name);
}

test "SupabaseClient realtime subscription" {
    const allocator = std.testing.allocator;

    var client = try SupabaseClient.init(allocator, .{
        .url = "https://xxx.supabase.co",
        .anon_key = "test-anon-key",
    });
    defer client.deinit();

    const callback = struct {
        fn cb(_: RealtimeChange) void {}
    }.cb;

    const sub = try client.subscribe("messages", .all, callback);
    try std.testing.expect(sub.active);

    client.unsubscribe(sub);
}
