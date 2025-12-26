//! Navigation Mesh & Pathfinding System
//!
//! Provides navigation mesh generation, pathfinding (A*), and path smoothing
//! for AI agent navigation in 3D environments.
//!
//! ## Features
//! - NavMesh polygon representation with adjacency
//! - A* pathfinding on navigation graph
//! - Funnel algorithm for path smoothing
//! - Dynamic obstacle support
//! - Agent navigation with steering behaviors
//!
//! ## Example
//! ```zig
//! const navmesh = @import("navmesh.zig");
//!
//! // Create a navmesh from geometry
//! var mesh = try navmesh.NavMesh.init(allocator);
//! defer mesh.deinit();
//!
//! // Add polygons
//! try mesh.addPolygon(&.{v0, v1, v2});
//!
//! // Find path
//! const path = try mesh.findPath(start, end);
//! defer allocator.free(path);
//! ```

const std = @import("std");
const types = @import("types.zig");

const Vec3 = types.Vec3;
const AABB = types.AABB;

// ============================================================================
// Core Types
// ============================================================================

/// Navigation polygon edge
pub const NavEdge = struct {
    /// Start vertex index
    v0: u32,
    /// End vertex index
    v1: u32,
    /// Adjacent polygon index (null if boundary)
    adjacent: ?u32 = null,
    /// Edge midpoint (for pathfinding)
    midpoint: Vec3 = Vec3.zero(),
    /// Edge width (for agent fitting)
    width: f32 = 0,
};

/// Navigation polygon (convex)
pub const NavPolygon = struct {
    /// Vertex indices (CCW winding)
    vertices: []u32,
    /// Edges with adjacency info
    edges: []NavEdge,
    /// Polygon center (for heuristics)
    center: Vec3 = Vec3.zero(),
    /// Polygon normal
    normal: Vec3 = Vec3.up(),
    /// Bounding box
    bounds: AABB = .{},
    /// Area in square units
    area: f32 = 0,
    /// Traversal cost multiplier
    cost: f32 = 1.0,
    /// Polygon flags (walkable, water, etc.)
    flags: PolygonFlags = .{},

    /// Polygon type flags
    pub const PolygonFlags = packed struct {
        walkable: bool = true,
        water: bool = false,
        jump: bool = false,
        ladder: bool = false,
        disabled: bool = false,
        _padding: u3 = 0,
    };
};

/// Navigation mesh graph node for pathfinding
pub const NavNode = struct {
    /// Polygon index
    polygon: u32,
    /// Position (polygon center or edge midpoint)
    position: Vec3,
    /// Pathfinding data
    g_cost: f32 = std.math.inf(f32),
    h_cost: f32 = 0,
    parent: ?u32 = null,
    closed: bool = false,

    pub fn fCost(self: NavNode) f32 {
        return self.g_cost + self.h_cost;
    }
};

/// Path waypoint with additional info
pub const PathWaypoint = struct {
    position: Vec3,
    polygon: u32,
    flags: WaypointFlags = .{},

    pub const WaypointFlags = packed struct {
        corner: bool = false,
        portal: bool = false,
        jump: bool = false,
        _padding: u5 = 0,
    };
};

/// Navigation query filter
pub const NavQueryFilter = struct {
    /// Include polygon flags
    include_flags: NavPolygon.PolygonFlags = .{ .walkable = true },
    /// Exclude polygon flags
    exclude_flags: NavPolygon.PolygonFlags = .{ .disabled = true },
    /// Maximum agent height
    agent_height: f32 = 2.0,
    /// Maximum agent radius
    agent_radius: f32 = 0.5,
    /// Maximum traversable slope (radians)
    max_slope: f32 = 0.785, // ~45 degrees
    /// Maximum step height
    max_step_height: f32 = 0.5,

    pub fn canTraverse(self: NavQueryFilter, polygon: *const NavPolygon) bool {
        const flags = polygon.flags;
        // Check include
        if (self.include_flags.walkable and !flags.walkable) return false;
        // Check exclude
        if (self.exclude_flags.disabled and flags.disabled) return false;
        return true;
    }
};

/// Agent state for navigation
pub const NavAgent = struct {
    /// Current position
    position: Vec3 = Vec3.zero(),
    /// Current velocity
    velocity: Vec3 = Vec3.zero(),
    /// Target position
    target: ?Vec3 = null,
    /// Current polygon index
    current_polygon: ?u32 = null,
    /// Current path
    path: std.ArrayList(PathWaypoint),
    /// Path index
    path_index: u32 = 0,
    /// Agent radius
    radius: f32 = 0.5,
    /// Agent height
    height: f32 = 2.0,
    /// Maximum speed
    max_speed: f32 = 5.0,
    /// Maximum acceleration
    max_acceleration: f32 = 10.0,
    /// State
    state: AgentState = .idle,
    /// Allocator
    allocator: std.mem.Allocator,

    pub const AgentState = enum(u8) {
        idle,
        moving,
        waiting,
        stuck,
    };

    pub fn init(allocator: std.mem.Allocator) NavAgent {
        return .{
            .path = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NavAgent) void {
        self.path.deinit(self.allocator);
    }

    /// Set target and request path
    pub fn setTarget(self: *NavAgent, target: Vec3) void {
        self.target = target;
        self.path.clearRetainingCapacity();
        self.path_index = 0;
        self.state = .moving;
    }

    /// Update agent movement
    pub fn update(self: *NavAgent, dt: f32) void {
        if (self.state != .moving) return;
        if (self.path.items.len == 0) return;
        if (self.path_index >= self.path.items.len) {
            self.state = .idle;
            return;
        }

        const waypoint = self.path.items[self.path_index];
        const to_waypoint = waypoint.position.sub(self.position);
        const dist = to_waypoint.length();

        // Reached waypoint?
        if (dist < self.radius) {
            self.path_index += 1;
            if (self.path_index >= self.path.items.len) {
                self.state = .idle;
                self.velocity = Vec3.zero();
            }
            return;
        }

        // Steer towards waypoint
        const desired = to_waypoint.normalize().scale(self.max_speed);
        const steering = desired.sub(self.velocity);
        const accel = clampLength(steering, self.max_acceleration);

        self.velocity = clampLength(self.velocity.add(accel.scale(dt)), self.max_speed);
        self.position = self.position.add(self.velocity.scale(dt));
    }

    fn clampLength(v: Vec3, max_len: f32) Vec3 {
        const len = v.length();
        if (len > max_len) {
            return v.scale(max_len / len);
        }
        return v;
    }
};

// ============================================================================
// Navigation Mesh
// ============================================================================

/// Navigation mesh for pathfinding
pub const NavMesh = struct {
    /// Allocator
    allocator: std.mem.Allocator,
    /// Vertices
    vertices: std.ArrayList(Vec3),
    /// Polygons
    polygons: std.ArrayList(NavPolygon),
    /// Spatial grid for fast queries
    grid: ?SpatialGrid = null,
    /// Overall bounds
    bounds: AABB = .{},
    /// Grid cell size
    cell_size: f32 = 10.0,

    /// Spatial acceleration grid
    pub const SpatialGrid = struct {
        cells: std.AutoHashMap(GridKey, std.ArrayList(u32)),
        cell_size: f32,
        allocator: std.mem.Allocator,

        pub const GridKey = struct {
            x: i32,
            y: i32,
            z: i32,
        };

        pub fn init(allocator: std.mem.Allocator, cell_size: f32) SpatialGrid {
            return .{
                .cells = std.AutoHashMap(GridKey, std.ArrayList(u32)).init(allocator),
                .cell_size = cell_size,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *SpatialGrid) void {
            var iter = self.cells.valueIterator();
            while (iter.next()) |list_ptr| {
                list_ptr.deinit(self.allocator);
            }
            self.cells.deinit();
        }

        pub fn getKey(self: *const SpatialGrid, pos: Vec3) GridKey {
            return .{
                .x = @intFromFloat(@floor(pos.x / self.cell_size)),
                .y = @intFromFloat(@floor(pos.y / self.cell_size)),
                .z = @intFromFloat(@floor(pos.z / self.cell_size)),
            };
        }

        pub fn insert(self: *SpatialGrid, polygon_idx: u32, center: Vec3) !void {
            const key = self.getKey(center);
            const result = try self.cells.getOrPut(key);
            if (!result.found_existing) {
                result.value_ptr.* = .{};
            }
            try result.value_ptr.append(self.allocator, polygon_idx);
        }

        pub fn query(self: *const SpatialGrid, pos: Vec3) ?[]const u32 {
            const key = self.getKey(pos);
            if (self.cells.get(key)) |list| {
                return list.items;
            }
            return null;
        }
    };

    pub fn init(allocator: std.mem.Allocator) NavMesh {
        return .{
            .allocator = allocator,
            .vertices = .{},
            .polygons = .{},
        };
    }

    pub fn deinit(self: *NavMesh) void {
        for (self.polygons.items) |*poly| {
            self.allocator.free(poly.vertices);
            self.allocator.free(poly.edges);
        }
        self.polygons.deinit(self.allocator);
        self.vertices.deinit(self.allocator);
        if (self.grid) |*grid| {
            grid.deinit();
        }
    }

    /// Add a vertex and return its index
    pub fn addVertex(self: *NavMesh, v: Vec3) !u32 {
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.vertices.append(self.allocator, v);
        return idx;
    }

    /// Add a polygon from vertex indices
    pub fn addPolygon(self: *NavMesh, vertex_indices: []const u32) !u32 {
        const poly_idx: u32 = @intCast(self.polygons.items.len);

        // Copy vertex indices
        const verts = try self.allocator.alloc(u32, vertex_indices.len);
        @memcpy(verts, vertex_indices);

        // Create edges
        const edges = try self.allocator.alloc(NavEdge, vertex_indices.len);
        for (edges, 0..) |*edge, i| {
            const next = (i + 1) % vertex_indices.len;
            const v0_idx = vertex_indices[i];
            const v1_idx = vertex_indices[next];
            const v0 = self.vertices.items[v0_idx];
            const v1 = self.vertices.items[v1_idx];

            edge.* = .{
                .v0 = v0_idx,
                .v1 = v1_idx,
                .midpoint = v0.add(v1).scale(0.5),
                .width = v0.sub(v1).length(),
            };
        }

        // Calculate center and bounds
        var center = Vec3.zero();
        var min_pt = Vec3.init(std.math.inf(f32), std.math.inf(f32), std.math.inf(f32));
        var max_pt = Vec3.init(-std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32));

        for (vertex_indices) |idx| {
            const v = self.vertices.items[idx];
            center = center.add(v);
            min_pt = Vec3.init(@min(min_pt.x, v.x), @min(min_pt.y, v.y), @min(min_pt.z, v.z));
            max_pt = Vec3.init(@max(max_pt.x, v.x), @max(max_pt.y, v.y), @max(max_pt.z, v.z));
        }
        center = center.scale(1.0 / @as(f32, @floatFromInt(vertex_indices.len)));

        // Calculate normal (assuming CCW winding)
        var normal = Vec3.up();
        if (vertex_indices.len >= 3) {
            const v0 = self.vertices.items[vertex_indices[0]];
            const v1 = self.vertices.items[vertex_indices[1]];
            const v2 = self.vertices.items[vertex_indices[2]];
            const edge1 = v1.sub(v0);
            const edge2 = v2.sub(v0);
            normal = edge1.cross(edge2).normalize();
        }

        // Calculate area (sum of triangles from center)
        var area: f32 = 0;
        for (0..vertex_indices.len) |i| {
            const next = (i + 1) % vertex_indices.len;
            const v0 = self.vertices.items[vertex_indices[i]];
            const v1 = self.vertices.items[vertex_indices[next]];
            const tri_area = v0.sub(center).cross(v1.sub(center)).length() * 0.5;
            area += tri_area;
        }

        try self.polygons.append(self.allocator, .{
            .vertices = verts,
            .edges = edges,
            .center = center,
            .normal = normal,
            .bounds = .{ .min = min_pt, .max = max_pt },
            .area = area,
        });

        // Update overall bounds
        self.bounds.min = Vec3.init(
            @min(self.bounds.min.x, min_pt.x),
            @min(self.bounds.min.y, min_pt.y),
            @min(self.bounds.min.z, min_pt.z),
        );
        self.bounds.max = Vec3.init(
            @max(self.bounds.max.x, max_pt.x),
            @max(self.bounds.max.y, max_pt.y),
            @max(self.bounds.max.z, max_pt.z),
        );

        return poly_idx;
    }

    /// Build adjacency information between polygons
    pub fn buildAdjacency(self: *NavMesh) void {
        // For each polygon pair, check for shared edges
        for (self.polygons.items, 0..) |*poly_a, i| {
            for (self.polygons.items[(i + 1)..], (i + 1)..) |*poly_b, j| {
                // Check each edge pair
                for (poly_a.edges) |*edge_a| {
                    for (poly_b.edges) |*edge_b| {
                        // Shared edge has reversed vertex order
                        if (edge_a.v0 == edge_b.v1 and edge_a.v1 == edge_b.v0) {
                            edge_a.adjacent = @intCast(j);
                            edge_b.adjacent = @intCast(i);
                        }
                    }
                }
            }
        }
    }

    /// Build spatial grid for fast queries
    pub fn buildSpatialGrid(self: *NavMesh) !void {
        if (self.grid) |*grid| {
            grid.deinit();
        }
        self.grid = SpatialGrid.init(self.allocator, self.cell_size);

        for (self.polygons.items, 0..) |poly, i| {
            try self.grid.?.insert(@intCast(i), poly.center);
        }
    }

    /// Find the polygon containing a point
    pub fn findPolygon(self: *const NavMesh, pos: Vec3, filter: ?NavQueryFilter) ?u32 {
        // Use spatial grid if available
        if (self.grid) |grid| {
            if (grid.query(pos)) |candidates| {
                for (candidates) |idx| {
                    const poly = &self.polygons.items[idx];
                    if (filter) |f| {
                        if (!f.canTraverse(poly)) continue;
                    }
                    if (self.pointInPolygon(pos, poly)) {
                        return idx;
                    }
                }
            }
        }

        // Fallback to linear search
        for (self.polygons.items, 0..) |*poly, i| {
            if (filter) |f| {
                if (!f.canTraverse(poly)) continue;
            }
            if (self.pointInPolygon(pos, poly)) {
                return @intCast(i);
            }
        }
        return null;
    }

    /// Test if point is inside polygon (2D projection)
    fn pointInPolygon(self: *const NavMesh, pos: Vec3, poly: *const NavPolygon) bool {
        // Bounds check first
        if (pos.x < poly.bounds.min.x or pos.x > poly.bounds.max.x) return false;
        if (pos.z < poly.bounds.min.z or pos.z > poly.bounds.max.z) return false;

        // Winding number test (XZ plane)
        var winding: i32 = 0;
        const n = poly.vertices.len;

        for (0..n) |i| {
            const v0 = self.vertices.items[poly.vertices[i]];
            const v1 = self.vertices.items[poly.vertices[(i + 1) % n]];

            if (v0.z <= pos.z) {
                if (v1.z > pos.z) {
                    if (isLeft2D(v0, v1, pos) > 0) {
                        winding += 1;
                    }
                }
            } else {
                if (v1.z <= pos.z) {
                    if (isLeft2D(v0, v1, pos) < 0) {
                        winding -= 1;
                    }
                }
            }
        }

        return winding != 0;
    }

    fn isLeft2D(v0: Vec3, v1: Vec3, p: Vec3) f32 {
        return (v1.x - v0.x) * (p.z - v0.z) - (p.x - v0.x) * (v1.z - v0.z);
    }

    /// Find path between two points using A*
    pub fn findPath(
        self: *const NavMesh,
        start: Vec3,
        goal: Vec3,
        filter: ?NavQueryFilter,
        allocator: std.mem.Allocator,
    ) !?[]PathWaypoint {
        // Find start and goal polygons
        const start_poly = self.findPolygon(start, filter) orelse return null;
        const goal_poly = self.findPolygon(goal, filter) orelse return null;

        // Same polygon - direct path
        if (start_poly == goal_poly) {
            var path = try allocator.alloc(PathWaypoint, 2);
            path[0] = .{ .position = start, .polygon = start_poly };
            path[1] = .{ .position = goal, .polygon = goal_poly };
            return path;
        }

        // A* pathfinding
        var nodes = try allocator.alloc(NavNode, self.polygons.items.len);
        defer allocator.free(nodes);

        for (nodes, 0..) |*node, i| {
            node.* = .{
                .polygon = @intCast(i),
                .position = self.polygons.items[i].center,
            };
        }

        // Open list (priority queue would be more efficient)
        var open: std.ArrayList(u32) = .{};
        defer open.deinit(allocator);

        // Initialize start node
        nodes[start_poly].g_cost = 0;
        nodes[start_poly].h_cost = heuristic(start, goal);
        try open.append(allocator, start_poly);

        while (open.items.len > 0) {
            // Find node with lowest f_cost
            var best_idx: usize = 0;
            var best_f = nodes[open.items[0]].fCost();
            for (open.items[1..], 1..) |node_idx, i| {
                const f = nodes[node_idx].fCost();
                if (f < best_f) {
                    best_f = f;
                    best_idx = i;
                }
            }

            const current = open.items[best_idx];
            _ = open.swapRemove(best_idx);

            // Goal reached
            if (current == goal_poly) {
                return try self.reconstructPath(nodes, start, goal, start_poly, goal_poly, allocator);
            }

            nodes[current].closed = true;

            // Explore neighbors
            const poly = &self.polygons.items[current];
            for (poly.edges) |edge| {
                if (edge.adjacent) |neighbor| {
                    if (nodes[neighbor].closed) continue;

                    const neighbor_poly = &self.polygons.items[neighbor];
                    if (filter) |f| {
                        if (!f.canTraverse(neighbor_poly)) continue;
                    }

                    const move_cost = nodes[current].position.sub(edge.midpoint).length();
                    const new_g = nodes[current].g_cost + move_cost * neighbor_poly.cost;

                    if (new_g < nodes[neighbor].g_cost) {
                        nodes[neighbor].g_cost = new_g;
                        nodes[neighbor].h_cost = heuristic(neighbor_poly.center, goal);
                        nodes[neighbor].parent = current;

                        // Add to open if not already there
                        var in_open = false;
                        for (open.items) |o| {
                            if (o == neighbor) {
                                in_open = true;
                                break;
                            }
                        }
                        if (!in_open) {
                            try open.append(allocator, neighbor);
                        }
                    }
                }
            }
        }

        return null; // No path found
    }

    fn heuristic(a: Vec3, b: Vec3) f32 {
        return a.sub(b).length();
    }

    fn reconstructPath(
        self: *const NavMesh,
        nodes: []NavNode,
        start: Vec3,
        goal: Vec3,
        start_poly: u32,
        goal_poly: u32,
        allocator: std.mem.Allocator,
    ) ![]PathWaypoint {
        // Count path length
        var count: usize = 2; // start + goal
        var current = goal_poly;
        while (nodes[current].parent) |parent| {
            count += 1;
            current = parent;
            if (current == start_poly) break;
        }

        var path = try allocator.alloc(PathWaypoint, count);

        // Fill in reverse
        var idx = count - 1;
        path[idx] = .{ .position = goal, .polygon = goal_poly };

        current = goal_poly;
        while (nodes[current].parent) |parent| {
            idx -= 1;
            // Find portal between parent and current
            const parent_poly = &self.polygons.items[parent];
            for (parent_poly.edges) |edge| {
                if (edge.adjacent == current) {
                    path[idx] = .{
                        .position = edge.midpoint,
                        .polygon = parent,
                        .flags = .{ .portal = true },
                    };
                    break;
                }
            }
            current = parent;
            if (current == start_poly) break;
        }

        path[0] = .{ .position = start, .polygon = start_poly };

        return path;
    }

    /// Apply funnel algorithm for path smoothing
    pub fn smoothPath(
        _: *const NavMesh,
        path: []PathWaypoint,
        allocator: std.mem.Allocator,
    ) ![]PathWaypoint {
        if (path.len <= 2) {
            const result = try allocator.alloc(PathWaypoint, path.len);
            @memcpy(result, path);
            return result;
        }

        var smoothed: std.ArrayList(PathWaypoint) = .{};
        errdefer smoothed.deinit(allocator);

        try smoothed.append(allocator, path[0]);

        var apex = path[0].position;
        var left = apex;
        var right = apex;
        var apex_idx: usize = 0;
        var left_idx: usize = 0;
        var right_idx: usize = 0;

        for (path[1..], 1..) |waypoint, i| {
            const portal_left = waypoint.position; // Simplified: use waypoint directly
            const portal_right = waypoint.position;

            // Update right funnel side
            if (triArea2D(apex, right, portal_right) <= 0) {
                if (apex.x == right.x and apex.z == right.z or
                    triArea2D(apex, left, portal_right) > 0)
                {
                    right = portal_right;
                    right_idx = i;
                } else {
                    // Right over left, add left as corner
                    try smoothed.append(allocator, .{
                        .position = left,
                        .polygon = path[left_idx].polygon,
                        .flags = .{ .corner = true },
                    });
                    apex = left;
                    apex_idx = left_idx;
                    left = apex;
                    right = apex;
                    left_idx = apex_idx;
                    right_idx = apex_idx;
                    continue;
                }
            }

            // Update left funnel side
            if (triArea2D(apex, left, portal_left) >= 0) {
                if (apex.x == left.x and apex.z == left.z or
                    triArea2D(apex, right, portal_left) < 0)
                {
                    left = portal_left;
                    left_idx = i;
                } else {
                    // Left over right, add right as corner
                    try smoothed.append(allocator, .{
                        .position = right,
                        .polygon = path[right_idx].polygon,
                        .flags = .{ .corner = true },
                    });
                    apex = right;
                    apex_idx = right_idx;
                    left = apex;
                    right = apex;
                    left_idx = apex_idx;
                    right_idx = apex_idx;
                    continue;
                }
            }
        }

        // Add final point
        try smoothed.append(allocator, path[path.len - 1]);

        return smoothed.toOwnedSlice(allocator);
    }

    fn triArea2D(a: Vec3, b: Vec3, c: Vec3) f32 {
        return (c.x - a.x) * (b.z - a.z) - (b.x - a.x) * (c.z - a.z);
    }

    /// Get closest point on navmesh to given position
    pub fn getClosestPoint(self: *const NavMesh, pos: Vec3, filter: ?NavQueryFilter) ?struct { point: Vec3, polygon: u32 } {
        var closest_dist = std.math.inf(f32);
        var closest_point: Vec3 = undefined;
        var closest_poly: u32 = undefined;

        for (self.polygons.items, 0..) |*poly, i| {
            if (filter) |f| {
                if (!f.canTraverse(poly)) continue;
            }

            const point = self.closestPointOnPolygon(pos, poly);
            const dist = pos.sub(point).lengthSquared();

            if (dist < closest_dist) {
                closest_dist = dist;
                closest_point = point;
                closest_poly = @intCast(i);
            }
        }

        if (closest_dist < std.math.inf(f32)) {
            return .{ .point = closest_point, .polygon = closest_poly };
        }
        return null;
    }

    fn closestPointOnPolygon(self: *const NavMesh, pos: Vec3, poly: *const NavPolygon) Vec3 {
        // Check if point is inside
        if (self.pointInPolygon(pos, poly)) {
            // Project onto polygon plane
            const to_point = pos.sub(poly.center);
            const dist = to_point.dot(poly.normal);
            return pos.sub(poly.normal.scale(dist));
        }

        // Find closest point on edges
        var closest = poly.center;
        var closest_dist = std.math.inf(f32);

        for (poly.edges) |edge| {
            const v0 = self.vertices.items[edge.v0];
            const v1 = self.vertices.items[edge.v1];
            const point = closestPointOnSegment(pos, v0, v1);
            const dist = pos.sub(point).lengthSquared();

            if (dist < closest_dist) {
                closest_dist = dist;
                closest = point;
            }
        }

        return closest;
    }
};

fn closestPointOnSegment(p: Vec3, a: Vec3, b: Vec3) Vec3 {
    const ab = b.sub(a);
    const ap = p.sub(a);
    var t = ap.dot(ab) / ab.dot(ab);
    t = std.math.clamp(t, 0.0, 1.0);
    return a.add(ab.scale(t));
}

// ============================================================================
// NavMesh Builder
// ============================================================================

/// Builder for generating navigation meshes from geometry
pub const NavMeshBuilder = struct {
    allocator: std.mem.Allocator,
    /// Cell size for voxelization
    cell_size: f32 = 0.3,
    /// Cell height for voxelization
    cell_height: f32 = 0.2,
    /// Agent height
    agent_height: f32 = 2.0,
    /// Agent radius
    agent_radius: f32 = 0.5,
    /// Maximum slope (radians)
    max_slope: f32 = 0.785,
    /// Maximum step height
    max_step_height: f32 = 0.5,
    /// Minimum region area
    min_region_area: f32 = 8.0,
    /// Merge region area
    merge_region_area: f32 = 20.0,

    pub fn init(allocator: std.mem.Allocator) NavMeshBuilder {
        return .{ .allocator = allocator };
    }

    /// Build navmesh from triangle soup
    pub fn build(
        self: *NavMeshBuilder,
        vertices: []const Vec3,
        indices: []const u32,
    ) !NavMesh {
        var mesh = NavMesh.init(self.allocator);
        errdefer mesh.deinit();

        // Add vertices
        for (vertices) |v| {
            _ = try mesh.addVertex(v);
        }

        // Add triangles as polygons
        var i: usize = 0;
        while (i < indices.len) : (i += 3) {
            const tri_indices = [3]u32{ indices[i], indices[i + 1], indices[i + 2] };

            // Check slope
            const v0 = vertices[indices[i]];
            const v1 = vertices[indices[i + 1]];
            const v2 = vertices[indices[i + 2]];

            const edge1 = v1.sub(v0);
            const edge2 = v2.sub(v0);
            const normal = edge1.cross(edge2).normalize();

            const slope = std.math.acos(normal.dot(Vec3.up()));
            if (slope <= self.max_slope) {
                _ = try mesh.addPolygon(&tri_indices);
            }
        }

        mesh.buildAdjacency();
        try mesh.buildSpatialGrid();

        return mesh;
    }

    /// Build navmesh from heightfield
    pub fn buildFromHeightfield(
        self: *NavMeshBuilder,
        heights: []const f32,
        width: u32,
        depth: u32,
        scale: Vec3,
    ) !NavMesh {
        var mesh = NavMesh.init(self.allocator);
        errdefer mesh.deinit();

        // Create vertices from heightfield
        for (0..depth) |z| {
            for (0..width) |x| {
                const height = heights[z * width + x];
                const pos = Vec3.init(
                    @as(f32, @floatFromInt(x)) * scale.x,
                    height * scale.y,
                    @as(f32, @floatFromInt(z)) * scale.z,
                );
                _ = try mesh.addVertex(pos);
            }
        }

        // Create quads from heightfield grid
        for (0..(depth - 1)) |z| {
            for (0..(width - 1)) |x| {
                const idx0: u32 = @intCast(z * width + x);
                const idx1: u32 = @intCast(z * width + (x + 1));
                const idx2: u32 = @intCast((z + 1) * width + (x + 1));
                const idx3: u32 = @intCast((z + 1) * width + x);

                // Check walkability (height difference)
                const h0 = heights[idx0];
                const h1 = heights[idx1];
                const h2 = heights[idx2];
                const h3 = heights[idx3];

                const max_diff = @max(@max(@abs(h0 - h1), @abs(h1 - h2)), @max(@abs(h2 - h3), @abs(h3 - h0)));

                if (max_diff * scale.y <= self.max_step_height) {
                    const quad_indices = [4]u32{ idx0, idx1, idx2, idx3 };
                    _ = try mesh.addPolygon(&quad_indices);
                }
            }
        }

        mesh.buildAdjacency();
        try mesh.buildSpatialGrid();

        return mesh;
    }
};

// ============================================================================
// Dynamic Obstacles
// ============================================================================

/// Dynamic obstacle that can be added/removed from navmesh
pub const DynamicObstacle = struct {
    /// Obstacle ID
    id: u32,
    /// Position
    position: Vec3,
    /// Radius
    radius: f32,
    /// Height
    height: f32,
    /// Shape type
    shape: Shape = .cylinder,
    /// Affected polygon indices
    affected_polygons: std.ArrayList(u32),
    /// Is active
    active: bool = true,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub const Shape = enum(u8) {
        cylinder,
        box,
        convex,
    };

    pub fn init(allocator: std.mem.Allocator, id: u32, pos: Vec3, radius: f32, height: f32) DynamicObstacle {
        return .{
            .id = id,
            .position = pos,
            .radius = radius,
            .height = height,
            .affected_polygons = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DynamicObstacle) void {
        self.affected_polygons.deinit(self.allocator);
    }
};

/// Manages dynamic obstacles on a navmesh
pub const ObstacleManager = struct {
    allocator: std.mem.Allocator,
    obstacles: std.AutoHashMap(u32, DynamicObstacle),
    next_id: u32 = 0,
    mesh: *NavMesh,

    pub fn init(allocator: std.mem.Allocator, mesh: *NavMesh) ObstacleManager {
        return .{
            .allocator = allocator,
            .obstacles = std.AutoHashMap(u32, DynamicObstacle).init(allocator),
            .mesh = mesh,
        };
    }

    pub fn deinit(self: *ObstacleManager) void {
        var iter = self.obstacles.valueIterator();
        while (iter.next()) |obstacle_ptr| {
            obstacle_ptr.deinit();
        }
        self.obstacles.deinit();
    }

    /// Add a cylindrical obstacle
    pub fn addObstacle(self: *ObstacleManager, pos: Vec3, radius: f32, height: f32) !u32 {
        const id = self.next_id;
        self.next_id += 1;

        var obstacle = DynamicObstacle.init(self.allocator, id, pos, radius, height);

        // Find affected polygons
        for (self.mesh.polygons.items, 0..) |*poly, i| {
            const dist = pos.sub(poly.center).length();
            if (dist <= radius + poly.bounds.max.sub(poly.bounds.min).length() * 0.5) {
                try obstacle.affected_polygons.append(obstacle.allocator, @intCast(i));
                // Mark polygon as blocked
                poly.flags.disabled = true;
            }
        }

        try self.obstacles.put(id, obstacle);
        return id;
    }

    /// Remove an obstacle
    pub fn removeObstacle(self: *ObstacleManager, id: u32) void {
        if (self.obstacles.getPtr(id)) |obstacle| {
            // Restore affected polygons
            for (obstacle.affected_polygons.items) |poly_idx| {
                self.mesh.polygons.items[poly_idx].flags.disabled = false;
            }
            obstacle.deinit();
            _ = self.obstacles.remove(id);
        }
    }

    /// Update obstacle position
    pub fn updateObstacle(self: *ObstacleManager, id: u32, new_pos: Vec3) !void {
        if (self.obstacles.getPtr(id)) |obstacle| {
            // Restore old affected polygons
            for (obstacle.affected_polygons.items) |poly_idx| {
                self.mesh.polygons.items[poly_idx].flags.disabled = false;
            }
            obstacle.affected_polygons.clearRetainingCapacity();

            // Update position
            obstacle.position = new_pos;

            // Find new affected polygons
            for (self.mesh.polygons.items, 0..) |*poly, i| {
                const dist = new_pos.sub(poly.center).length();
                if (dist <= obstacle.radius + poly.bounds.max.sub(poly.bounds.min).length() * 0.5) {
                    try obstacle.affected_polygons.append(obstacle.allocator, @intCast(i));
                    poly.flags.disabled = true;
                }
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "NavMesh basic operations" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Add vertices for a square
    const v0 = try mesh.addVertex(Vec3.init(0, 0, 0));
    const v1 = try mesh.addVertex(Vec3.init(10, 0, 0));
    const v2 = try mesh.addVertex(Vec3.init(10, 0, 10));
    const v3 = try mesh.addVertex(Vec3.init(0, 0, 10));

    // Add polygon
    const indices = [_]u32{ v0, v1, v2, v3 };
    const poly_idx = try mesh.addPolygon(&indices);

    try std.testing.expectEqual(@as(u32, 0), poly_idx);
    try std.testing.expectEqual(@as(usize, 4), mesh.vertices.items.len);
    try std.testing.expectEqual(@as(usize, 1), mesh.polygons.items.len);
}

test "NavMesh point in polygon" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create a triangle
    _ = try mesh.addVertex(Vec3.init(0, 0, 0));
    _ = try mesh.addVertex(Vec3.init(10, 0, 0));
    _ = try mesh.addVertex(Vec3.init(5, 0, 10));
    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2 });

    // Point inside
    const inside = mesh.findPolygon(Vec3.init(5, 0, 3), null);
    try std.testing.expect(inside != null);
    try std.testing.expectEqual(@as(u32, 0), inside.?);

    // Point outside
    const outside = mesh.findPolygon(Vec3.init(-5, 0, 0), null);
    try std.testing.expect(outside == null);
}

test "NavMesh pathfinding" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create two adjacent triangles
    _ = try mesh.addVertex(Vec3.init(0, 0, 0)); // 0
    _ = try mesh.addVertex(Vec3.init(10, 0, 0)); // 1
    _ = try mesh.addVertex(Vec3.init(10, 0, 10)); // 2
    _ = try mesh.addVertex(Vec3.init(0, 0, 10)); // 3
    _ = try mesh.addVertex(Vec3.init(20, 0, 10)); // 4

    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2, 3 }); // Square
    _ = try mesh.addPolygon(&[_]u32{ 1, 4, 2 }); // Triangle

    mesh.buildAdjacency();

    // Find path (goal at x=15, z=7 is clearly inside the triangle)
    const path = try mesh.findPath(
        Vec3.init(5, 0, 5),
        Vec3.init(15, 0, 7),
        null,
        allocator,
    );

    try std.testing.expect(path != null);
    defer allocator.free(path.?);

    try std.testing.expect(path.?.len >= 2);
}

test "NavAgent update" {
    const allocator = std.testing.allocator;

    var agent = NavAgent.init(allocator);
    defer agent.deinit();

    agent.position = Vec3.init(0, 0, 0);
    agent.setTarget(Vec3.init(10, 0, 0));

    // Add a waypoint manually
    try agent.path.append(allocator, .{
        .position = Vec3.init(10, 0, 0),
        .polygon = 0,
    });

    // Update
    agent.update(0.1);

    // Agent should be moving
    try std.testing.expect(agent.velocity.length() > 0);
}

test "NavMeshBuilder heightfield" {
    const allocator = std.testing.allocator;

    var builder = NavMeshBuilder.init(allocator);

    // Create 3x3 flat heightfield
    const heights = [_]f32{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const scale = Vec3.init(1, 1, 1);

    var mesh = try builder.buildFromHeightfield(&heights, 3, 3, scale);
    defer mesh.deinit();

    // Should have 4 quads (2x2 grid)
    try std.testing.expectEqual(@as(usize, 4), mesh.polygons.items.len);
}

test "NavNode fCost calculation" {
    var node = NavNode{
        .polygon = 0,
        .position = Vec3.zero(),
        .g_cost = 5.0,
        .h_cost = 3.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), node.fCost(), 0.01);

    // Infinite g_cost should result in infinite fCost
    node.g_cost = std.math.inf(f32);
    try std.testing.expect(node.fCost() == std.math.inf(f32));
}

test "NavQueryFilter canTraverse" {
    const filter = NavQueryFilter{
        .include_flags = .{ .walkable = true },
        .exclude_flags = .{ .disabled = true },
    };

    // Walkable polygon should be traversable
    var walkable_poly = NavPolygon{
        .vertices = undefined,
        .edges = undefined,
        .flags = .{ .walkable = true, .disabled = false },
    };
    try std.testing.expect(filter.canTraverse(&walkable_poly));

    // Disabled polygon should not be traversable
    var disabled_poly = NavPolygon{
        .vertices = undefined,
        .edges = undefined,
        .flags = .{ .walkable = true, .disabled = true },
    };
    try std.testing.expect(!filter.canTraverse(&disabled_poly));

    // Non-walkable polygon should not be traversable
    var non_walkable = NavPolygon{
        .vertices = undefined,
        .edges = undefined,
        .flags = .{ .walkable = false, .disabled = false },
    };
    try std.testing.expect(!filter.canTraverse(&non_walkable));
}

test "SpatialGrid operations" {
    const allocator = std.testing.allocator;

    var grid = NavMesh.SpatialGrid.init(allocator, 10.0);
    defer grid.deinit();

    // Insert polygon at position
    try grid.insert(0, Vec3.init(5, 0, 5));
    try grid.insert(1, Vec3.init(5, 0, 8));
    try grid.insert(2, Vec3.init(25, 0, 5)); // Different cell

    // Query same cell
    const result1 = grid.query(Vec3.init(3, 0, 3));
    try std.testing.expect(result1 != null);
    try std.testing.expectEqual(@as(usize, 2), result1.?.len);

    // Query different cell
    const result2 = grid.query(Vec3.init(25, 0, 5));
    try std.testing.expect(result2 != null);
    try std.testing.expectEqual(@as(usize, 1), result2.?.len);

    // Query empty cell
    const result3 = grid.query(Vec3.init(100, 0, 100));
    try std.testing.expect(result3 == null);

    // Test getKey consistency
    const key1 = grid.getKey(Vec3.init(5, 0, 5));
    const key2 = grid.getKey(Vec3.init(8, 0, 8));
    try std.testing.expectEqual(key1.x, key2.x);
    try std.testing.expectEqual(key1.z, key2.z);
}

test "NavMesh smoothPath" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create a simple path
    var path = [_]PathWaypoint{
        .{ .position = Vec3.init(0, 0, 0), .polygon = 0 },
        .{ .position = Vec3.init(5, 0, 5), .polygon = 0 },
        .{ .position = Vec3.init(10, 0, 10), .polygon = 0 },
    };

    const smoothed = try mesh.smoothPath(&path, allocator);
    defer allocator.free(smoothed);

    // Smoothed path should have at least 2 points (start and end)
    try std.testing.expect(smoothed.len >= 2);
    // First point should be start
    try std.testing.expectApproxEqAbs(@as(f32, 0), smoothed[0].position.x, 0.01);
    // Last point should be end
    try std.testing.expectApproxEqAbs(@as(f32, 10), smoothed[smoothed.len - 1].position.x, 0.01);
}

test "NavMesh getClosestPoint" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create a square polygon
    _ = try mesh.addVertex(Vec3.init(0, 0, 0));
    _ = try mesh.addVertex(Vec3.init(10, 0, 0));
    _ = try mesh.addVertex(Vec3.init(10, 0, 10));
    _ = try mesh.addVertex(Vec3.init(0, 0, 10));
    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2, 3 });

    // Point inside polygon
    const inside_result = mesh.getClosestPoint(Vec3.init(5, 0, 5), null);
    try std.testing.expect(inside_result != null);
    try std.testing.expectEqual(@as(u32, 0), inside_result.?.polygon);

    // Point outside polygon - should find closest point on edge
    const outside_result = mesh.getClosestPoint(Vec3.init(15, 0, 5), null);
    try std.testing.expect(outside_result != null);
    // Closest point should be on the right edge (x=10)
    try std.testing.expectApproxEqAbs(@as(f32, 10), outside_result.?.point.x, 0.01);
}

test "DynamicObstacle initialization" {
    const allocator = std.testing.allocator;

    var obstacle = DynamicObstacle.init(allocator, 42, Vec3.init(5, 0, 5), 2.0, 3.0);
    defer obstacle.deinit();

    try std.testing.expectEqual(@as(u32, 42), obstacle.id);
    try std.testing.expectApproxEqAbs(@as(f32, 5), obstacle.position.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), obstacle.radius, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), obstacle.height, 0.01);
    try std.testing.expect(obstacle.active);
    try std.testing.expectEqual(DynamicObstacle.Shape.cylinder, obstacle.shape);
}

test "ObstacleManager add and remove" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create a polygon
    _ = try mesh.addVertex(Vec3.init(0, 0, 0));
    _ = try mesh.addVertex(Vec3.init(20, 0, 0));
    _ = try mesh.addVertex(Vec3.init(20, 0, 20));
    _ = try mesh.addVertex(Vec3.init(0, 0, 20));
    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2, 3 });

    var manager = ObstacleManager.init(allocator, &mesh);
    defer manager.deinit();

    // Add obstacle
    const obs_id = try manager.addObstacle(Vec3.init(10, 0, 10), 3.0, 2.0);
    try std.testing.expectEqual(@as(u32, 0), obs_id);

    // Polygon should be disabled
    try std.testing.expect(mesh.polygons.items[0].flags.disabled);

    // Remove obstacle
    manager.removeObstacle(obs_id);

    // Polygon should be enabled again
    try std.testing.expect(!mesh.polygons.items[0].flags.disabled);
}

test "ObstacleManager update position" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create two separate polygons
    _ = try mesh.addVertex(Vec3.init(0, 0, 0));
    _ = try mesh.addVertex(Vec3.init(10, 0, 0));
    _ = try mesh.addVertex(Vec3.init(10, 0, 10));
    _ = try mesh.addVertex(Vec3.init(0, 0, 10));
    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2, 3 });

    _ = try mesh.addVertex(Vec3.init(50, 0, 0));
    _ = try mesh.addVertex(Vec3.init(60, 0, 0));
    _ = try mesh.addVertex(Vec3.init(60, 0, 10));
    _ = try mesh.addVertex(Vec3.init(50, 0, 10));
    _ = try mesh.addPolygon(&[_]u32{ 4, 5, 6, 7 });

    var manager = ObstacleManager.init(allocator, &mesh);
    defer manager.deinit();

    // Add obstacle near first polygon
    const obs_id = try manager.addObstacle(Vec3.init(5, 0, 5), 2.0, 2.0);

    // First polygon should be disabled
    try std.testing.expect(mesh.polygons.items[0].flags.disabled);
    // Second polygon should not be disabled
    try std.testing.expect(!mesh.polygons.items[1].flags.disabled);

    // Move obstacle to second polygon
    try manager.updateObstacle(obs_id, Vec3.init(55, 0, 5));

    // First polygon should now be enabled
    try std.testing.expect(!mesh.polygons.items[0].flags.disabled);
    // Second polygon should now be disabled
    try std.testing.expect(mesh.polygons.items[1].flags.disabled);
}

test "NavMeshBuilder build from triangles" {
    const allocator = std.testing.allocator;

    var builder = NavMeshBuilder.init(allocator);

    // Create a simple triangle (CCW winding when viewed from above)
    // The vertex order is important: normal should point up for flat ground
    const vertices = [_]Vec3{
        Vec3.init(0, 0, 0),
        Vec3.init(5, 0, 10),
        Vec3.init(10, 0, 0),
    };
    // Indices in CCW order from above: 0, 1, 2 gives normal pointing up
    const indices = [_]u32{ 0, 1, 2 };

    var mesh = try builder.build(&vertices, &indices);
    defer mesh.deinit();

    // Should have 1 polygon (the triangle is flat, so walkable)
    try std.testing.expectEqual(@as(usize, 1), mesh.polygons.items.len);
    try std.testing.expectEqual(@as(usize, 3), mesh.vertices.items.len);
}

test "NavMesh buildAdjacency" {
    const allocator = std.testing.allocator;

    var mesh = NavMesh.init(allocator);
    defer mesh.deinit();

    // Create two triangles sharing an edge
    _ = try mesh.addVertex(Vec3.init(0, 0, 0)); // 0
    _ = try mesh.addVertex(Vec3.init(10, 0, 0)); // 1
    _ = try mesh.addVertex(Vec3.init(5, 0, 10)); // 2
    _ = try mesh.addVertex(Vec3.init(15, 0, 10)); // 3

    // First triangle: 0, 1, 2
    _ = try mesh.addPolygon(&[_]u32{ 0, 1, 2 });
    // Second triangle shares edge 1-2 (but reversed: 2, 1)
    _ = try mesh.addPolygon(&[_]u32{ 1, 3, 2 });

    mesh.buildAdjacency();

    // Find the shared edge in polygon 0
    var found_adj: bool = false;
    for (mesh.polygons.items[0].edges) |edge| {
        if (edge.adjacent != null and edge.adjacent.? == 1) {
            found_adj = true;
            break;
        }
    }
    try std.testing.expect(found_adj);
}

test "PathWaypoint flags" {
    const waypoint = PathWaypoint{
        .position = Vec3.init(5, 0, 5),
        .polygon = 0,
        .flags = .{ .corner = true, .portal = false, .jump = true },
    };

    try std.testing.expect(waypoint.flags.corner);
    try std.testing.expect(!waypoint.flags.portal);
    try std.testing.expect(waypoint.flags.jump);
}

test "NavPolygon flags" {
    const flags = NavPolygon.PolygonFlags{
        .walkable = true,
        .water = true,
        .jump = false,
        .ladder = true,
        .disabled = false,
    };

    try std.testing.expect(flags.walkable);
    try std.testing.expect(flags.water);
    try std.testing.expect(!flags.jump);
    try std.testing.expect(flags.ladder);
    try std.testing.expect(!flags.disabled);
}
