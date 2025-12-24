//! Zylix mBaaS - Type Definitions
//!
//! Common types for mBaaS (mobile Backend as a Service) integrations.
//! Provides unified interfaces for Firebase, Supabase, and AWS Amplify.

const std = @import("std");

/// mBaaS provider type
pub const Provider = enum {
    firebase,
    supabase,
    amplify,
};

/// mBaaS error types
pub const MbaasError = error{
    /// Authentication errors
    AuthenticationFailed,
    InvalidCredentials,
    UserNotFound,
    EmailAlreadyInUse,
    WeakPassword,
    InvalidEmail,
    TokenExpired,
    TokenInvalid,
    SessionExpired,

    /// Database errors
    DocumentNotFound,
    CollectionNotFound,
    PermissionDenied,
    QueryError,
    WriteConflict,
    TransactionFailed,

    /// Storage errors
    FileNotFound,
    BucketNotFound,
    UploadFailed,
    DownloadFailed,
    QuotaExceeded,
    InvalidPath,

    /// Network errors
    NetworkError,
    Timeout,
    ServiceUnavailable,
    RateLimited,

    /// Configuration errors
    InvalidConfiguration,
    MissingApiKey,
    InvalidProjectId,

    /// General errors
    Unknown,
    NotImplemented,
    InvalidArgument,
    OutOfMemory,
};

/// Combined error type
pub const Error = MbaasError || std.mem.Allocator.Error;

// ============================================================================
// Authentication Types
// ============================================================================

/// Authentication provider for social login
pub const AuthProvider = enum {
    email,
    google,
    apple,
    facebook,
    twitter,
    github,
    microsoft,
    phone,
    anonymous,
    custom_token,
};

/// User information
pub const User = struct {
    /// Unique user identifier
    uid: []const u8,

    /// User email (may be null for anonymous/phone users)
    email: ?[]const u8 = null,

    /// Display name
    display_name: ?[]const u8 = null,

    /// Profile photo URL
    photo_url: ?[]const u8 = null,

    /// Phone number
    phone_number: ?[]const u8 = null,

    /// Whether email is verified
    email_verified: bool = false,

    /// Whether user is anonymous
    is_anonymous: bool = false,

    /// Provider-specific data
    provider_data: ?[]const u8 = null,

    /// Creation timestamp (Unix milliseconds)
    created_at: ?i64 = null,

    /// Last sign-in timestamp (Unix milliseconds)
    last_sign_in: ?i64 = null,

    /// Custom claims (JSON)
    custom_claims: ?[]const u8 = null,

    /// ID token for authenticated requests
    id_token: ?[]const u8 = null,

    /// Refresh token for session renewal
    refresh_token: ?[]const u8 = null,

    pub fn deinit(self: *User, allocator: std.mem.Allocator) void {
        if (self.uid.len > 0) allocator.free(self.uid);
        if (self.email) |e| allocator.free(e);
        if (self.display_name) |d| allocator.free(d);
        if (self.photo_url) |p| allocator.free(p);
        if (self.phone_number) |ph| allocator.free(ph);
        if (self.provider_data) |pd| allocator.free(pd);
        if (self.custom_claims) |c| allocator.free(c);
        if (self.id_token) |t| allocator.free(t);
        if (self.refresh_token) |r| allocator.free(r);
    }
};

/// Authentication state
pub const AuthState = enum {
    signed_out,
    signed_in,
    loading,
    error_state,
};

/// Sign-in options
pub const SignInOptions = struct {
    /// Remember the user across sessions
    remember: bool = true,

    /// Scopes for OAuth providers
    scopes: ?[]const []const u8 = null,

    /// Custom parameters for OAuth
    custom_parameters: ?[]const u8 = null,
};

/// Password reset options
pub const PasswordResetOptions = struct {
    /// URL to redirect after password reset
    continue_url: ?[]const u8 = null,

    /// Handle code in app
    handle_code_in_app: bool = false,
};

// ============================================================================
// Database Types
// ============================================================================

/// Document data value
pub const Value = union(enum) {
    null_value: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    bytes: []const u8,
    timestamp: i64,
    array: []const Value,
    map: std.StringHashMapUnmanaged(Value),
    reference: []const u8,
    geo_point: GeoPoint,

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .bytes => |b| allocator.free(b),
            .reference => |r| allocator.free(r),
            .array => |arr| {
                for (arr) |*v| {
                    var value = v.*;
                    value.deinit(allocator);
                }
                allocator.free(arr);
            },
            .map => |*m| {
                var it = m.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    var value = entry.value_ptr.*;
                    value.deinit(allocator);
                }
                m.deinit(allocator);
            },
            else => {},
        }
    }
};

/// Geographic point
pub const GeoPoint = struct {
    latitude: f64,
    longitude: f64,
};

/// Document representation
pub const Document = struct {
    /// Document path/ID
    id: []const u8,

    /// Document data fields
    data: std.StringHashMapUnmanaged(Value),

    /// Creation timestamp
    created_at: ?i64 = null,

    /// Last update timestamp
    updated_at: ?i64 = null,

    /// Document exists flag
    exists: bool = true,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Document {
        const id_copy = try allocator.dupe(u8, id);
        return .{
            .id = id_copy,
            .data = .{},
        };
    }

    pub fn deinit(self: *Document, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        var it = self.data.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            var value = entry.value_ptr.*;
            value.deinit(allocator);
        }
        self.data.deinit(allocator);
    }

    pub fn get(self: *const Document, key: []const u8) ?Value {
        return self.data.get(key);
    }

    pub fn getString(self: *const Document, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |value| {
            switch (value) {
                .string => |s| return s,
                else => return null,
            }
        }
        return null;
    }

    pub fn getInt(self: *const Document, key: []const u8) ?i64 {
        if (self.data.get(key)) |value| {
            switch (value) {
                .integer => |i| return i,
                else => return null,
            }
        }
        return null;
    }

    pub fn getBool(self: *const Document, key: []const u8) ?bool {
        if (self.data.get(key)) |value| {
            switch (value) {
                .boolean => |b| return b,
                else => return null,
            }
        }
        return null;
    }
};

/// Query filter operator
pub const FilterOperator = enum {
    equal,
    not_equal,
    less_than,
    less_than_or_equal,
    greater_than,
    greater_than_or_equal,
    array_contains,
    array_contains_any,
    in_list,
    not_in_list,
};

/// Query filter
pub const Filter = struct {
    field: []const u8,
    operator: FilterOperator,
    value: Value,
};

/// Sort direction
pub const SortDirection = enum {
    ascending,
    descending,
};

/// Query order
pub const OrderBy = struct {
    field: []const u8,
    direction: SortDirection = .ascending,
};

/// Query options
pub const QueryOptions = struct {
    /// Filters to apply
    filters: ?[]const Filter = null,

    /// Order by clauses
    order_by: ?[]const OrderBy = null,

    /// Maximum documents to return
    limit: ?u32 = null,

    /// Number of documents to skip
    offset: ?u32 = null,

    /// Start after document ID
    start_after: ?[]const u8 = null,

    /// Start at document ID
    start_at: ?[]const u8 = null,

    /// End before document ID
    end_before: ?[]const u8 = null,

    /// End at document ID
    end_at: ?[]const u8 = null,
};

/// Write operation type
pub const WriteOperation = enum {
    set,
    update,
    delete,
    merge,
};

/// Batch write operation
pub const BatchOperation = struct {
    operation: WriteOperation,
    path: []const u8,
    data: ?std.StringHashMapUnmanaged(Value) = null,
};

/// Transaction options
pub const TransactionOptions = struct {
    /// Maximum number of attempts
    max_attempts: u8 = 5,

    /// Timeout in milliseconds
    timeout_ms: u32 = 30000,
};

// ============================================================================
// Storage Types
// ============================================================================

/// File metadata
pub const FileMetadata = struct {
    /// File name
    name: []const u8,

    /// Full path in storage
    path: []const u8,

    /// MIME type
    content_type: ?[]const u8 = null,

    /// File size in bytes
    size: u64 = 0,

    /// MD5 hash
    md5_hash: ?[]const u8 = null,

    /// Creation timestamp
    created_at: ?i64 = null,

    /// Last update timestamp
    updated_at: ?i64 = null,

    /// Custom metadata
    custom_metadata: ?std.StringHashMapUnmanaged([]const u8) = null,

    /// Download URL
    download_url: ?[]const u8 = null,

    pub fn deinit(self: *FileMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.path);
        if (self.content_type) |ct| allocator.free(ct);
        if (self.md5_hash) |h| allocator.free(h);
        if (self.download_url) |u| allocator.free(u);
        if (self.custom_metadata) |*m| {
            var it = m.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            m.deinit(allocator);
        }
    }
};

/// Upload options
pub const UploadOptions = struct {
    /// MIME content type
    content_type: ?[]const u8 = null,

    /// Custom metadata
    custom_metadata: ?std.StringHashMapUnmanaged([]const u8) = null,

    /// Cache control header
    cache_control: ?[]const u8 = null,

    /// Content encoding
    content_encoding: ?[]const u8 = null,

    /// Content disposition
    content_disposition: ?[]const u8 = null,
};

/// Upload progress
pub const UploadProgress = struct {
    /// Bytes transferred
    bytes_transferred: u64,

    /// Total bytes
    total_bytes: u64,

    /// Progress percentage (0-100)
    percentage: f32,

    /// Upload state
    state: UploadState,
};

/// Upload state
pub const UploadState = enum {
    pending,
    running,
    paused,
    success,
    cancelled,
    error_state,
};

/// Download options
pub const DownloadOptions = struct {
    /// Maximum size in bytes (0 = unlimited)
    max_size: u64 = 0,
};

/// List options for storage
pub const ListOptions = struct {
    /// Maximum items to return
    max_results: u32 = 100,

    /// Page token for pagination
    page_token: ?[]const u8 = null,

    /// Delimiter for folder simulation
    delimiter: ?[]const u8 = null,
};

/// List result
pub const ListResult = struct {
    /// Items in current page
    items: []FileMetadata,

    /// Prefixes (folders)
    prefixes: [][]const u8,

    /// Token for next page
    next_page_token: ?[]const u8,

    pub fn deinit(self: *ListResult, allocator: std.mem.Allocator) void {
        for (self.items) |*item| {
            item.deinit(allocator);
        }
        allocator.free(self.items);
        for (self.prefixes) |p| {
            allocator.free(p);
        }
        allocator.free(self.prefixes);
        if (self.next_page_token) |t| allocator.free(t);
    }
};

// ============================================================================
// Realtime / Push Notification Types
// ============================================================================

/// Subscription for realtime updates
pub const Subscription = struct {
    id: u64,
    active: bool = true,

    pub fn unsubscribe(self: *Subscription) void {
        self.active = false;
    }
};

/// Realtime event type
pub const RealtimeEventType = enum {
    added,
    modified,
    removed,
};

/// Realtime change event
pub const RealtimeChange = struct {
    event_type: RealtimeEventType,
    document: Document,
    old_document: ?Document = null,
};

/// Push notification message
pub const NotificationMessage = struct {
    /// Notification title
    title: ?[]const u8 = null,

    /// Notification body
    body: ?[]const u8 = null,

    /// Image URL
    image_url: ?[]const u8 = null,

    /// Custom data payload (JSON)
    data: ?[]const u8 = null,

    /// Topic to send to
    topic: ?[]const u8 = null,

    /// Specific device token
    token: ?[]const u8 = null,

    /// Condition for targeting
    condition: ?[]const u8 = null,

    /// Android-specific options
    android_config: ?AndroidNotificationConfig = null,

    /// iOS-specific options (APNs)
    apns_config: ?ApnsNotificationConfig = null,

    /// Web push options
    webpush_config: ?WebPushConfig = null,
};

/// Android notification configuration
pub const AndroidNotificationConfig = struct {
    /// Channel ID
    channel_id: ?[]const u8 = null,

    /// Notification icon
    icon: ?[]const u8 = null,

    /// Notification color
    color: ?[]const u8 = null,

    /// Click action
    click_action: ?[]const u8 = null,

    /// Priority
    priority: AndroidPriority = .normal,
};

/// Android notification priority
pub const AndroidPriority = enum {
    normal,
    high,
};

/// APNs (iOS) notification configuration
pub const ApnsNotificationConfig = struct {
    /// Badge count
    badge: ?u32 = null,

    /// Sound
    sound: ?[]const u8 = null,

    /// Content available for background updates
    content_available: bool = false,

    /// Mutable content for notification extensions
    mutable_content: bool = false,

    /// Category for actionable notifications
    category: ?[]const u8 = null,
};

/// Web push configuration
pub const WebPushConfig = struct {
    /// Icon URL
    icon: ?[]const u8 = null,

    /// Badge URL
    badge: ?[]const u8 = null,

    /// Require interaction
    require_interaction: bool = false,

    /// Vibration pattern
    vibrate: ?[]const u32 = null,
};

// ============================================================================
// Configuration Types
// ============================================================================

/// Firebase configuration
pub const FirebaseConfig = struct {
    /// Firebase project ID
    project_id: []const u8,

    /// API key
    api_key: []const u8,

    /// App ID
    app_id: ?[]const u8 = null,

    /// Messaging sender ID
    messaging_sender_id: ?[]const u8 = null,

    /// Storage bucket
    storage_bucket: ?[]const u8 = null,

    /// Auth domain
    auth_domain: ?[]const u8 = null,

    /// Database URL
    database_url: ?[]const u8 = null,

    /// Measurement ID (Analytics)
    measurement_id: ?[]const u8 = null,
};

/// Supabase configuration
pub const SupabaseConfig = struct {
    /// Supabase project URL
    url: []const u8,

    /// Anon/public key
    anon_key: []const u8,

    /// Service role key (server-side only)
    service_role_key: ?[]const u8 = null,

    /// Custom schema
    schema: []const u8 = "public",

    /// Auto refresh token
    auto_refresh_token: bool = true,

    /// Persist session
    persist_session: bool = true,

    /// Storage key for session
    storage_key: []const u8 = "supabase.auth.token",
};

/// AWS Amplify configuration
pub const AmplifyConfig = struct {
    /// AWS Region
    region: []const u8,

    /// Cognito User Pool ID
    user_pool_id: ?[]const u8 = null,

    /// Cognito User Pool Client ID
    user_pool_client_id: ?[]const u8 = null,

    /// Cognito Identity Pool ID
    identity_pool_id: ?[]const u8 = null,

    /// S3 bucket name
    s3_bucket: ?[]const u8 = null,

    /// AppSync API endpoint
    appsync_endpoint: ?[]const u8 = null,

    /// AppSync API key
    appsync_api_key: ?[]const u8 = null,

    /// AppSync authentication type
    appsync_auth_type: AmplifyAuthType = .api_key,
};

/// Amplify authentication type
pub const AmplifyAuthType = enum {
    api_key,
    aws_iam,
    openid_connect,
    amazon_cognito_user_pools,
};

// ============================================================================
// Callback Types
// ============================================================================

/// Auth state change callback
pub const AuthStateCallback = *const fn (?User) void;

/// Realtime data callback
pub const RealtimeCallback = *const fn (RealtimeChange) void;

/// Upload progress callback
pub const UploadProgressCallback = *const fn (UploadProgress) void;

/// Error callback
pub const ErrorCallback = *const fn (MbaasError) void;

// ============================================================================
// Unit Tests
// ============================================================================

test "User initialization and deinit" {
    const allocator = std.testing.allocator;

    var user = User{
        .uid = try allocator.dupe(u8, "test-uid-123"),
        .email = try allocator.dupe(u8, "test@example.com"),
        .display_name = try allocator.dupe(u8, "Test User"),
    };
    defer user.deinit(allocator);

    try std.testing.expectEqualStrings("test-uid-123", user.uid);
    try std.testing.expectEqualStrings("test@example.com", user.email.?);
    try std.testing.expectEqualStrings("Test User", user.display_name.?);
}

test "Document creation and access" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator, "users/user123");
    defer doc.deinit(allocator);

    try std.testing.expectEqualStrings("users/user123", doc.id);
    try std.testing.expect(doc.exists);
}

test "Value types" {
    const str_val = Value{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", str_val.string);

    const int_val = Value{ .integer = 42 };
    try std.testing.expectEqual(@as(i64, 42), int_val.integer);

    const bool_val = Value{ .boolean = true };
    try std.testing.expect(bool_val.boolean);

    const float_val = Value{ .float = 3.14 };
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), float_val.float, 0.001);
}

test "GeoPoint" {
    const point = GeoPoint{
        .latitude = 37.7749,
        .longitude = -122.4194,
    };
    try std.testing.expectApproxEqAbs(@as(f64, 37.7749), point.latitude, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, -122.4194), point.longitude, 0.0001);
}

test "Filter operators" {
    const filter = Filter{
        .field = "age",
        .operator = .greater_than,
        .value = .{ .integer = 18 },
    };
    try std.testing.expectEqualStrings("age", filter.field);
    try std.testing.expectEqual(FilterOperator.greater_than, filter.operator);
}

test "FileMetadata basic" {
    const allocator = std.testing.allocator;

    var meta = FileMetadata{
        .name = try allocator.dupe(u8, "test.txt"),
        .path = try allocator.dupe(u8, "/uploads/test.txt"),
        .size = 1024,
    };
    defer meta.deinit(allocator);

    try std.testing.expectEqualStrings("test.txt", meta.name);
    try std.testing.expectEqual(@as(u64, 1024), meta.size);
}

test "NotificationMessage" {
    const msg = NotificationMessage{
        .title = "Hello",
        .body = "World",
        .topic = "news",
    };
    try std.testing.expectEqualStrings("Hello", msg.title.?);
    try std.testing.expectEqualStrings("World", msg.body.?);
}

test "Configuration types" {
    const firebase_config = FirebaseConfig{
        .project_id = "my-project",
        .api_key = "AIzaSy...",
    };
    try std.testing.expectEqualStrings("my-project", firebase_config.project_id);

    const supabase_config = SupabaseConfig{
        .url = "https://xxx.supabase.co",
        .anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    };
    try std.testing.expectEqualStrings("public", supabase_config.schema);

    const amplify_config = AmplifyConfig{
        .region = "us-east-1",
    };
    try std.testing.expectEqual(AmplifyAuthType.api_key, amplify_config.appsync_auth_type);
}
