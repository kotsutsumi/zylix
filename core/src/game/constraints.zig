//! Physics Constraints - Joints and connections between bodies
//!
//! Provides various constraint types for connecting rigid bodies,
//! including distance, revolute, prismatic, and weld constraints.

const std = @import("std");
const physics = @import("physics.zig");

const Vec2 = @import("sprite.zig").Vec2;
const RigidBody = physics.RigidBody;

/// Constraint type
pub const ConstraintType = enum(u8) {
    distance = 0,
    revolute = 1,
    prismatic = 2,
    weld = 3,
    rope = 4,
    mouse = 5,
};

/// Base constraint structure
pub const Constraint = struct {
    id: u32 = 0,
    body_a: *RigidBody,
    body_b: ?*RigidBody, // Optional for single-body constraints
    anchor_a: Vec2 = .{}, // Local anchor on body A
    anchor_b: Vec2 = .{}, // Local anchor on body B (or world point)
    enabled: bool = true,
    stiffness: f32 = 1.0, // 0-1, how rigid the constraint is
    damping: f32 = 0.3, // Velocity damping

    /// Get world position of anchor A
    pub fn getWorldAnchorA(self: *const Constraint) Vec2 {
        return self.rotatePoint(self.anchor_a, self.body_a.rotation).add(self.body_a.position);
    }

    /// Get world position of anchor B
    pub fn getWorldAnchorB(self: *const Constraint) Vec2 {
        if (self.body_b) |b| {
            return self.rotatePoint(self.anchor_b, b.rotation).add(b.position);
        }
        return self.anchor_b; // World point
    }

    fn rotatePoint(self: *const Constraint, point: Vec2, angle: f32) Vec2 {
        _ = self;
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        return .{
            .x = point.x * cos_a - point.y * sin_a,
            .y = point.x * sin_a + point.y * cos_a,
        };
    }
};

/// Distance constraint - keeps two anchors at a fixed distance
pub const DistanceConstraint = struct {
    base: Constraint,
    length: f32 = 100, // Target distance
    min_length: f32 = 0, // Minimum allowed distance
    max_length: f32 = std.math.floatMax(f32), // Maximum allowed distance

    pub fn init(body_a: *RigidBody, body_b: *RigidBody, anchor_a: Vec2, anchor_b: Vec2) DistanceConstraint {
        var constraint = DistanceConstraint{
            .base = .{
                .body_a = body_a,
                .body_b = body_b,
                .anchor_a = anchor_a,
                .anchor_b = anchor_b,
            },
        };

        // Calculate initial length
        const world_a = constraint.base.getWorldAnchorA();
        const world_b = constraint.base.getWorldAnchorB();
        constraint.length = world_a.sub(world_b).length();

        return constraint;
    }

    pub fn solve(self: *DistanceConstraint, dt: f32) void {
        if (!self.base.enabled) return;

        const body_a = self.base.body_a;
        const body_b = self.base.body_b orelse return;

        if (body_a.body_type == .static and body_b.body_type == .static) return;

        const world_a = self.base.getWorldAnchorA();
        const world_b = self.base.getWorldAnchorB();

        var delta = world_b.sub(world_a);
        const current_length = delta.length();

        if (current_length < 0.0001) return;

        // Clamp to min/max
        const target_length = std.math.clamp(current_length, self.min_length, self.max_length);

        if (@abs(current_length - target_length) < 0.0001) return;

        const normal = delta.scale(1.0 / current_length);
        const error = current_length - target_length;

        // Calculate correction
        const inv_mass_sum = body_a.inv_mass + body_b.inv_mass;
        if (inv_mass_sum == 0) return;

        const stiffness = self.base.stiffness;
        const correction = normal.scale(error * stiffness / inv_mass_sum);

        // Apply position correction
        body_a.position = body_a.position.add(correction.scale(body_a.inv_mass));
        body_b.position = body_b.position.sub(correction.scale(body_b.inv_mass));

        // Apply velocity damping
        const rel_vel = body_b.velocity.sub(body_a.velocity);
        const damping_force = normal.scale(rel_vel.dot(normal) * self.base.damping);

        body_a.velocity = body_a.velocity.add(damping_force.scale(body_a.inv_mass * dt));
        body_b.velocity = body_b.velocity.sub(damping_force.scale(body_b.inv_mass * dt));
    }
};

/// Revolute constraint - allows rotation around a shared pivot point
pub const RevoluteConstraint = struct {
    base: Constraint,
    reference_angle: f32 = 0, // Initial angle difference
    lower_limit: f32 = -std.math.pi, // Lower angle limit
    upper_limit: f32 = std.math.pi, // Upper angle limit
    enable_limit: bool = false,
    motor_speed: f32 = 0, // Target angular velocity
    max_motor_torque: f32 = 0, // Maximum motor torque
    enable_motor: bool = false,

    pub fn init(body_a: *RigidBody, body_b: *RigidBody, world_anchor: Vec2) RevoluteConstraint {
        // Convert world anchor to local anchors (inverse rotate to body local space)
        const delta_a = world_anchor.sub(body_a.position);
        const delta_b = world_anchor.sub(body_b.position);

        // Inverse rotate to get body-local coordinates
        const cos_a = @cos(-body_a.rotation);
        const sin_a = @sin(-body_a.rotation);
        const local_a = Vec2{
            .x = delta_a.x * cos_a - delta_a.y * sin_a,
            .y = delta_a.x * sin_a + delta_a.y * cos_a,
        };

        const cos_b = @cos(-body_b.rotation);
        const sin_b = @sin(-body_b.rotation);
        const local_b = Vec2{
            .x = delta_b.x * cos_b - delta_b.y * sin_b,
            .y = delta_b.x * sin_b + delta_b.y * cos_b,
        };

        return RevoluteConstraint{
            .base = .{
                .body_a = body_a,
                .body_b = body_b,
                .anchor_a = local_a,
                .anchor_b = local_b,
            },
            .reference_angle = body_b.rotation - body_a.rotation,
        };
    }

    pub fn solve(self: *RevoluteConstraint, dt: f32) void {
        if (!self.base.enabled) return;

        const body_a = self.base.body_a;
        const body_b = self.base.body_b orelse return;

        if (body_a.body_type == .static and body_b.body_type == .static) return;

        // Position constraint - keep anchors together
        const world_a = self.base.getWorldAnchorA();
        const world_b = self.base.getWorldAnchorB();
        const delta = world_b.sub(world_a);

        const inv_mass_sum = body_a.inv_mass + body_b.inv_mass;
        if (inv_mass_sum > 0) {
            const correction = delta.scale(self.base.stiffness / inv_mass_sum);
            body_a.position = body_a.position.add(correction.scale(body_a.inv_mass));
            body_b.position = body_b.position.sub(correction.scale(body_b.inv_mass));
        }

        // Motor
        if (self.enable_motor and self.max_motor_torque > 0) {
            const current_speed = body_b.angular_velocity - body_a.angular_velocity;
            const motor_impulse = std.math.clamp(
                (self.motor_speed - current_speed) * body_a.inertia,
                -self.max_motor_torque * dt,
                self.max_motor_torque * dt,
            );

            body_a.angular_velocity -= motor_impulse * body_a.inv_inertia;
            body_b.angular_velocity += motor_impulse * body_b.inv_inertia;
        }

        // Angle limits
        if (self.enable_limit) {
            const relative_angle = body_b.rotation - body_a.rotation - self.reference_angle;

            if (relative_angle < self.lower_limit) {
                const error = relative_angle - self.lower_limit;
                const impulse = -error * self.base.stiffness;
                body_a.angular_velocity -= impulse * body_a.inv_inertia;
                body_b.angular_velocity += impulse * body_b.inv_inertia;
            } else if (relative_angle > self.upper_limit) {
                const error = relative_angle - self.upper_limit;
                const impulse = -error * self.base.stiffness;
                body_a.angular_velocity -= impulse * body_a.inv_inertia;
                body_b.angular_velocity += impulse * body_b.inv_inertia;
            }
        }
    }
};

/// Prismatic constraint - allows linear motion along an axis
pub const PrismaticConstraint = struct {
    base: Constraint,
    axis: Vec2 = .{ .x = 1, .y = 0 }, // Local axis on body A
    reference_angle: f32 = 0,
    lower_translation: f32 = 0,
    upper_translation: f32 = 0,
    enable_limit: bool = false,
    motor_speed: f32 = 0,
    max_motor_force: f32 = 0,
    enable_motor: bool = false,

    pub fn init(body_a: *RigidBody, body_b: *RigidBody, world_anchor: Vec2, axis: Vec2) PrismaticConstraint {
        const local_a = world_anchor.sub(body_a.position);
        const local_b = world_anchor.sub(body_b.position);

        return PrismaticConstraint{
            .base = .{
                .body_a = body_a,
                .body_b = body_b,
                .anchor_a = local_a,
                .anchor_b = local_b,
            },
            .axis = axis.normalize(),
            .reference_angle = body_b.rotation - body_a.rotation,
        };
    }

    pub fn solve(self: *PrismaticConstraint, dt: f32) void {
        if (!self.base.enabled) return;

        const body_a = self.base.body_a;
        const body_b = self.base.body_b orelse return;

        if (body_a.body_type == .static and body_b.body_type == .static) return;

        // Get world axis
        const cos_a = @cos(body_a.rotation);
        const sin_a = @sin(body_a.rotation);
        const world_axis = Vec2{
            .x = self.axis.x * cos_a - self.axis.y * sin_a,
            .y = self.axis.x * sin_a + self.axis.y * cos_a,
        };

        // Perpendicular axis
        const perp = Vec2{ .x = -world_axis.y, .y = world_axis.x };

        // Position constraint - restrict motion to axis
        const world_a = self.base.getWorldAnchorA();
        const world_b = self.base.getWorldAnchorB();
        const delta = world_b.sub(world_a);

        // Error perpendicular to axis
        const perp_error = delta.dot(perp);

        const inv_mass_sum = body_a.inv_mass + body_b.inv_mass;
        if (inv_mass_sum > 0) {
            const correction = perp.scale(perp_error * self.base.stiffness / inv_mass_sum);
            body_a.position = body_a.position.add(correction.scale(body_a.inv_mass));
            body_b.position = body_b.position.sub(correction.scale(body_b.inv_mass));
        }

        // Rotation constraint
        const angle_error = body_b.rotation - body_a.rotation - self.reference_angle;
        const angle_correction = angle_error * self.base.stiffness;
        body_a.angular_velocity += angle_correction * body_a.inv_inertia;
        body_b.angular_velocity -= angle_correction * body_b.inv_inertia;

        // Translation limits
        if (self.enable_limit) {
            const translation = delta.dot(world_axis);

            if (translation < self.lower_translation) {
                const error = translation - self.lower_translation;
                const impulse = world_axis.scale(-error * self.base.stiffness / inv_mass_sum);
                body_a.position = body_a.position.add(impulse.scale(body_a.inv_mass));
                body_b.position = body_b.position.sub(impulse.scale(body_b.inv_mass));
            } else if (translation > self.upper_translation) {
                const error = translation - self.upper_translation;
                const impulse = world_axis.scale(-error * self.base.stiffness / inv_mass_sum);
                body_a.position = body_a.position.add(impulse.scale(body_a.inv_mass));
                body_b.position = body_b.position.sub(impulse.scale(body_b.inv_mass));
            }
        }

        // Motor
        if (self.enable_motor and self.max_motor_force > 0) {
            const rel_vel = body_b.velocity.sub(body_a.velocity);
            const current_speed = rel_vel.dot(world_axis);
            const motor_impulse = std.math.clamp(
                (self.motor_speed - current_speed) * body_a.mass,
                -self.max_motor_force * dt,
                self.max_motor_force * dt,
            );

            const impulse = world_axis.scale(motor_impulse);
            body_a.velocity = body_a.velocity.sub(impulse.scale(body_a.inv_mass));
            body_b.velocity = body_b.velocity.add(impulse.scale(body_b.inv_mass));
        }
    }
};

/// Weld constraint - completely locks two bodies together
pub const WeldConstraint = struct {
    base: Constraint,
    reference_angle: f32 = 0,

    pub fn init(body_a: *RigidBody, body_b: *RigidBody, world_anchor: Vec2) WeldConstraint {
        const local_a = world_anchor.sub(body_a.position);
        const local_b = world_anchor.sub(body_b.position);

        return WeldConstraint{
            .base = .{
                .body_a = body_a,
                .body_b = body_b,
                .anchor_a = local_a,
                .anchor_b = local_b,
                .stiffness = 1.0,
            },
            .reference_angle = body_b.rotation - body_a.rotation,
        };
    }

    pub fn solve(self: *WeldConstraint, dt: f32) void {
        _ = dt;
        if (!self.base.enabled) return;

        const body_a = self.base.body_a;
        const body_b = self.base.body_b orelse return;

        if (body_a.body_type == .static and body_b.body_type == .static) return;

        // Position constraint
        const world_a = self.base.getWorldAnchorA();
        const world_b = self.base.getWorldAnchorB();
        const delta = world_b.sub(world_a);

        const inv_mass_sum = body_a.inv_mass + body_b.inv_mass;
        if (inv_mass_sum > 0) {
            const correction = delta.scale(self.base.stiffness / inv_mass_sum);
            body_a.position = body_a.position.add(correction.scale(body_a.inv_mass));
            body_b.position = body_b.position.sub(correction.scale(body_b.inv_mass));
        }

        // Rotation constraint
        const angle_error = body_b.rotation - body_a.rotation - self.reference_angle;
        const inv_inertia_sum = body_a.inv_inertia + body_b.inv_inertia;

        if (inv_inertia_sum > 0) {
            const angle_correction = angle_error * self.base.stiffness / inv_inertia_sum;
            body_a.rotation += angle_correction * body_a.inv_inertia;
            body_b.rotation -= angle_correction * body_b.inv_inertia;
        }

        // Match velocities
        const avg_velocity = Vec2{
            .x = (body_a.velocity.x * body_a.mass + body_b.velocity.x * body_b.mass) / (body_a.mass + body_b.mass),
            .y = (body_a.velocity.y * body_a.mass + body_b.velocity.y * body_b.mass) / (body_a.mass + body_b.mass),
        };

        body_a.velocity = avg_velocity;
        body_b.velocity = avg_velocity;

        // Match angular velocities
        const total_inertia = body_a.inertia + body_b.inertia;
        if (total_inertia > 0) {
            const avg_angular = (body_a.angular_velocity * body_a.inertia + body_b.angular_velocity * body_b.inertia) / total_inertia;
            body_a.angular_velocity = avg_angular;
            body_b.angular_velocity = avg_angular;
        }
    }
};

/// Rope constraint - keeps two anchors within a maximum distance
pub const RopeConstraint = struct {
    base: Constraint,
    max_length: f32 = 100,

    pub fn init(body_a: *RigidBody, body_b: *RigidBody, anchor_a: Vec2, anchor_b: Vec2, max_length: f32) RopeConstraint {
        return RopeConstraint{
            .base = .{
                .body_a = body_a,
                .body_b = body_b,
                .anchor_a = anchor_a,
                .anchor_b = anchor_b,
            },
            .max_length = max_length,
        };
    }

    pub fn solve(self: *RopeConstraint, dt: f32) void {
        _ = dt;
        if (!self.base.enabled) return;

        const body_a = self.base.body_a;
        const body_b = self.base.body_b orelse return;

        if (body_a.body_type == .static and body_b.body_type == .static) return;

        const world_a = self.base.getWorldAnchorA();
        const world_b = self.base.getWorldAnchorB();

        var delta = world_b.sub(world_a);
        const current_length = delta.length();

        if (current_length <= self.max_length) return;

        const normal = delta.scale(1.0 / current_length);
        const error = current_length - self.max_length;

        const inv_mass_sum = body_a.inv_mass + body_b.inv_mass;
        if (inv_mass_sum == 0) return;

        const correction = normal.scale(error * self.base.stiffness / inv_mass_sum);

        body_a.position = body_a.position.add(correction.scale(body_a.inv_mass));
        body_b.position = body_b.position.sub(correction.scale(body_b.inv_mass));

        // Clamp velocities to not exceed rope
        const rel_vel = body_b.velocity.sub(body_a.velocity);
        const vel_along_rope = rel_vel.dot(normal);

        if (vel_along_rope > 0) {
            const impulse = normal.scale(vel_along_rope / inv_mass_sum);
            body_a.velocity = body_a.velocity.add(impulse.scale(body_a.inv_mass));
            body_b.velocity = body_b.velocity.sub(impulse.scale(body_b.inv_mass));
        }
    }
};

/// Mouse constraint - attaches a body to a world point (for dragging)
pub const MouseConstraint = struct {
    base: Constraint,
    target: Vec2 = .{}, // World target position
    max_force: f32 = 1000,
    frequency: f32 = 5.0, // Hz
    damping_ratio: f32 = 0.7,

    pub fn init(body: *RigidBody, anchor: Vec2) MouseConstraint {
        return MouseConstraint{
            .base = .{
                .body_a = body,
                .body_b = null,
                .anchor_a = anchor,
            },
            .target = body.position.add(anchor),
        };
    }

    pub fn setTarget(self: *MouseConstraint, target: Vec2) void {
        self.target = target;
    }

    pub fn solve(self: *MouseConstraint, dt: f32) void {
        if (!self.base.enabled) return;

        const body = self.base.body_a;
        if (body.body_type == .static) return;

        const world_anchor = self.base.getWorldAnchorA();
        const delta = self.target.sub(world_anchor);

        // Spring-damper model
        const omega = 2.0 * std.math.pi * self.frequency;
        const d = 2.0 * body.mass * self.damping_ratio * omega;
        const k = body.mass * omega * omega;

        // Calculate force
        const force = Vec2{
            .x = k * delta.x - d * body.velocity.x,
            .y = k * delta.y - d * body.velocity.y,
        };

        // Clamp force
        const force_magnitude = force.length();
        const clamped_force = if (force_magnitude > self.max_force)
            force.scale(self.max_force / force_magnitude)
        else
            force;

        // Apply force
        body.applyForceAtPoint(clamped_force.scale(dt), world_anchor);
    }
};

/// Constraint manager
pub const ConstraintManager = struct {
    allocator: std.mem.Allocator,
    distance_constraints: std.ArrayListUnmanaged(DistanceConstraint) = .{},
    revolute_constraints: std.ArrayListUnmanaged(RevoluteConstraint) = .{},
    prismatic_constraints: std.ArrayListUnmanaged(PrismaticConstraint) = .{},
    weld_constraints: std.ArrayListUnmanaged(WeldConstraint) = .{},
    rope_constraints: std.ArrayListUnmanaged(RopeConstraint) = .{},
    mouse_constraints: std.ArrayListUnmanaged(MouseConstraint) = .{},
    next_id: u32 = 1,

    pub fn init(allocator: std.mem.Allocator) ConstraintManager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ConstraintManager) void {
        self.distance_constraints.deinit(self.allocator);
        self.revolute_constraints.deinit(self.allocator);
        self.prismatic_constraints.deinit(self.allocator);
        self.weld_constraints.deinit(self.allocator);
        self.rope_constraints.deinit(self.allocator);
        self.mouse_constraints.deinit(self.allocator);
    }

    pub fn addDistance(self: *ConstraintManager, constraint: DistanceConstraint) !*DistanceConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.distance_constraints.append(self.allocator, c);
        return &self.distance_constraints.items[self.distance_constraints.items.len - 1];
    }

    pub fn addRevolute(self: *ConstraintManager, constraint: RevoluteConstraint) !*RevoluteConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.revolute_constraints.append(self.allocator, c);
        return &self.revolute_constraints.items[self.revolute_constraints.items.len - 1];
    }

    pub fn addPrismatic(self: *ConstraintManager, constraint: PrismaticConstraint) !*PrismaticConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.prismatic_constraints.append(self.allocator, c);
        return &self.prismatic_constraints.items[self.prismatic_constraints.items.len - 1];
    }

    pub fn addWeld(self: *ConstraintManager, constraint: WeldConstraint) !*WeldConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.weld_constraints.append(self.allocator, c);
        return &self.weld_constraints.items[self.weld_constraints.items.len - 1];
    }

    pub fn addRope(self: *ConstraintManager, constraint: RopeConstraint) !*RopeConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.rope_constraints.append(self.allocator, c);
        return &self.rope_constraints.items[self.rope_constraints.items.len - 1];
    }

    pub fn addMouse(self: *ConstraintManager, constraint: MouseConstraint) !*MouseConstraint {
        var c = constraint;
        c.base.id = self.next_id;
        self.next_id += 1;
        try self.mouse_constraints.append(self.allocator, c);
        return &self.mouse_constraints.items[self.mouse_constraints.items.len - 1];
    }

    pub fn solve(self: *ConstraintManager, dt: f32) void {
        for (self.distance_constraints.items) |*c| c.solve(dt);
        for (self.revolute_constraints.items) |*c| c.solve(dt);
        for (self.prismatic_constraints.items) |*c| c.solve(dt);
        for (self.weld_constraints.items) |*c| c.solve(dt);
        for (self.rope_constraints.items) |*c| c.solve(dt);
        for (self.mouse_constraints.items) |*c| c.solve(dt);
    }

    pub fn clear(self: *ConstraintManager) void {
        self.distance_constraints.clearRetainingCapacity();
        self.revolute_constraints.clearRetainingCapacity();
        self.prismatic_constraints.clearRetainingCapacity();
        self.weld_constraints.clearRetainingCapacity();
        self.rope_constraints.clearRetainingCapacity();
        self.mouse_constraints.clearRetainingCapacity();
    }
};

test "DistanceConstraint basic" {
    var body_a = physics.RigidBody.init(.dynamic);
    body_a.position = .{ .x = 0, .y = 0 };

    var body_b = physics.RigidBody.init(.dynamic);
    body_b.position = .{ .x = 100, .y = 0 };

    var constraint = DistanceConstraint.init(&body_a, &body_b, .{}, .{});

    try std.testing.expectEqual(@as(f32, 100), constraint.length);
}

test "RevoluteConstraint basic" {
    var body_a = physics.RigidBody.init(.static);
    body_a.position = .{ .x = 0, .y = 0 };

    var body_b = physics.RigidBody.init(.dynamic);
    body_b.position = .{ .x = 50, .y = 0 };

    const constraint = RevoluteConstraint.init(&body_a, &body_b, .{ .x = 0, .y = 0 });

    try std.testing.expectEqual(@as(f32, 0), constraint.reference_angle);
}

test "ConstraintManager basic" {
    const allocator = std.testing.allocator;
    var manager = ConstraintManager.init(allocator);
    defer manager.deinit();

    var body_a = physics.RigidBody.init(.dynamic);
    var body_b = physics.RigidBody.init(.dynamic);
    body_a.position = .{ .x = 0, .y = 0 };
    body_b.position = .{ .x = 100, .y = 0 };

    const constraint = DistanceConstraint.init(&body_a, &body_b, .{}, .{});
    _ = try manager.addDistance(constraint);

    try std.testing.expectEqual(@as(usize, 1), manager.distance_constraints.items.len);
}
