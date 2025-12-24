//! Zylix Edge - Azure Functions Adapter
//!
//! Deploy Zylix applications to Azure Functions with access to:
//! - Azure Functions Custom Handler
//! - HTTP Triggers
//! - Azure Cosmos DB
//! - Azure Blob Storage
//! - Azure Service Bus
//! - Azure Event Grid
//! - Durable Functions

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;

/// Azure Functions configuration
pub const AzureConfig = struct {
    /// Function app name
    app_name: []const u8 = "",

    /// Azure region
    region: Region = .east_us,

    /// Runtime version
    runtime_version: []const u8 = "4",

    /// Enable Durable Functions
    durable_functions: bool = false,

    pub const Region = enum {
        east_us,
        east_us_2,
        west_us,
        west_us_2,
        central_us,
        north_europe,
        west_europe,
        southeast_asia,
        east_asia,
        australia_east,
        japan_east,
        brazil_south,

        pub fn toString(self: Region) []const u8 {
            return switch (self) {
                .east_us => "eastus",
                .east_us_2 => "eastus2",
                .west_us => "westus",
                .west_us_2 => "westus2",
                .central_us => "centralus",
                .north_europe => "northeurope",
                .west_europe => "westeurope",
                .southeast_asia => "southeastasia",
                .east_asia => "eastasia",
                .australia_east => "australiaeast",
                .japan_east => "japaneast",
                .brazil_south => "brazilsouth",
            };
        }
    };
};

/// Azure Functions HTTP request
pub const AzureHttpRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: std.StringHashMapUnmanaged([]const u8),
    query: std.StringHashMapUnmanaged([]const u8),
    body: ?[]const u8,
    params: std.StringHashMapUnmanaged([]const u8),

    /// Convert to EdgeRequest
    pub fn toEdgeRequest(self: *AzureHttpRequest, allocator: std.mem.Allocator) !EdgeRequest {
        var req = EdgeRequest.init(allocator);

        req.method = server.Method.fromString(self.method) orelse .GET;
        req.url = self.url;
        req.body = self.body;

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            try req.headers.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        return req;
    }
};

/// Azure Functions HTTP response
pub const AzureHttpResponse = struct {
    status_code: u16,
    headers: std.StringHashMapUnmanaged([]const u8),
    body: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) AzureHttpResponse {
        _ = allocator;
        return .{
            .status_code = 200,
            .headers = .{},
            .body = null,
        };
    }

    pub fn deinit(self: *AzureHttpResponse, allocator: std.mem.Allocator) void {
        self.headers.deinit(allocator);
    }

    /// Create from EdgeResponse
    pub fn fromEdgeResponse(allocator: std.mem.Allocator, edge_res: *EdgeResponse) !AzureHttpResponse {
        var res = AzureHttpResponse.init(allocator);
        res.status_code = edge_res.status;
        res.body = edge_res.body;

        var it = edge_res.headers.iterator();
        while (it.next()) |entry| {
            try res.headers.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        return res;
    }
};

/// Cosmos DB client (simplified)
pub const CosmosDBClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    database: []const u8,
    container: []const u8,

    // Local storage for simulation
    items: std.StringHashMapUnmanaged([]const u8),

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        database: []const u8,
        container: []const u8,
    ) !*CosmosDBClient {
        const client = try allocator.create(CosmosDBClient);
        client.* = .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .database = try allocator.dupe(u8, database),
            .container = try allocator.dupe(u8, container),
            .items = .{},
        };
        return client;
    }

    pub fn deinit(self: *CosmosDBClient) void {
        var it = self.items.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.items.deinit(self.allocator);
        self.allocator.free(self.endpoint);
        self.allocator.free(self.database);
        self.allocator.free(self.container);
        self.allocator.destroy(self);
    }

    /// Read item
    pub fn readItem(self: *CosmosDBClient, id: []const u8, partition_key: []const u8) !?[]const u8 {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ partition_key, id });
        defer self.allocator.free(key);
        return self.items.get(key);
    }

    /// Create or replace item
    pub fn upsertItem(self: *CosmosDBClient, id: []const u8, partition_key: []const u8, item: []const u8) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ partition_key, id });

        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const item_copy = try self.allocator.dupe(u8, item);

        try self.items.put(self.allocator, key_copy, item_copy);
        self.allocator.free(key);
    }

    /// Delete item
    pub fn deleteItem(self: *CosmosDBClient, id: []const u8, partition_key: []const u8) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ partition_key, id });
        defer self.allocator.free(key);

        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }
};

/// Azure Blob Storage client (simplified)
pub const BlobStorageClient = struct {
    allocator: std.mem.Allocator,
    account_name: []const u8,
    container_name: []const u8,

    // Local storage for simulation
    blobs: std.StringHashMapUnmanaged(BlobData),

    pub const BlobData = struct {
        content: []const u8,
        content_type: []const u8,
        properties: std.StringHashMapUnmanaged([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator, account_name: []const u8, container_name: []const u8) !*BlobStorageClient {
        const client = try allocator.create(BlobStorageClient);
        client.* = .{
            .allocator = allocator,
            .account_name = try allocator.dupe(u8, account_name),
            .container_name = try allocator.dupe(u8, container_name),
            .blobs = .{},
        };
        return client;
    }

    pub fn deinit(self: *BlobStorageClient) void {
        var it = self.blobs.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.content);
            self.allocator.free(entry.value_ptr.content_type);
            var props = entry.value_ptr.properties;
            props.deinit(self.allocator);
        }
        self.blobs.deinit(self.allocator);
        self.allocator.free(self.account_name);
        self.allocator.free(self.container_name);
        self.allocator.destroy(self);
    }

    /// Download blob
    pub fn downloadBlob(self: *BlobStorageClient, blob_name: []const u8) !?BlobData {
        return self.blobs.get(blob_name);
    }

    /// Upload blob
    pub fn uploadBlob(self: *BlobStorageClient, blob_name: []const u8, content: []const u8, content_type: []const u8) !void {
        if (self.blobs.fetchRemove(blob_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.content);
            self.allocator.free(old.value.content_type);
            var props = old.value.properties;
            props.deinit(self.allocator);
        }

        const name_copy = try self.allocator.dupe(u8, blob_name);
        errdefer self.allocator.free(name_copy);
        const content_copy = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(content_copy);
        const ct_copy = try self.allocator.dupe(u8, content_type);

        try self.blobs.put(self.allocator, name_copy, .{
            .content = content_copy,
            .content_type = ct_copy,
            .properties = .{},
        });
    }

    /// Delete blob
    pub fn deleteBlob(self: *BlobStorageClient, blob_name: []const u8) !void {
        if (self.blobs.fetchRemove(blob_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.content);
            self.allocator.free(old.value.content_type);
            var props = old.value.properties;
            props.deinit(self.allocator);
        }
    }
};

/// Azure Functions adapter
pub const AzureAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    azure_config: AzureConfig,
    cosmos_db: ?*CosmosDBClient,
    blob_storage: ?*BlobStorageClient,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) AzureAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .azure },
            .azure_config = .{},
            .cosmos_db = null,
            .blob_storage = null,
            .app = null,
        };
    }

    pub fn deinit(self: *AzureAdapter) void {
        if (self.cosmos_db) |db| db.deinit();
        if (self.blob_storage) |blob| blob.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *AzureAdapter, app: *server.Zylix) *AzureAdapter {
        self.app = app;
        return self;
    }

    /// Configure Cosmos DB
    pub fn withCosmosDB(self: *AzureAdapter, endpoint: []const u8, database: []const u8, container: []const u8) !*AzureAdapter {
        self.cosmos_db = try CosmosDBClient.init(self.allocator, endpoint, database, container);
        return self;
    }

    /// Configure Blob Storage
    pub fn withBlobStorage(self: *AzureAdapter, account_name: []const u8, container_name: []const u8) !*AzureAdapter {
        self.blob_storage = try BlobStorageClient.init(self.allocator, account_name, container_name);
        return self;
    }

    /// Set region
    pub fn withRegion(self: *AzureAdapter, region: AzureConfig.Region) *AzureAdapter {
        self.azure_config.region = region;
        return self;
    }

    /// Enable Durable Functions
    pub fn withDurableFunctions(self: *AzureAdapter) *AzureAdapter {
        self.azure_config.durable_functions = true;
        return self;
    }

    /// Handle Azure Functions HTTP request
    pub fn handleHttp(self: *AzureAdapter, request: *AzureHttpRequest) !AzureHttpResponse {
        var edge_req = try request.toEdgeRequest(self.allocator);
        defer edge_req.deinit();

        var edge_res = try self.handle(&edge_req);
        defer edge_res.deinit();

        return AzureHttpResponse.fromEdgeResponse(self.allocator, &edge_res);
    }

    /// Handle incoming request
    pub fn handle(self: *AzureAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__azure_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            return EdgeResponse.fromServerResponse(self.allocator, &server_res);
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }

    /// Serve the application (entry point for custom handler)
    pub fn serve(self: *AzureAdapter) !void {
        _ = self;
        // Would start HTTP listener for custom handler protocol
        std.log.info("Azure Functions custom handler started", .{});
    }
};

/// Create Azure Functions middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            _ = try ctx.response.setHeader("x-azure-ref", "simulated");
            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "CosmosDBClient basic operations" {
    const allocator = std.testing.allocator;

    var client = try CosmosDBClient.init(allocator, "https://test.documents.azure.com", "mydb", "container");
    defer client.deinit();

    try client.upsertItem("1", "pk1", "{\"id\":\"1\",\"name\":\"test\"}");
    const item = try client.readItem("1", "pk1");
    try std.testing.expect(item != null);

    try client.deleteItem("1", "pk1");
    const deleted = try client.readItem("1", "pk1");
    try std.testing.expect(deleted == null);
}

test "BlobStorageClient basic operations" {
    const allocator = std.testing.allocator;

    var client = try BlobStorageClient.init(allocator, "myaccount", "mycontainer");
    defer client.deinit();

    try client.uploadBlob("file.txt", "Hello", "text/plain");
    const blob = try client.downloadBlob("file.txt");
    try std.testing.expect(blob != null);
    try std.testing.expectEqualStrings("Hello", blob.?.content);
}

test "AzureAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = AzureAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = adapter_instance.withRegion(.west_europe).withDurableFunctions();

    try std.testing.expectEqual(Platform.azure, adapter_instance.config.platform);
    try std.testing.expect(adapter_instance.azure_config.durable_functions);
}
