//! Diff Calculation Engine
//!
//! Tracks field-level changes in state for efficient UI updates.
//! Supports up to 64 top-level fields per state type.

const std = @import("std");

/// Maximum number of fields that can be tracked
pub const MAX_FIELDS: usize = 64;

/// Information about a changed field
pub const FieldChange = struct {
    field_id: u16, // Index of the field in struct
    offset: usize, // Byte offset in struct
    size: usize, // Field size in bytes
};

/// Generic diff calculator for a state type
pub fn Diff(comptime T: type) type {
    const fields = std.meta.fields(T);
    const field_count = fields.len;

    if (field_count > MAX_FIELDS) {
        @compileError("State type has too many fields (max 64)");
    }

    return struct {
        const Self = @This();

        /// Bitmask of changed fields (bit N = field N changed)
        changed_mask: u64,

        /// Array of field change info
        changes: [MAX_FIELDS]FieldChange,

        /// Number of changed fields
        change_count: u8,

        /// State version when diff was calculated
        version: u64,

        /// Initialize empty diff
        pub fn init() Self {
            return .{
                .changed_mask = 0,
                .changes = undefined,
                .change_count = 0,
                .version = 0,
            };
        }

        /// Calculate diff between old and new state
        pub fn calculate(old: *const T, new: *const T, version: u64) Self {
            var diff = Self{
                .changed_mask = 0,
                .changes = undefined,
                .change_count = 0,
                .version = version,
            };

            inline for (fields, 0..) |field, i| {
                const old_value = @field(old.*, field.name);
                const new_value = @field(new.*, field.name);

                if (!fieldEqual(field.type, &old_value, &new_value)) {
                    diff.changed_mask |= (@as(u64, 1) << @intCast(i));
                    diff.changes[diff.change_count] = .{
                        .field_id = @intCast(i),
                        .offset = @offsetOf(T, field.name),
                        .size = @sizeOf(field.type),
                    };
                    diff.change_count += 1;
                }
            }

            return diff;
        }

        /// Check if a specific field changed (by index)
        pub fn hasFieldChanged(self: *const Self, field_id: u16) bool {
            if (field_id >= field_count) return false;
            return (self.changed_mask & (@as(u64, 1) << @intCast(field_id))) != 0;
        }

        /// Check if a specific field changed (by name)
        pub fn hasFieldChangedByName(self: *const Self, comptime field_name: []const u8) bool {
            const field_id = comptime getFieldIndex(field_name);
            return self.hasFieldChanged(field_id);
        }

        /// Check if any field changed
        pub fn hasChanges(self: *const Self) bool {
            return self.changed_mask != 0;
        }

        /// Get number of changed fields
        pub fn getChangeCount(self: *const Self) u8 {
            return self.change_count;
        }

        /// Get changed field info by index
        pub fn getChange(self: *const Self, index: u8) ?FieldChange {
            if (index >= self.change_count) return null;
            return self.changes[index];
        }

        /// Iterator over changed fields
        pub fn changedFields(self: *const Self) ChangedFieldIterator {
            return .{
                .diff = self,
                .index = 0,
            };
        }

        pub const ChangedFieldIterator = struct {
            diff: *const Self,
            index: u8,

            pub fn next(self: *ChangedFieldIterator) ?FieldChange {
                if (self.index >= self.diff.change_count) return null;
                const change = self.diff.changes[self.index];
                self.index += 1;
                return change;
            }
        };

        /// Get field index by name (comptime)
        fn getFieldIndex(comptime name: []const u8) u16 {
            inline for (fields, 0..) |field, i| {
                if (std.mem.eql(u8, field.name, name)) {
                    return @intCast(i);
                }
            }
            @compileError("Field not found: " ++ name);
        }

        /// Get field name by index
        pub fn getFieldName(field_id: u16) ?[]const u8 {
            if (field_id >= field_count) return null;
            inline for (fields, 0..) |field, i| {
                if (i == field_id) return field.name;
            }
            return null;
        }

        /// Get total number of fields in type
        pub fn getFieldCount() usize {
            return field_count;
        }
    };
}

/// Compare two field values for equality
fn fieldEqual(comptime FieldType: type, a: *const FieldType, b: *const FieldType) bool {
    const info = @typeInfo(FieldType);

    switch (info) {
        .array => |arr| {
            // For arrays, compare element by element
            const a_arr: *const [arr.len]arr.child = a;
            const b_arr: *const [arr.len]arr.child = b;
            for (a_arr, b_arr) |av, bv| {
                if (!fieldEqual(arr.child, &av, &bv)) return false;
            }
            return true;
        },
        .@"struct" => {
            // For structs, use meta.eql
            return std.meta.eql(a.*, b.*);
        },
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                // Slices: compare by content
                return std.mem.eql(ptr.child, a.*, b.*);
            } else {
                // Other pointers: compare addresses
                return a.* == b.*;
            }
        },
        .optional => {
            // Optionals: handle null case
            if (a.* == null and b.* == null) return true;
            if (a.* == null or b.* == null) return false;
            return fieldEqual(@typeInfo(FieldType).optional.child, &a.*.?, &b.*.?);
        },
        else => {
            // Primitives: direct comparison
            return a.* == b.*;
        },
    }
}

/// C ABI compatible diff structure
pub const ABIDiff = extern struct {
    changed_mask: u64,
    change_count: u8,
    version: u64,
};

/// Convert generic Diff to ABI-compatible structure
pub fn toABIDiff(comptime T: type, diff: *const Diff(T)) ABIDiff {
    return .{
        .changed_mask = diff.changed_mask,
        .change_count = diff.change_count,
        .version = diff.version,
    };
}

// === Tests ===

test "diff empty - no changes" {
    const TestState = struct {
        a: i32 = 0,
        b: i32 = 0,
    };

    const old = TestState{};
    const new = TestState{};

    const diff = Diff(TestState).calculate(&old, &new, 1);

    try std.testing.expect(!diff.hasChanges());
    try std.testing.expectEqual(@as(u8, 0), diff.getChangeCount());
}

test "diff single field change" {
    const TestState = struct {
        a: i32 = 0,
        b: i32 = 0,
        c: i32 = 0,
    };

    const old = TestState{ .a = 0, .b = 5, .c = 10 };
    const new = TestState{ .a = 0, .b = 99, .c = 10 };

    const diff = Diff(TestState).calculate(&old, &new, 1);

    try std.testing.expect(diff.hasChanges());
    try std.testing.expectEqual(@as(u8, 1), diff.getChangeCount());
    try std.testing.expect(!diff.hasFieldChangedByName("a"));
    try std.testing.expect(diff.hasFieldChangedByName("b"));
    try std.testing.expect(!diff.hasFieldChangedByName("c"));
}

test "diff multiple field changes" {
    const TestState = struct {
        x: i64 = 0,
        y: i64 = 0,
        z: i64 = 0,
    };

    const old = TestState{ .x = 1, .y = 2, .z = 3 };
    const new = TestState{ .x = 10, .y = 2, .z = 30 };

    const diff = Diff(TestState).calculate(&old, &new, 5);

    try std.testing.expectEqual(@as(u8, 2), diff.getChangeCount());
    try std.testing.expect(diff.hasFieldChangedByName("x"));
    try std.testing.expect(!diff.hasFieldChangedByName("y"));
    try std.testing.expect(diff.hasFieldChangedByName("z"));
    try std.testing.expectEqual(@as(u64, 5), diff.version);
}

test "diff array field" {
    const TestState = struct {
        buffer: [8]u8 = [_]u8{0} ** 8,
        count: usize = 0,
    };

    const old = TestState{};
    var new = TestState{};
    new.buffer[0] = 'H';
    new.buffer[1] = 'i';

    const diff = Diff(TestState).calculate(&old, &new, 1);

    try std.testing.expect(diff.hasFieldChangedByName("buffer"));
    try std.testing.expect(!diff.hasFieldChangedByName("count"));
}

test "diff iterator" {
    const TestState = struct {
        a: i32 = 0,
        b: i32 = 0,
        c: i32 = 0,
    };

    const old = TestState{ .a = 1, .b = 2, .c = 3 };
    const new = TestState{ .a = 10, .b = 2, .c = 30 };

    const diff = Diff(TestState).calculate(&old, &new, 1);

    var iter = diff.changedFields();
    var count: u8 = 0;

    while (iter.next()) |change| {
        _ = change;
        count += 1;
    }

    try std.testing.expectEqual(@as(u8, 2), count);
}

test "diff field info" {
    const TestState = struct {
        value: i64 = 0,
        name: [32]u8 = [_]u8{0} ** 32,
    };

    const old = TestState{};
    var new = TestState{};
    new.value = 42;

    const diff = Diff(TestState).calculate(&old, &new, 1);

    const change = diff.getChange(0).?;
    try std.testing.expectEqual(@as(u16, 0), change.field_id);
    try std.testing.expectEqual(@as(usize, 0), change.offset);
    try std.testing.expectEqual(@sizeOf(i64), change.size);
}

test "diff get field name" {
    const TestState = struct {
        alpha: i32 = 0,
        beta: i32 = 0,
    };

    const name0 = Diff(TestState).getFieldName(0);
    const name1 = Diff(TestState).getFieldName(1);
    const name_invalid = Diff(TestState).getFieldName(99);

    try std.testing.expectEqualStrings("alpha", name0.?);
    try std.testing.expectEqualStrings("beta", name1.?);
    try std.testing.expect(name_invalid == null);
}

test "diff ABI conversion" {
    const TestState = struct {
        x: i32 = 0,
    };

    const old = TestState{ .x = 0 };
    const new = TestState{ .x = 1 };

    const diff = Diff(TestState).calculate(&old, &new, 42);
    const abi_diff = toABIDiff(TestState, &diff);

    try std.testing.expectEqual(@as(u64, 1), abi_diff.changed_mask);
    try std.testing.expectEqual(@as(u8, 1), abi_diff.change_count);
    try std.testing.expectEqual(@as(u64, 42), abi_diff.version);
}

test "diff optional field" {
    const TestState = struct {
        value: ?i32 = null,
    };

    const old = TestState{ .value = null };
    const new = TestState{ .value = 42 };

    const diff = Diff(TestState).calculate(&old, &new, 1);

    try std.testing.expect(diff.hasFieldChangedByName("value"));
}
