//! Build Artifact Query API
//!
//! Query and manage build artifacts with support for:
//! - Artifact path retrieval
//! - Metadata access (size, hash, timestamp)
//! - Signing status information
//! - Export and packaging
//!
//! This module provides artifact management for build outputs.

const std = @import("std");
const build = @import("build.zig");
const project = @import("project.zig");

/// Artifact error types
pub const ArtifactError = error{
    NotFound,
    InvalidPath,
    AccessDenied,
    HashMismatch,
    ExportFailed,
    OutOfMemory,
};

/// Artifact type
pub const ArtifactType = enum(u8) {
    executable = 0,
    library = 1,
    framework = 2,
    bundle = 3,
    archive = 4,
    debug_symbols = 5,
    source_map = 6,
    asset = 7,

    pub fn extension(self: ArtifactType, target: project.Target) []const u8 {
        return switch (self) {
            .executable => switch (target) {
                .windows => ".exe",
                .web => ".wasm",
                else => "",
            },
            .library => switch (target) {
                .windows => ".dll",
                .ios, .macos => ".dylib",
                else => ".so",
            },
            .framework => ".framework",
            .bundle => switch (target) {
                .ios => ".ipa",
                .android => ".apk",
                .macos => ".app",
                else => ".zip",
            },
            .archive => ".zip",
            .debug_symbols => switch (target) {
                .ios, .macos => ".dSYM",
                .windows => ".pdb",
                else => ".debug",
            },
            .source_map => ".map",
            .asset => "",
        };
    }
};

/// Artifact metadata
pub const ArtifactMetadata = struct {
    /// File size in bytes
    size: u64,
    /// SHA-256 hash
    hash: []const u8,
    /// Creation timestamp
    created_at: i64,
    /// Modification timestamp
    modified_at: i64,
    /// Artifact type
    artifact_type: ArtifactType,
    /// Target platform
    target: project.Target,
    /// Build mode
    build_mode: build.BuildMode,
    /// Is signed
    signed: bool = false,
    /// Signing identity (if signed)
    signing_identity: ?[]const u8 = null,
    /// Signing timestamp (if signed)
    signed_at: ?i64 = null,
};

/// Artifact information
pub const Artifact = struct {
    /// Artifact path
    path: []const u8,
    /// Artifact name
    name: []const u8,
    /// Metadata
    metadata: ArtifactMetadata,
    /// Associated build ID
    build_id: build.BuildId,
};

/// Export options
pub const ExportOptions = struct {
    /// Compress output
    compress: bool = true,
    /// Include debug symbols
    include_symbols: bool = false,
    /// Include source maps
    include_source_maps: bool = false,
    /// Custom archive name
    archive_name: ?[]const u8 = null,
};

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?ArtifactError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: ArtifactError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) ArtifactError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return ArtifactError.NotFound;
        }
    };
}

/// Artifact Manager
pub const Artifacts = struct {
    allocator: std.mem.Allocator,
    artifacts: std.StringHashMapUnmanaged(Artifact) = .{},

    pub fn init(allocator: std.mem.Allocator) Artifacts {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Artifacts) void {
        self.artifacts.deinit(self.allocator);
    }

    /// Get all artifacts for a build
    pub fn getArtifacts(self: *Artifacts, build_id: build.BuildId) *Future([]Artifact) {
        const future = self.allocator.create(Future([]Artifact)) catch {
            const err_future = self.allocator.create(Future([]Artifact)) catch unreachable;
            err_future.* = Future([]Artifact).init();
            err_future.fail(ArtifactError.OutOfMemory);
            return err_future;
        };
        future.* = Future([]Artifact).init();

        var result = std.ArrayList(Artifact).init(self.allocator);
        var iter = self.artifacts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.build_id.id == build_id.id) {
                result.append(entry.value_ptr.*) catch {
                    future.fail(ArtifactError.OutOfMemory);
                    return future;
                };
            }
        }

        future.complete(result.toOwnedSlice() catch &.{});
        return future;
    }

    /// Get metadata for a specific artifact
    pub fn getMetadata(self: *const Artifacts, artifact_path: []const u8) ?ArtifactMetadata {
        if (self.artifacts.get(artifact_path)) |artifact| {
            return artifact.metadata;
        }
        return null;
    }

    /// Export artifact to destination
    pub fn exportArtifact(
        self: *Artifacts,
        artifact_path: []const u8,
        destination: []const u8,
        options: ExportOptions,
    ) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(ArtifactError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        _ = destination;
        _ = options;

        if (self.artifacts.get(artifact_path) == null) {
            future.fail(ArtifactError.NotFound);
            return future;
        }

        // In real implementation, would copy/archive the artifact
        future.complete({});
        return future;
    }

    /// Register an artifact (called by build system)
    pub fn register(
        self: *Artifacts,
        path: []const u8,
        name: []const u8,
        build_id: build.BuildId,
        metadata: ArtifactMetadata,
    ) !void {
        const artifact = Artifact{
            .path = path,
            .name = name,
            .build_id = build_id,
            .metadata = metadata,
        };
        try self.artifacts.put(self.allocator, path, artifact);
    }

    /// Remove artifacts for a build
    pub fn removeForBuild(self: *Artifacts, build_id: build.BuildId) usize {
        var removed: usize = 0;
        var to_remove: std.ArrayListUnmanaged([]const u8) = .{};
        defer to_remove.deinit(self.allocator);

        var iter = self.artifacts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.build_id.id == build_id.id) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            if (self.artifacts.remove(key)) {
                removed += 1;
            }
        }

        return removed;
    }

    /// Get artifact count
    pub fn count(self: *const Artifacts) usize {
        return self.artifacts.count();
    }

    /// Verify artifact integrity
    pub fn verify(self: *const Artifacts, artifact_path: []const u8, expected_hash: []const u8) bool {
        if (self.artifacts.get(artifact_path)) |artifact| {
            return std.mem.eql(u8, artifact.metadata.hash, expected_hash);
        }
        return false;
    }
};

/// Calculate file hash (placeholder)
pub fn calculateHash(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    _ = path;
    // In real implementation, would calculate SHA-256 hash
    const hash = try allocator.alloc(u8, 64);
    @memset(hash, '0');
    return hash;
}

/// Create an artifact manager
pub fn createArtifactManager(allocator: std.mem.Allocator) Artifacts {
    return Artifacts.init(allocator);
}

// Tests
test "Artifacts initialization" {
    const allocator = std.testing.allocator;
    var artifacts = createArtifactManager(allocator);
    defer artifacts.deinit();

    try std.testing.expectEqual(@as(usize, 0), artifacts.count());
}

test "ArtifactType extensions" {
    try std.testing.expect(std.mem.eql(u8, ".exe", ArtifactType.executable.extension(.windows)));
    try std.testing.expect(std.mem.eql(u8, ".wasm", ArtifactType.executable.extension(.web)));
    try std.testing.expect(std.mem.eql(u8, "", ArtifactType.executable.extension(.linux)));

    try std.testing.expect(std.mem.eql(u8, ".ipa", ArtifactType.bundle.extension(.ios)));
    try std.testing.expect(std.mem.eql(u8, ".apk", ArtifactType.bundle.extension(.android)));
    try std.testing.expect(std.mem.eql(u8, ".app", ArtifactType.bundle.extension(.macos)));

    try std.testing.expect(std.mem.eql(u8, ".dSYM", ArtifactType.debug_symbols.extension(.ios)));
    try std.testing.expect(std.mem.eql(u8, ".pdb", ArtifactType.debug_symbols.extension(.windows)));
}

test "Artifact registration" {
    const allocator = std.testing.allocator;
    var artifacts = createArtifactManager(allocator);
    defer artifacts.deinit();

    const build_id = build.BuildId{
        .id = 1,
        .project_name = "test",
        .target = .ios,
        .started_at = 0,
    };

    try artifacts.register(
        "/tmp/test.app",
        "test.app",
        build_id,
        .{
            .size = 1024,
            .hash = "abc123",
            .created_at = 0,
            .modified_at = 0,
            .artifact_type = .bundle,
            .target = .ios,
            .build_mode = .release,
        },
    );

    try std.testing.expectEqual(@as(usize, 1), artifacts.count());
}

test "Artifact metadata retrieval" {
    const allocator = std.testing.allocator;
    var artifacts = createArtifactManager(allocator);
    defer artifacts.deinit();

    const build_id = build.BuildId{
        .id = 1,
        .project_name = "test",
        .target = .android,
        .started_at = 0,
    };

    try artifacts.register(
        "/tmp/test.apk",
        "test.apk",
        build_id,
        .{
            .size = 2048,
            .hash = "def456",
            .created_at = 100,
            .modified_at = 200,
            .artifact_type = .bundle,
            .target = .android,
            .build_mode = .debug,
        },
    );

    const metadata = artifacts.getMetadata("/tmp/test.apk");
    try std.testing.expect(metadata != null);
    try std.testing.expectEqual(@as(u64, 2048), metadata.?.size);
    try std.testing.expectEqual(ArtifactType.bundle, metadata.?.artifact_type);

    try std.testing.expect(artifacts.getMetadata("/nonexistent") == null);
}

test "Artifact verification" {
    const allocator = std.testing.allocator;
    var artifacts = createArtifactManager(allocator);
    defer artifacts.deinit();

    const build_id = build.BuildId{
        .id = 1,
        .project_name = "test",
        .target = .web,
        .started_at = 0,
    };

    try artifacts.register(
        "/tmp/test.wasm",
        "test.wasm",
        build_id,
        .{
            .size = 512,
            .hash = "correcthash",
            .created_at = 0,
            .modified_at = 0,
            .artifact_type = .executable,
            .target = .web,
            .build_mode = .release,
        },
    );

    try std.testing.expect(artifacts.verify("/tmp/test.wasm", "correcthash"));
    try std.testing.expect(!artifacts.verify("/tmp/test.wasm", "wronghash"));
    try std.testing.expect(!artifacts.verify("/nonexistent", "anyhash"));
}

test "Remove artifacts for build" {
    const allocator = std.testing.allocator;
    var artifacts = createArtifactManager(allocator);
    defer artifacts.deinit();

    const build_id1 = build.BuildId{ .id = 1, .project_name = "test1", .target = .ios, .started_at = 0 };
    const build_id2 = build.BuildId{ .id = 2, .project_name = "test2", .target = .ios, .started_at = 0 };

    try artifacts.register("/tmp/a1.app", "a1.app", build_id1, .{
        .size = 100,
        .hash = "h1",
        .created_at = 0,
        .modified_at = 0,
        .artifact_type = .bundle,
        .target = .ios,
        .build_mode = .debug,
    });
    try artifacts.register("/tmp/a2.app", "a2.app", build_id1, .{
        .size = 200,
        .hash = "h2",
        .created_at = 0,
        .modified_at = 0,
        .artifact_type = .bundle,
        .target = .ios,
        .build_mode = .debug,
    });
    try artifacts.register("/tmp/b1.app", "b1.app", build_id2, .{
        .size = 300,
        .hash = "h3",
        .created_at = 0,
        .modified_at = 0,
        .artifact_type = .bundle,
        .target = .ios,
        .build_mode = .debug,
    });

    try std.testing.expectEqual(@as(usize, 3), artifacts.count());

    const removed = artifacts.removeForBuild(build_id1);
    try std.testing.expectEqual(@as(usize, 2), removed);
    try std.testing.expectEqual(@as(usize, 1), artifacts.count());
}
