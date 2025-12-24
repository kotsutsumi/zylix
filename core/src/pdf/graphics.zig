//! Zylix PDF - Graphics Operations
//!
//! Vector graphics and path operations for PDF documents.

const std = @import("std");
const types = @import("types.zig");

const Color = types.Color;
const Point = types.Point;
const Rectangle = types.Rectangle;
const LineCap = types.LineCap;
const LineJoin = types.LineJoin;
const BlendMode = types.BlendMode;

/// Graphics state
pub const GraphicsState = struct {
    fill_color: Color = Color.black,
    stroke_color: Color = Color.black,
    line_width: f32 = 1.0,
    line_cap: LineCap = .butt,
    line_join: LineJoin = .miter,
    miter_limit: f32 = 10.0,
    dash_pattern: ?[]const f32 = null,
    dash_phase: f32 = 0,
    opacity: f32 = 1.0,
    fill_opacity: f32 = 1.0,
    stroke_opacity: f32 = 1.0,
    blend_mode: BlendMode = .normal,
    transform: Matrix = Matrix.identity,

    pub fn default() GraphicsState {
        return .{};
    }
};

/// 2D transformation matrix [a b c d e f]
/// | a b 0 |
/// | c d 0 |
/// | e f 1 |
pub const Matrix = struct {
    a: f32 = 1,
    b: f32 = 0,
    c: f32 = 0,
    d: f32 = 1,
    e: f32 = 0,
    f: f32 = 0,

    pub const identity = Matrix{};

    /// Create translation matrix
    pub fn translation(tx: f32, ty: f32) Matrix {
        return .{ .a = 1, .b = 0, .c = 0, .d = 1, .e = tx, .f = ty };
    }

    /// Create scaling matrix
    pub fn scaling(sx: f32, sy: f32) Matrix {
        return .{ .a = sx, .b = 0, .c = 0, .d = sy, .e = 0, .f = 0 };
    }

    /// Create rotation matrix (angle in radians)
    pub fn rotation(angle: f32) Matrix {
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        return .{ .a = cos_a, .b = sin_a, .c = -sin_a, .d = cos_a, .e = 0, .f = 0 };
    }

    /// Create skew matrix
    pub fn skew(angle_x: f32, angle_y: f32) Matrix {
        return .{ .a = 1, .b = @tan(angle_y), .c = @tan(angle_x), .d = 1, .e = 0, .f = 0 };
    }

    /// Multiply two matrices
    pub fn multiply(self: Matrix, other: Matrix) Matrix {
        return .{
            .a = self.a * other.a + self.b * other.c,
            .b = self.a * other.b + self.b * other.d,
            .c = self.c * other.a + self.d * other.c,
            .d = self.c * other.b + self.d * other.d,
            .e = self.e * other.a + self.f * other.c + other.e,
            .f = self.e * other.b + self.f * other.d + other.f,
        };
    }

    /// Transform a point
    pub fn transformPoint(self: Matrix, point: Point) Point {
        return .{
            .x = self.a * point.x + self.c * point.y + self.e,
            .y = self.b * point.x + self.d * point.y + self.f,
        };
    }

    /// Get inverse matrix
    pub fn inverse(self: Matrix) ?Matrix {
        const det = self.a * self.d - self.b * self.c;
        if (@abs(det) < 0.0001) return null;

        const inv_det = 1.0 / det;
        return .{
            .a = self.d * inv_det,
            .b = -self.b * inv_det,
            .c = -self.c * inv_det,
            .d = self.a * inv_det,
            .e = (self.c * self.f - self.d * self.e) * inv_det,
            .f = (self.b * self.e - self.a * self.f) * inv_det,
        };
    }
};

/// Path segment types
pub const PathSegment = union(enum) {
    move_to: Point,
    line_to: Point,
    curve_to: struct { cp1: Point, cp2: Point, end: Point },
    quad_to: struct { cp: Point, end: Point },
    arc_to: struct { rx: f32, ry: f32, angle: f32, large_arc: bool, sweep: bool, end: Point },
    close,
};

/// Path builder for complex shapes
pub const Path = struct {
    allocator: std.mem.Allocator,
    segments: std.ArrayList(PathSegment),
    current_point: Point,
    start_point: Point,
    closed: bool,

    pub fn create(allocator: std.mem.Allocator) Path {
        return .{
            .allocator = allocator,
            .segments = .{},
            .current_point = Point.init(0, 0),
            .start_point = Point.init(0, 0),
            .closed = false,
        };
    }

    pub fn deinit(self: *Path) void {
        self.segments.deinit(self.allocator);
    }

    pub fn clear(self: *Path) void {
        self.segments.clearRetainingCapacity();
        self.current_point = Point.init(0, 0);
        self.start_point = Point.init(0, 0);
        self.closed = false;
    }

    pub fn moveTo(self: *Path, x: f32, y: f32) !void {
        const point = Point.init(x, y);
        try self.segments.append(self.allocator, .{ .move_to = point });
        self.current_point = point;
        self.start_point = point;
        self.closed = false;
    }

    pub fn lineTo(self: *Path, x: f32, y: f32) !void {
        const point = Point.init(x, y);
        try self.segments.append(self.allocator, .{ .line_to = point });
        self.current_point = point;
    }

    pub fn curveTo(self: *Path, cp1x: f32, cp1y: f32, cp2x: f32, cp2y: f32, x: f32, y: f32) !void {
        const end = Point.init(x, y);
        try self.segments.append(self.allocator, .{
            .curve_to = .{
                .cp1 = Point.init(cp1x, cp1y),
                .cp2 = Point.init(cp2x, cp2y),
                .end = end,
            },
        });
        self.current_point = end;
    }

    pub fn quadTo(self: *Path, cpx: f32, cpy: f32, x: f32, y: f32) !void {
        const end = Point.init(x, y);
        try self.segments.append(self.allocator, .{
            .quad_to = .{
                .cp = Point.init(cpx, cpy),
                .end = end,
            },
        });
        self.current_point = end;
    }

    pub fn close(self: *Path) !void {
        try self.segments.append(self.allocator, .close);
        self.current_point = self.start_point;
        self.closed = true;
    }

    /// Add a rectangle to the path
    pub fn addRect(self: *Path, rect: Rectangle) !void {
        try self.moveTo(rect.x, rect.y);
        try self.lineTo(rect.x + rect.width, rect.y);
        try self.lineTo(rect.x + rect.width, rect.y + rect.height);
        try self.lineTo(rect.x, rect.y + rect.height);
        try self.close();
    }

    /// Add a rounded rectangle to the path
    pub fn addRoundedRect(self: *Path, rect: Rectangle, radius: f32) !void {
        const r = @min(radius, @min(rect.width / 2, rect.height / 2));
        const k: f32 = 0.5522847498; // bezier approximation constant

        try self.moveTo(rect.x + r, rect.y);

        // Top edge
        try self.lineTo(rect.x + rect.width - r, rect.y);
        // Top-right corner
        try self.curveTo(rect.x + rect.width - r + r * k, rect.y, rect.x + rect.width, rect.y + r - r * k, rect.x + rect.width, rect.y + r);

        // Right edge
        try self.lineTo(rect.x + rect.width, rect.y + rect.height - r);
        // Bottom-right corner
        try self.curveTo(rect.x + rect.width, rect.y + rect.height - r + r * k, rect.x + rect.width - r + r * k, rect.y + rect.height, rect.x + rect.width - r, rect.y + rect.height);

        // Bottom edge
        try self.lineTo(rect.x + r, rect.y + rect.height);
        // Bottom-left corner
        try self.curveTo(rect.x + r - r * k, rect.y + rect.height, rect.x, rect.y + rect.height - r + r * k, rect.x, rect.y + rect.height - r);

        // Left edge
        try self.lineTo(rect.x, rect.y + r);
        // Top-left corner
        try self.curveTo(rect.x, rect.y + r - r * k, rect.x + r - r * k, rect.y, rect.x + r, rect.y);

        try self.close();
    }

    /// Add a circle to the path
    pub fn addCircle(self: *Path, cx: f32, cy: f32, radius: f32) !void {
        try self.addEllipse(cx, cy, radius, radius);
    }

    /// Add an ellipse to the path
    pub fn addEllipse(self: *Path, cx: f32, cy: f32, rx: f32, ry: f32) !void {
        const k: f32 = 0.5522847498; // bezier approximation constant
        const kx = rx * k;
        const ky = ry * k;

        try self.moveTo(cx + rx, cy);
        try self.curveTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
        try self.curveTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
        try self.curveTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
        try self.curveTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
        try self.close();
    }

    /// Get bounding box of the path
    pub fn getBounds(self: *const Path) Rectangle {
        var min_x: f32 = std.math.floatMax(f32);
        var min_y: f32 = std.math.floatMax(f32);
        var max_x: f32 = -std.math.floatMax(f32);
        var max_y: f32 = -std.math.floatMax(f32);

        for (self.segments.items) |segment| {
            const points: []const Point = switch (segment) {
                .move_to => |p| &[_]Point{p},
                .line_to => |p| &[_]Point{p},
                .curve_to => |c| &[_]Point{ c.cp1, c.cp2, c.end },
                .quad_to => |q| &[_]Point{ q.cp, q.end },
                .arc_to => |a| &[_]Point{a.end},
                .close => continue,
            };

            for (points) |p| {
                min_x = @min(min_x, p.x);
                min_y = @min(min_y, p.y);
                max_x = @max(max_x, p.x);
                max_y = @max(max_y, p.y);
            }
        }

        if (min_x > max_x) {
            return Rectangle.init(0, 0, 0, 0);
        }

        return Rectangle.init(min_x, min_y, max_x - min_x, max_y - min_y);
    }
};

/// Gradient types
pub const GradientType = enum {
    linear,
    radial,
};

/// Color stop for gradients
pub const ColorStop = struct {
    offset: f32, // 0.0 to 1.0
    color: Color,
};

/// Gradient definition
pub const Gradient = struct {
    allocator: std.mem.Allocator,
    gradient_type: GradientType,
    stops: std.ArrayList(ColorStop),
    start: Point,
    end: Point,
    radius_start: f32 = 0,
    radius_end: f32 = 0,

    pub fn createLinear(allocator: std.mem.Allocator, x1: f32, y1: f32, x2: f32, y2: f32) Gradient {
        return .{
            .allocator = allocator,
            .gradient_type = .linear,
            .stops = .{},
            .start = Point.init(x1, y1),
            .end = Point.init(x2, y2),
        };
    }

    pub fn createRadial(allocator: std.mem.Allocator, cx: f32, cy: f32, radius: f32) Gradient {
        return .{
            .allocator = allocator,
            .gradient_type = .radial,
            .stops = .{},
            .start = Point.init(cx, cy),
            .end = Point.init(cx, cy),
            .radius_start = 0,
            .radius_end = radius,
        };
    }

    pub fn deinit(self: *Gradient) void {
        self.stops.deinit(self.allocator);
    }

    pub fn addColorStop(self: *Gradient, offset: f32, color: Color) !void {
        try self.stops.append(self.allocator, .{ .offset = offset, .color = color });
    }
};

// Unit tests
test "Matrix operations" {
    const m1 = Matrix.translation(10, 20);
    const m2 = Matrix.scaling(2, 2);
    const result = m1.multiply(m2);

    // translation(10,20) * scaling(2,2): e = 10*2 + 20*0 + 0 = 20, f = 10*0 + 20*2 + 0 = 40
    try std.testing.expectApproxEqAbs(20, result.e, 0.001);
    try std.testing.expectApproxEqAbs(40, result.f, 0.001);
}

test "Matrix transform point" {
    const m = Matrix.translation(10, 20);
    const p = m.transformPoint(Point.init(5, 5));

    try std.testing.expectApproxEqAbs(p.x, 15, 0.001);
    try std.testing.expectApproxEqAbs(p.y, 25, 0.001);
}

test "Path building" {
    const allocator = std.testing.allocator;

    var path = Path.create(allocator);
    defer path.deinit();

    try path.moveTo(0, 0);
    try path.lineTo(100, 0);
    try path.lineTo(100, 100);
    try path.lineTo(0, 100);
    try path.close();

    try std.testing.expectEqual(path.segments.items.len, 5);
}

test "Path bounds" {
    const allocator = std.testing.allocator;

    var path = Path.create(allocator);
    defer path.deinit();

    try path.addRect(Rectangle.init(10, 20, 100, 50));

    const bounds = path.getBounds();
    try std.testing.expectApproxEqAbs(bounds.x, 10, 0.001);
    try std.testing.expectApproxEqAbs(bounds.y, 20, 0.001);
    try std.testing.expectApproxEqAbs(bounds.width, 100, 0.001);
    try std.testing.expectApproxEqAbs(bounds.height, 50, 0.001);
}
