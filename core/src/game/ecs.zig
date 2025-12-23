//! Entity-Component-System Architecture
//!
//! Provides a flexible ECS implementation for game object management,
//! enabling composition over inheritance and cache-friendly data access.

const std = @import("std");

/// Entity ID type
pub const Entity = u32;

/// Component type ID
pub const ComponentId = u16;

/// Invalid entity constant
pub const INVALID_ENTITY: Entity = 0;

/// Component storage interface
pub const ComponentStorage = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        remove: *const fn (ptr: *anyopaque, entity: Entity) void,
        has: *const fn (ptr: *anyopaque, entity: Entity) bool,
        clear: *const fn (ptr: *anyopaque) void,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn remove(self: ComponentStorage, entity: Entity) void {
        self.vtable.remove(self.ptr, entity);
    }

    pub fn has(self: ComponentStorage, entity: Entity) bool {
        return self.vtable.has(self.ptr, entity);
    }

    pub fn clear(self: ComponentStorage) void {
        self.vtable.clear(self.ptr);
    }

    pub fn deinit(self: ComponentStorage) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Generic component array
pub fn ComponentArray(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        data: std.AutoHashMapUnmanaged(Entity, T) = .{},

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit(self.allocator);
        }

        pub fn insert(self: *Self, entity: Entity, component: T) !void {
            try self.data.put(self.allocator, entity, component);
        }

        pub fn remove(self: *Self, entity: Entity) void {
            _ = self.data.remove(entity);
        }

        pub fn get(self: *Self, entity: Entity) ?*T {
            return self.data.getPtr(entity);
        }

        pub fn getConst(self: *const Self, entity: Entity) ?T {
            return self.data.get(entity);
        }

        pub fn has(self: *const Self, entity: Entity) bool {
            return self.data.contains(entity);
        }

        pub fn clear(self: *Self) void {
            self.data.clearRetainingCapacity();
        }

        pub fn count(self: *const Self) usize {
            return self.data.count();
        }

        pub fn iterator(self: *Self) std.AutoHashMapUnmanaged(Entity, T).Iterator {
            return self.data.iterator();
        }

        // Storage interface
        pub fn storage(self: *Self) ComponentStorage {
            return .{
                .ptr = self,
                .vtable = &.{
                    .remove = removeWrapper,
                    .has = hasWrapper,
                    .clear = clearWrapper,
                    .deinit = deinitWrapper,
                },
            };
        }

        fn removeWrapper(ptr: *anyopaque, entity: Entity) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.remove(entity);
        }

        fn hasWrapper(ptr: *anyopaque, entity: Entity) bool {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.has(entity);
        }

        fn clearWrapper(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.clear();
        }

        fn deinitWrapper(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.deinit();
        }
    };
}

/// System function type
pub const SystemFn = *const fn (*World, f32) void;

/// System registration
pub const System = struct {
    name: []const u8,
    update_fn: SystemFn,
    priority: i32 = 0,
    enabled: bool = true,
};

/// Component trait marker
pub const Component = struct {
    /// Generate stable type ID using hash of type name
    pub fn getId(comptime T: type) ComponentId {
        const type_name = @typeName(T);
        return @truncate(std.hash.Fnv1a_64.hash(type_name));
    }
};

/// ECS World - manages entities, components, and systems
pub const World = struct {
    allocator: std.mem.Allocator,

    // Entity management
    entities: std.ArrayListUnmanaged(Entity) = .{},
    entity_generations: std.AutoHashMapUnmanaged(Entity, u32) = .{},
    free_entities: std.ArrayListUnmanaged(Entity) = .{},
    next_entity: Entity = 1,

    // Component storage
    component_storages: std.AutoHashMapUnmanaged(ComponentId, ComponentStorage) = .{},

    // Systems
    systems: std.ArrayListUnmanaged(System) = .{},
    systems_sorted: bool = true,

    // Event queue (simple implementation)
    events: std.ArrayListUnmanaged(Event) = .{},

    pub fn init(allocator: std.mem.Allocator) World {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *World) void {
        // Deinit all component storages
        var iter = self.component_storages.valueIterator();
        while (iter.next()) |storage| {
            storage.deinit();
        }
        self.component_storages.deinit(self.allocator);

        self.entities.deinit(self.allocator);
        self.entity_generations.deinit(self.allocator);
        self.free_entities.deinit(self.allocator);
        self.systems.deinit(self.allocator);
        self.events.deinit(self.allocator);
    }

    /// Create a new entity
    pub fn createEntity(self: *World) !Entity {
        var entity: Entity = undefined;

        if (self.free_entities.items.len > 0) {
            entity = self.free_entities.pop();
            const gen = self.entity_generations.get(entity) orelse 0;
            try self.entity_generations.put(self.allocator, entity, gen + 1);
        } else {
            entity = self.next_entity;
            self.next_entity += 1;
            try self.entity_generations.put(self.allocator, entity, 0);
        }

        try self.entities.append(self.allocator, entity);
        return entity;
    }

    /// Destroy an entity and all its components
    pub fn destroyEntity(self: *World, entity: Entity) void {
        // Remove from entities list
        for (self.entities.items, 0..) |e, i| {
            if (e == entity) {
                _ = self.entities.swapRemove(i);
                break;
            }
        }

        // Remove all components
        var iter = self.component_storages.valueIterator();
        while (iter.next()) |storage| {
            storage.remove(entity);
        }

        // Add to free list - log warning if allocation fails
        self.free_entities.append(self.allocator, entity) catch {
            std.log.warn("ECS: Failed to add entity {} to free list - ID may not be recycled", .{entity});
        };
    }

    /// Check if entity is valid
    pub fn isEntityValid(self: *const World, entity: Entity) bool {
        if (entity == INVALID_ENTITY) return false;
        for (self.entities.items) |e| {
            if (e == entity) return true;
        }
        return false;
    }

    /// Get entity count
    pub fn entityCount(self: *const World) usize {
        return self.entities.items.len;
    }

    /// Register a component type
    pub fn registerComponent(self: *World, comptime T: type) !*ComponentArray(T) {
        const id = Component.getId(T);

        if (self.component_storages.contains(id)) {
            return error.ComponentAlreadyRegistered;
        }

        const array = try self.allocator.create(ComponentArray(T));
        array.* = ComponentArray(T).init(self.allocator);

        try self.component_storages.put(self.allocator, id, array.storage());

        return array;
    }

    /// Get component storage for a type
    pub fn getComponentStorage(self: *World, comptime T: type) ?*ComponentArray(T) {
        const id = Component.getId(T);
        if (self.component_storages.get(id)) |storage| {
            return @ptrCast(@alignCast(storage.ptr));
        }
        return null;
    }

    /// Add component to entity
    pub fn addComponent(self: *World, entity: Entity, comptime T: type, component: T) !void {
        if (!self.isEntityValid(entity)) return error.InvalidEntity;

        var storage = self.getComponentStorage(T);
        if (storage == null) {
            storage = try self.registerComponent(T);
        }

        try storage.?.insert(entity, component);
    }

    /// Remove component from entity
    pub fn removeComponent(self: *World, entity: Entity, comptime T: type) void {
        if (self.getComponentStorage(T)) |storage| {
            storage.remove(entity);
        }
    }

    /// Get component from entity
    pub fn getComponent(self: *World, entity: Entity, comptime T: type) ?*T {
        if (self.getComponentStorage(T)) |storage| {
            return storage.get(entity);
        }
        return null;
    }

    /// Check if entity has component
    pub fn hasComponent(self: *const World, entity: Entity, comptime T: type) bool {
        const id = Component.getId(T);
        if (self.component_storages.get(id)) |storage| {
            return storage.has(entity);
        }
        return false;
    }

    /// Register a system
    pub fn registerSystem(self: *World, system: System) !void {
        try self.systems.append(self.allocator, system);
        self.systems_sorted = false;
    }

    /// Update all systems
    pub fn update(self: *World, delta_time: f32) void {
        // Sort systems by priority if needed
        if (!self.systems_sorted) {
            std.mem.sort(System, self.systems.items, {}, struct {
                fn lessThan(_: void, a: System, b: System) bool {
                    return a.priority < b.priority;
                }
            }.lessThan);
            self.systems_sorted = true;
        }

        // Run all enabled systems
        for (self.systems.items) |system| {
            if (system.enabled) {
                system.update_fn(self, delta_time);
            }
        }

        // Clear events
        self.events.clearRetainingCapacity();
    }

    /// Enable/disable a system
    pub fn setSystemEnabled(self: *World, name: []const u8, enabled: bool) void {
        for (self.systems.items) |*system| {
            if (std.mem.eql(u8, system.name, name)) {
                system.enabled = enabled;
                break;
            }
        }
    }

    /// Emit an event
    pub fn emitEvent(self: *World, event: Event) !void {
        try self.events.append(self.allocator, event);
    }

    /// Get all entities with specific components
    pub fn query(self: *World, comptime T: type) QueryIterator(T) {
        return QueryIterator(T).init(self);
    }

    /// Clear all entities and components
    pub fn clear(self: *World) void {
        self.entities.clearRetainingCapacity();
        self.free_entities.clearRetainingCapacity();
        self.entity_generations.clearRetainingCapacity();
        self.next_entity = 1;

        var iter = self.component_storages.valueIterator();
        while (iter.next()) |storage| {
            storage.clear();
        }
    }
};

/// Query iterator for entities with specific component
pub fn QueryIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        world: *World,
        entity_index: usize = 0,

        pub fn init(world: *World) Self {
            return .{ .world = world };
        }

        pub fn next(self: *Self) ?struct { entity: Entity, component: *T } {
            while (self.entity_index < self.world.entities.items.len) {
                const entity = self.world.entities.items[self.entity_index];
                self.entity_index += 1;

                if (self.world.getComponent(entity, T)) |component| {
                    return .{ .entity = entity, .component = component };
                }
            }
            return null;
        }

        pub fn reset(self: *Self) void {
            self.entity_index = 0;
        }
    };
}

/// Simple event type
pub const Event = struct {
    type_id: u32,
    data: [64]u8 = undefined,
    data_len: usize = 0,

    pub const EventError = error{EventDataTooLarge};

    pub fn create(comptime T: type, value: T) EventError!Event {
        if (@sizeOf(T) > 64) {
            return error.EventDataTooLarge;
        }

        var event = Event{
            .type_id = @truncate(std.hash.Fnv1a_64.hash(@typeName(T))),
        };

        @memcpy(event.data[0..@sizeOf(T)], std.mem.asBytes(&value));
        event.data_len = @sizeOf(T);

        return event;
    }

    pub fn getData(self: *const Event, comptime T: type) ?T {
        if (self.data_len != @sizeOf(T)) return null;
        return std.mem.bytesToValue(T, self.data[0..@sizeOf(T)]);
    }
};

// Common component types
pub const Transform = struct {
    x: f32 = 0,
    y: f32 = 0,
    rotation: f32 = 0,
    scale_x: f32 = 1,
    scale_y: f32 = 1,
};

pub const Velocity = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub const Renderable = struct {
    texture_id: u32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    visible: bool = true,
    layer: i32 = 0,
};

pub const Collider2D = struct {
    width: f32 = 0,
    height: f32 = 0,
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    is_trigger: bool = false,
};

pub const Tag = struct {
    value: []const u8 = "",
};

test "World create and destroy entities" {
    const allocator = std.testing.allocator;
    var world = World.init(allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();

    try std.testing.expectEqual(@as(usize, 2), world.entityCount());

    world.destroyEntity(e1);
    try std.testing.expectEqual(@as(usize, 1), world.entityCount());

    try std.testing.expect(!world.isEntityValid(e1));
    try std.testing.expect(world.isEntityValid(e2));
}

test "World add and get components" {
    const allocator = std.testing.allocator;
    var world = World.init(allocator);
    defer world.deinit();

    const entity = try world.createEntity();

    try world.addComponent(entity, Transform, .{ .x = 100, .y = 200 });
    try world.addComponent(entity, Velocity, .{ .x = 5, .y = -3 });

    const transform = world.getComponent(entity, Transform);
    try std.testing.expect(transform != null);
    try std.testing.expectEqual(@as(f32, 100), transform.?.x);

    try std.testing.expect(world.hasComponent(entity, Transform));
    try std.testing.expect(world.hasComponent(entity, Velocity));
}

test "World query" {
    const allocator = std.testing.allocator;
    var world = World.init(allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, Transform, .{ .x = 1 });
    try world.addComponent(e2, Transform, .{ .x = 2 });
    // e3 has no Transform

    _ = e3;

    var query = world.query(Transform);
    var count: usize = 0;

    while (query.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 2), count);
}

test "Event system" {
    const TestEvent = struct { value: i32 };

    const event = try Event.create(TestEvent, .{ .value = 42 });
    const data = event.getData(TestEvent);

    try std.testing.expect(data != null);
    try std.testing.expectEqual(@as(i32, 42), data.?.value);
}
