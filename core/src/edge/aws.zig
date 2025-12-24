//! Zylix Edge - AWS Lambda Adapter
//!
//! Deploy Zylix applications to AWS Lambda with access to:
//! - Lambda Custom Runtime
//! - Lambda@Edge
//! - API Gateway integration
//! - DynamoDB
//! - S3
//! - SQS/SNS
//! - EventBridge

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;

/// AWS Lambda configuration
pub const LambdaConfig = struct {
    /// Lambda function name
    function_name: []const u8 = "",

    /// AWS region
    region: Region = .us_east_1,

    /// Memory size in MB
    memory_size: u32 = 128,

    /// Timeout in seconds
    timeout: u32 = 30,

    /// Enable Lambda@Edge mode
    lambda_edge: bool = false,

    /// Enable provisioned concurrency
    provisioned_concurrency: ?u32 = null,

    pub const Region = enum {
        us_east_1,
        us_east_2,
        us_west_1,
        us_west_2,
        eu_west_1,
        eu_west_2,
        eu_central_1,
        ap_northeast_1,
        ap_southeast_1,
        ap_southeast_2,

        pub fn toString(self: Region) []const u8 {
            return switch (self) {
                .us_east_1 => "us-east-1",
                .us_east_2 => "us-east-2",
                .us_west_1 => "us-west-1",
                .us_west_2 => "us-west-2",
                .eu_west_1 => "eu-west-1",
                .eu_west_2 => "eu-west-2",
                .eu_central_1 => "eu-central-1",
                .ap_northeast_1 => "ap-northeast-1",
                .ap_southeast_1 => "ap-southeast-1",
                .ap_southeast_2 => "ap-southeast-2",
            };
        }
    };
};

/// API Gateway event (v2 HTTP API)
pub const APIGatewayEvent = struct {
    version: []const u8,
    route_key: []const u8,
    raw_path: []const u8,
    raw_query_string: ?[]const u8,
    headers: std.StringHashMapUnmanaged([]const u8),
    request_context: RequestContext,
    body: ?[]const u8,
    is_base64_encoded: bool,

    pub const RequestContext = struct {
        account_id: []const u8,
        api_id: []const u8,
        domain_name: []const u8,
        http: HttpInfo,
        request_id: []const u8,
        stage: []const u8,
        time: []const u8,
        time_epoch: u64,

        pub const HttpInfo = struct {
            method: []const u8,
            path: []const u8,
            protocol: []const u8,
            source_ip: []const u8,
            user_agent: []const u8,
        };
    };

    /// Convert to EdgeRequest
    pub fn toEdgeRequest(self: *APIGatewayEvent, allocator: std.mem.Allocator) !EdgeRequest {
        var req = EdgeRequest.init(allocator);

        req.method = server.Method.fromString(self.request_context.http.method) orelse .GET;
        req.url = self.raw_path;
        req.query = self.raw_query_string;
        req.body = self.body;
        req.client_ip = self.request_context.http.source_ip;

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            try req.headers.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        return req;
    }
};

/// API Gateway response
pub const APIGatewayResponse = struct {
    status_code: u16,
    headers: std.StringHashMapUnmanaged([]const u8),
    body: ?[]const u8,
    is_base64_encoded: bool,

    pub fn init(allocator: std.mem.Allocator) APIGatewayResponse {
        _ = allocator;
        return .{
            .status_code = 200,
            .headers = std.StringHashMapUnmanaged([]const u8){},
            .body = null,
            .is_base64_encoded = false,
        };
    }

    pub fn deinit(self: *APIGatewayResponse, allocator: std.mem.Allocator) void {
        self.headers.deinit(allocator);
    }

    /// Create from EdgeResponse
    pub fn fromEdgeResponse(allocator: std.mem.Allocator, edge_res: *EdgeResponse) !APIGatewayResponse {
        var res = APIGatewayResponse.init(allocator);
        res.status_code = edge_res.status;
        res.body = edge_res.body;

        var it = edge_res.headers.iterator();
        while (it.next()) |entry| {
            try res.headers.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        return res;
    }

    /// Serialize to JSON
    pub fn toJson(self: *APIGatewayResponse, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "{\"statusCode\":");
        try buffer.writer(allocator).print("{d}", .{self.status_code});

        try buffer.appendSlice(allocator, ",\"headers\":{");
        var first = true;
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            if (!first) try buffer.appendSlice(allocator, ",");
            try buffer.writer(allocator).print("\"{s}\":\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
            first = false;
        }
        try buffer.appendSlice(allocator, "}");

        if (self.body) |body| {
            try buffer.appendSlice(allocator, ",\"body\":\"");
            // Escape JSON string
            for (body) |c| {
                switch (c) {
                    '"' => try buffer.appendSlice(allocator, "\\\""),
                    '\\' => try buffer.appendSlice(allocator, "\\\\"),
                    '\n' => try buffer.appendSlice(allocator, "\\n"),
                    '\r' => try buffer.appendSlice(allocator, "\\r"),
                    '\t' => try buffer.appendSlice(allocator, "\\t"),
                    else => try buffer.append(allocator, c),
                }
            }
            try buffer.appendSlice(allocator, "\"");
        }

        try buffer.appendSlice(allocator, ",\"isBase64Encoded\":");
        try buffer.appendSlice(allocator, if (self.is_base64_encoded) "true" else "false");
        try buffer.appendSlice(allocator, "}");

        return buffer.toOwnedSlice(allocator);
    }
};

/// DynamoDB client (simplified)
pub const DynamoDBClient = struct {
    allocator: std.mem.Allocator,
    table_name: []const u8,
    region: LambdaConfig.Region,

    // Local storage for simulation
    items: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, table_name: []const u8, region: LambdaConfig.Region) !*DynamoDBClient {
        const client = try allocator.create(DynamoDBClient);
        client.* = .{
            .allocator = allocator,
            .table_name = try allocator.dupe(u8, table_name),
            .region = region,
            .items = .{},
        };
        return client;
    }

    pub fn deinit(self: *DynamoDBClient) void {
        var it = self.items.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.items.deinit(self.allocator);
        self.allocator.free(self.table_name);
        self.allocator.destroy(self);
    }

    /// Get item
    pub fn getItem(self: *DynamoDBClient, key: []const u8) !?[]const u8 {
        return self.items.get(key);
    }

    /// Put item
    pub fn putItem(self: *DynamoDBClient, key: []const u8, value: []const u8) !void {
        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.items.put(self.allocator, key_copy, value_copy);
    }

    /// Delete item
    pub fn deleteItem(self: *DynamoDBClient, key: []const u8) !void {
        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }
};

/// S3 client (simplified)
pub const S3Client = struct {
    allocator: std.mem.Allocator,
    bucket: []const u8,
    region: LambdaConfig.Region,

    // Local storage for simulation
    objects: std.StringHashMapUnmanaged(S3Object),

    pub const S3Object = struct {
        body: []const u8,
        content_type: []const u8,
        metadata: std.StringHashMapUnmanaged([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator, bucket: []const u8, region: LambdaConfig.Region) !*S3Client {
        const client = try allocator.create(S3Client);
        client.* = .{
            .allocator = allocator,
            .bucket = try allocator.dupe(u8, bucket),
            .region = region,
            .objects = .{},
        };
        return client;
    }

    pub fn deinit(self: *S3Client) void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.body);
            self.allocator.free(entry.value_ptr.content_type);
            entry.value_ptr.metadata.deinit(self.allocator);
        }
        self.objects.deinit(self.allocator);
        self.allocator.free(self.bucket);
        self.allocator.destroy(self);
    }

    /// Get object
    pub fn getObject(self: *S3Client, key: []const u8) !?S3Object {
        return self.objects.get(key);
    }

    /// Put object
    pub fn putObject(self: *S3Client, key: []const u8, body: []const u8, content_type: []const u8) !void {
        if (self.objects.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.body);
            self.allocator.free(old.value.content_type);
            var meta = old.value.metadata;
            meta.deinit(self.allocator);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const body_copy = try self.allocator.dupe(u8, body);
        errdefer self.allocator.free(body_copy);
        const ct_copy = try self.allocator.dupe(u8, content_type);

        try self.objects.put(self.allocator, key_copy, .{
            .body = body_copy,
            .content_type = ct_copy,
            .metadata = .{},
        });
    }

    /// Delete object
    pub fn deleteObject(self: *S3Client, key: []const u8) !void {
        if (self.objects.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.body);
            self.allocator.free(old.value.content_type);
            var meta = old.value.metadata;
            meta.deinit(self.allocator);
        }
    }
};

/// AWS Lambda adapter
pub const LambdaAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    lambda_config: LambdaConfig,
    dynamodb: ?*DynamoDBClient,
    s3: ?*S3Client,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) LambdaAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .aws_lambda },
            .lambda_config = .{},
            .dynamodb = null,
            .s3 = null,
            .app = null,
        };
    }

    pub fn deinit(self: *LambdaAdapter) void {
        if (self.dynamodb) |db| db.deinit();
        if (self.s3) |s3| s3.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *LambdaAdapter, app: *server.Zylix) *LambdaAdapter {
        self.app = app;
        return self;
    }

    /// Configure DynamoDB
    pub fn withDynamoDB(self: *LambdaAdapter, table_name: []const u8) !*LambdaAdapter {
        self.dynamodb = try DynamoDBClient.init(self.allocator, table_name, self.lambda_config.region);
        return self;
    }

    /// Configure S3
    pub fn withS3(self: *LambdaAdapter, bucket: []const u8) !*LambdaAdapter {
        self.s3 = try S3Client.init(self.allocator, bucket, self.lambda_config.region);
        return self;
    }

    /// Set region
    pub fn withRegion(self: *LambdaAdapter, region: LambdaConfig.Region) *LambdaAdapter {
        self.lambda_config.region = region;
        return self;
    }

    /// Enable Lambda@Edge
    pub fn withLambdaEdge(self: *LambdaAdapter) *LambdaAdapter {
        self.lambda_config.lambda_edge = true;
        return self;
    }

    /// Handle API Gateway event
    pub fn handleAPIGateway(self: *LambdaAdapter, event: *APIGatewayEvent) !APIGatewayResponse {
        var edge_req = try event.toEdgeRequest(self.allocator);
        defer edge_req.deinit();

        var edge_res = try self.handle(&edge_req);
        defer edge_res.deinit();

        return APIGatewayResponse.fromEdgeResponse(self.allocator, &edge_res);
    }

    /// Handle incoming request
    pub fn handle(self: *LambdaAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__lambda_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            return EdgeResponse.fromServerResponse(self.allocator, &server_res);
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }
};

/// Create AWS Lambda middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            _ = try ctx.response.setHeader("x-amzn-requestid", "simulated");
            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "DynamoDBClient basic operations" {
    const allocator = std.testing.allocator;

    var client = try DynamoDBClient.init(allocator, "test-table", .us_east_1);
    defer client.deinit();

    try client.putItem("key1", "{\"id\":\"1\"}");
    const item = try client.getItem("key1");
    try std.testing.expectEqualStrings("{\"id\":\"1\"}", item.?);

    try client.deleteItem("key1");
    const deleted = try client.getItem("key1");
    try std.testing.expect(deleted == null);
}

test "S3Client basic operations" {
    const allocator = std.testing.allocator;

    var client = try S3Client.init(allocator, "test-bucket", .us_east_1);
    defer client.deinit();

    try client.putObject("file.txt", "Hello", "text/plain");
    const obj = try client.getObject("file.txt");
    try std.testing.expect(obj != null);
    try std.testing.expectEqualStrings("Hello", obj.?.body);
}

test "LambdaAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = LambdaAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = adapter_instance.withRegion(.eu_west_1).withLambdaEdge();
    _ = try adapter_instance.withDynamoDB("my-table");

    try std.testing.expectEqual(Platform.aws_lambda, adapter_instance.config.platform);
    try std.testing.expect(adapter_instance.lambda_config.lambda_edge);
}

test "APIGatewayResponse toJson" {
    const allocator = std.testing.allocator;

    var res = APIGatewayResponse.init(allocator);
    defer res.deinit(allocator);

    res.status_code = 200;
    res.body = "Hello";
    try res.headers.put(allocator, "content-type", "text/plain");

    const json = try res.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"statusCode\":200") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"body\":\"Hello\"") != null);
}
