//! Generic State Store Module
//!
//! Provides a type-safe, generic state container with version tracking
//! and change detection capabilities.

const std = @import("std");

/// Generic store with change tracking
pub fn Store(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Current state
        state: T,

        /// Previous state (for diff calculation)
        prev_state: T,

        /// State version (monotonically increasing)
        version: u64,

        /// Whether state has changed since last commit
        dirty: bool,

        /// Initialize store with initial state
        pub fn init(initial: T) Self {
            return .{
                .state = initial,
                .prev_state = initial,
                .version = 0,
                .dirty = false,
            };
        }

        /// Get current state (read-only)
        pub fn getState(self: *const Self) *const T {
            return &self.state;
        }

        /// Get mutable state (internal use)
        pub fn getStateMut(self: *Self) *T {
            return &self.state;
        }

        /// Get previous state (for diff calculation)
        pub fn getPrevState(self: *const Self) *const T {
            return &self.prev_state;
        }

        /// Get current version
        pub fn getVersion(self: *const Self) u64 {
            return self.version;
        }

        /// Check if state has uncommitted changes
        pub fn isDirty(self: *const Self) bool {
            return self.dirty;
        }

        /// Update state using a mutator function
        pub fn update(self: *Self, mutator: *const fn (*T) void) void {
            mutator(&self.state);
            self.dirty = true;
        }

        /// Update state using a mutator with context
        pub fn updateWithContext(
            self: *Self,
            comptime Context: type,
            ctx: Context,
            mutator: *const fn (*T, Context) void,
        ) void {
            mutator(&self.state, ctx);
            self.dirty = true;
        }

        /// Commit changes: save current state as prev, bump version
        pub fn commit(self: *Self) void {
            if (self.dirty) {
                self.prev_state = self.state;
                self.version +%= 1;
                self.dirty = false;
            }
        }

        /// Update and commit in one operation
        pub fn updateAndCommit(self: *Self, mutator: *const fn (*T) void) void {
            self.update(mutator);
            self.commit();
        }

        /// Reset state to initial value
        pub fn reset(self: *Self, initial: T) void {
            self.prev_state = self.state;
            self.state = initial;
            self.version +%= 1;
            self.dirty = false;
        }

        /// Check if a specific field has changed
        pub fn hasFieldChanged(self: *const Self, comptime field_name: []const u8) bool {
            const old = @field(self.prev_state, field_name);
            const new = @field(self.state, field_name);
            return !std.meta.eql(old, new);
        }

        /// Get size of state type
        pub fn getStateSize() usize {
            return @sizeOf(T);
        }

        /// Get view data pointer (for C ABI)
        pub fn getViewData(self: *const Self) ?*const anyopaque {
            return @ptrCast(&self.state);
        }

        /// Get view data size (for C ABI)
        pub fn getViewDataSize() usize {
            return @sizeOf(T);
        }
    };
}

/// Type-erased store interface for C ABI
pub const StoreInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        getVersion: *const fn (*anyopaque) u64,
        getViewData: *const fn (*anyopaque) ?*const anyopaque,
        getViewDataSize: *const fn () usize,
        commit: *const fn (*anyopaque) void,
        isDirty: *const fn (*anyopaque) bool,
    };

    pub fn getVersion(self: StoreInterface) u64 {
        return self.vtable.getVersion(self.ptr);
    }

    pub fn getViewData(self: StoreInterface) ?*const anyopaque {
        return self.vtable.getViewData(self.ptr);
    }

    pub fn getViewDataSize(self: StoreInterface) usize {
        return self.vtable.getViewDataSize();
    }

    pub fn commit(self: StoreInterface) void {
        self.vtable.commit(self.ptr);
    }

    pub fn isDirty(self: StoreInterface) bool {
        return self.vtable.isDirty(self.ptr);
    }
};

/// Create a type-erased interface from a concrete store
pub fn makeInterface(comptime T: type, store: *Store(T)) StoreInterface {
    const Impl = struct {
        fn getVersion(ptr: *anyopaque) u64 {
            const self: *Store(T) = @ptrCast(@alignCast(ptr));
            return self.getVersion();
        }

        fn getViewData(ptr: *anyopaque) ?*const anyopaque {
            const self: *Store(T) = @ptrCast(@alignCast(ptr));
            return self.getViewData();
        }

        fn getViewDataSize() usize {
            return Store(T).getViewDataSize();
        }

        fn commit(ptr: *anyopaque) void {
            const self: *Store(T) = @ptrCast(@alignCast(ptr));
            self.commit();
        }

        fn isDirty(ptr: *anyopaque) bool {
            const self: *Store(T) = @ptrCast(@alignCast(ptr));
            return self.isDirty();
        }
    };

    const vtable = &StoreInterface.VTable{
        .getVersion = Impl.getVersion,
        .getViewData = Impl.getViewData,
        .getViewDataSize = Impl.getViewDataSize,
        .commit = Impl.commit,
        .isDirty = Impl.isDirty,
    };

    return .{
        .ptr = @ptrCast(store),
        .vtable = vtable,
    };
}

// === Tests ===

test "store initialization" {
    const TestState = struct {
        counter: i64 = 0,
        name: [32]u8 = [_]u8{0} ** 32,
    };

    var store = Store(TestState).init(.{});

    try std.testing.expectEqual(@as(u64, 0), store.getVersion());
    try std.testing.expectEqual(@as(i64, 0), store.getState().counter);
    try std.testing.expect(!store.isDirty());
}

test "store update and commit" {
    const TestState = struct {
        counter: i64 = 0,
    };

    var store = Store(TestState).init(.{});

    const increment = struct {
        fn f(state: *TestState) void {
            state.counter += 1;
        }
    }.f;

    store.update(&increment);
    try std.testing.expect(store.isDirty());
    try std.testing.expectEqual(@as(i64, 1), store.getState().counter);
    try std.testing.expectEqual(@as(u64, 0), store.getVersion()); // Not committed yet

    store.commit();
    try std.testing.expect(!store.isDirty());
    try std.testing.expectEqual(@as(u64, 1), store.getVersion());
}

test "store updateAndCommit" {
    const TestState = struct {
        value: i32 = 0,
    };

    var store = Store(TestState).init(.{});

    const setValue = struct {
        fn f(state: *TestState) void {
            state.value = 42;
        }
    }.f;

    store.updateAndCommit(&setValue);
    try std.testing.expectEqual(@as(i32, 42), store.getState().value);
    try std.testing.expectEqual(@as(u64, 1), store.getVersion());
    try std.testing.expect(!store.isDirty());
}

test "store field change detection" {
    const TestState = struct {
        a: i32 = 0,
        b: i32 = 0,
    };

    var store = Store(TestState).init(.{});

    // Modify only field 'a'
    store.getStateMut().a = 10;
    store.dirty = true;

    try std.testing.expect(store.hasFieldChanged("a"));
    try std.testing.expect(!store.hasFieldChanged("b"));
}

test "store reset" {
    const TestState = struct {
        counter: i64 = 0,
    };

    var store = Store(TestState).init(.{});

    // Use update to properly set dirty flag
    const setValue = struct {
        fn f(state: *TestState) void {
            state.counter = 100;
        }
    }.f;
    store.updateAndCommit(&setValue); // version = 1

    store.reset(.{ .counter = 0 }); // version = 2

    try std.testing.expectEqual(@as(i64, 0), store.getState().counter);
    try std.testing.expectEqual(@as(u64, 2), store.getVersion());
}

test "store view data for ABI" {
    const TestState = struct {
        x: i64 = 123,
    };

    var store = Store(TestState).init(.{ .x = 456 });

    const view_data = store.getViewData();
    try std.testing.expect(view_data != null);

    const state_ptr: *const TestState = @ptrCast(@alignCast(view_data.?));
    try std.testing.expectEqual(@as(i64, 456), state_ptr.x);

    try std.testing.expectEqual(@sizeOf(TestState), Store(TestState).getViewDataSize());
}

test "store interface type erasure" {
    const TestState = struct {
        value: i32 = 0,
    };

    var store = Store(TestState).init(.{ .value = 99 });
    const iface = makeInterface(TestState, &store);

    try std.testing.expectEqual(@as(u64, 0), iface.getVersion());
    try std.testing.expect(!iface.isDirty());

    store.getStateMut().value = 100;
    store.dirty = true;
    iface.commit();

    try std.testing.expectEqual(@as(u64, 1), iface.getVersion());
}
