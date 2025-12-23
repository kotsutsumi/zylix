//! Physics Engine - Matter.js-inspired 2D physics simulation
//!
//! Provides rigid body dynamics, collision detection and response,
//! and physical constraint support.

const std = @import("std");
const sprite = @import("sprite.zig");

const Vec2 = sprite.Vec2;
const Rect = sprite.Rect;

/// Body type
pub const BodyType = enum(u8) {
    dynamic = 0, // Affected by forces and collisions
    static = 1, // Never moves
    kinematic = 2, // Moves but not affected by forces
};

/// Collision shape type
pub const ShapeType = enum(u8) {
    circle = 0,
    aabb = 1, // Axis-aligned bounding box
    polygon = 2,
};

/// Collision filter for selective collision
pub const CollisionFilter = struct {
    category: u16 = 0x0001,
    mask: u16 = 0xFFFF,
    group: i16 = 0,

    pub fn shouldCollide(self: CollisionFilter, other: CollisionFilter) bool {
        // Same positive group always collides
        if (self.group > 0 and self.group == other.group) return true;
        // Same negative group never collides
        if (self.group < 0 and self.group == other.group) return false;
        // Check category/mask
        return (self.mask & other.category) != 0 and (other.mask & self.category) != 0;
    }
};

/// Physical material properties
pub const Material = struct {
    density: f32 = 1.0,
    friction: f32 = 0.3,
    restitution: f32 = 0.0, // Bounciness (0-1)
    friction_static: f32 = 0.5,
    friction_air: f32 = 0.01,
};

/// Circle collider
pub const CircleShape = struct {
    radius: f32 = 1.0,
    offset: Vec2 = .{},
};

/// AABB collider
pub const AABBShape = struct {
    half_width: f32 = 1.0,
    half_height: f32 = 1.0,
    offset: Vec2 = .{},
};

/// Polygon collider (convex only)
pub const PolygonShape = struct {
    vertices: []const Vec2,
    offset: Vec2 = .{},
};

/// Collision shape
pub const Collider = union(ShapeType) {
    circle: CircleShape,
    aabb: AABBShape,
    polygon: PolygonShape,

    pub fn circle(radius: f32) Collider {
        return .{ .circle = .{ .radius = radius } };
    }

    pub fn box(half_width: f32, half_height: f32) Collider {
        return .{ .aabb = .{ .half_width = half_width, .half_height = half_height } };
    }

    pub fn getBounds(self: Collider, position: Vec2, rotation: f32) Rect {
        _ = rotation;
        switch (self) {
            .circle => |c| {
                return .{
                    .x = position.x + c.offset.x - c.radius,
                    .y = position.y + c.offset.y - c.radius,
                    .width = c.radius * 2,
                    .height = c.radius * 2,
                };
            },
            .aabb => |a| {
                return .{
                    .x = position.x + a.offset.x - a.half_width,
                    .y = position.y + a.offset.y - a.half_height,
                    .width = a.half_width * 2,
                    .height = a.half_height * 2,
                };
            },
            .polygon => {
                // Simplified bounds for polygon
                return .{ .x = position.x - 1, .y = position.y - 1, .width = 2, .height = 2 };
            },
        }
    }
};

/// Rigid body
pub const RigidBody = struct {
    // Identity
    id: u32 = 0,
    label: ?[]const u8 = null,
    user_data: ?*anyopaque = null,

    // Type
    body_type: BodyType = .dynamic,

    // Transform
    position: Vec2 = .{},
    velocity: Vec2 = .{},
    acceleration: Vec2 = .{},
    rotation: f32 = 0,
    angular_velocity: f32 = 0,
    angular_acceleration: f32 = 0,

    // Physics properties
    mass: f32 = 1.0,
    inv_mass: f32 = 1.0,
    inertia: f32 = 1.0,
    inv_inertia: f32 = 1.0,
    material: Material = .{},

    // Collision
    collider: Collider = Collider.circle(1.0),
    filter: CollisionFilter = .{},
    is_sensor: bool = false, // Triggers events but no physical response

    // State
    is_sleeping: bool = false,
    sleep_threshold: f32 = 60, // Frames of low motion before sleeping
    motion: f32 = 0, // Used for sleep detection
    force: Vec2 = .{}, // Accumulated force
    torque: f32 = 0, // Accumulated torque

    // Constraints
    is_static: bool = false,
    fixed_rotation: bool = false,

    pub fn init(body_type: BodyType) RigidBody {
        var body = RigidBody{
            .body_type = body_type,
        };

        if (body_type == .static) {
            body.mass = 0;
            body.inv_mass = 0;
            body.inertia = 0;
            body.inv_inertia = 0;
            body.is_static = true;
        }

        return body;
    }

    pub fn setMass(self: *RigidBody, mass: f32) void {
        if (self.body_type == .static) return;
        self.mass = @max(0.001, mass);
        self.inv_mass = 1.0 / self.mass;
        self.updateInertia();
    }

    pub fn updateInertia(self: *RigidBody) void {
        if (self.body_type == .static or self.fixed_rotation) {
            self.inertia = 0;
            self.inv_inertia = 0;
            return;
        }

        // Calculate moment of inertia based on shape
        switch (self.collider) {
            .circle => |c| {
                // I = (1/2) * m * r^2
                self.inertia = 0.5 * self.mass * c.radius * c.radius;
            },
            .aabb => |a| {
                // I = (1/12) * m * (w^2 + h^2)
                const w = a.half_width * 2;
                const h = a.half_height * 2;
                self.inertia = (self.mass / 12.0) * (w * w + h * h);
            },
            .polygon => {
                // Simplified: treat as circle
                self.inertia = self.mass;
            },
        }

        self.inv_inertia = if (self.inertia > 0) 1.0 / self.inertia else 0;
    }

    pub fn applyForce(self: *RigidBody, force: Vec2) void {
        if (self.body_type == .static) return;
        self.force = self.force.add(force);
        self.wake();
    }

    pub fn applyForceAtPoint(self: *RigidBody, force: Vec2, point: Vec2) void {
        if (self.body_type == .static) return;
        self.force = self.force.add(force);

        // Calculate torque from force applied at point
        const r = point.sub(self.position);
        self.torque += r.x * force.y - r.y * force.x;
        self.wake();
    }

    pub fn applyImpulse(self: *RigidBody, impulse: Vec2) void {
        if (self.body_type == .static) return;
        self.velocity = self.velocity.add(impulse.scale(self.inv_mass));
        self.wake();
    }

    pub fn applyImpulseAtPoint(self: *RigidBody, impulse: Vec2, point: Vec2) void {
        if (self.body_type == .static) return;
        self.velocity = self.velocity.add(impulse.scale(self.inv_mass));

        const r = point.sub(self.position);
        self.angular_velocity += (r.x * impulse.y - r.y * impulse.x) * self.inv_inertia;
        self.wake();
    }

    pub fn setVelocity(self: *RigidBody, velocity: Vec2) void {
        self.velocity = velocity;
        self.wake();
    }

    pub fn setPosition(self: *RigidBody, position: Vec2) void {
        self.position = position;
        self.wake();
    }

    pub fn setRotation(self: *RigidBody, rotation: f32) void {
        self.rotation = rotation;
        self.wake();
    }

    pub fn wake(self: *RigidBody) void {
        self.is_sleeping = false;
        self.motion = self.sleep_threshold;
    }

    pub fn sleep(self: *RigidBody) void {
        self.is_sleeping = true;
        self.velocity = .{};
        self.angular_velocity = 0;
    }

    pub fn getBounds(self: *const RigidBody) Rect {
        return self.collider.getBounds(self.position, self.rotation);
    }

    pub fn integrate(self: *RigidBody, dt: f32, gravity: Vec2) void {
        if (self.body_type == .static or self.is_sleeping) return;

        // Apply gravity
        if (self.body_type == .dynamic) {
            self.force = self.force.add(gravity.scale(self.mass));
        }

        // Integrate velocity
        self.acceleration = self.force.scale(self.inv_mass);
        self.velocity = self.velocity.add(self.acceleration.scale(dt));

        // Apply air friction
        self.velocity = self.velocity.scale(1.0 - self.material.friction_air);

        // Integrate position
        self.position = self.position.add(self.velocity.scale(dt));

        // Angular integration
        if (!self.fixed_rotation) {
            self.angular_acceleration = self.torque * self.inv_inertia;
            self.angular_velocity += self.angular_acceleration * dt;
            self.angular_velocity *= (1.0 - self.material.friction_air);
            self.rotation += self.angular_velocity * dt;
        }

        // Clear forces
        self.force = .{};
        self.torque = 0;

        // Update motion for sleep detection
        const speed = self.velocity.length();
        self.motion = self.motion * 0.9 + speed * 0.1;
    }
};

/// Collision manifold - contact information
pub const ContactManifold = struct {
    body_a: *RigidBody,
    body_b: *RigidBody,
    normal: Vec2 = .{}, // From A to B
    penetration: f32 = 0,
    contact_point: Vec2 = .{},
    is_active: bool = true,
};

/// Collision detection utilities
pub const Collision = struct {
    /// Circle vs Circle collision
    pub fn circleVsCircle(a_pos: Vec2, a_radius: f32, b_pos: Vec2, b_radius: f32) ?struct { normal: Vec2, penetration: f32, point: Vec2 } {
        const diff = b_pos.sub(a_pos);
        const dist_sq = diff.x * diff.x + diff.y * diff.y;
        const radius_sum = a_radius + b_radius;

        if (dist_sq >= radius_sum * radius_sum) return null;

        const dist = @sqrt(dist_sq);
        const normal = if (dist > 0.0001) diff.scale(1.0 / dist) else Vec2{ .x = 1, .y = 0 };
        const penetration = radius_sum - dist;
        const point = a_pos.add(normal.scale(a_radius));

        return .{ .normal = normal, .penetration = penetration, .point = point };
    }

    /// AABB vs AABB collision
    pub fn aabbVsAabb(a_pos: Vec2, a_half: Vec2, b_pos: Vec2, b_half: Vec2) ?struct { normal: Vec2, penetration: f32, point: Vec2 } {
        const diff = b_pos.sub(a_pos);
        const overlap_x = a_half.x + b_half.x - @abs(diff.x);
        const overlap_y = a_half.y + b_half.y - @abs(diff.y);

        if (overlap_x <= 0 or overlap_y <= 0) return null;

        var normal: Vec2 = undefined;
        var penetration: f32 = undefined;

        if (overlap_x < overlap_y) {
            penetration = overlap_x;
            normal = if (diff.x < 0) Vec2{ .x = -1, .y = 0 } else Vec2{ .x = 1, .y = 0 };
        } else {
            penetration = overlap_y;
            normal = if (diff.y < 0) Vec2{ .x = 0, .y = -1 } else Vec2{ .x = 0, .y = 1 };
        }

        const point = Vec2{
            .x = a_pos.x + @as(f32, if (diff.x < 0) -a_half.x else a_half.x),
            .y = a_pos.y + @as(f32, if (diff.y < 0) -a_half.y else a_half.y),
        };

        return .{ .normal = normal, .penetration = penetration, .point = point };
    }

    /// Circle vs AABB collision
    pub fn circleVsAabb(circle_pos: Vec2, radius: f32, aabb_pos: Vec2, aabb_half: Vec2) ?struct { normal: Vec2, penetration: f32, point: Vec2 } {
        // Find closest point on AABB to circle center
        const closest = Vec2{
            .x = std.math.clamp(circle_pos.x, aabb_pos.x - aabb_half.x, aabb_pos.x + aabb_half.x),
            .y = std.math.clamp(circle_pos.y, aabb_pos.y - aabb_half.y, aabb_pos.y + aabb_half.y),
        };

        const diff = circle_pos.sub(closest);
        const dist_sq = diff.x * diff.x + diff.y * diff.y;

        if (dist_sq >= radius * radius) return null;

        const dist = @sqrt(dist_sq);
        const normal = if (dist > 0.0001) diff.scale(1.0 / dist) else Vec2{ .x = 1, .y = 0 };
        const penetration = radius - dist;

        return .{ .normal = normal, .penetration = penetration, .point = closest };
    }
};

/// Physics world - manages all bodies and simulation
pub const PhysicsWorld = struct {
    allocator: std.mem.Allocator,

    // Bodies
    bodies: std.ArrayListUnmanaged(*RigidBody) = .{},
    next_id: u32 = 1,

    // Simulation parameters
    gravity: Vec2 = .{ .x = 0, .y = 980 }, // Pixels per second squared
    iterations: u32 = 10, // Constraint solver iterations

    // Collision
    contacts: std.ArrayListUnmanaged(ContactManifold) = .{},
    on_collision_start: ?*const fn (*RigidBody, *RigidBody, ContactManifold) void = null,
    on_collision_end: ?*const fn (*RigidBody, *RigidBody) void = null,

    // Sleeping
    enable_sleeping: bool = true,
    sleep_threshold: f32 = 0.5,

    // Bounds
    bounds: ?Rect = null,

    pub fn init(allocator: std.mem.Allocator) PhysicsWorld {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *PhysicsWorld) void {
        for (self.bodies.items) |body| {
            self.allocator.destroy(body);
        }
        self.bodies.deinit(self.allocator);
        self.contacts.deinit(self.allocator);
    }

    pub fn createBody(self: *PhysicsWorld, body_type: BodyType) !*RigidBody {
        const body = try self.allocator.create(RigidBody);
        body.* = RigidBody.init(body_type);
        body.id = self.next_id;
        self.next_id += 1;
        try self.bodies.append(self.allocator, body);
        return body;
    }

    pub fn destroyBody(self: *PhysicsWorld, body: *RigidBody) void {
        for (self.bodies.items, 0..) |b, i| {
            if (b == body) {
                _ = self.bodies.swapRemove(i);
                self.allocator.destroy(body);
                break;
            }
        }
    }

    pub fn step(self: *PhysicsWorld, dt: f32) void {
        // Clear contacts
        self.contacts.clearRetainingCapacity();

        // Integrate bodies
        for (self.bodies.items) |body| {
            body.integrate(dt, self.gravity);
        }

        // Broad phase - detect potential collisions
        self.broadPhase();

        // Narrow phase - detailed collision detection
        self.narrowPhase();

        // Solve constraints
        var i: u32 = 0;
        while (i < self.iterations) : (i += 1) {
            self.solveConstraints();
        }

        // Apply bounds
        if (self.bounds) |bounds| {
            for (self.bodies.items) |body| {
                self.applyBounds(body, bounds);
            }
        }

        // Sleep detection
        if (self.enable_sleeping) {
            for (self.bodies.items) |body| {
                if (body.motion < self.sleep_threshold and !body.is_sleeping) {
                    body.sleep();
                }
            }
        }
    }

    fn broadPhase(self: *PhysicsWorld) void {
        // Simple O(n^2) broad phase - for better performance use spatial hash or BVH
        const bodies = self.bodies.items;

        for (bodies, 0..) |a, i| {
            for (bodies[i + 1 ..]) |b| {
                // Skip if both sleeping
                if (a.is_sleeping and b.is_sleeping) continue;

                // Skip if shouldn't collide
                if (!a.filter.shouldCollide(b.filter)) continue;

                // AABB overlap test
                const a_bounds = a.getBounds();
                const b_bounds = b.getBounds();
                if (a_bounds.intersects(b_bounds)) {
                    // Add potential collision pair
                    self.contacts.append(self.allocator, .{
                        .body_a = a,
                        .body_b = b,
                    }) catch {
                        std.log.warn("Physics: Failed to add contact - allocation error", .{});
                        continue;
                    };
                }
            }
        }
    }

    fn narrowPhase(self: *PhysicsWorld) void {
        for (self.contacts.items) |*contact| {
            const a = contact.body_a;
            const b = contact.body_b;

            const result: ?struct { normal: Vec2, penetration: f32, point: Vec2 } = switch (a.collider) {
                .circle => |ac| switch (b.collider) {
                    .circle => |bc| Collision.circleVsCircle(
                        a.position.add(ac.offset),
                        ac.radius,
                        b.position.add(bc.offset),
                        bc.radius,
                    ),
                    .aabb => |ba| Collision.circleVsAabb(
                        a.position.add(ac.offset),
                        ac.radius,
                        b.position.add(ba.offset),
                        .{ .x = ba.half_width, .y = ba.half_height },
                    ),
                    .polygon => null,
                },
                .aabb => |aa| switch (b.collider) {
                    .circle => |bc| blk: {
                        const r = Collision.circleVsAabb(
                            b.position.add(bc.offset),
                            bc.radius,
                            a.position.add(aa.offset),
                            .{ .x = aa.half_width, .y = aa.half_height },
                        );
                        if (r) |res| {
                            break :blk .{
                                .normal = res.normal.scale(-1),
                                .penetration = res.penetration,
                                .point = res.point,
                            };
                        }
                        break :blk null;
                    },
                    .aabb => |ba| Collision.aabbVsAabb(
                        a.position.add(aa.offset),
                        .{ .x = aa.half_width, .y = aa.half_height },
                        b.position.add(ba.offset),
                        .{ .x = ba.half_width, .y = ba.half_height },
                    ),
                    .polygon => null,
                },
                .polygon => null,
            };

            if (result) |r| {
                contact.normal = r.normal;
                contact.penetration = r.penetration;
                contact.contact_point = r.point;
                contact.is_active = true;

                if (self.on_collision_start) |callback| {
                    callback(a, b, contact.*);
                }
            } else {
                contact.is_active = false;
            }
        }
    }

    fn solveConstraints(self: *PhysicsWorld) void {
        for (self.contacts.items) |*contact| {
            if (!contact.is_active) continue;

            const a = contact.body_a;
            const b = contact.body_b;

            // Skip if both static
            if (a.body_type == .static and b.body_type == .static) continue;

            // Skip sensors
            if (a.is_sensor or b.is_sensor) continue;

            const normal = contact.normal;
            const penetration = contact.penetration;

            // Calculate relative velocity
            const rel_vel = b.velocity.sub(a.velocity);
            const vel_along_normal = rel_vel.dot(normal);

            // Don't resolve if separating
            if (vel_along_normal > 0) continue;

            // Calculate restitution
            const e = @min(a.material.restitution, b.material.restitution);

            // Calculate impulse scalar
            const inv_mass_sum = a.inv_mass + b.inv_mass;
            if (inv_mass_sum == 0) continue;

            var j = -(1 + e) * vel_along_normal;
            j /= inv_mass_sum;

            // Apply impulse
            const impulse = normal.scale(j);
            a.velocity = a.velocity.sub(impulse.scale(a.inv_mass));
            b.velocity = b.velocity.add(impulse.scale(b.inv_mass));

            // Positional correction (prevent sinking)
            const slop: f32 = 0.01;
            const percent: f32 = 0.8;
            const correction = normal.scale(@max(penetration - slop, 0) / inv_mass_sum * percent);
            a.position = a.position.sub(correction.scale(a.inv_mass));
            b.position = b.position.add(correction.scale(b.inv_mass));

            // Friction
            const tangent = Vec2{
                .x = rel_vel.x - normal.x * vel_along_normal,
                .y = rel_vel.y - normal.y * vel_along_normal,
            };

            const tangent_len = tangent.length();
            if (tangent_len > 0.0001) {
                const tangent_normalized = tangent.scale(1.0 / tangent_len);
                const friction = @sqrt(a.material.friction * b.material.friction);
                var jt = -rel_vel.dot(tangent_normalized);
                jt /= inv_mass_sum;

                // Coulomb friction
                const friction_impulse = if (@abs(jt) < j * friction)
                    tangent_normalized.scale(jt)
                else
                    tangent_normalized.scale(-j * friction);

                a.velocity = a.velocity.sub(friction_impulse.scale(a.inv_mass));
                b.velocity = b.velocity.add(friction_impulse.scale(b.inv_mass));
            }
        }
    }

    fn applyBounds(self: *PhysicsWorld, body: *RigidBody, bounds: Rect) void {
        _ = self;
        if (body.body_type == .static) return;

        const body_bounds = body.getBounds();
        const restitution = body.material.restitution;

        // Left bound
        if (body_bounds.x < bounds.x) {
            body.position.x += bounds.x - body_bounds.x;
            body.velocity.x = @abs(body.velocity.x) * restitution;
        }
        // Right bound
        if (body_bounds.x + body_bounds.width > bounds.x + bounds.width) {
            body.position.x -= (body_bounds.x + body_bounds.width) - (bounds.x + bounds.width);
            body.velocity.x = -@abs(body.velocity.x) * restitution;
        }
        // Top bound
        if (body_bounds.y < bounds.y) {
            body.position.y += bounds.y - body_bounds.y;
            body.velocity.y = @abs(body.velocity.y) * restitution;
        }
        // Bottom bound
        if (body_bounds.y + body_bounds.height > bounds.y + bounds.height) {
            body.position.y -= (body_bounds.y + body_bounds.height) - (bounds.y + bounds.height);
            body.velocity.y = -@abs(body.velocity.y) * restitution;
        }
    }

    pub fn raycast(self: *const PhysicsWorld, origin: Vec2, direction: Vec2, max_distance: f32) ?struct {
        body: *RigidBody,
        point: Vec2,
        normal: Vec2,
        distance: f32,
    } {
        var closest: ?struct {
            body: *RigidBody,
            point: Vec2,
            normal: Vec2,
            distance: f32,
        } = null;

        for (self.bodies.items) |body| {
            if (body.is_sensor) continue;

            // Simple AABB raycast
            const bounds = body.getBounds();
            if (rayVsAabb(origin, direction, bounds)) |hit| {
                if (hit.distance <= max_distance) {
                    if (closest == null or hit.distance < closest.?.distance) {
                        closest = .{
                            .body = body,
                            .point = origin.add(direction.scale(hit.distance)),
                            .normal = hit.normal,
                            .distance = hit.distance,
                        };
                    }
                }
            }
        }

        return closest;
    }

    fn rayVsAabb(origin: Vec2, direction: Vec2, aabb: Rect) ?struct { distance: f32, normal: Vec2 } {
        // Handle division by zero: use very large values for parallel rays
        const inv_dir_x = if (@abs(direction.x) > 1e-10) 1.0 / direction.x else std.math.copysign(@as(f32, std.math.floatMax(f32)), direction.x);
        const inv_dir_y = if (@abs(direction.y) > 1e-10) 1.0 / direction.y else std.math.copysign(@as(f32, std.math.floatMax(f32)), direction.y);

        const t1 = (aabb.x - origin.x) * inv_dir_x;
        const t2 = (aabb.x + aabb.width - origin.x) * inv_dir_x;
        const t3 = (aabb.y - origin.y) * inv_dir_y;
        const t4 = (aabb.y + aabb.height - origin.y) * inv_dir_y;

        const tmin = @max(@min(t1, t2), @min(t3, t4));
        const tmax = @min(@max(t1, t2), @max(t3, t4));

        if (tmax < 0 or tmin > tmax) return null;

        const t = if (tmin < 0) tmax else tmin;
        if (t < 0) return null;

        // Calculate hit normal
        var normal = Vec2{};
        if (t == t1) normal.x = -1;
        if (t == t2) normal.x = 1;
        if (t == t3) normal.y = -1;
        if (t == t4) normal.y = 1;

        return .{ .distance = t, .normal = normal };
    }

    pub fn queryPoint(self: *const PhysicsWorld, allocator: std.mem.Allocator, point: Vec2) !std.ArrayList(*RigidBody) {
        var result = std.ArrayList(*RigidBody).init(allocator);
        errdefer result.deinit();

        for (self.bodies.items) |body| {
            if (body.getBounds().contains(point)) {
                try result.append(body);
            }
        }

        return result;
    }

    pub fn queryRect(self: *const PhysicsWorld, allocator: std.mem.Allocator, rect: Rect) !std.ArrayList(*RigidBody) {
        var result = std.ArrayList(*RigidBody).init(allocator);
        errdefer result.deinit();

        for (self.bodies.items) |body| {
            if (body.getBounds().intersects(rect)) {
                try result.append(body);
            }
        }

        return result;
    }
};

test "RigidBody basic" {
    var body = RigidBody.init(.dynamic);
    body.setMass(2.0);

    try std.testing.expectEqual(@as(f32, 2.0), body.mass);
    try std.testing.expectEqual(@as(f32, 0.5), body.inv_mass);
}

test "Collision circle vs circle" {
    const result = Collision.circleVsCircle(
        .{ .x = 0, .y = 0 },
        5,
        .{ .x = 8, .y = 0 },
        5,
    );

    try std.testing.expect(result != null);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), result.?.penetration, 0.001);
}

test "Collision no overlap" {
    const result = Collision.circleVsCircle(
        .{ .x = 0, .y = 0 },
        5,
        .{ .x = 20, .y = 0 },
        5,
    );

    try std.testing.expect(result == null);
}

test "PhysicsWorld basic" {
    const allocator = std.testing.allocator;
    var world = PhysicsWorld.init(allocator);
    defer world.deinit();

    const body = try world.createBody(.dynamic);
    body.position = .{ .x = 100, .y = 100 };
    body.collider = Collider.circle(20);

    try std.testing.expectEqual(@as(usize, 1), world.bodies.items.len);

    world.step(1.0 / 60.0);

    // Body should have moved due to gravity
    try std.testing.expect(body.position.y > 100);
}
