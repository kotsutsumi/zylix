//! Zylix Edge - Google Cloud Run Adapter
//!
//! Deploy Zylix applications to Google Cloud Run with access to:
//! - Cloud Firestore
//! - Cloud Storage
//! - Pub/Sub
//! - Cloud Tasks
//! - Secret Manager

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;

/// Google Cloud Run configuration
pub const GCPConfig = struct {
    /// Project ID
    project_id: []const u8 = "",

    /// Region
    region: Region = .us_central1,

    /// Service name
    service_name: []const u8 = "",

    /// Min instances (0 for scale to zero)
    min_instances: u32 = 0,

    /// Max instances
    max_instances: u32 = 100,

    /// Memory limit (MB)
    memory_mb: u32 = 512,

    /// CPU limit
    cpu: f32 = 1.0,

    /// Timeout in seconds
    timeout_seconds: u32 = 300,

    pub const Region = enum {
        us_central1,
        us_east1,
        us_west1,
        europe_west1,
        europe_west2,
        asia_east1,
        asia_northeast1,
        asia_southeast1,
        australia_southeast1,
        southamerica_east1,

        pub fn toString(self: Region) []const u8 {
            return switch (self) {
                .us_central1 => "us-central1",
                .us_east1 => "us-east1",
                .us_west1 => "us-west1",
                .europe_west1 => "europe-west1",
                .europe_west2 => "europe-west2",
                .asia_east1 => "asia-east1",
                .asia_northeast1 => "asia-northeast1",
                .asia_southeast1 => "asia-southeast1",
                .australia_southeast1 => "australia-southeast1",
                .southamerica_east1 => "southamerica-east1",
            };
        }
    };
};

/// Cloud Firestore client (simplified)
pub const FirestoreClient = struct {
    allocator: std.mem.Allocator,
    project_id: []const u8,

    // Local storage for simulation
    collections: std.StringHashMapUnmanaged(Collection),

    const Collection = struct {
        documents: std.StringHashMapUnmanaged([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator, project_id: []const u8) !*FirestoreClient {
        const client = try allocator.create(FirestoreClient);
        client.* = .{
            .allocator = allocator,
            .project_id = try allocator.dupe(u8, project_id),
            .collections = .{},
        };
        return client;
    }

    pub fn deinit(self: *FirestoreClient) void {
        var col_it = self.collections.iterator();
        while (col_it.next()) |col_entry| {
            self.allocator.free(col_entry.key_ptr.*);
            var doc_it = col_entry.value_ptr.documents.iterator();
            while (doc_it.next()) |doc_entry| {
                self.allocator.free(doc_entry.key_ptr.*);
                self.allocator.free(doc_entry.value_ptr.*);
            }
            col_entry.value_ptr.documents.deinit(self.allocator);
        }
        self.collections.deinit(self.allocator);
        self.allocator.free(self.project_id);
        self.allocator.destroy(self);
    }

    /// Get document
    pub fn getDocument(self: *FirestoreClient, collection: []const u8, doc_id: []const u8) !?[]const u8 {
        if (self.collections.get(collection)) |col| {
            return col.documents.get(doc_id);
        }
        return null;
    }

    /// Set document
    pub fn setDocument(self: *FirestoreClient, collection: []const u8, doc_id: []const u8, data: []const u8) !void {
        const col = self.collections.getPtr(collection) orelse blk: {
            const col_key = try self.allocator.dupe(u8, collection);
            errdefer self.allocator.free(col_key);
            try self.collections.put(self.allocator, col_key, .{ .documents = .{} });
            break :blk self.collections.getPtr(col_key).?;
        };

        if (col.documents.fetchRemove(doc_id)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const doc_key = try self.allocator.dupe(u8, doc_id);
        errdefer self.allocator.free(doc_key);
        const data_copy = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(data_copy);

        try col.documents.put(self.allocator, doc_key, data_copy);
    }

    /// Delete document
    pub fn deleteDocument(self: *FirestoreClient, collection: []const u8, doc_id: []const u8) !void {
        if (self.collections.getPtr(collection)) |col| {
            if (col.documents.fetchRemove(doc_id)) |old| {
                self.allocator.free(old.key);
                self.allocator.free(old.value);
            }
        }
    }

    /// Query documents (simplified - returns all in collection)
    pub fn query(self: *FirestoreClient, collection: []const u8) !QueryResult {
        var docs = std.ArrayList(Document).init(self.allocator);
        errdefer docs.deinit();

        if (self.collections.get(collection)) |col| {
            var it = col.documents.iterator();
            while (it.next()) |entry| {
                try docs.append(.{
                    .id = entry.key_ptr.*,
                    .data = entry.value_ptr.*,
                });
            }
        }

        return .{
            .documents = try docs.toOwnedSlice(),
        };
    }

    pub const Document = struct {
        id: []const u8,
        data: []const u8,
    };

    pub const QueryResult = struct {
        documents: []const Document,
    };
};

/// Cloud Storage client (simplified)
pub const CloudStorageClient = struct {
    allocator: std.mem.Allocator,
    bucket_name: []const u8,

    // Local storage for simulation
    objects: std.StringHashMapUnmanaged(ObjectData),

    const ObjectData = struct {
        content: []const u8,
        content_type: []const u8,
        metadata: std.StringHashMapUnmanaged([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator, bucket_name: []const u8) !*CloudStorageClient {
        const client = try allocator.create(CloudStorageClient);
        client.* = .{
            .allocator = allocator,
            .bucket_name = try allocator.dupe(u8, bucket_name),
            .objects = .{},
        };
        return client;
    }

    pub fn deinit(self: *CloudStorageClient) void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.content);
            self.allocator.free(entry.value_ptr.content_type);
            var meta = entry.value_ptr.metadata;
            meta.deinit(self.allocator);
        }
        self.objects.deinit(self.allocator);
        self.allocator.free(self.bucket_name);
        self.allocator.destroy(self);
    }

    /// Download object
    pub fn download(self: *CloudStorageClient, object_name: []const u8) !?ObjectData {
        return self.objects.get(object_name);
    }

    /// Upload object
    pub fn upload(self: *CloudStorageClient, object_name: []const u8, content: []const u8, content_type: []const u8) !void {
        if (self.objects.fetchRemove(object_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.content);
            self.allocator.free(old.value.content_type);
            var meta = old.value.metadata;
            meta.deinit(self.allocator);
        }

        const name_copy = try self.allocator.dupe(u8, object_name);
        errdefer self.allocator.free(name_copy);
        const content_copy = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(content_copy);
        const ct_copy = try self.allocator.dupe(u8, content_type);
        errdefer self.allocator.free(ct_copy);

        try self.objects.put(self.allocator, name_copy, .{
            .content = content_copy,
            .content_type = ct_copy,
            .metadata = .{},
        });
    }

    /// Delete object
    pub fn delete(self: *CloudStorageClient, object_name: []const u8) !void {
        if (self.objects.fetchRemove(object_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.content);
            self.allocator.free(old.value.content_type);
            var meta = old.value.metadata;
            meta.deinit(self.allocator);
        }
    }

    /// List objects
    pub fn list(self: *CloudStorageClient, prefix: ?[]const u8) !ListResult {
        var names = std.ArrayList([]const u8).init(self.allocator);
        errdefer names.deinit();

        var it = self.objects.iterator();
        while (it.next()) |entry| {
            if (prefix) |p| {
                if (!std.mem.startsWith(u8, entry.key_ptr.*, p)) continue;
            }
            try names.append(entry.key_ptr.*);
        }

        return .{
            .objects = try names.toOwnedSlice(),
        };
    }

    pub const ListResult = struct {
        objects: []const []const u8,
    };
};

/// Pub/Sub client (simplified)
pub const PubSubClient = struct {
    allocator: std.mem.Allocator,
    project_id: []const u8,

    // Local storage for simulation
    topics: std.StringHashMapUnmanaged(Topic),

    const Topic = struct {
        messages: std.ArrayList(Message),
        subscriptions: std.ArrayList(Subscription),
    };

    const Message = struct {
        data: []const u8,
        attributes: std.StringHashMapUnmanaged([]const u8),
        publish_time: i64,
    };

    const Subscription = struct {
        name: []const u8,
        handler: ?*const fn ([]const u8) void,
    };

    pub fn init(allocator: std.mem.Allocator, project_id: []const u8) !*PubSubClient {
        const client = try allocator.create(PubSubClient);
        client.* = .{
            .allocator = allocator,
            .project_id = try allocator.dupe(u8, project_id),
            .topics = .{},
        };
        return client;
    }

    pub fn deinit(self: *PubSubClient) void {
        var it = self.topics.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.messages.items) |msg| {
                self.allocator.free(msg.data);
                var attrs = msg.attributes;
                attrs.deinit(self.allocator);
            }
            entry.value_ptr.messages.deinit(self.allocator);
            for (entry.value_ptr.subscriptions.items) |sub| {
                self.allocator.free(sub.name);
            }
            entry.value_ptr.subscriptions.deinit(self.allocator);
        }
        self.topics.deinit(self.allocator);
        self.allocator.free(self.project_id);
        self.allocator.destroy(self);
    }

    /// Create topic
    pub fn createTopic(self: *PubSubClient, topic_name: []const u8) !void {
        if (self.topics.get(topic_name) != null) return;

        const name_copy = try self.allocator.dupe(u8, topic_name);
        errdefer self.allocator.free(name_copy);

        try self.topics.put(self.allocator, name_copy, .{
            .messages = std.ArrayList(Message).init(self.allocator),
            .subscriptions = std.ArrayList(Subscription).init(self.allocator),
        });
    }

    /// Publish message
    pub fn publish(self: *PubSubClient, topic_name: []const u8, data: []const u8) !void {
        const topic = self.topics.getPtr(topic_name) orelse return error.TopicNotFound;

        const data_copy = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(data_copy);

        try topic.messages.append(.{
            .data = data_copy,
            .attributes = .{},
            .publish_time = std.time.milliTimestamp(),
        });

        // Notify subscribers
        for (topic.subscriptions.items) |sub| {
            if (sub.handler) |handler| {
                handler(data);
            }
        }
    }

    /// Subscribe to topic
    pub fn subscribe(self: *PubSubClient, topic_name: []const u8, subscription_name: []const u8, handler: ?*const fn ([]const u8) void) !void {
        const topic = self.topics.getPtr(topic_name) orelse return error.TopicNotFound;

        const name_copy = try self.allocator.dupe(u8, subscription_name);
        errdefer self.allocator.free(name_copy);

        try topic.subscriptions.append(.{
            .name = name_copy,
            .handler = handler,
        });
    }

    pub const TopicNotFound = error.TopicNotFound;
};

/// Google Cloud Run adapter
pub const GCPAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    gcp_config: GCPConfig,
    firestore: ?*FirestoreClient,
    storage: ?*CloudStorageClient,
    pubsub: ?*PubSubClient,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) GCPAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .gcp },
            .gcp_config = .{},
            .firestore = null,
            .storage = null,
            .pubsub = null,
            .app = null,
        };
    }

    pub fn deinit(self: *GCPAdapter) void {
        if (self.firestore) |fs| fs.deinit();
        if (self.storage) |st| st.deinit();
        if (self.pubsub) |ps| ps.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *GCPAdapter, app: *server.Zylix) *GCPAdapter {
        self.app = app;
        return self;
    }

    /// Set project ID
    pub fn withProject(self: *GCPAdapter, project_id: []const u8) *GCPAdapter {
        self.gcp_config.project_id = project_id;
        return self;
    }

    /// Set region
    pub fn withRegion(self: *GCPAdapter, region: GCPConfig.Region) *GCPAdapter {
        self.gcp_config.region = region;
        return self;
    }

    /// Configure Firestore
    pub fn withFirestore(self: *GCPAdapter, project_id: []const u8) !*GCPAdapter {
        self.firestore = try FirestoreClient.init(self.allocator, project_id);
        return self;
    }

    /// Configure Cloud Storage
    pub fn withStorage(self: *GCPAdapter, bucket_name: []const u8) !*GCPAdapter {
        self.storage = try CloudStorageClient.init(self.allocator, bucket_name);
        return self;
    }

    /// Configure Pub/Sub
    pub fn withPubSub(self: *GCPAdapter, project_id: []const u8) !*GCPAdapter {
        self.pubsub = try PubSubClient.init(self.allocator, project_id);
        return self;
    }

    /// Set resource limits
    pub fn withResources(self: *GCPAdapter, memory_mb: u32, cpu: f32) *GCPAdapter {
        self.gcp_config.memory_mb = memory_mb;
        self.gcp_config.cpu = cpu;
        return self;
    }

    /// Set scaling parameters
    pub fn withScaling(self: *GCPAdapter, min_instances: u32, max_instances: u32) *GCPAdapter {
        self.gcp_config.min_instances = min_instances;
        self.gcp_config.max_instances = max_instances;
        return self;
    }

    /// Handle incoming request
    pub fn handle(self: *GCPAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__gcp_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            return EdgeResponse.fromServerResponse(self.allocator, &server_res);
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }

    /// Serve the application (Cloud Run entry point)
    pub fn serve(self: *GCPAdapter, port: u16) !void {
        _ = self;
        std.log.info("Cloud Run server listening on port {d}", .{port});
    }
};

/// Create GCP middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            _ = try ctx.response.setHeader("x-cloud-trace-context", "simulated");
            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "FirestoreClient basic operations" {
    const allocator = std.testing.allocator;

    var client = try FirestoreClient.init(allocator, "my-project");
    defer client.deinit();

    try client.setDocument("users", "1", "{\"name\":\"test\"}");
    const doc = try client.getDocument("users", "1");
    try std.testing.expect(doc != null);
    try std.testing.expectEqualStrings("{\"name\":\"test\"}", doc.?);

    try client.deleteDocument("users", "1");
    const deleted = try client.getDocument("users", "1");
    try std.testing.expect(deleted == null);
}

test "CloudStorageClient basic operations" {
    const allocator = std.testing.allocator;

    var client = try CloudStorageClient.init(allocator, "my-bucket");
    defer client.deinit();

    try client.upload("file.txt", "Hello", "text/plain");
    const obj = try client.download("file.txt");
    try std.testing.expect(obj != null);
    try std.testing.expectEqualStrings("Hello", obj.?.content);
}

test "GCPAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = GCPAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = adapter_instance.withProject("my-project").withRegion(.us_central1);
    _ = adapter_instance.withResources(1024, 2.0).withScaling(1, 10);

    try std.testing.expectEqual(Platform.gcp, adapter_instance.config.platform);
    try std.testing.expectEqual(@as(u32, 1024), adapter_instance.gcp_config.memory_mb);
}
