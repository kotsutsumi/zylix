//! Save/Load System
//!
//! Provides game state persistence with serialization, compression,
//! versioning, and multiple save slot support.

const std = @import("std");

/// Save file format version
pub const SAVE_VERSION: u32 = 1;

/// Save file magic number for validation
pub const SAVE_MAGIC: [4]u8 = .{ 'Z', 'Y', 'L', 'X' };

/// Maximum save slots
pub const MAX_SAVE_SLOTS: usize = 10;

/// Save file header
pub const SaveHeader = struct {
    magic: [4]u8 = SAVE_MAGIC,
    version: u32 = SAVE_VERSION,
    timestamp: i64 = 0,
    checksum: u32 = 0,
    data_size: u32 = 0,
    compressed: bool = false,
    slot_id: u8 = 0,
    name: [64]u8 = [_]u8{0} ** 64,
    play_time: u64 = 0, // in seconds

    pub fn setName(self: *SaveHeader, name: []const u8) void {
        const len = @min(name.len, 63);
        @memcpy(self.name[0..len], name[0..len]);
        self.name[len] = 0;
    }

    pub fn getName(self: *const SaveHeader) []const u8 {
        var len: usize = 0;
        while (len < 64 and self.name[len] != 0) : (len += 1) {}
        return self.name[0..len];
    }

    pub fn isValid(self: *const SaveHeader) bool {
        return std.mem.eql(u8, &self.magic, &SAVE_MAGIC);
    }
};

/// Serializable value types
pub const ValueType = enum(u8) {
    nil = 0,
    bool_type = 1,
    int = 2,
    float = 3,
    string = 4,
    array = 5,
    map = 6,
};

/// Serialized value for flexible data storage
pub const Value = union(ValueType) {
    nil: void,
    bool_type: bool,
    int: i64,
    float: f64,
    string: []const u8,
    array: []const Value,
    map: std.StringHashMapUnmanaged(Value),

    pub fn boolean(b: bool) Value {
        return .{ .bool_type = b };
    }

    pub fn integer(i: i64) Value {
        return .{ .int = i };
    }

    pub fn number(f: f64) Value {
        return .{ .float = f };
    }

    /// Free all memory associated with this value
    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| {
                // Only free if it's an owned slice (from deserialization)
                if (s.len > 0) {
                    allocator.free(s);
                }
            },
            .array => |arr| {
                for (arr) |*item| {
                    var mutable_item = item.*;
                    mutable_item.deinit(allocator);
                }
                if (arr.len > 0) {
                    allocator.free(arr);
                }
            },
            .map => |*m| {
                var iter = m.iterator();
                while (iter.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    var mutable_val = entry.value_ptr.*;
                    mutable_val.deinit(allocator);
                }
                m.deinit(allocator);
            },
            else => {},
        }
    }
};

/// Save slot metadata
pub const SaveSlot = struct {
    id: u8,
    occupied: bool = false,
    header: SaveHeader = .{},
    path: [256]u8 = [_]u8{0} ** 256,

    pub fn getPath(self: *const SaveSlot) []const u8 {
        var len: usize = 0;
        while (len < 256 and self.path[len] != 0) : (len += 1) {}
        return self.path[0..len];
    }

    pub fn setPath(self: *SaveSlot, path: []const u8) void {
        const len = @min(path.len, 255);
        @memcpy(self.path[0..len], path[0..len]);
        self.path[len] = 0;
    }
};

/// Serialization context
pub const SerializeContext = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8) = .{},

    pub fn init(allocator: std.mem.Allocator) SerializeContext {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SerializeContext) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn reset(self: *SerializeContext) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn writeByte(self: *SerializeContext, byte: u8) !void {
        try self.buffer.append(self.allocator, byte);
    }

    pub fn writeBytes(self: *SerializeContext, bytes: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, bytes);
    }

    pub fn writeU16(self: *SerializeContext, value: u16) !void {
        try self.writeBytes(&std.mem.toBytes(std.mem.nativeToLittle(u16, value)));
    }

    pub fn writeU32(self: *SerializeContext, value: u32) !void {
        try self.writeBytes(&std.mem.toBytes(std.mem.nativeToLittle(u32, value)));
    }

    pub fn writeU64(self: *SerializeContext, value: u64) !void {
        try self.writeBytes(&std.mem.toBytes(std.mem.nativeToLittle(u64, value)));
    }

    pub fn writeI64(self: *SerializeContext, value: i64) !void {
        try self.writeBytes(&std.mem.toBytes(std.mem.nativeToLittle(i64, value)));
    }

    pub fn writeF32(self: *SerializeContext, value: f32) !void {
        try self.writeBytes(&std.mem.toBytes(value));
    }

    pub fn writeF64(self: *SerializeContext, value: f64) !void {
        try self.writeBytes(&std.mem.toBytes(value));
    }

    pub fn writeString(self: *SerializeContext, str: []const u8) !void {
        try self.writeU32(@intCast(str.len));
        try self.writeBytes(str);
    }

    pub fn getData(self: *const SerializeContext) []const u8 {
        return self.buffer.items;
    }
};

/// Deserialization context
pub const DeserializeContext = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn init(data: []const u8) DeserializeContext {
        return .{ .data = data };
    }

    pub fn readByte(self: *DeserializeContext) !u8 {
        if (self.pos >= self.data.len) return error.EndOfData;
        const byte = self.data[self.pos];
        self.pos += 1;
        return byte;
    }

    pub fn readBytes(self: *DeserializeContext, len: usize) ![]const u8 {
        if (self.pos + len > self.data.len) return error.EndOfData;
        const bytes = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return bytes;
    }

    pub fn readU16(self: *DeserializeContext) !u16 {
        const bytes = try self.readBytes(2);
        return std.mem.littleToNative(u16, std.mem.bytesToValue(u16, bytes[0..2]));
    }

    pub fn readU32(self: *DeserializeContext) !u32 {
        const bytes = try self.readBytes(4);
        return std.mem.littleToNative(u32, std.mem.bytesToValue(u32, bytes[0..4]));
    }

    pub fn readU64(self: *DeserializeContext) !u64 {
        const bytes = try self.readBytes(8);
        return std.mem.littleToNative(u64, std.mem.bytesToValue(u64, bytes[0..8]));
    }

    pub fn readI64(self: *DeserializeContext) !i64 {
        const bytes = try self.readBytes(8);
        return std.mem.littleToNative(i64, std.mem.bytesToValue(i64, bytes[0..8]));
    }

    pub fn readF32(self: *DeserializeContext) !f32 {
        const bytes = try self.readBytes(4);
        return std.mem.bytesToValue(f32, bytes[0..4]);
    }

    pub fn readF64(self: *DeserializeContext) !f64 {
        const bytes = try self.readBytes(8);
        return std.mem.bytesToValue(f64, bytes[0..8]);
    }

    pub fn readString(self: *DeserializeContext, allocator: std.mem.Allocator) ![]u8 {
        const len = try self.readU32();
        const bytes = try self.readBytes(len);
        const str = try allocator.alloc(u8, len);
        @memcpy(str, bytes);
        return str;
    }

    pub fn remaining(self: *const DeserializeContext) usize {
        return self.data.len - self.pos;
    }
};

/// Serializable trait
pub fn Serializable(comptime T: type) type {
    return struct {
        pub fn serialize(value: *const T, ctx: *SerializeContext) !void {
            const bytes = std.mem.asBytes(value);
            try ctx.writeBytes(bytes);
        }

        pub fn deserialize(ctx: *DeserializeContext) !T {
            const bytes = try ctx.readBytes(@sizeOf(T));
            return std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]);
        }
    };
}

/// Save manager
pub const SaveManager = struct {
    allocator: std.mem.Allocator,
    save_dir: [256]u8 = [_]u8{0} ** 256,
    slots: [MAX_SAVE_SLOTS]SaveSlot = undefined,
    auto_save_enabled: bool = true,
    auto_save_interval: u64 = 300, // 5 minutes

    // Callbacks
    on_save: ?*const fn (slot: u8) void = null,
    on_load: ?*const fn (slot: u8) void = null,
    on_error: ?*const fn (err: anyerror) void = null,

    pub fn init(allocator: std.mem.Allocator, save_dir: []const u8) SaveManager {
        var manager = SaveManager{
            .allocator = allocator,
        };

        // Set save directory
        const len = @min(save_dir.len, 255);
        @memcpy(manager.save_dir[0..len], save_dir[0..len]);
        manager.save_dir[len] = 0;

        // Initialize slots
        for (0..MAX_SAVE_SLOTS) |i| {
            manager.slots[i] = .{
                .id = @intCast(i),
            };
        }

        return manager;
    }

    pub fn deinit(self: *SaveManager) void {
        _ = self;
    }

    fn getSaveDir(self: *const SaveManager) []const u8 {
        var len: usize = 0;
        while (len < 256 and self.save_dir[len] != 0) : (len += 1) {}
        return self.save_dir[0..len];
    }

    /// Scan for existing save files
    pub fn scanSaves(self: *SaveManager) !void {
        const dir_path = self.getSaveDir();

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
            // Directory doesn't exist yet
            return;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                // Check if it's a save file
                if (std.mem.endsWith(u8, entry.name, ".sav")) {
                    // Parse slot number from filename
                    if (std.fmt.parseInt(u8, entry.name[0 .. entry.name.len - 4], 10)) |slot_id| {
                        if (slot_id < MAX_SAVE_SLOTS) {
                            try self.loadSlotHeader(slot_id);
                        }
                    } else |_| {}
                }
            }
        }
    }

    /// Load just the header for a slot
    fn loadSlotHeader(self: *SaveManager, slot_id: u8) !void {
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/{d}.sav", .{ self.getSaveDir(), slot_id });

        var file = std.fs.cwd().openFile(path, .{}) catch {
            return;
        };
        defer file.close();

        var header: SaveHeader = undefined;
        const bytes_read = try file.read(std.mem.asBytes(&header));
        if (bytes_read < @sizeOf(SaveHeader)) return error.InvalidSaveFile;

        if (!header.isValid()) return error.InvalidSaveFile;

        self.slots[slot_id].occupied = true;
        self.slots[slot_id].header = header;
        self.slots[slot_id].setPath(path);
    }

    /// Save game data to a slot
    pub fn save(self: *SaveManager, slot_id: u8, name: []const u8, data: []const u8) !void {
        if (slot_id >= MAX_SAVE_SLOTS) return error.InvalidSlot;

        // Create save directory if needed
        std.fs.cwd().makeDir(self.getSaveDir()) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Build path
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/{d}.sav", .{ self.getSaveDir(), slot_id });

        // Create header
        var header = SaveHeader{
            .timestamp = std.time.timestamp(),
            .data_size = @intCast(data.len),
            .slot_id = slot_id,
        };
        header.setName(name);
        header.checksum = calculateChecksum(data);

        // Write file
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(std.mem.asBytes(&header));
        try file.writeAll(data);

        // Update slot
        self.slots[slot_id].occupied = true;
        self.slots[slot_id].header = header;
        self.slots[slot_id].setPath(path);

        if (self.on_save) |callback| {
            callback(slot_id);
        }
    }

    /// Load game data from a slot
    pub fn load(self: *SaveManager, slot_id: u8) ![]u8 {
        if (slot_id >= MAX_SAVE_SLOTS) return error.InvalidSlot;
        if (!self.slots[slot_id].occupied) return error.EmptySlot;

        const path = self.slots[slot_id].getPath();

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        // Read header
        var header: SaveHeader = undefined;
        _ = try file.read(std.mem.asBytes(&header));

        if (!header.isValid()) return error.InvalidSaveFile;

        // Read data
        const data = try self.allocator.alloc(u8, header.data_size);
        errdefer self.allocator.free(data);

        const bytes_read = try file.read(data);
        if (bytes_read != header.data_size) return error.CorruptedSaveFile;

        // Verify checksum
        if (calculateChecksum(data) != header.checksum) {
            return error.ChecksumMismatch;
        }

        if (self.on_load) |callback| {
            callback(slot_id);
        }

        return data;
    }

    /// Delete a save slot
    pub fn delete(self: *SaveManager, slot_id: u8) !void {
        if (slot_id >= MAX_SAVE_SLOTS) return error.InvalidSlot;
        if (!self.slots[slot_id].occupied) return;

        const path = self.slots[slot_id].getPath();
        std.fs.cwd().deleteFile(path) catch {};

        self.slots[slot_id].occupied = false;
        self.slots[slot_id].header = .{};
    }

    /// Get slot info
    pub fn getSlot(self: *const SaveManager, slot_id: u8) ?*const SaveSlot {
        if (slot_id >= MAX_SAVE_SLOTS) return null;
        return &self.slots[slot_id];
    }

    /// Get all occupied slots
    pub fn getOccupiedSlots(self: *const SaveManager) []const SaveSlot {
        var count: usize = 0;
        for (self.slots) |slot| {
            if (slot.occupied) count += 1;
        }

        // Return all slots, caller can filter by occupied
        return &self.slots;
    }

    /// Find first empty slot
    pub fn findEmptySlot(self: *const SaveManager) ?u8 {
        for (self.slots, 0..) |slot, i| {
            if (!slot.occupied) return @intCast(i);
        }
        return null;
    }

    /// Check if slot is occupied
    pub fn isSlotOccupied(self: *const SaveManager, slot_id: u8) bool {
        if (slot_id >= MAX_SAVE_SLOTS) return false;
        return self.slots[slot_id].occupied;
    }
};

/// Calculate checksum for data integrity
pub fn calculateChecksum(data: []const u8) u32 {
    // Simple CRC32-like checksum
    var crc: u32 = 0xFFFFFFFF;

    for (data) |byte| {
        crc ^= byte;
        for (0..8) |_| {
            if (crc & 1 != 0) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc >>= 1;
            }
        }
    }

    return ~crc;
}

/// Game state container
pub const GameState = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMapUnmanaged(Value) = .{},

    pub fn init(allocator: std.mem.Allocator) GameState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *GameState) void {
        // Free all stored values first
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            // Free the key (if it was allocated)
            self.allocator.free(entry.key_ptr.*);
            // Free the value
            var val = entry.value_ptr.*;
            val.deinit(self.allocator);
        }
        self.data.deinit(self.allocator);
    }

    pub fn set(self: *GameState, key: []const u8, value: Value) !void {
        try self.data.put(self.allocator, key, value);
    }

    pub fn get(self: *const GameState, key: []const u8) ?Value {
        return self.data.get(key);
    }

    pub fn remove(self: *GameState, key: []const u8) void {
        if (self.data.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            var val = kv.value;
            val.deinit(self.allocator);
        }
    }

    pub fn clear(self: *GameState) void {
        // Free all values before clearing
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var val = entry.value_ptr.*;
            val.deinit(self.allocator);
        }
        self.data.clearRetainingCapacity();
    }

    /// Serialize to binary
    pub fn serialize(self: *const GameState, ctx: *SerializeContext) !void {
        try ctx.writeU32(@intCast(self.data.count()));

        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            try ctx.writeString(entry.key_ptr.*);
            try serializeValue(entry.value_ptr.*, ctx);
        }
    }

    /// Deserialize from binary
    pub fn deserialize(self: *GameState, ctx: *DeserializeContext) !void {
        self.clear();

        const count = try ctx.readU32();

        for (0..count) |_| {
            const key = try ctx.readString(self.allocator);
            const value = try deserializeValue(ctx, self.allocator);
            try self.data.put(self.allocator, key, value);
        }
    }
};

fn serializeValue(value: Value, ctx: *SerializeContext) !void {
    try ctx.writeByte(@intFromEnum(value));

    switch (value) {
        .nil => {},
        .bool_type => |b| try ctx.writeByte(if (b) 1 else 0),
        .int => |i| try ctx.writeI64(i),
        .float => |f| try ctx.writeF64(f),
        .string => |s| try ctx.writeString(s),
        .array => |arr| {
            try ctx.writeU32(@intCast(arr.len));
            for (arr) |item| {
                try serializeValue(item, ctx);
            }
        },
        .map => |m| {
            try ctx.writeU32(@intCast(m.count()));
            var iter = m.iterator();
            while (iter.next()) |entry| {
                try ctx.writeString(entry.key_ptr.*);
                try serializeValue(entry.value_ptr.*, ctx);
            }
        },
    }
}

fn deserializeValue(ctx: *DeserializeContext, allocator: std.mem.Allocator) !Value {
    const type_byte = try ctx.readByte();
    const value_type: ValueType = @enumFromInt(type_byte);

    return switch (value_type) {
        .nil => .{ .nil = {} },
        .bool_type => .{ .bool_type = (try ctx.readByte()) != 0 },
        .int => .{ .int = try ctx.readI64() },
        .float => .{ .float = try ctx.readF64() },
        .string => .{ .string = try ctx.readString(allocator) },
        .array => {
            const count = try ctx.readU32();
            const arr = try allocator.alloc(Value, count);
            for (0..count) |i| {
                arr[i] = try deserializeValue(ctx, allocator);
            }
            return .{ .array = arr };
        },
        .map => {
            var m = std.StringHashMapUnmanaged(Value){};
            const count = try ctx.readU32();
            for (0..count) |_| {
                const key = try ctx.readString(allocator);
                const val = try deserializeValue(ctx, allocator);
                try m.put(allocator, key, val);
            }
            return .{ .map = m };
        },
    };
}

/// Quick save/load functions
pub fn quickSave(allocator: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var header = SaveHeader{
        .timestamp = std.time.timestamp(),
        .data_size = @intCast(data.len),
        .checksum = calculateChecksum(data),
    };

    try file.writeAll(std.mem.asBytes(&header));
    try file.writeAll(data);
    _ = allocator;
}

pub fn quickLoad(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var header: SaveHeader = undefined;
    _ = try file.read(std.mem.asBytes(&header));

    if (!header.isValid()) return error.InvalidSaveFile;

    const data = try allocator.alloc(u8, header.data_size);
    errdefer allocator.free(data);

    const bytes_read = try file.read(data);
    if (bytes_read != header.data_size) return error.CorruptedSaveFile;

    if (calculateChecksum(data) != header.checksum) {
        return error.ChecksumMismatch;
    }

    return data;
}

test "SerializeContext basic" {
    const allocator = std.testing.allocator;

    var ctx = SerializeContext.init(allocator);
    defer ctx.deinit();

    try ctx.writeByte(0x42);
    try ctx.writeU32(12345);
    try ctx.writeString("hello");

    const data = ctx.getData();
    try std.testing.expect(data.len > 0);
}

test "DeserializeContext basic" {
    const allocator = std.testing.allocator;

    // Create test data
    var ctx = SerializeContext.init(allocator);
    defer ctx.deinit();

    try ctx.writeByte(0x42);
    try ctx.writeU32(12345);
    try ctx.writeString("hello");

    // Deserialize
    var dctx = DeserializeContext.init(ctx.getData());

    try std.testing.expectEqual(@as(u8, 0x42), try dctx.readByte());
    try std.testing.expectEqual(@as(u32, 12345), try dctx.readU32());

    const str = try dctx.readString(allocator);
    defer allocator.free(str);
    try std.testing.expectEqualStrings("hello", str);
}

test "calculateChecksum" {
    const data1 = "hello world";
    const data2 = "hello world!";

    const crc1 = calculateChecksum(data1);
    const crc2 = calculateChecksum(data2);

    try std.testing.expect(crc1 != crc2);
    try std.testing.expectEqual(crc1, calculateChecksum(data1)); // Deterministic
}

test "SaveHeader" {
    var header = SaveHeader{};
    header.setName("Test Save");

    try std.testing.expectEqualStrings("Test Save", header.getName());
    try std.testing.expect(header.isValid());
}

test "GameState basic" {
    const allocator = std.testing.allocator;

    var state = GameState.init(allocator);
    defer state.deinit();

    try state.set("player_x", Value.number(100.5));
    try state.set("health", Value.integer(100));
    try state.set("alive", Value.boolean(true));

    const x = state.get("player_x");
    try std.testing.expect(x != null);
    try std.testing.expectEqual(@as(f64, 100.5), x.?.float);

    const health = state.get("health");
    try std.testing.expect(health != null);
    try std.testing.expectEqual(@as(i64, 100), health.?.int);
}

test "GameState serialize deserialize" {
    const allocator = std.testing.allocator;

    var state = GameState.init(allocator);
    defer state.deinit();

    try state.set("score", Value.integer(9999));
    try state.set("name", .{ .string = "Player1" });

    // Serialize
    var ctx = SerializeContext.init(allocator);
    defer ctx.deinit();
    try state.serialize(&ctx);

    // Deserialize
    var state2 = GameState.init(allocator);
    defer state2.deinit();

    var dctx = DeserializeContext.init(ctx.getData());
    try state2.deserialize(&dctx);

    const score = state2.get("score");
    try std.testing.expect(score != null);
    try std.testing.expectEqual(@as(i64, 9999), score.?.int);
}
