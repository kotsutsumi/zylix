//! Zylix 3D Graphics - Core Types
//!
//! Fundamental types for 3D graphics: vectors, matrices, colors, transforms.

const std = @import("std");

// ============================================================================
// Vector Types
// ============================================================================

/// 2D vector
pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }

    pub fn one() Vec2 {
        return .{ .x = 1, .y = 1 };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vec2, s: f32) Vec2 {
        return .{ .x = self.x * s, .y = self.y * s };
    }

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len == 0) return self;
        return self.scale(1.0 / len);
    }
};

/// 3D vector
pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn one() Vec3 {
        return .{ .x = 1, .y = 1, .z = 1 };
    }

    pub fn up() Vec3 {
        return .{ .x = 0, .y = 1, .z = 0 };
    }

    pub fn down() Vec3 {
        return .{ .x = 0, .y = -1, .z = 0 };
    }

    pub fn forward() Vec3 {
        return .{ .x = 0, .y = 0, .z = -1 };
    }

    pub fn back() Vec3 {
        return .{ .x = 0, .y = 0, .z = 1 };
    }

    pub fn right() Vec3 {
        return .{ .x = 1, .y = 0, .z = 0 };
    }

    pub fn left() Vec3 {
        return .{ .x = -1, .y = 0, .z = 0 };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }

    pub fn scale(self: Vec3, s: f32) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn negate(self: Vec3) Vec3 {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn lengthSquared(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len == 0) return self;
        return self.scale(1.0 / len);
    }

    pub fn lerp(self: Vec3, other: Vec3, t: f32) Vec3 {
        return .{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
            .z = self.z + (other.z - self.z) * t,
        };
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        return self.sub(other).length();
    }

    pub fn reflect(self: Vec3, normal: Vec3) Vec3 {
        const d = 2.0 * self.dot(normal);
        return self.sub(normal.scale(d));
    }
};

/// 4D vector (homogeneous coordinates)
pub const Vec4 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }

    pub fn toVec3(self: Vec4) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    pub fn zero() Vec4 {
        return .{ .x = 0, .y = 0, .z = 0, .w = 0 };
    }

    pub fn one() Vec4 {
        return .{ .x = 1, .y = 1, .z = 1, .w = 1 };
    }

    pub fn add(self: Vec4, other: Vec4) Vec4 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z, .w = self.w + other.w };
    }

    pub fn sub(self: Vec4, other: Vec4) Vec4 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z, .w = self.w - other.w };
    }

    pub fn scale(self: Vec4, s: f32) Vec4 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s, .w = self.w * s };
    }

    pub fn dot(self: Vec4, other: Vec4) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w;
    }
};

// ============================================================================
// Quaternion
// ============================================================================

/// Quaternion for 3D rotations
pub const Quaternion = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn identity() Quaternion {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }

    pub fn fromAxisAngle(axis: Vec3, angle: f32) Quaternion {
        const half_angle = angle * 0.5;
        const s = @sin(half_angle);
        const normalized = axis.normalize();
        return .{
            .x = normalized.x * s,
            .y = normalized.y * s,
            .z = normalized.z * s,
            .w = @cos(half_angle),
        };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Quaternion {
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);

        return .{
            .w = cr * cp * cy + sr * sp * sy,
            .x = sr * cp * cy - cr * sp * sy,
            .y = cr * sp * cy + sr * cp * sy,
            .z = cr * cp * sy - sr * sp * cy,
        };
    }

    pub fn toEuler(self: Quaternion) Vec3 {
        var euler: Vec3 = .{};

        // Roll (x-axis rotation)
        const sinr_cosp = 2.0 * (self.w * self.x + self.y * self.z);
        const cosr_cosp = 1.0 - 2.0 * (self.x * self.x + self.y * self.y);
        euler.x = std.math.atan2(sinr_cosp, cosr_cosp);

        // Pitch (y-axis rotation)
        const sinp = 2.0 * (self.w * self.y - self.z * self.x);
        if (@abs(sinp) >= 1.0) {
            euler.y = std.math.copysign(std.math.pi / 2.0, sinp);
        } else {
            euler.y = std.math.asin(sinp);
        }

        // Yaw (z-axis rotation)
        const siny_cosp = 2.0 * (self.w * self.z + self.x * self.y);
        const cosy_cosp = 1.0 - 2.0 * (self.y * self.y + self.z * self.z);
        euler.z = std.math.atan2(siny_cosp, cosy_cosp);

        return euler;
    }

    pub fn multiply(self: Quaternion, other: Quaternion) Quaternion {
        return .{
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
        };
    }

    pub fn conjugate(self: Quaternion) Quaternion {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z, .w = self.w };
    }

    pub fn length(self: Quaternion) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
    }

    pub fn normalize(self: Quaternion) Quaternion {
        const len = self.length();
        if (len == 0) return identity();
        return .{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
            .w = self.w / len,
        };
    }

    pub fn rotateVec3(self: Quaternion, v: Vec3) Vec3 {
        const qv = Vec3.init(self.x, self.y, self.z);
        const uv = qv.cross(v);
        const uuv = qv.cross(uv);
        return v.add(uv.scale(2.0 * self.w)).add(uuv.scale(2.0));
    }

    pub fn slerp(self: Quaternion, other: Quaternion, t: f32) Quaternion {
        var cos_half_theta = self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w;

        var other_adjusted = other;
        if (cos_half_theta < 0) {
            other_adjusted = .{ .x = -other.x, .y = -other.y, .z = -other.z, .w = -other.w };
            cos_half_theta = -cos_half_theta;
        }

        if (cos_half_theta >= 1.0) {
            return self;
        }

        const half_theta = std.math.acos(cos_half_theta);
        const sin_half_theta = @sqrt(1.0 - cos_half_theta * cos_half_theta);

        if (@abs(sin_half_theta) < 0.001) {
            return .{
                .x = self.x * 0.5 + other_adjusted.x * 0.5,
                .y = self.y * 0.5 + other_adjusted.y * 0.5,
                .z = self.z * 0.5 + other_adjusted.z * 0.5,
                .w = self.w * 0.5 + other_adjusted.w * 0.5,
            };
        }

        const ratio_a = @sin((1.0 - t) * half_theta) / sin_half_theta;
        const ratio_b = @sin(t * half_theta) / sin_half_theta;

        return .{
            .x = self.x * ratio_a + other_adjusted.x * ratio_b,
            .y = self.y * ratio_a + other_adjusted.y * ratio_b,
            .z = self.z * ratio_a + other_adjusted.z * ratio_b,
            .w = self.w * ratio_a + other_adjusted.w * ratio_b,
        };
    }
};

// ============================================================================
// Matrix Types
// ============================================================================

/// 4x4 transformation matrix (column-major order)
pub const Mat4 = struct {
    data: [16]f32 = [_]f32{
        1, 0, 0, 0, // column 0
        0, 1, 0, 0, // column 1
        0, 0, 1, 0, // column 2
        0, 0, 0, 1, // column 3
    },

    pub fn identity() Mat4 {
        return .{};
    }

    pub fn zero() Mat4 {
        return .{ .data = [_]f32{0} ** 16 };
    }

    pub fn get(self: Mat4, row: usize, col: usize) f32 {
        return self.data[col * 4 + row];
    }

    pub fn set(self: *Mat4, row: usize, col: usize, value: f32) void {
        self.data[col * 4 + row] = value;
    }

    pub fn multiply(self: Mat4, other: Mat4) Mat4 {
        var result = zero();
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                var sum: f32 = 0;
                var k: usize = 0;
                while (k < 4) : (k += 1) {
                    sum += self.get(i, k) * other.get(k, j);
                }
                result.set(i, j, sum);
            }
        }
        return result;
    }

    pub fn transformVec4(self: Mat4, v: Vec4) Vec4 {
        return .{
            .x = self.get(0, 0) * v.x + self.get(0, 1) * v.y + self.get(0, 2) * v.z + self.get(0, 3) * v.w,
            .y = self.get(1, 0) * v.x + self.get(1, 1) * v.y + self.get(1, 2) * v.z + self.get(1, 3) * v.w,
            .z = self.get(2, 0) * v.x + self.get(2, 1) * v.y + self.get(2, 2) * v.z + self.get(2, 3) * v.w,
            .w = self.get(3, 0) * v.x + self.get(3, 1) * v.y + self.get(3, 2) * v.z + self.get(3, 3) * v.w,
        };
    }

    pub fn transformPoint(self: Mat4, p: Vec3) Vec3 {
        const v4 = self.transformVec4(Vec4.fromVec3(p, 1.0));
        if (v4.w != 0) {
            return Vec3.init(v4.x / v4.w, v4.y / v4.w, v4.z / v4.w);
        }
        return v4.toVec3();
    }

    pub fn transformDirection(self: Mat4, d: Vec3) Vec3 {
        const v4 = self.transformVec4(Vec4.fromVec3(d, 0.0));
        return v4.toVec3();
    }

    pub fn translation(t: Vec3) Mat4 {
        var m = identity();
        m.set(0, 3, t.x);
        m.set(1, 3, t.y);
        m.set(2, 3, t.z);
        return m;
    }

    pub fn scaling(s: Vec3) Mat4 {
        var m = identity();
        m.set(0, 0, s.x);
        m.set(1, 1, s.y);
        m.set(2, 2, s.z);
        return m;
    }

    pub fn rotationX(angle: f32) Mat4 {
        var m = identity();
        const c = @cos(angle);
        const s = @sin(angle);
        m.set(1, 1, c);
        m.set(1, 2, -s);
        m.set(2, 1, s);
        m.set(2, 2, c);
        return m;
    }

    pub fn rotationY(angle: f32) Mat4 {
        var m = identity();
        const c = @cos(angle);
        const s = @sin(angle);
        m.set(0, 0, c);
        m.set(0, 2, s);
        m.set(2, 0, -s);
        m.set(2, 2, c);
        return m;
    }

    pub fn rotationZ(angle: f32) Mat4 {
        var m = identity();
        const c = @cos(angle);
        const s = @sin(angle);
        m.set(0, 0, c);
        m.set(0, 1, -s);
        m.set(1, 0, s);
        m.set(1, 1, c);
        return m;
    }

    pub fn fromQuaternion(q: Quaternion) Mat4 {
        var m = identity();

        const xx = q.x * q.x;
        const yy = q.y * q.y;
        const zz = q.z * q.z;
        const xy = q.x * q.y;
        const xz = q.x * q.z;
        const yz = q.y * q.z;
        const wx = q.w * q.x;
        const wy = q.w * q.y;
        const wz = q.w * q.z;

        m.set(0, 0, 1.0 - 2.0 * (yy + zz));
        m.set(0, 1, 2.0 * (xy - wz));
        m.set(0, 2, 2.0 * (xz + wy));

        m.set(1, 0, 2.0 * (xy + wz));
        m.set(1, 1, 1.0 - 2.0 * (xx + zz));
        m.set(1, 2, 2.0 * (yz - wx));

        m.set(2, 0, 2.0 * (xz - wy));
        m.set(2, 1, 2.0 * (yz + wx));
        m.set(2, 2, 1.0 - 2.0 * (xx + yy));

        return m;
    }

    pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var m = zero();
        const tan_half_fov = @tan(fov_y * 0.5);

        m.set(0, 0, 1.0 / (aspect * tan_half_fov));
        m.set(1, 1, 1.0 / tan_half_fov);
        m.set(2, 2, -(far + near) / (far - near));
        m.set(2, 3, -(2.0 * far * near) / (far - near));
        m.set(3, 2, -1.0);

        return m;
    }

    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        var m = identity();

        m.set(0, 0, 2.0 / (right - left));
        m.set(1, 1, 2.0 / (top - bottom));
        m.set(2, 2, -2.0 / (far - near));
        m.set(0, 3, -(right + left) / (right - left));
        m.set(1, 3, -(top + bottom) / (top - bottom));
        m.set(2, 3, -(far + near) / (far - near));

        return m;
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = target.sub(eye).normalize();
        const s = f.cross(up).normalize();
        const u = s.cross(f);

        var m = identity();
        m.set(0, 0, s.x);
        m.set(0, 1, s.y);
        m.set(0, 2, s.z);
        m.set(1, 0, u.x);
        m.set(1, 1, u.y);
        m.set(1, 2, u.z);
        m.set(2, 0, -f.x);
        m.set(2, 1, -f.y);
        m.set(2, 2, -f.z);
        m.set(0, 3, -s.dot(eye));
        m.set(1, 3, -u.dot(eye));
        m.set(2, 3, f.dot(eye));

        return m;
    }

    pub fn transpose(self: Mat4) Mat4 {
        var m: Mat4 = .{};
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                m.set(i, j, self.get(j, i));
            }
        }
        return m;
    }

    pub fn determinant(self: Mat4) f32 {
        const a = self.get(0, 0);
        const b = self.get(0, 1);
        const c = self.get(0, 2);
        const d = self.get(0, 3);
        const e = self.get(1, 0);
        const f = self.get(1, 1);
        const g = self.get(1, 2);
        const h = self.get(1, 3);
        const i = self.get(2, 0);
        const j = self.get(2, 1);
        const k = self.get(2, 2);
        const l = self.get(2, 3);
        const m = self.get(3, 0);
        const n = self.get(3, 1);
        const o = self.get(3, 2);
        const p = self.get(3, 3);

        const kp_lo = k * p - l * o;
        const jp_ln = j * p - l * n;
        const jo_kn = j * o - k * n;
        const ip_lm = i * p - l * m;
        const io_km = i * o - k * m;
        const in_jm = i * n - j * m;

        return a * (f * kp_lo - g * jp_ln + h * jo_kn) -
            b * (e * kp_lo - g * ip_lm + h * io_km) +
            c * (e * jp_ln - f * ip_lm + h * in_jm) -
            d * (e * jo_kn - f * io_km + g * in_jm);
    }
};

// ============================================================================
// Color Types
// ============================================================================

/// RGBA color (0.0 - 1.0 range)
pub const Color = struct {
    r: f32 = 1.0,
    g: f32 = 1.0,
    b: f32 = 1.0,
    a: f32 = 1.0,

    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
            .g = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
            .b = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
            .a = 1.0,
        };
    }

    pub fn fromHexWithAlpha(hex: u32) Color {
        return .{
            .r = @as(f32, @floatFromInt((hex >> 24) & 0xFF)) / 255.0,
            .g = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
            .b = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
            .a = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
        };
    }

    pub fn toVec3(self: Color) Vec3 {
        return .{ .x = self.r, .y = self.g, .z = self.b };
    }

    pub fn toVec4(self: Color) Vec4 {
        return .{ .x = self.r, .y = self.g, .z = self.b, .w = self.a };
    }

    pub fn lerp(self: Color, other: Color, t: f32) Color {
        return .{
            .r = self.r + (other.r - self.r) * t,
            .g = self.g + (other.g - self.g) * t,
            .b = self.b + (other.b - self.b) * t,
            .a = self.a + (other.a - self.a) * t,
        };
    }

    // Common colors
    pub fn white() Color {
        return .{ .r = 1, .g = 1, .b = 1, .a = 1 };
    }
    pub fn black() Color {
        return .{ .r = 0, .g = 0, .b = 0, .a = 1 };
    }
    pub fn red() Color {
        return .{ .r = 1, .g = 0, .b = 0, .a = 1 };
    }
    pub fn green() Color {
        return .{ .r = 0, .g = 1, .b = 0, .a = 1 };
    }
    pub fn blue() Color {
        return .{ .r = 0, .g = 0, .b = 1, .a = 1 };
    }
    pub fn yellow() Color {
        return .{ .r = 1, .g = 1, .b = 0, .a = 1 };
    }
    pub fn cyan() Color {
        return .{ .r = 0, .g = 1, .b = 1, .a = 1 };
    }
    pub fn magenta() Color {
        return .{ .r = 1, .g = 0, .b = 1, .a = 1 };
    }
    pub fn gray() Color {
        return .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1 };
    }
    pub fn transparent() Color {
        return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    }
};

// ============================================================================
// Transform
// ============================================================================

/// 3D transform with position, rotation, and scale
pub const Transform = struct {
    position: Vec3 = Vec3.zero(),
    rotation: Quaternion = Quaternion.identity(),
    scale: Vec3 = Vec3.one(),

    pub fn identity() Transform {
        return .{};
    }

    pub fn toMatrix(self: Transform) Mat4 {
        const t = Mat4.translation(self.position);
        const r = Mat4.fromQuaternion(self.rotation);
        const s = Mat4.scaling(self.scale);
        return t.multiply(r.multiply(s));
    }

    pub fn forward(self: Transform) Vec3 {
        return self.rotation.rotateVec3(Vec3.forward());
    }

    pub fn right(self: Transform) Vec3 {
        return self.rotation.rotateVec3(Vec3.right());
    }

    pub fn up(self: Transform) Vec3 {
        return self.rotation.rotateVec3(Vec3.up());
    }

    pub fn translate(self: *Transform, delta: Vec3) void {
        self.position = self.position.add(delta);
    }

    pub fn rotate(self: *Transform, axis: Vec3, angle: f32) void {
        const q = Quaternion.fromAxisAngle(axis, angle);
        self.rotation = q.multiply(self.rotation).normalize();
    }

    pub fn lookAt(self: *Transform, target: Vec3, world_up: Vec3) void {
        const direction = target.sub(self.position).normalize();
        const right_vec = world_up.cross(direction).normalize();
        const up_vec = direction.cross(right_vec);

        // Convert rotation matrix to quaternion
        const m00 = right_vec.x;
        const m01 = up_vec.x;
        const m02 = direction.x;
        const m10 = right_vec.y;
        const m11 = up_vec.y;
        const m12 = direction.y;
        const m20 = right_vec.z;
        const m21 = up_vec.z;
        const m22 = direction.z;

        const trace = m00 + m11 + m22;
        if (trace > 0) {
            const s = @sqrt(trace + 1.0) * 2.0;
            self.rotation = .{
                .w = 0.25 * s,
                .x = (m21 - m12) / s,
                .y = (m02 - m20) / s,
                .z = (m10 - m01) / s,
            };
        } else if (m00 > m11 and m00 > m22) {
            const s = @sqrt(1.0 + m00 - m11 - m22) * 2.0;
            self.rotation = .{
                .w = (m21 - m12) / s,
                .x = 0.25 * s,
                .y = (m01 + m10) / s,
                .z = (m02 + m20) / s,
            };
        } else if (m11 > m22) {
            const s = @sqrt(1.0 + m11 - m00 - m22) * 2.0;
            self.rotation = .{
                .w = (m02 - m20) / s,
                .x = (m01 + m10) / s,
                .y = 0.25 * s,
                .z = (m12 + m21) / s,
            };
        } else {
            const s = @sqrt(1.0 + m22 - m00 - m11) * 2.0;
            self.rotation = .{
                .w = (m10 - m01) / s,
                .x = (m02 + m20) / s,
                .y = (m12 + m21) / s,
                .z = 0.25 * s,
            };
        }
    }

    pub fn lerp(self: Transform, other: Transform, t: f32) Transform {
        return .{
            .position = self.position.lerp(other.position, t),
            .rotation = self.rotation.slerp(other.rotation, t),
            .scale = self.scale.lerp(other.scale, t),
        };
    }
};

// ============================================================================
// Bounding Volumes
// ============================================================================

/// Axis-aligned bounding box
pub const AABB = struct {
    min: Vec3 = Vec3.init(std.math.floatMax(f32), std.math.floatMax(f32), std.math.floatMax(f32)),
    max: Vec3 = Vec3.init(-std.math.floatMax(f32), -std.math.floatMax(f32), -std.math.floatMax(f32)),

    pub fn empty() AABB {
        return .{};
    }

    pub fn fromPoints(points: []const Vec3) AABB {
        var aabb = empty();
        for (points) |p| {
            aabb.expand(p);
        }
        return aabb;
    }

    pub fn expand(self: *AABB, point: Vec3) void {
        self.min.x = @min(self.min.x, point.x);
        self.min.y = @min(self.min.y, point.y);
        self.min.z = @min(self.min.z, point.z);
        self.max.x = @max(self.max.x, point.x);
        self.max.y = @max(self.max.y, point.y);
        self.max.z = @max(self.max.z, point.z);
    }

    pub fn merge(self: AABB, other: AABB) AABB {
        return .{
            .min = Vec3.init(@min(self.min.x, other.min.x), @min(self.min.y, other.min.y), @min(self.min.z, other.min.z)),
            .max = Vec3.init(@max(self.max.x, other.max.x), @max(self.max.y, other.max.y), @max(self.max.z, other.max.z)),
        };
    }

    pub fn center(self: AABB) Vec3 {
        return self.min.add(self.max).scale(0.5);
    }

    pub fn size(self: AABB) Vec3 {
        return self.max.sub(self.min);
    }

    pub fn contains(self: AABB, point: Vec3) bool {
        return point.x >= self.min.x and point.x <= self.max.x and
            point.y >= self.min.y and point.y <= self.max.y and
            point.z >= self.min.z and point.z <= self.max.z;
    }

    pub fn intersects(self: AABB, other: AABB) bool {
        return self.min.x <= other.max.x and self.max.x >= other.min.x and
            self.min.y <= other.max.y and self.max.y >= other.min.y and
            self.min.z <= other.max.z and self.max.z >= other.min.z;
    }
};

/// Bounding sphere
pub const BoundingSphere = struct {
    center: Vec3 = Vec3.zero(),
    radius: f32 = 0,

    pub fn fromPoints(points: []const Vec3) BoundingSphere {
        if (points.len == 0) return .{};

        // Calculate center as average of all points
        var center_sum = Vec3.zero();
        for (points) |p| {
            center_sum = center_sum.add(p);
        }
        const center = center_sum.scale(1.0 / @as(f32, @floatFromInt(points.len)));

        // Find max distance from center
        var max_dist_sq: f32 = 0;
        for (points) |p| {
            const dist_sq = p.sub(center).lengthSquared();
            if (dist_sq > max_dist_sq) max_dist_sq = dist_sq;
        }

        return .{ .center = center, .radius = @sqrt(max_dist_sq) };
    }

    pub fn contains(self: BoundingSphere, point: Vec3) bool {
        return point.sub(self.center).lengthSquared() <= self.radius * self.radius;
    }

    pub fn intersects(self: BoundingSphere, other: BoundingSphere) bool {
        const distance = self.center.sub(other.center).length();
        return distance <= self.radius + other.radius;
    }

    pub fn intersectsAABB(self: BoundingSphere, aabb: AABB) bool {
        // Find closest point on AABB to sphere center
        const closest = Vec3.init(
            std.math.clamp(self.center.x, aabb.min.x, aabb.max.x),
            std.math.clamp(self.center.y, aabb.min.y, aabb.max.y),
            std.math.clamp(self.center.z, aabb.min.z, aabb.max.z),
        );
        return closest.sub(self.center).lengthSquared() <= self.radius * self.radius;
    }
};

// ============================================================================
// Ray
// ============================================================================

/// Ray for raycasting
pub const Ray = struct {
    origin: Vec3 = Vec3.zero(),
    direction: Vec3 = Vec3.forward(),

    pub fn init(origin: Vec3, direction: Vec3) Ray {
        return .{ .origin = origin, .direction = direction.normalize() };
    }

    pub fn getPoint(self: Ray, t: f32) Vec3 {
        return self.origin.add(self.direction.scale(t));
    }

    pub fn intersectsAABB(self: Ray, aabb: AABB) ?f32 {
        var tmin: f32 = 0;
        var tmax: f32 = std.math.floatMax(f32);

        inline for (0..3) |i| {
            const origin = switch (i) {
                0 => self.origin.x,
                1 => self.origin.y,
                2 => self.origin.z,
                else => unreachable,
            };
            const dir = switch (i) {
                0 => self.direction.x,
                1 => self.direction.y,
                2 => self.direction.z,
                else => unreachable,
            };
            const min_val = switch (i) {
                0 => aabb.min.x,
                1 => aabb.min.y,
                2 => aabb.min.z,
                else => unreachable,
            };
            const max_val = switch (i) {
                0 => aabb.max.x,
                1 => aabb.max.y,
                2 => aabb.max.z,
                else => unreachable,
            };

            if (@abs(dir) < 0.0001) {
                if (origin < min_val or origin > max_val) return null;
            } else {
                var t1 = (min_val - origin) / dir;
                var t2 = (max_val - origin) / dir;
                if (t1 > t2) {
                    const temp = t1;
                    t1 = t2;
                    t2 = temp;
                }
                tmin = @max(tmin, t1);
                tmax = @min(tmax, t2);
                if (tmin > tmax) return null;
            }
        }

        return if (tmin >= 0) tmin else null;
    }

    pub fn intersectsSphere(self: Ray, sphere: BoundingSphere) ?f32 {
        const oc = self.origin.sub(sphere.center);
        const a = self.direction.dot(self.direction);
        const b = 2.0 * oc.dot(self.direction);
        const c = oc.dot(oc) - sphere.radius * sphere.radius;
        const discriminant = b * b - 4.0 * a * c;

        if (discriminant < 0) return null;

        const t = (-b - @sqrt(discriminant)) / (2.0 * a);
        return if (t >= 0) t else null;
    }

    pub fn intersectsPlane(self: Ray, plane_normal: Vec3, plane_d: f32) ?f32 {
        const denom = plane_normal.dot(self.direction);
        if (@abs(denom) < 0.0001) return null;

        const t = -(plane_normal.dot(self.origin) + plane_d) / denom;
        return if (t >= 0) t else null;
    }
};

// ============================================================================
// Frustum
// ============================================================================

/// View frustum for culling
pub const Frustum = struct {
    planes: [6]Vec4 = [_]Vec4{Vec4.zero()} ** 6,

    pub const PlaneIndex = enum(usize) {
        left = 0,
        right = 1,
        bottom = 2,
        top = 3,
        near = 4,
        far = 5,
    };

    pub fn fromMatrix(view_projection: Mat4) Frustum {
        var frustum: Frustum = .{};

        // Left plane
        frustum.planes[0] = .{
            .x = view_projection.get(0, 3) + view_projection.get(0, 0),
            .y = view_projection.get(1, 3) + view_projection.get(1, 0),
            .z = view_projection.get(2, 3) + view_projection.get(2, 0),
            .w = view_projection.get(3, 3) + view_projection.get(3, 0),
        };

        // Right plane
        frustum.planes[1] = .{
            .x = view_projection.get(0, 3) - view_projection.get(0, 0),
            .y = view_projection.get(1, 3) - view_projection.get(1, 0),
            .z = view_projection.get(2, 3) - view_projection.get(2, 0),
            .w = view_projection.get(3, 3) - view_projection.get(3, 0),
        };

        // Bottom plane
        frustum.planes[2] = .{
            .x = view_projection.get(0, 3) + view_projection.get(0, 1),
            .y = view_projection.get(1, 3) + view_projection.get(1, 1),
            .z = view_projection.get(2, 3) + view_projection.get(2, 1),
            .w = view_projection.get(3, 3) + view_projection.get(3, 1),
        };

        // Top plane
        frustum.planes[3] = .{
            .x = view_projection.get(0, 3) - view_projection.get(0, 1),
            .y = view_projection.get(1, 3) - view_projection.get(1, 1),
            .z = view_projection.get(2, 3) - view_projection.get(2, 1),
            .w = view_projection.get(3, 3) - view_projection.get(3, 1),
        };

        // Near plane
        frustum.planes[4] = .{
            .x = view_projection.get(0, 3) + view_projection.get(0, 2),
            .y = view_projection.get(1, 3) + view_projection.get(1, 2),
            .z = view_projection.get(2, 3) + view_projection.get(2, 2),
            .w = view_projection.get(3, 3) + view_projection.get(3, 2),
        };

        // Far plane
        frustum.planes[5] = .{
            .x = view_projection.get(0, 3) - view_projection.get(0, 2),
            .y = view_projection.get(1, 3) - view_projection.get(1, 2),
            .z = view_projection.get(2, 3) - view_projection.get(2, 2),
            .w = view_projection.get(3, 3) - view_projection.get(3, 2),
        };

        // Normalize planes
        for (&frustum.planes) |*plane| {
            const len = @sqrt(plane.x * plane.x + plane.y * plane.y + plane.z * plane.z);
            if (len > 0) {
                plane.x /= len;
                plane.y /= len;
                plane.z /= len;
                plane.w /= len;
            }
        }

        return frustum;
    }

    pub fn containsPoint(self: Frustum, point: Vec3) bool {
        for (self.planes) |plane| {
            const distance = plane.x * point.x + plane.y * point.y + plane.z * point.z + plane.w;
            if (distance < 0) return false;
        }
        return true;
    }

    pub fn intersectsAABB(self: Frustum, aabb: AABB) bool {
        for (self.planes) |plane| {
            const p = Vec3.init(
                if (plane.x >= 0) aabb.max.x else aabb.min.x,
                if (plane.y >= 0) aabb.max.y else aabb.min.y,
                if (plane.z >= 0) aabb.max.z else aabb.min.z,
            );
            const distance = plane.x * p.x + plane.y * p.y + plane.z * p.z + plane.w;
            if (distance < 0) return false;
        }
        return true;
    }

    pub fn intersectsSphere(self: Frustum, sphere: BoundingSphere) bool {
        for (self.planes) |plane| {
            const distance = plane.x * sphere.center.x + plane.y * sphere.center.y + plane.z * sphere.center.z + plane.w;
            if (distance < -sphere.radius) return false;
        }
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Vec3 operations" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);

    const sum = a.add(b);
    try std.testing.expectApproxEqAbs(@as(f32, 5), sum.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7), sum.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9), sum.z, 0.001);

    const cross = a.cross(b);
    try std.testing.expectApproxEqAbs(@as(f32, -3), cross.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), cross.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -3), cross.z, 0.001);
}

test "Mat4 identity" {
    const m = Mat4.identity();
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.get(0, 0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.get(1, 1), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.get(2, 2), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.get(3, 3), 0.001);
}

test "Quaternion rotation" {
    const q = Quaternion.fromAxisAngle(Vec3.up(), std.math.pi / 2.0);
    const v = Vec3.forward();
    const rotated = q.rotateVec3(v);
    try std.testing.expectApproxEqAbs(@as(f32, -1), rotated.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), rotated.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), rotated.z, 0.01);
}

test "AABB intersection" {
    const a = AABB{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(2, 2, 2) };
    const b = AABB{ .min = Vec3.init(1, 1, 1), .max = Vec3.init(3, 3, 3) };
    const c = AABB{ .min = Vec3.init(5, 5, 5), .max = Vec3.init(6, 6, 6) };

    try std.testing.expect(a.intersects(b));
    try std.testing.expect(!a.intersects(c));
}

test "Ray-AABB intersection" {
    const ray = Ray.init(Vec3.init(0, 0, -5), Vec3.init(0, 0, 1));
    const aabb = AABB{ .min = Vec3.init(-1, -1, -1), .max = Vec3.init(1, 1, 1) };

    const t = ray.intersectsAABB(aabb);
    try std.testing.expect(t != null);
    try std.testing.expectApproxEqAbs(@as(f32, 4), t.?, 0.001);
}
