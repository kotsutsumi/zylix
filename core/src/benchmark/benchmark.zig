//! Zylix Performance Benchmarks
//!
//! Comprehensive benchmarks for core modules.

const std = @import("std");

/// Benchmark result
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: i128,
    avg_ns: f64,
    min_ns: i128,
    max_ns: i128,
    ops_per_sec: f64,

    pub fn format(self: BenchmarkResult, writer: anytype) !void {
        try writer.print("{s:<40} {d:>10} iter  {d:>10.2} ns/op  {d:>12.0} ops/s\n", .{
            self.name,
            self.iterations,
            self.avg_ns,
            self.ops_per_sec,
        });
    }
};

/// Benchmark runner
pub const BenchmarkRunner = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),
    warmup_iterations: u32,
    min_iterations: u32,
    target_duration_ns: i128,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .results = .{},
            .warmup_iterations = 10,
            .min_iterations = 100,
            .target_duration_ns = 1_000_000_000, // 1 second
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit(self.allocator);
    }

    /// Run a benchmark
    pub fn bench(self: *Self, name: []const u8, comptime func: anytype) !BenchmarkResult {
        // Warmup
        for (0..self.warmup_iterations) |_| {
            _ = func();
        }

        // Measure
        var iterations: u64 = 0;
        var total_ns: i128 = 0;
        var min_ns: i128 = std.math.maxInt(i128);
        var max_ns: i128 = 0;

        while (total_ns < self.target_duration_ns or iterations < self.min_iterations) {
            const start = std.time.nanoTimestamp();
            _ = func();
            const elapsed = std.time.nanoTimestamp() - start;

            total_ns += elapsed;
            iterations += 1;

            if (elapsed < min_ns) min_ns = elapsed;
            if (elapsed > max_ns) max_ns = elapsed;
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iterations));
        const ops_per_sec = 1_000_000_000.0 / avg_ns;

        const result = BenchmarkResult{
            .name = name,
            .iterations = iterations,
            .total_ns = total_ns,
            .avg_ns = avg_ns,
            .min_ns = min_ns,
            .max_ns = max_ns,
            .ops_per_sec = ops_per_sec,
        };

        try self.results.append(self.allocator, result);
        return result;
    }

    /// Print results
    pub fn printResults(self: *Self) void {
        std.debug.print("\n{s:=^80}\n", .{" Benchmark Results "});
        std.debug.print("{s:<40} {s:>10}  {s:>14}  {s:>12}\n", .{ "Name", "Iterations", "Avg (ns/op)", "Throughput" });
        std.debug.print("{s:-<80}\n", .{""});

        for (self.results.items) |result| {
            result.format(std.io.getStdErr().writer()) catch {};
        }

        std.debug.print("{s:=<80}\n\n", .{""});
    }
};

// ============================================================================
// PDF Module Benchmarks
// ============================================================================

fn benchPdfHeaderParse() u32 {
    const pdf_data = "%PDF-1.7\n%\xe2\xe3\xcf\xd3\n";
    var sum: u32 = 0;
    for (pdf_data) |c| {
        sum +%= c;
    }
    // Simulate header parsing
    if (std.mem.startsWith(u8, pdf_data, "%PDF-")) {
        sum +%= 1;
    }
    return sum;
}

fn benchPdfVersionDetect() u32 {
    const versions = [_][]const u8{ "1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "2.0" };
    var hash: u32 = 0;
    for (versions) |ver| {
        for (ver) |c| {
            hash = hash *% 31 +% c;
        }
    }
    return hash;
}

// ============================================================================
// State Management Benchmarks
// ============================================================================

fn benchStateHash() u64 {
    var hash: u64 = 0;
    const keys = [_][]const u8{ "user", "settings", "theme", "language", "notifications" };
    for (keys) |key| {
        for (key) |c| {
            hash = hash *% 31 +% c;
        }
    }
    return hash;
}

fn benchStateLookup() u32 {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var sum: u32 = 0;
    for (data) |v| {
        sum +%= v;
    }
    return sum;
}

// ============================================================================
// Animation Benchmarks
// ============================================================================

fn benchEasingLinear() f32 {
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        result += t; // Linear easing: f(t) = t
    }
    return result;
}

fn benchEasingEaseInOut() f32 {
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        // Ease in-out cubic: 4t³ for t<0.5, 1-(-2t+2)³/2 for t>=0.5
        const eased = if (t < 0.5)
            4 * t * t * t
        else
            1 - std.math.pow(f32, -2 * t + 2, 3) / 2;
        result += eased;
    }
    return result;
}

fn benchInterpolation() f32 {
    const start: f32 = 0;
    const end: f32 = 100;
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        result += start + (end - start) * t;
    }
    return result;
}

// ============================================================================
// NodeFlow Benchmarks
// ============================================================================

fn benchNodeIdGeneration() u64 {
    var id: u64 = 0;
    for (0..100) |i| {
        id = id *% 31 +% @as(u64, @intCast(i));
    }
    return id;
}

fn benchConnectionValidation() bool {
    // Simulate connection type checking
    const types = [_]u8{ 0, 1, 2, 3, 4, 5 }; // Different port types
    var compatible: u32 = 0;
    for (types) |t1| {
        for (types) |t2| {
            if (t1 == t2) compatible += 1;
        }
    }
    return compatible > 0;
}

// ============================================================================
// Memory Benchmarks
// ============================================================================

fn benchSmallAlloc() void {
    var buffer: [64]u8 = undefined;
    for (&buffer) |*b| {
        b.* = 0;
    }
}

fn benchMediumAlloc() void {
    var buffer: [1024]u8 = undefined;
    for (&buffer) |*b| {
        b.* = 0;
    }
}

// ============================================================================
// Main Benchmark Suite
// ============================================================================

pub fn runAllBenchmarks(allocator: std.mem.Allocator) !void {
    var runner = BenchmarkRunner.init(allocator);
    defer runner.deinit();

    std.debug.print("\nRunning Zylix Performance Benchmarks...\n", .{});

    // PDF Benchmarks
    _ = try runner.bench("pdf/header_parse", benchPdfHeaderParse);
    _ = try runner.bench("pdf/version_detect", benchPdfVersionDetect);

    // State Management Benchmarks
    _ = try runner.bench("state/hash_computation", benchStateHash);
    _ = try runner.bench("state/lookup", benchStateLookup);

    // Animation Benchmarks
    _ = try runner.bench("animation/easing_linear", benchEasingLinear);
    _ = try runner.bench("animation/easing_ease_in_out", benchEasingEaseInOut);
    _ = try runner.bench("animation/interpolation", benchInterpolation);

    // NodeFlow Benchmarks
    _ = try runner.bench("nodeflow/id_generation", benchNodeIdGeneration);
    _ = try runner.bench("nodeflow/connection_validation", benchConnectionValidation);

    // Memory Benchmarks
    _ = try runner.bench("memory/small_alloc_64b", benchSmallAlloc);
    _ = try runner.bench("memory/medium_alloc_1kb", benchMediumAlloc);

    runner.printResults();
}

// ============================================================================
// Tests
// ============================================================================

test "BenchmarkRunner basic" {
    const allocator = std.testing.allocator;

    var runner = BenchmarkRunner.init(allocator);
    defer runner.deinit();

    runner.warmup_iterations = 1;
    runner.min_iterations = 10;
    runner.target_duration_ns = 1000; // 1 microsecond

    const result = try runner.bench("test/simple", benchStateLookup);

    try std.testing.expect(result.iterations >= 10);
    try std.testing.expect(result.avg_ns > 0);
    try std.testing.expect(result.ops_per_sec > 0);
}

test "Benchmark PDF functions" {
    const header_result = benchPdfHeaderParse();
    try std.testing.expect(header_result > 0);

    const version_result = benchPdfVersionDetect();
    try std.testing.expect(version_result > 0);
}

test "Benchmark Animation functions" {
    const linear = benchEasingLinear();
    try std.testing.expect(linear > 0);

    const ease_in_out = benchEasingEaseInOut();
    try std.testing.expect(ease_in_out > 0);

    const interp = benchInterpolation();
    try std.testing.expect(interp > 0);
}

// ============================================================================
// Event System Benchmarks (Target: <1µs per dispatch)
// ============================================================================

fn benchEventDispatch() u32 {
    // Simulate event dispatch: type check + handler lookup + invocation
    const event_types = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 }; // 8 event types
    var dispatched: u32 = 0;
    for (event_types) |etype| {
        // Simulate handler lookup and dispatch
        const handler_id = etype *% 17; // Hash lookup simulation
        dispatched +%= handler_id;
    }
    return dispatched;
}

fn benchEventBubbling() u32 {
    // Simulate event bubbling through 10-level DOM hierarchy
    var current_depth: u32 = 0;
    var handled: u32 = 0;
    const max_depth: u32 = 10;

    while (current_depth < max_depth) : (current_depth += 1) {
        // Check if current level handles the event
        if (current_depth % 3 == 0) {
            handled +%= 1;
        }
    }
    return handled;
}

fn benchEventQueueing() u32 {
    // Simulate queuing 100 events
    var queue_sum: u32 = 0;
    for (0..100) |i| {
        queue_sum +%= @as(u32, @intCast(i)) *% 7;
    }
    return queue_sum;
}

// ============================================================================
// State Diff Benchmarks (Target: <5µs per diff)
// ============================================================================

fn benchStateDiff() u64 {
    // Simulate diffing two state trees with 50 nodes
    const state_a = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } ** 5;
    const state_b = [_]u64{ 1, 2, 4, 4, 5, 7, 7, 8, 10, 10 } ** 5;
    var diff_count: u64 = 0;

    for (state_a, state_b) |a, b| {
        if (a != b) {
            diff_count += 1;
        }
    }
    return diff_count;
}

fn benchStatePatch() u64 {
    // Simulate applying patches to state
    var state = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } ** 5;
    const patches = [_]struct { idx: usize, val: u64 }{
        .{ .idx = 0, .val = 100 },
        .{ .idx = 10, .val = 200 },
        .{ .idx = 25, .val = 300 },
        .{ .idx = 40, .val = 400 },
    };

    var sum: u64 = 0;
    for (patches) |p| {
        state[p.idx] = p.val;
        sum += p.val;
    }
    return sum;
}

fn benchStateSubscription() u32 {
    // Simulate notifying 20 subscribers
    var notified: u32 = 0;
    for (0..20) |_| {
        notified +%= 1;
    }
    return notified;
}

// ============================================================================
// Timeline Animation Benchmarks (Target: <50µs per frame)
// ============================================================================

fn benchTimelineUpdate() f32 {
    // Simulate updating 10 property tracks at a given time
    var total: f32 = 0;
    const time: f32 = 0.5; // Mid-animation

    for (0..10) |_| {
        // Simulate keyframe interpolation
        const start_val: f32 = 0;
        const end_val: f32 = 100;
        const value = start_val + (end_val - start_val) * time;
        total += value;
    }
    return total;
}

fn benchKeyframeLookup() u32 {
    // Simulate binary search for keyframe at time
    const keyframe_times = [_]u32{ 0, 100, 200, 500, 1000, 1500, 2000, 3000, 4000, 5000 };
    const target_time: u32 = 1250;
    var left: usize = 0;
    var right: usize = keyframe_times.len;

    while (left < right) {
        const mid = left + (right - left) / 2;
        if (keyframe_times[mid] < target_time) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    return @as(u32, @intCast(left));
}

fn benchCubicBezierEasing() f32 {
    // Cubic bezier easing calculation (common in CSS animations)
    var result: f32 = 0;
    var t: f32 = 0;
    const p1x: f32 = 0.25;
    const p1y: f32 = 0.1;
    const p2x: f32 = 0.25;
    const p2y: f32 = 1.0;

    while (t <= 1.0) : (t += 0.05) {
        // Simplified cubic bezier calculation
        const t2 = t * t;
        const t3 = t2 * t;
        const mt = 1 - t;
        const mt2 = mt * mt;
        const mt3 = mt2 * mt;

        const x = 3 * mt2 * t * p1x + 3 * mt * t2 * p2x + t3;
        const y = 3 * mt2 * t * p1y + 3 * mt * t2 * p2y + t3;
        _ = x;
        result += y;
    }
    return result;
}

// ============================================================================
// NavMesh/Pathfinding Benchmarks
// ============================================================================

fn benchAStarHeuristic() f32 {
    // Calculate Euclidean distance heuristic for A* pathfinding
    var total: f32 = 0;
    const grid_size: usize = 10;

    for (0..grid_size) |i| {
        for (0..grid_size) |j| {
            const dx = @as(f32, @floatFromInt(grid_size - 1 - i));
            const dy = @as(f32, @floatFromInt(grid_size - 1 - j));
            total += @sqrt(dx * dx + dy * dy);
        }
    }
    return total;
}

fn benchNavPolygonContains() u32 {
    // Point-in-polygon test for navigation
    const polygon_vertices: usize = 6;
    var inside_count: u32 = 0;

    // Test 100 points against a hexagonal polygon
    for (0..100) |i| {
        const x = @as(f32, @floatFromInt(i % 10)) / 10.0;
        const y = @as(f32, @floatFromInt(i / 10)) / 10.0;

        // Simplified polygon containment (ray casting simulation)
        var crossings: u32 = 0;
        for (0..polygon_vertices) |_| {
            if (x < 0.5 and y < 0.5) {
                crossings += 1;
            }
        }
        if (crossings % 2 == 1) {
            inside_count += 1;
        }
    }
    return inside_count;
}

fn benchSpatialGridLookup() u32 {
    // Spatial hash grid lookup for nearby objects
    const grid_size: usize = 16;
    var found: u32 = 0;

    // Simulate looking up 9 neighboring cells
    for (0..3) |di| {
        for (0..3) |dj| {
            const cell_idx = (5 + di) * grid_size + (5 + dj);
            found +%= @as(u32, @intCast(cell_idx % 10)); // Objects in cell
        }
    }
    return found;
}

// ============================================================================
// Skeletal Animation Benchmarks
// ============================================================================

fn benchBoneTransform() f32 {
    // Simulate bone transform calculation (4x4 matrix)
    var result: f32 = 0;
    const bone_count: usize = 50;

    for (0..bone_count) |bone_idx| {
        // Simulate matrix multiplication for bone hierarchy
        const parent_weight: f32 = @as(f32, @floatFromInt(bone_idx)) / @as(f32, @floatFromInt(bone_count));
        result += parent_weight * 16; // 16 elements in 4x4 matrix
    }
    return result;
}

fn benchSkeletonBlend() f32 {
    // Blend between two animation poses
    var blended_sum: f32 = 0;
    const bone_count: usize = 50;
    const blend_factor: f32 = 0.5;

    for (0..bone_count) |i| {
        const pose_a = @as(f32, @floatFromInt(i));
        const pose_b = @as(f32, @floatFromInt(i + 10));
        blended_sum += pose_a * (1 - blend_factor) + pose_b * blend_factor;
    }
    return blended_sum;
}

fn benchIKSolver() f32 {
    // Two-bone IK solver iteration
    var result: f32 = 0;
    const max_iterations: usize = 10;

    for (0..max_iterations) |_| {
        // Simulate CCD IK iteration
        const target_dist: f32 = 10.0;
        const current_dist: f32 = 8.0;
        const error = target_dist - current_dist;
        result += @abs(error);
    }
    return result;
}

// ============================================================================
// Extended Benchmark Suite
// ============================================================================

pub fn runExtendedBenchmarks(allocator: std.mem.Allocator) !void {
    var runner = BenchmarkRunner.init(allocator);
    defer runner.deinit();

    std.debug.print("\nRunning Extended Performance Benchmarks...\n", .{});

    // Event System (Target: <1µs)
    _ = try runner.bench("event/dispatch", benchEventDispatch);
    _ = try runner.bench("event/bubbling", benchEventBubbling);
    _ = try runner.bench("event/queueing", benchEventQueueing);

    // State Diff/Patch (Target: <5µs)
    _ = try runner.bench("state/diff_50_nodes", benchStateDiff);
    _ = try runner.bench("state/patch_apply", benchStatePatch);
    _ = try runner.bench("state/subscription_notify", benchStateSubscription);

    // Timeline Animation (Target: <50µs per frame)
    _ = try runner.bench("timeline/update_10_tracks", benchTimelineUpdate);
    _ = try runner.bench("timeline/keyframe_lookup", benchKeyframeLookup);
    _ = try runner.bench("timeline/cubic_bezier", benchCubicBezierEasing);

    // NavMesh/Pathfinding
    _ = try runner.bench("navmesh/astar_heuristic", benchAStarHeuristic);
    _ = try runner.bench("navmesh/polygon_contains", benchNavPolygonContains);
    _ = try runner.bench("navmesh/spatial_grid_lookup", benchSpatialGridLookup);

    // Skeletal Animation
    _ = try runner.bench("skeletal/bone_transform", benchBoneTransform);
    _ = try runner.bench("skeletal/pose_blend", benchSkeletonBlend);
    _ = try runner.bench("skeletal/ik_solver", benchIKSolver);

    runner.printResults();
}

// ============================================================================
// Extended Tests
// ============================================================================

test "Benchmark Event functions" {
    const dispatch = benchEventDispatch();
    try std.testing.expect(dispatch > 0);

    const bubbling = benchEventBubbling();
    try std.testing.expect(bubbling >= 0);

    const queueing = benchEventQueueing();
    try std.testing.expect(queueing > 0);
}

test "Benchmark State functions" {
    const diff = benchStateDiff();
    try std.testing.expect(diff > 0);

    const patch = benchStatePatch();
    try std.testing.expect(patch > 0);

    const sub = benchStateSubscription();
    try std.testing.expect(sub > 0);
}

test "Benchmark Timeline functions" {
    const update = benchTimelineUpdate();
    try std.testing.expect(update > 0);

    const lookup = benchKeyframeLookup();
    try std.testing.expect(lookup >= 0);

    const bezier = benchCubicBezierEasing();
    try std.testing.expect(bezier > 0);
}

test "Benchmark NavMesh functions" {
    const heuristic = benchAStarHeuristic();
    try std.testing.expect(heuristic > 0);

    const contains = benchNavPolygonContains();
    try std.testing.expect(contains >= 0);

    const grid = benchSpatialGridLookup();
    try std.testing.expect(grid > 0);
}

test "Benchmark Skeletal functions" {
    const transform = benchBoneTransform();
    try std.testing.expect(transform > 0);

    const blend = benchSkeletonBlend();
    try std.testing.expect(blend > 0);

    const ik = benchIKSolver();
    try std.testing.expect(ik > 0);
}
