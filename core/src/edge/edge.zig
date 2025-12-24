//! Zylix Edge - Universal Edge Computing Adapters
//!
//! Deploy Zylix applications to any edge computing platform with a unified API.
//! Supports all major serverless and edge platforms:
//!
//! - **Cloudflare Workers**: KV, D1, R2, Durable Objects
//! - **Vercel Edge Functions**: KV, Blob, Edge Config, ISR
//! - **AWS Lambda**: DynamoDB, S3, API Gateway, Lambda@Edge
//! - **Azure Functions**: Cosmos DB, Blob Storage, Durable Functions
//! - **Deno Deploy**: Deno KV, BroadcastChannel, Cron
//! - **Google Cloud Run**: Firestore, Cloud Storage, Pub/Sub
//! - **Fastly Compute@Edge**: KV Store, Config Store, Secret Store
//!
//! ## Usage
//!
//! ```zig
//! const edge = @import("edge");
//!
//! // Create platform-specific adapter
//! var adapter = edge.cloudflare.CloudflareAdapter.init(allocator);
//! defer adapter.deinit();
//!
//! // Configure platform services
//! _ = try adapter.withKV("my-namespace");
//! _ = try adapter.withR2("my-bucket");
//!
//! // Set the Zylix application
//! _ = adapter.setApp(&app);
//!
//! // Or use the unified edge factory
//! var unified = try edge.create(allocator, .cloudflare);
//! defer unified.deinit();
//! ```

const std = @import("std");

// Core types
pub const types = @import("types.zig");
pub const Platform = types.Platform;
pub const EdgeConfig = types.EdgeConfig;
pub const EdgeRequest = types.EdgeRequest;
pub const EdgeResponse = types.EdgeResponse;
pub const EdgeAdapter = types.EdgeAdapter;
pub const GeoInfo = types.GeoInfo;
pub const CacheControl = types.CacheControl;

// Platform-specific adapters
pub const cloudflare = @import("cloudflare.zig");
pub const vercel = @import("vercel.zig");
pub const aws = @import("aws.zig");
pub const azure = @import("azure.zig");
pub const deno = @import("deno.zig");
pub const gcp = @import("gcp.zig");
pub const fastly = @import("fastly.zig");

/// Unified edge adapter that wraps platform-specific implementations
pub const UnifiedAdapter = struct {
    allocator: std.mem.Allocator,
    platform: Platform,
    inner: AdapterUnion,

    const AdapterUnion = union(Platform) {
        cloudflare: cloudflare.CloudflareAdapter,
        vercel: vercel.VercelAdapter,
        aws_lambda: aws.LambdaAdapter,
        azure: azure.AzureAdapter,
        deno: deno.DenoAdapter,
        gcp: gcp.GCPAdapter,
        fastly: fastly.FastlyAdapter,
        native: void,
        unknown: void,
    };

    /// Create a new unified adapter for the specified platform
    pub fn init(allocator: std.mem.Allocator, platform: Platform) !*UnifiedAdapter {
        const adapter = try allocator.create(UnifiedAdapter);
        adapter.* = .{
            .allocator = allocator,
            .platform = platform,
            .inner = switch (platform) {
                .cloudflare => .{ .cloudflare = cloudflare.CloudflareAdapter.init(allocator) },
                .vercel => .{ .vercel = vercel.VercelAdapter.init(allocator) },
                .aws_lambda => .{ .aws_lambda = aws.LambdaAdapter.init(allocator) },
                .azure => .{ .azure = azure.AzureAdapter.init(allocator) },
                .deno => .{ .deno = deno.DenoAdapter.init(allocator) },
                .gcp => .{ .gcp = gcp.GCPAdapter.init(allocator) },
                .fastly => .{ .fastly = fastly.FastlyAdapter.init(allocator) },
                .native => .{ .native = {} },
                .unknown => .{ .unknown = {} },
            },
        };
        return adapter;
    }

    pub fn deinit(self: *UnifiedAdapter) void {
        switch (self.inner) {
            .cloudflare => |*a| a.deinit(),
            .vercel => |*a| a.deinit(),
            .aws_lambda => |*a| a.deinit(),
            .azure => |*a| a.deinit(),
            .deno => |*a| a.deinit(),
            .gcp => |*a| a.deinit(),
            .fastly => |*a| a.deinit(),
            .native, .unknown => {},
        }
        self.allocator.destroy(self);
    }

    /// Handle an incoming edge request
    pub fn handle(self: *UnifiedAdapter, request: *EdgeRequest) !EdgeResponse {
        return switch (self.inner) {
            .cloudflare => |*a| a.fetch(request),
            .vercel => |*a| a.handle(request),
            .aws_lambda => |*a| a.handle(request),
            .azure => |*a| a.handle(request),
            .deno => |*a| a.handle(request),
            .gcp => |*a| a.handle(request),
            .fastly => |*a| a.handle(request),
            .native, .unknown => {
                var res = EdgeResponse.init(self.allocator);
                _ = res.setStatus(501);
                _ = res.setBody("Native/Unknown adapter not implemented");
                return res;
            },
        };
    }

    /// Get the platform name
    pub fn platformName(self: *const UnifiedAdapter) []const u8 {
        return self.platform.name();
    }

    /// Get Cloudflare adapter (if applicable)
    pub fn asCloudflare(self: *UnifiedAdapter) ?*cloudflare.CloudflareAdapter {
        return switch (self.inner) {
            .cloudflare => |*a| a,
            else => null,
        };
    }

    /// Get Vercel adapter (if applicable)
    pub fn asVercel(self: *UnifiedAdapter) ?*vercel.VercelAdapter {
        return switch (self.inner) {
            .vercel => |*a| a,
            else => null,
        };
    }

    /// Get AWS adapter (if applicable)
    pub fn asAWS(self: *UnifiedAdapter) ?*aws.LambdaAdapter {
        return switch (self.inner) {
            .aws_lambda => |*a| a,
            else => null,
        };
    }

    /// Get Azure adapter (if applicable)
    pub fn asAzure(self: *UnifiedAdapter) ?*azure.AzureAdapter {
        return switch (self.inner) {
            .azure => |*a| a,
            else => null,
        };
    }

    /// Get Deno adapter (if applicable)
    pub fn asDeno(self: *UnifiedAdapter) ?*deno.DenoAdapter {
        return switch (self.inner) {
            .deno => |*a| a,
            else => null,
        };
    }

    /// Get GCP adapter (if applicable)
    pub fn asGCP(self: *UnifiedAdapter) ?*gcp.GCPAdapter {
        return switch (self.inner) {
            .gcp => |*a| a,
            else => null,
        };
    }

    /// Get Fastly adapter (if applicable)
    pub fn asFastly(self: *UnifiedAdapter) ?*fastly.FastlyAdapter {
        return switch (self.inner) {
            .fastly => |*a| a,
            else => null,
        };
    }
};

/// Create a unified edge adapter for the specified platform
pub fn create(allocator: std.mem.Allocator, platform: Platform) !*UnifiedAdapter {
    return UnifiedAdapter.init(allocator, platform);
}

/// Detect the current edge platform from environment
pub fn detectPlatform() Platform {
    // Check environment variables to detect platform
    // These are typical environment variables set by each platform

    // Cloudflare Workers
    if (std.posix.getenv("CF_WORKER")) |_| return .cloudflare;

    // Vercel Edge
    if (std.posix.getenv("VERCEL")) |_| return .vercel;

    // AWS Lambda
    if (std.posix.getenv("AWS_LAMBDA_FUNCTION_NAME")) |_| return .aws_lambda;

    // Azure Functions
    if (std.posix.getenv("AZURE_FUNCTIONS_ENVIRONMENT")) |_| return .azure;

    // Deno Deploy
    if (std.posix.getenv("DENO_DEPLOYMENT_ID")) |_| return .deno;

    // Google Cloud Run
    if (std.posix.getenv("K_SERVICE")) |_| return .gcp;

    // Fastly Compute
    if (std.posix.getenv("FASTLY_SERVICE_VERSION")) |_| return .fastly;

    return .unknown;
}

/// Create an adapter for the auto-detected platform
pub fn createAuto(allocator: std.mem.Allocator) !*UnifiedAdapter {
    const platform = detectPlatform();
    return create(allocator, platform);
}

/// Edge middleware helper - adds common edge headers
pub fn edgeMiddleware(platform: Platform) types.EdgeMiddlewareFn {
    _ = platform;
    return struct {
        fn middleware(request: *EdgeRequest, response: *EdgeResponse) anyerror!void {
            _ = request;
            _ = try response.setHeader("x-edge-runtime", "zylix");
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "UnifiedAdapter creation for all platforms" {
    const allocator = std.testing.allocator;

    const platforms = [_]Platform{
        .cloudflare,
        .vercel,
        .aws_lambda,
        .azure,
        .deno,
        .gcp,
        .fastly,
    };

    for (platforms) |platform| {
        var adapter = try UnifiedAdapter.init(allocator, platform);
        defer adapter.deinit();

        try std.testing.expectEqual(platform, adapter.platform);
    }
}

test "Platform detection" {
    // In test environment, should return unknown
    const platform = detectPlatform();
    try std.testing.expectEqual(Platform.unknown, platform);
}

test "Platform-specific accessor functions" {
    const allocator = std.testing.allocator;

    var cf_adapter = try create(allocator, .cloudflare);
    defer cf_adapter.deinit();
    try std.testing.expect(cf_adapter.asCloudflare() != null);
    try std.testing.expect(cf_adapter.asVercel() == null);

    var vercel_adapter = try create(allocator, .vercel);
    defer vercel_adapter.deinit();
    try std.testing.expect(vercel_adapter.asVercel() != null);
    try std.testing.expect(vercel_adapter.asCloudflare() == null);
}

test "EdgeRequest and EdgeResponse" {
    const allocator = std.testing.allocator;

    var req = EdgeRequest.init(allocator);
    defer req.deinit();

    req.method = .GET;
    req.url = "/api/test";

    var res = EdgeResponse.init(allocator);
    defer res.deinit();

    _ = res.setStatus(200);
    _ = res.setBody("Hello, Edge!");
    _ = try res.setHeader("content-type", "text/plain");

    try std.testing.expectEqual(@as(u16, 200), res.status);
}

// Re-export common types for convenience
pub const CloudflareAdapter = cloudflare.CloudflareAdapter;
pub const CloudflareKV = cloudflare.CloudflareKV;
pub const D1Database = cloudflare.D1Database;
pub const R2Bucket = cloudflare.R2Bucket;

pub const VercelAdapter = vercel.VercelAdapter;
pub const VercelKV = vercel.VercelKV;
pub const VercelBlob = vercel.VercelBlob;

pub const LambdaAdapter = aws.LambdaAdapter;
pub const DynamoDBClient = aws.DynamoDBClient;
pub const S3Client = aws.S3Client;

pub const AzureAdapter = azure.AzureAdapter;
pub const CosmosDBClient = azure.CosmosDBClient;
pub const BlobStorageClient = azure.BlobStorageClient;

pub const DenoAdapter = deno.DenoAdapter;
pub const DenoKV = deno.DenoKV;
pub const BroadcastChannel = deno.BroadcastChannel;

pub const GCPAdapter = gcp.GCPAdapter;
pub const FirestoreClient = gcp.FirestoreClient;
pub const CloudStorageClient = gcp.CloudStorageClient;
pub const PubSubClient = gcp.PubSubClient;

pub const FastlyAdapter = fastly.FastlyAdapter;
pub const ConfigStore = fastly.ConfigStore;
pub const FastlyKVStore = fastly.KVStore;
pub const SecretStore = fastly.SecretStore;
