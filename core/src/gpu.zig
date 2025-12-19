//! ZigDom GPU Module
//!
//! Provides GPU-compatible data structures and computations for WebGPU.
//! All structs use explicit alignment for direct GPU buffer transfer.
//!
//! Philosophy:
//! - Zig handles all math, transforms, and data generation
//! - JavaScript only bridges to WebGPU API
//! - Memory layout matches GPU requirements exactly

const std = @import("std");
const math = std.math;

// === GPU-Compatible Data Types ===

/// 2D Vector (8 bytes, aligned for GPU)
pub const Vec2 = extern struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ .x = v.x * s, .y = v.y * s };
    }
};

/// 3D Vector (12 bytes, padded to 16 for GPU alignment)
pub const Vec3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    _pad: f32 = 0, // Padding for 16-byte alignment

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z, ._pad = 0 };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z, ._pad = 0 };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z, ._pad = 0 };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s, ._pad = 0 };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
            ._pad = 0,
        };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        if (len == 0) return v;
        return v.scale(1.0 / len);
    }
};

/// 4D Vector (16 bytes, perfect GPU alignment)
pub const Vec4 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }
};

/// 4x4 Matrix (64 bytes, column-major for GPU)
pub const Mat4 = extern struct {
    // Column-major order (matches WGSL/WebGPU)
    m: [16]f32 = [_]f32{
        1, 0, 0, 0, // Column 0
        0, 1, 0, 0, // Column 1
        0, 0, 1, 0, // Column 2
        0, 0, 0, 1, // Column 3
    },

    pub fn identity() Mat4 {
        return .{};
    }

    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        return .{ .m = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1,
        } };
    }

    pub fn scaling(x: f32, y: f32, z: f32) Mat4 {
        return .{ .m = .{
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn rotationX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            1, 0,  0, 0,
            0, c,  s, 0,
            0, -s, c, 0,
            0, 0,  0, 1,
        } };
    }

    pub fn rotationY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            c, 0, -s, 0,
            0, 1, 0,  0,
            s, 0, c,  0,
            0, 0, 0,  1,
        } };
    }

    pub fn rotationZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            c,  s, 0, 0,
            -s, c, 0, 0,
            0,  0, 1, 0,
            0,  0, 0, 1,
        } };
    }

    pub fn multiply(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = .{ .m = [_]f32{0} ** 16 };
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                var k: usize = 0;
                while (k < 4) : (k += 1) {
                    result.m[i * 4 + j] += a.m[k * 4 + j] * b.m[i * 4 + k];
                }
            }
        }
        return result;
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov / 2.0);
        const range_inv = 1.0 / (near - far);
        return .{ .m = .{
            f / aspect, 0, 0,                          0,
            0,          f, 0,                          0,
            0,          0, (far + near) * range_inv,   -1,
            0,          0, 2.0 * far * near * range_inv, 0,
        } };
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const zaxis = eye.sub(target).normalize();
        const xaxis = up.cross(zaxis).normalize();
        const yaxis = zaxis.cross(xaxis);

        return .{ .m = .{
            xaxis.x,             yaxis.x,             zaxis.x,             0,
            xaxis.y,             yaxis.y,             zaxis.y,             0,
            xaxis.z,             yaxis.z,             zaxis.z,             0,
            -Vec3.dot(xaxis, eye), -Vec3.dot(yaxis, eye), -Vec3.dot(zaxis, eye), 1,
        } };
    }
};

/// Vertex with position and color (32 bytes)
pub const Vertex = extern struct {
    position: Vec3,  // 16 bytes (with padding)
    color: Vec4,     // 16 bytes

    pub fn new(pos: Vec3, col: Vec4) Vertex {
        return .{ .position = pos, .color = col };
    }
};

/// GPU Uniform buffer for transforms (128 bytes)
pub const Uniforms = extern struct {
    model: Mat4 = Mat4.identity(),
    view: Mat4 = Mat4.identity(),
    projection: Mat4 = Mat4.identity(),

    // Must be 256-byte aligned for uniform buffer
    _padding: [64]u8 = [_]u8{0} ** 64,
};

// === Scene State ===

/// Animation state
pub const AnimationState = struct {
    time: f32 = 0,
    rotation_x: f32 = 0,
    rotation_y: f32 = 0,
    rotation_z: f32 = 0,
};

// === Cube Mesh Data ===

pub const CUBE_VERTEX_COUNT: usize = 36;

/// Generate cube vertices (36 vertices for 12 triangles)
pub fn generateCubeVertices() [CUBE_VERTEX_COUNT]Vertex {
    const s: f32 = 0.5; // Half-size

    // Colors for each face
    const red = Vec4.new(1, 0, 0, 1);
    const green = Vec4.new(0, 1, 0, 1);
    const blue = Vec4.new(0, 0, 1, 1);
    const yellow = Vec4.new(1, 1, 0, 1);
    const magenta = Vec4.new(1, 0, 1, 1);
    const cyan = Vec4.new(0, 1, 1, 1);

    return .{
        // Front face (red)
        Vertex.new(Vec3.new(-s, -s, s), red),
        Vertex.new(Vec3.new(s, -s, s), red),
        Vertex.new(Vec3.new(s, s, s), red),
        Vertex.new(Vec3.new(-s, -s, s), red),
        Vertex.new(Vec3.new(s, s, s), red),
        Vertex.new(Vec3.new(-s, s, s), red),

        // Back face (green)
        Vertex.new(Vec3.new(s, -s, -s), green),
        Vertex.new(Vec3.new(-s, -s, -s), green),
        Vertex.new(Vec3.new(-s, s, -s), green),
        Vertex.new(Vec3.new(s, -s, -s), green),
        Vertex.new(Vec3.new(-s, s, -s), green),
        Vertex.new(Vec3.new(s, s, -s), green),

        // Top face (blue)
        Vertex.new(Vec3.new(-s, s, s), blue),
        Vertex.new(Vec3.new(s, s, s), blue),
        Vertex.new(Vec3.new(s, s, -s), blue),
        Vertex.new(Vec3.new(-s, s, s), blue),
        Vertex.new(Vec3.new(s, s, -s), blue),
        Vertex.new(Vec3.new(-s, s, -s), blue),

        // Bottom face (yellow)
        Vertex.new(Vec3.new(-s, -s, -s), yellow),
        Vertex.new(Vec3.new(s, -s, -s), yellow),
        Vertex.new(Vec3.new(s, -s, s), yellow),
        Vertex.new(Vec3.new(-s, -s, -s), yellow),
        Vertex.new(Vec3.new(s, -s, s), yellow),
        Vertex.new(Vec3.new(-s, -s, s), yellow),

        // Right face (magenta)
        Vertex.new(Vec3.new(s, -s, s), magenta),
        Vertex.new(Vec3.new(s, -s, -s), magenta),
        Vertex.new(Vec3.new(s, s, -s), magenta),
        Vertex.new(Vec3.new(s, -s, s), magenta),
        Vertex.new(Vec3.new(s, s, -s), magenta),
        Vertex.new(Vec3.new(s, s, s), magenta),

        // Left face (cyan)
        Vertex.new(Vec3.new(-s, -s, -s), cyan),
        Vertex.new(Vec3.new(-s, -s, s), cyan),
        Vertex.new(Vec3.new(-s, s, s), cyan),
        Vertex.new(Vec3.new(-s, -s, -s), cyan),
        Vertex.new(Vec3.new(-s, s, s), cyan),
        Vertex.new(Vec3.new(-s, s, -s), cyan),
    };
}

// === Global GPU State ===

var cube_vertices: [CUBE_VERTEX_COUNT]Vertex = undefined;
var uniforms: Uniforms = .{};
var animation: AnimationState = .{};
var gpu_initialized: bool = false;

/// Initialize GPU resources
pub fn init() void {
    cube_vertices = generateCubeVertices();

    // Setup view matrix (camera at z=3 looking at origin)
    uniforms.view = Mat4.lookAt(
        Vec3.new(0, 0, 3),
        Vec3.new(0, 0, 0),
        Vec3.new(0, 1, 0),
    );

    // Setup projection matrix (45 degree FOV)
    uniforms.projection = Mat4.perspective(
        math.pi / 4.0, // 45 degrees
        1.0, // Aspect ratio (will be updated by JS)
        0.1,
        100.0,
    );

    animation = .{};
    gpu_initialized = true;
}

/// Deinitialize GPU resources
pub fn deinit() void {
    gpu_initialized = false;
}

/// Update animation state
pub fn update(delta_time: f32) void {
    if (!gpu_initialized) return;

    animation.time += delta_time;
    animation.rotation_y = animation.time;
    animation.rotation_x = animation.time * 0.5;

    // Update model matrix with rotation
    const rot_x = Mat4.rotationX(animation.rotation_x);
    const rot_y = Mat4.rotationY(animation.rotation_y);
    uniforms.model = Mat4.multiply(rot_y, rot_x);
}

/// Set aspect ratio (called when canvas resizes)
pub fn setAspectRatio(aspect: f32) void {
    uniforms.projection = Mat4.perspective(
        math.pi / 4.0,
        aspect,
        0.1,
        100.0,
    );
}

/// Get pointer to vertex buffer
pub fn getVertexBuffer() *const [CUBE_VERTEX_COUNT]Vertex {
    return &cube_vertices;
}

/// Get vertex buffer size in bytes
pub fn getVertexBufferSize() usize {
    return @sizeOf([CUBE_VERTEX_COUNT]Vertex);
}

/// Get pointer to uniform buffer
pub fn getUniformBuffer() *const Uniforms {
    return &uniforms;
}

/// Get uniform buffer size in bytes
pub fn getUniformBufferSize() usize {
    return @sizeOf(Uniforms);
}

/// Get vertex count
pub fn getVertexCount() u32 {
    return CUBE_VERTEX_COUNT;
}

// === Tests ===

test "Vec3 operations" {
    const a = Vec3.new(1, 2, 3);
    const b = Vec3.new(4, 5, 6);

    const sum = Vec3.add(a, b);
    try std.testing.expectApproxEqAbs(@as(f32, 5), sum.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7), sum.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9), sum.z, 0.001);
}

test "Mat4 identity" {
    const m = Mat4.identity();
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.m[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.m[5], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.m[10], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.m[15], 0.001);
}

test "Vertex size is 32 bytes" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Vertex));
}

test "Uniforms size is 256 bytes" {
    try std.testing.expectEqual(@as(usize, 256), @sizeOf(Uniforms));
}

test "cube vertices generation" {
    const verts = generateCubeVertices();
    try std.testing.expectEqual(@as(usize, 36), verts.len);
}
