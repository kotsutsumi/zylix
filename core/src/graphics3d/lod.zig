//! Level of Detail (LOD) & Mesh Virtualization System
//!
//! Provides automatic level of detail management for efficient rendering of
//! 3D meshes at varying distances, including mesh simplification, LOD selection,
//! and virtualized mesh streaming for large scenes.
//!
//! ## Features
//! - Automatic LOD level selection based on screen coverage
//! - Mesh simplification with edge collapse algorithm
//! - Smooth LOD transitions (cross-fading, morphing)
//! - Mesh virtualization for streaming large meshes
//! - Instance LOD management for batched rendering
//! - Configurable quality/performance tradeoffs
//!
//! ## Example
//! ```zig
//! const lod = @import("lod.zig");
//!
//! // Create LOD group with multiple detail levels
//! var group = lod.LODGroup.init(allocator, "character");
//! try group.addLevel(high_mesh, 0, 10);   // 0-10 units
//! try group.addLevel(med_mesh, 10, 50);    // 10-50 units
//! try group.addLevel(low_mesh, 50, 200);   // 50-200 units
//! try group.setBillboard(billboard_tex, 200); // 200+ units
//!
//! // Select appropriate LOD
//! const selected = group.selectLOD(camera_pos, object_pos);
//! ```

const std = @import("std");
const types = @import("types.zig");
const mesh_mod = @import("mesh.zig");

const Vec3 = types.Vec3;
const AABB = types.AABB;
const Mat4 = types.Mat4;

// ============================================================================
// LOD Configuration
// ============================================================================

/// LOD system configuration
pub const LODConfig = struct {
    /// Screen coverage threshold for each LOD level (0.0-1.0)
    screen_coverage_thresholds: [MAX_LOD_LEVELS]f32 = .{ 0.5, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001 },
    /// Enable smooth transitions between LOD levels
    enable_transitions: bool = true,
    /// Transition duration in seconds
    transition_duration: f32 = 0.3,
    /// Hysteresis factor to prevent LOD popping
    hysteresis: f32 = 1.1,
    /// Maximum distance for LOD consideration
    max_distance: f32 = 1000.0,
    /// Minimum screen coverage before culling
    min_screen_coverage: f32 = 0.0001,
    /// Enable distance-based bias
    distance_bias: f32 = 1.0,
    /// Quality bias (higher = prefer higher LOD levels)
    quality_bias: f32 = 1.0,
};

/// Maximum number of LOD levels
pub const MAX_LOD_LEVELS: usize = 8;

/// Transition type between LOD levels
pub const TransitionType = enum(u8) {
    /// Instant switch (no transition)
    instant,
    /// Cross-fade between meshes
    crossfade,
    /// Vertex morphing
    morph,
    /// Alpha dithering
    dither,
};

// ============================================================================
// LOD Level
// ============================================================================

/// A single LOD level with mesh and distance range
pub const LODLevel = struct {
    /// Mesh for this LOD level (null for billboard)
    mesh: ?*mesh_mod.Mesh = null,
    /// Minimum distance for this LOD
    min_distance: f32,
    /// Maximum distance for this LOD
    max_distance: f32,
    /// Screen coverage threshold (computed or manual)
    screen_coverage: f32 = 0.0,
    /// Vertex count for this level
    vertex_count: u32 = 0,
    /// Triangle count for this level
    triangle_count: u32 = 0,
    /// Is this a billboard level?
    is_billboard: bool = false,
    /// Custom data pointer
    user_data: ?*anyopaque = null,

    pub fn init(mesh_ref: ?*mesh_mod.Mesh, min_dist: f32, max_dist: f32) LODLevel {
        var level = LODLevel{
            .mesh = mesh_ref,
            .min_distance = min_dist,
            .max_distance = max_dist,
        };

        if (mesh_ref) |m| {
            level.vertex_count = @intCast(m.vertices.items.len);
            level.triangle_count = @intCast(m.indices.items.len / 3);
        }

        return level;
    }

    /// Get complexity ratio compared to reference (0.0-1.0)
    pub fn getComplexityRatio(self: *const LODLevel, reference_triangles: u32) f32 {
        if (reference_triangles == 0) return 0;
        return @as(f32, @floatFromInt(self.triangle_count)) / @as(f32, @floatFromInt(reference_triangles));
    }
};

// ============================================================================
// LOD Group
// ============================================================================

/// A group of LOD levels for a single object
pub const LODGroup = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    levels: [MAX_LOD_LEVELS]?LODLevel,
    level_count: u8,
    /// Reference bounding sphere radius for screen coverage calculation
    bounding_radius: f32,
    /// Current active LOD level
    current_level: u8,
    /// Target LOD level during transition
    target_level: u8,
    /// Transition progress (0.0-1.0)
    transition_progress: f32,
    /// Transition type
    transition_type: TransitionType,
    /// Configuration
    config: LODConfig,
    /// Is this group enabled?
    enabled: bool,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) LODGroup {
        return .{
            .allocator = allocator,
            .name = name,
            .levels = [_]?LODLevel{null} ** MAX_LOD_LEVELS,
            .level_count = 0,
            .bounding_radius = 1.0,
            .current_level = 0,
            .target_level = 0,
            .transition_progress = 1.0,
            .transition_type = .crossfade,
            .config = .{},
            .enabled = true,
        };
    }

    pub fn deinit(self: *LODGroup) void {
        _ = self;
        // LODGroup doesn't own the meshes, just references them
    }

    /// Add a LOD level with distance range
    pub fn addLevel(self: *LODGroup, mesh_ref: ?*mesh_mod.Mesh, min_distance: f32, max_distance: f32) !u8 {
        if (self.level_count >= MAX_LOD_LEVELS) {
            return error.TooManyLODLevels;
        }

        const level_idx = self.level_count;
        self.levels[level_idx] = LODLevel.init(mesh_ref, min_distance, max_distance);
        self.level_count += 1;

        // Update bounding radius from first level's mesh
        if (level_idx == 0) {
            if (mesh_ref) |m| {
                // Estimate radius from mesh bounds
                const bounds = m.bounds_aabb;
                const extent = bounds.max.sub(bounds.min);
                self.bounding_radius = @max(@max(extent.x, extent.y), extent.z) * 0.5;
            }
        }

        return level_idx;
    }

    /// Add a billboard as the lowest LOD level
    pub fn setBillboard(self: *LODGroup, min_distance: f32) !u8 {
        if (self.level_count >= MAX_LOD_LEVELS) {
            return error.TooManyLODLevels;
        }

        const level_idx = self.level_count;
        var level = LODLevel.init(null, min_distance, self.config.max_distance);
        level.is_billboard = true;
        level.vertex_count = 4;
        level.triangle_count = 2;
        self.levels[level_idx] = level;
        self.level_count += 1;

        return level_idx;
    }

    /// Calculate screen coverage for an object
    pub fn calculateScreenCoverage(self: *const LODGroup, camera_pos: Vec3, object_pos: Vec3, fov: f32, screen_height: f32) f32 {
        const distance = camera_pos.sub(object_pos).length();
        if (distance < 0.001) return 1.0;

        // Screen space size estimation
        const projected_size = (self.bounding_radius * 2.0 * screen_height) / (distance * 2.0 * @tan(fov * 0.5));
        return projected_size / screen_height;
    }

    /// Select appropriate LOD level based on distance
    pub fn selectLOD(self: *LODGroup, camera_pos: Vec3, object_pos: Vec3) u8 {
        if (!self.enabled or self.level_count == 0) return 0;

        const distance = camera_pos.sub(object_pos).length();

        // Find appropriate level based on distance
        var selected: u8 = 0;
        for (0..self.level_count) |i| {
            if (self.levels[i]) |level| {
                if (distance >= level.min_distance and distance < level.max_distance) {
                    selected = @intCast(i);
                    break;
                }
                // If beyond all levels, use the last one
                if (distance >= level.max_distance and i == self.level_count - 1) {
                    selected = @intCast(i);
                }
            }
        }

        return selected;
    }

    /// Select LOD with hysteresis to prevent popping
    pub fn selectLODWithHysteresis(self: *LODGroup, camera_pos: Vec3, object_pos: Vec3) u8 {
        const new_level = self.selectLOD(camera_pos, object_pos);

        // Only change if we've passed the hysteresis threshold
        if (new_level != self.current_level) {
            if (self.levels[self.current_level]) |current| {
                const distance = camera_pos.sub(object_pos).length();

                // Going to higher detail (lower level index)
                if (new_level < self.current_level) {
                    if (distance < current.min_distance / self.config.hysteresis) {
                        return new_level;
                    }
                }
                // Going to lower detail (higher level index)
                else {
                    if (distance > current.max_distance * self.config.hysteresis) {
                        return new_level;
                    }
                }
            }
            return self.current_level;
        }

        return new_level;
    }

    /// Update transition between LOD levels
    pub fn update(self: *LODGroup, delta_time: f32, camera_pos: Vec3, object_pos: Vec3) void {
        if (!self.enabled) return;

        const target = self.selectLODWithHysteresis(camera_pos, object_pos);

        if (target != self.target_level) {
            self.target_level = target;
            if (self.config.enable_transitions) {
                self.transition_progress = 0.0;
            } else {
                self.current_level = target;
                self.transition_progress = 1.0;
            }
        }

        // Update transition
        if (self.transition_progress < 1.0) {
            self.transition_progress += delta_time / self.config.transition_duration;
            if (self.transition_progress >= 1.0) {
                self.transition_progress = 1.0;
                self.current_level = self.target_level;
            }
        }
    }

    /// Get current level mesh
    pub fn getCurrentMesh(self: *const LODGroup) ?*mesh_mod.Mesh {
        if (self.level_count == 0) return null;
        if (self.levels[self.current_level]) |level| {
            return level.mesh;
        }
        return null;
    }

    /// Check if currently transitioning
    pub fn isTransitioning(self: *const LODGroup) bool {
        return self.transition_progress < 1.0;
    }

    /// Get transition blend factor (0.0 = current, 1.0 = target)
    pub fn getTransitionBlend(self: *const LODGroup) f32 {
        return self.transition_progress;
    }

    /// Get statistics about LOD group
    pub fn getStats(self: *const LODGroup) LODStats {
        var total_triangles: u32 = 0;
        var total_vertices: u32 = 0;

        for (0..self.level_count) |i| {
            if (self.levels[i]) |level| {
                total_triangles += level.triangle_count;
                total_vertices += level.vertex_count;
            }
        }

        const current_triangles = if (self.levels[self.current_level]) |l| l.triangle_count else 0;

        return .{
            .level_count = self.level_count,
            .current_level = self.current_level,
            .current_triangles = current_triangles,
            .total_triangles_all_levels = total_triangles,
            .total_vertices_all_levels = total_vertices,
            .is_transitioning = self.isTransitioning(),
            .transition_progress = self.transition_progress,
        };
    }
};

/// LOD group statistics
pub const LODStats = struct {
    level_count: u8,
    current_level: u8,
    current_triangles: u32,
    total_triangles_all_levels: u32,
    total_vertices_all_levels: u32,
    is_transitioning: bool,
    transition_progress: f32,
};

// ============================================================================
// LOD Manager
// ============================================================================

/// Manages multiple LOD groups for a scene
pub const LODManager = struct {
    allocator: std.mem.Allocator,
    groups: std.ArrayList(*LODGroup),
    config: LODConfig,
    /// Global quality multiplier (0.0-2.0)
    quality_level: f32,
    /// Performance budget (target triangle count)
    triangle_budget: u32,
    /// Current frame's total triangles rendered
    current_triangles: u32,

    pub fn init(allocator: std.mem.Allocator) LODManager {
        return .{
            .allocator = allocator,
            .groups = .{},
            .config = .{},
            .quality_level = 1.0,
            .triangle_budget = 1_000_000,
            .current_triangles = 0,
        };
    }

    pub fn deinit(self: *LODManager) void {
        for (self.groups.items) |group| {
            group.deinit();
            self.allocator.destroy(group);
        }
        self.groups.deinit(self.allocator);
    }

    /// Create a new LOD group
    pub fn createGroup(self: *LODManager, name: []const u8) !*LODGroup {
        const group = try self.allocator.create(LODGroup);
        group.* = LODGroup.init(self.allocator, name);
        group.config = self.config;
        try self.groups.append(self.allocator, group);
        return group;
    }

    /// Remove a LOD group
    pub fn removeGroup(self: *LODManager, group: *LODGroup) void {
        for (self.groups.items, 0..) |g, i| {
            if (g == group) {
                g.deinit();
                self.allocator.destroy(g);
                _ = self.groups.swapRemove(i);
                break;
            }
        }
    }

    /// Update all LOD groups
    pub fn update(self: *LODManager, delta_time: f32, camera_pos: Vec3) void {
        self.current_triangles = 0;

        for (self.groups.items) |group| {
            // Get object position from first level's mesh if available
            var object_pos = Vec3.zero();
            if (group.level_count > 0) {
                if (group.levels[0]) |level| {
                    if (level.mesh) |m| {
                        const center = m.bounds.min.add(m.bounds.max).scale(0.5);
                        object_pos = center;
                    }
                }
            }

            group.update(delta_time, camera_pos, object_pos);

            // Track triangle count
            if (group.levels[group.current_level]) |level| {
                self.current_triangles += level.triangle_count;
            }
        }
    }

    /// Set global quality level (0.0-2.0)
    pub fn setQualityLevel(self: *LODManager, quality: f32) void {
        self.quality_level = std.math.clamp(quality, 0.0, 2.0);

        // Update all groups with adjusted thresholds
        for (self.groups.items) |group| {
            group.config.quality_bias = self.quality_level;
        }
    }

    /// Get manager statistics
    pub fn getStats(self: *const LODManager) struct {
        group_count: usize,
        current_triangles: u32,
        budget_usage: f32,
    } {
        return .{
            .group_count = self.groups.items.len,
            .current_triangles = self.current_triangles,
            .budget_usage = @as(f32, @floatFromInt(self.current_triangles)) / @as(f32, @floatFromInt(self.triangle_budget)),
        };
    }
};

// ============================================================================
// Mesh Simplification
// ============================================================================

/// Edge collapse candidate for mesh simplification
pub const EdgeCollapse = struct {
    v0: u32,
    v1: u32,
    cost: f32,
    target_position: Vec3,
};

/// Mesh simplification using quadric error metrics
pub const MeshSimplifier = struct {
    allocator: std.mem.Allocator,
    /// Original vertex positions
    vertices: std.ArrayList(Vec3),
    /// Original indices
    indices: std.ArrayList(u32),
    /// Vertex quadric matrices (for error calculation)
    quadrics: std.ArrayList(QuadricMatrix),
    /// Edge collapse heap
    collapse_heap: std.ArrayList(EdgeCollapse),
    /// Vertex removal flags
    removed_vertices: std.ArrayList(bool),
    /// Vertex mapping after collapse
    vertex_map: std.ArrayList(u32),

    pub const QuadricMatrix = struct {
        /// 4x4 symmetric matrix stored as 10 elements
        data: [10]f32 = [_]f32{0} ** 10,

        pub fn init() QuadricMatrix {
            return .{};
        }

        pub fn fromPlane(n: Vec3, d: f32) QuadricMatrix {
            var q = QuadricMatrix{};
            // Q = (a,b,c,d)^T * (a,b,c,d)
            q.data[0] = n.x * n.x;
            q.data[1] = n.x * n.y;
            q.data[2] = n.x * n.z;
            q.data[3] = n.x * d;
            q.data[4] = n.y * n.y;
            q.data[5] = n.y * n.z;
            q.data[6] = n.y * d;
            q.data[7] = n.z * n.z;
            q.data[8] = n.z * d;
            q.data[9] = d * d;
            return q;
        }

        pub fn add(self: QuadricMatrix, other: QuadricMatrix) QuadricMatrix {
            var result = QuadricMatrix{};
            for (0..10) |i| {
                result.data[i] = self.data[i] + other.data[i];
            }
            return result;
        }

        pub fn evaluate(self: *const QuadricMatrix, v: Vec3) f32 {
            // v^T * Q * v
            return self.data[0] * v.x * v.x +
                2.0 * self.data[1] * v.x * v.y +
                2.0 * self.data[2] * v.x * v.z +
                2.0 * self.data[3] * v.x +
                self.data[4] * v.y * v.y +
                2.0 * self.data[5] * v.y * v.z +
                2.0 * self.data[6] * v.y +
                self.data[7] * v.z * v.z +
                2.0 * self.data[8] * v.z +
                self.data[9];
        }
    };

    pub fn init(allocator: std.mem.Allocator) MeshSimplifier {
        return .{
            .allocator = allocator,
            .vertices = .{},
            .indices = .{},
            .quadrics = .{},
            .collapse_heap = .{},
            .removed_vertices = .{},
            .vertex_map = .{},
        };
    }

    pub fn deinit(self: *MeshSimplifier) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.quadrics.deinit(self.allocator);
        self.collapse_heap.deinit(self.allocator);
        self.removed_vertices.deinit(self.allocator);
        self.vertex_map.deinit(self.allocator);
    }

    /// Load mesh data for simplification
    pub fn loadMesh(self: *MeshSimplifier, vertex_positions: []const Vec3, index_data: []const u32) !void {
        // Clear existing data
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.quadrics.clearRetainingCapacity();
        self.removed_vertices.clearRetainingCapacity();
        self.vertex_map.clearRetainingCapacity();

        // Copy vertices
        try self.vertices.ensureTotalCapacity(self.allocator, vertex_positions.len);
        for (vertex_positions) |v| {
            try self.vertices.append(self.allocator, v);
        }

        // Copy indices
        try self.indices.ensureTotalCapacity(self.allocator, index_data.len);
        for (index_data) |i| {
            try self.indices.append(self.allocator, i);
        }

        // Initialize quadrics
        try self.quadrics.ensureTotalCapacity(self.allocator, vertex_positions.len);
        for (0..vertex_positions.len) |_| {
            try self.quadrics.append(self.allocator, QuadricMatrix.init());
        }

        // Initialize vertex tracking
        try self.removed_vertices.ensureTotalCapacity(self.allocator, vertex_positions.len);
        try self.vertex_map.ensureTotalCapacity(self.allocator, vertex_positions.len);
        for (0..vertex_positions.len) |i| {
            try self.removed_vertices.append(self.allocator, false);
            try self.vertex_map.append(self.allocator, @intCast(i));
        }

        // Calculate initial quadrics from faces
        try self.calculateQuadrics();
    }

    fn calculateQuadrics(self: *MeshSimplifier) !void {
        const triangle_count = self.indices.items.len / 3;

        for (0..triangle_count) |t| {
            const idx0 = self.indices.items[t * 3];
            const idx1 = self.indices.items[t * 3 + 1];
            const idx2 = self.indices.items[t * 3 + 2];

            const v0 = self.vertices.items[idx0];
            const v1 = self.vertices.items[idx1];
            const v2 = self.vertices.items[idx2];

            // Calculate face plane
            const edge1 = v1.sub(v0);
            const edge2 = v2.sub(v0);
            const normal = edge1.cross(edge2).normalize();
            const d = -normal.dot(v0);

            const face_quadric = QuadricMatrix.fromPlane(normal, d);

            // Add to vertex quadrics
            self.quadrics.items[idx0] = self.quadrics.items[idx0].add(face_quadric);
            self.quadrics.items[idx1] = self.quadrics.items[idx1].add(face_quadric);
            self.quadrics.items[idx2] = self.quadrics.items[idx2].add(face_quadric);
        }
    }

    /// Simplify mesh to target triangle count
    pub fn simplify(self: *MeshSimplifier, target_triangles: u32) !SimplifiedMesh {
        var current_triangles: u32 = @intCast(self.indices.items.len / 3);

        while (current_triangles > target_triangles) {
            // Find best edge to collapse
            const collapse = self.findBestCollapse() orelse break;

            // Perform collapse
            self.collapseEdge(collapse);

            // Recalculate triangle count
            current_triangles = self.countActiveTriangles();
        }

        return try self.buildResult();
    }

    fn findBestCollapse(self: *MeshSimplifier) ?EdgeCollapse {
        var best_collapse: ?EdgeCollapse = null;
        var best_cost: f32 = std.math.inf(f32);

        const triangle_count = self.indices.items.len / 3;

        for (0..triangle_count) |t| {
            const base = t * 3;
            const idx0 = self.getMappedVertex(self.indices.items[base]);
            const idx1 = self.getMappedVertex(self.indices.items[base + 1]);
            const idx2 = self.getMappedVertex(self.indices.items[base + 2]);

            // Skip degenerate triangles
            if (idx0 == idx1 or idx1 == idx2 or idx0 == idx2) continue;

            // Check each edge
            const edges = [_][2]u32{ .{ idx0, idx1 }, .{ idx1, idx2 }, .{ idx2, idx0 } };

            for (edges) |edge| {
                if (self.removed_vertices.items[edge[0]] or self.removed_vertices.items[edge[1]]) continue;

                const v0 = self.vertices.items[edge[0]];
                const v1 = self.vertices.items[edge[1]];
                const midpoint = v0.add(v1).scale(0.5);

                const q_sum = self.quadrics.items[edge[0]].add(self.quadrics.items[edge[1]]);
                const cost = q_sum.evaluate(midpoint);

                if (cost < best_cost) {
                    best_cost = cost;
                    best_collapse = .{
                        .v0 = edge[0],
                        .v1 = edge[1],
                        .cost = cost,
                        .target_position = midpoint,
                    };
                }
            }
        }

        return best_collapse;
    }

    fn collapseEdge(self: *MeshSimplifier, collapse: EdgeCollapse) void {
        // Move v0 to target position
        self.vertices.items[collapse.v0] = collapse.target_position;

        // Merge quadrics
        self.quadrics.items[collapse.v0] = self.quadrics.items[collapse.v0].add(self.quadrics.items[collapse.v1]);

        // Mark v1 as removed and map to v0
        self.removed_vertices.items[collapse.v1] = true;
        self.vertex_map.items[collapse.v1] = collapse.v0;
    }

    fn getMappedVertex(self: *MeshSimplifier, v: u32) u32 {
        var current = v;
        while (self.vertex_map.items[current] != current) {
            current = self.vertex_map.items[current];
        }
        return current;
    }

    fn countActiveTriangles(self: *MeshSimplifier) u32 {
        var count: u32 = 0;
        const triangle_count = self.indices.items.len / 3;

        for (0..triangle_count) |t| {
            const base = t * 3;
            const idx0 = self.getMappedVertex(self.indices.items[base]);
            const idx1 = self.getMappedVertex(self.indices.items[base + 1]);
            const idx2 = self.getMappedVertex(self.indices.items[base + 2]);

            if (idx0 != idx1 and idx1 != idx2 and idx0 != idx2) {
                count += 1;
            }
        }

        return count;
    }

    fn buildResult(self: *MeshSimplifier) !SimplifiedMesh {
        var result = SimplifiedMesh.init(self.allocator);

        // Build vertex remap
        var new_index: u32 = 0;
        var vertex_remap = std.ArrayList(u32).init(self.allocator);
        defer vertex_remap.deinit();

        try vertex_remap.ensureTotalCapacity(self.vertices.items.len);
        for (0..self.vertices.items.len) |i| {
            if (!self.removed_vertices.items[i]) {
                try result.vertices.append(self.allocator, self.vertices.items[i]);
                try vertex_remap.append(self.allocator, new_index);
                new_index += 1;
            } else {
                try vertex_remap.append(self.allocator, 0xFFFFFFFF);
            }
        }

        // Build indices
        const triangle_count = self.indices.items.len / 3;
        for (0..triangle_count) |t| {
            const base = t * 3;
            const idx0 = self.getMappedVertex(self.indices.items[base]);
            const idx1 = self.getMappedVertex(self.indices.items[base + 1]);
            const idx2 = self.getMappedVertex(self.indices.items[base + 2]);

            if (idx0 != idx1 and idx1 != idx2 and idx0 != idx2) {
                try result.indices.append(self.allocator, vertex_remap.items[idx0]);
                try result.indices.append(self.allocator, vertex_remap.items[idx1]);
                try result.indices.append(self.allocator, vertex_remap.items[idx2]);
            }
        }

        return result;
    }
};

/// Result of mesh simplification
pub const SimplifiedMesh = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vec3),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) SimplifiedMesh {
        return .{
            .allocator = allocator,
            .vertices = .{},
            .indices = .{},
        };
    }

    pub fn deinit(self: *SimplifiedMesh) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
    }

    pub fn getTriangleCount(self: *const SimplifiedMesh) u32 {
        return @intCast(self.indices.items.len / 3);
    }

    pub fn getVertexCount(self: *const SimplifiedMesh) u32 {
        return @intCast(self.vertices.items.len);
    }
};

// ============================================================================
// Mesh Virtualization
// ============================================================================

/// A chunk of virtualized mesh data
pub const MeshChunk = struct {
    /// Unique chunk ID
    id: u64,
    /// Bounding box for this chunk
    bounds: AABB,
    /// Vertex data (null if not loaded)
    vertices: ?[]Vec3 = null,
    /// Index data (null if not loaded)
    indices: ?[]u32 = null,
    /// LOD level for this chunk
    lod_level: u8,
    /// Is this chunk currently resident in memory?
    is_resident: bool,
    /// Last access time (for LRU eviction)
    last_access_frame: u64,
    /// Priority for loading/unloading
    priority: f32,
    /// Streaming state
    state: ChunkState,

    pub const ChunkState = enum(u8) {
        unloaded,
        loading,
        loaded,
        unloading,
    };

    pub fn init(id: u64, bounds: AABB, lod_level: u8) MeshChunk {
        return .{
            .id = id,
            .bounds = bounds,
            .lod_level = lod_level,
            .is_resident = false,
            .last_access_frame = 0,
            .priority = 0,
            .state = .unloaded,
        };
    }
};

/// Manages streaming of large virtualized meshes
pub const VirtualMesh = struct {
    allocator: std.mem.Allocator,
    chunks: std.ArrayList(MeshChunk),
    /// Maximum memory budget for resident chunks (bytes)
    memory_budget: u64,
    /// Current memory usage
    current_memory: u64,
    /// Current frame number
    current_frame: u64,
    /// Name identifier
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) VirtualMesh {
        return .{
            .allocator = allocator,
            .chunks = .{},
            .memory_budget = 256 * 1024 * 1024, // 256MB default
            .current_memory = 0,
            .current_frame = 0,
            .name = name,
        };
    }

    pub fn deinit(self: *VirtualMesh) void {
        for (self.chunks.items) |*chunk| {
            if (chunk.vertices) |verts| {
                self.allocator.free(verts);
            }
            if (chunk.indices) |inds| {
                self.allocator.free(inds);
            }
        }
        self.chunks.deinit(self.allocator);
    }

    /// Add a chunk to the virtual mesh
    pub fn addChunk(self: *VirtualMesh, bounds: AABB, lod_level: u8) !u64 {
        const id = self.chunks.items.len;
        try self.chunks.append(self.allocator, MeshChunk.init(id, bounds, lod_level));
        return id;
    }

    /// Update chunk priorities based on camera position
    pub fn updatePriorities(self: *VirtualMesh, camera_pos: Vec3, camera_dir: Vec3) void {
        self.current_frame += 1;

        for (self.chunks.items) |*chunk| {
            const center = chunk.bounds.min.add(chunk.bounds.max).scale(0.5);
            const to_chunk = center.sub(camera_pos);
            const distance = to_chunk.length();

            // Priority based on distance and view direction
            const view_dot = if (distance > 0.001) to_chunk.scale(1.0 / distance).dot(camera_dir) else 1.0;
            chunk.priority = (1.0 / (distance + 1.0)) * @max(view_dot, 0.1);
        }
    }

    /// Request loading of high-priority chunks
    pub fn processStreaming(self: *VirtualMesh) void {
        // Sort by priority (in-place for simplicity)
        // In production, use a proper priority queue

        // Evict low-priority chunks if over budget
        while (self.current_memory > self.memory_budget) {
            var lowest_priority: f32 = std.math.inf(f32);
            var evict_idx: ?usize = null;

            for (self.chunks.items, 0..) |chunk, i| {
                if (chunk.is_resident and chunk.priority < lowest_priority) {
                    lowest_priority = chunk.priority;
                    evict_idx = i;
                }
            }

            if (evict_idx) |idx| {
                self.unloadChunk(&self.chunks.items[idx]);
            } else {
                break;
            }
        }
    }

    fn unloadChunk(self: *VirtualMesh, chunk: *MeshChunk) void {
        if (chunk.vertices) |verts| {
            const vert_size = verts.len * @sizeOf(Vec3);
            self.allocator.free(verts);
            self.current_memory -= vert_size;
            chunk.vertices = null;
        }
        if (chunk.indices) |inds| {
            const idx_size = inds.len * @sizeOf(u32);
            self.allocator.free(inds);
            self.current_memory -= idx_size;
            chunk.indices = null;
        }
        chunk.is_resident = false;
        chunk.state = .unloaded;
    }

    /// Get resident chunk count
    pub fn getResidentChunkCount(self: *const VirtualMesh) usize {
        var count: usize = 0;
        for (self.chunks.items) |chunk| {
            if (chunk.is_resident) count += 1;
        }
        return count;
    }

    /// Get memory usage info
    pub fn getMemoryUsage(self: *const VirtualMesh) struct { used: u64, budget: u64, percentage: f32 } {
        return .{
            .used = self.current_memory,
            .budget = self.memory_budget,
            .percentage = @as(f32, @floatFromInt(self.current_memory)) / @as(f32, @floatFromInt(self.memory_budget)) * 100.0,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LODLevel creation" {
    const level = LODLevel.init(null, 10.0, 50.0);
    try std.testing.expectEqual(@as(f32, 10.0), level.min_distance);
    try std.testing.expectEqual(@as(f32, 50.0), level.max_distance);
    try std.testing.expect(!level.is_billboard);
}

test "LODGroup initialization" {
    const allocator = std.testing.allocator;

    var group = LODGroup.init(allocator, "test_group");
    defer group.deinit();

    try std.testing.expectEqual(@as(u8, 0), group.level_count);
    try std.testing.expect(group.enabled);
}

test "LODGroup add levels" {
    const allocator = std.testing.allocator;

    var group = LODGroup.init(allocator, "test_group");
    defer group.deinit();

    _ = try group.addLevel(null, 0, 10);
    _ = try group.addLevel(null, 10, 50);
    _ = try group.addLevel(null, 50, 200);

    try std.testing.expectEqual(@as(u8, 3), group.level_count);
}

test "LODGroup selectLOD" {
    const allocator = std.testing.allocator;

    var group = LODGroup.init(allocator, "test_group");
    defer group.deinit();

    _ = try group.addLevel(null, 0, 10);
    _ = try group.addLevel(null, 10, 50);
    _ = try group.addLevel(null, 50, 200);

    const camera = Vec3.zero();

    // Close object - should use LOD 0
    const obj_close = Vec3.init(5, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), group.selectLOD(camera, obj_close));

    // Medium distance - should use LOD 1
    const obj_medium = Vec3.init(25, 0, 0);
    try std.testing.expectEqual(@as(u8, 1), group.selectLOD(camera, obj_medium));

    // Far object - should use LOD 2
    const obj_far = Vec3.init(100, 0, 0);
    try std.testing.expectEqual(@as(u8, 2), group.selectLOD(camera, obj_far));
}

test "LODManager basic operations" {
    const allocator = std.testing.allocator;

    var manager = LODManager.init(allocator);
    defer manager.deinit();

    const group = try manager.createGroup("test");
    _ = try group.addLevel(null, 0, 100);

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.group_count);
}

test "QuadricMatrix operations" {
    const n = Vec3.init(0, 1, 0);
    const q = MeshSimplifier.QuadricMatrix.fromPlane(n, -5.0);

    // Point on the plane should have low error
    const on_plane = Vec3.init(0, 5, 0);
    const error_on = q.evaluate(on_plane);
    try std.testing.expect(error_on < 0.001);

    // Point off the plane should have higher error
    const off_plane = Vec3.init(0, 10, 0);
    const error_off = q.evaluate(off_plane);
    try std.testing.expect(error_off > error_on);
}

test "VirtualMesh initialization" {
    const allocator = std.testing.allocator;

    var vmesh = VirtualMesh.init(allocator, "test_virtual");
    defer vmesh.deinit();

    const bounds = AABB{ .min = Vec3.zero(), .max = Vec3.init(10, 10, 10) };
    _ = try vmesh.addChunk(bounds, 0);

    try std.testing.expectEqual(@as(usize, 1), vmesh.chunks.items.len);

    const mem = vmesh.getMemoryUsage();
    try std.testing.expectEqual(@as(u64, 0), mem.used);
}
