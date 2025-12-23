//! Tile Map System
//!
//! Supports orthogonal, isometric, and hexagonal tile maps with multiple layers,
//! collision detection, and Tiled JSON format import.

const std = @import("std");
const sprite = @import("sprite.zig");

const Vec2 = sprite.Vec2;
const Rect = sprite.Rect;
const TextureRegion = sprite.TextureRegion;
const Color = sprite.Color;

/// Tile map orientation
pub const MapOrientation = enum(u8) {
    orthogonal = 0,
    isometric = 1,
    staggered_isometric = 2,
    hexagonal = 3,
};

/// Stagger axis for isometric/hex maps
pub const StaggerAxis = enum(u8) {
    x = 0,
    y = 1,
};

/// Stagger index for isometric/hex maps
pub const StaggerIndex = enum(u8) {
    even = 0,
    odd = 1,
};

/// Tile flip flags
pub const TileFlags = packed struct {
    flip_horizontal: bool = false,
    flip_vertical: bool = false,
    flip_diagonal: bool = false,
    _padding: u5 = 0,
};

/// Single tile data
pub const Tile = struct {
    gid: u32 = 0, // Global tile ID (0 = empty)
    flags: TileFlags = .{},

    pub fn isEmpty(self: Tile) bool {
        return self.gid == 0;
    }
};

/// Tile properties for collision and custom data
pub const TileProperties = struct {
    collision: bool = false,
    friction: f32 = 1.0,
    user_data: ?*anyopaque = null,
    animation_frames: ?[]const u32 = null,
    animation_durations: ?[]const f32 = null,
};

/// Tileset - collection of tile graphics
pub const TileSet = struct {
    allocator: std.mem.Allocator,
    name: []const u8 = "",
    first_gid: u32 = 1,
    tile_width: u32 = 32,
    tile_height: u32 = 32,
    spacing: u32 = 0,
    margin: u32 = 0,
    tile_count: u32 = 0,
    columns: u32 = 0,
    image_width: u32 = 0,
    image_height: u32 = 0,
    texture_id: sprite.TextureId = 0,
    properties: std.AutoHashMapUnmanaged(u32, TileProperties) = .{},

    pub fn init(allocator: std.mem.Allocator) TileSet {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TileSet) void {
        self.properties.deinit(self.allocator);
    }

    pub fn getTileRegion(self: *const TileSet, local_id: u32) TextureRegion {
        // Guard against invalid tileset or out of bounds
        if (local_id >= self.tile_count or self.image_width == 0 or self.image_height == 0 or self.columns == 0) {
            return .{};
        }

        const col = local_id % self.columns;
        const row = local_id / self.columns;

        const x = self.margin + col * (self.tile_width + self.spacing);
        const y = self.margin + row * (self.tile_height + self.spacing);

        const tw = @as(f32, @floatFromInt(self.image_width));
        const th = @as(f32, @floatFromInt(self.image_height));

        return .{
            .texture_id = self.texture_id,
            .u0 = @as(f32, @floatFromInt(x)) / tw,
            .v0 = @as(f32, @floatFromInt(y)) / th,
            .u1 = @as(f32, @floatFromInt(x + self.tile_width)) / tw,
            .v1 = @as(f32, @floatFromInt(y + self.tile_height)) / th,
            .source_x = @floatFromInt(x),
            .source_y = @floatFromInt(y),
            .source_width = @floatFromInt(self.tile_width),
            .source_height = @floatFromInt(self.tile_height),
            .frame_width = @floatFromInt(self.tile_width),
            .frame_height = @floatFromInt(self.tile_height),
        };
    }

    pub fn getProperties(self: *const TileSet, local_id: u32) ?TileProperties {
        return self.properties.get(local_id);
    }

    pub fn setProperties(self: *TileSet, local_id: u32, props: TileProperties) !void {
        try self.properties.put(self.allocator, local_id, props);
    }
};

/// Layer type
pub const LayerType = enum(u8) {
    tile_layer = 0,
    object_layer = 1,
    image_layer = 2,
    group_layer = 3,
};

/// Tile layer - grid of tiles
pub const TileLayer = struct {
    allocator: std.mem.Allocator,
    name: []const u8 = "",
    width: u32 = 0,
    height: u32 = 0,
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    opacity: f32 = 1.0,
    visible: bool = true,
    tint: Color = Color.white,
    tiles: std.ArrayListUnmanaged(Tile) = .{},
    parallax_x: f32 = 1.0,
    parallax_y: f32 = 1.0,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !TileLayer {
        var layer = TileLayer{
            .allocator = allocator,
            .width = width,
            .height = height,
        };

        const count = width * height;
        try layer.tiles.ensureTotalCapacity(allocator, count);
        layer.tiles.items.len = count;
        @memset(layer.tiles.items, Tile{});

        return layer;
    }

    pub fn deinit(self: *TileLayer) void {
        self.tiles.deinit(self.allocator);
    }

    pub fn getTile(self: *const TileLayer, x: u32, y: u32) ?Tile {
        if (x >= self.width or y >= self.height) return null;
        return self.tiles.items[y * self.width + x];
    }

    pub fn setTile(self: *TileLayer, x: u32, y: u32, tile: Tile) void {
        if (x >= self.width or y >= self.height) return;
        self.tiles.items[y * self.width + x] = tile;
    }

    pub fn fill(self: *TileLayer, gid: u32) void {
        for (self.tiles.items) |*tile| {
            tile.gid = gid;
            tile.flags = .{};
        }
    }

    pub fn fillRect(self: *TileLayer, rect: Rect, gid: u32) void {
        // Clamp values to non-negative before conversion to u32
        const clamped_x0 = @max(0.0, rect.x);
        const clamped_y0 = @max(0.0, rect.y);
        const clamped_x1 = @max(0.0, rect.x + rect.width);
        const clamped_y1 = @max(0.0, rect.y + rect.height);

        const x0: u32 = @intFromFloat(clamped_x0);
        const y0: u32 = @intFromFloat(clamped_y0);
        const x1 = @min(self.width, @as(u32, @intFromFloat(clamped_x1)));
        const y1 = @min(self.height, @as(u32, @intFromFloat(clamped_y1)));

        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                self.setTile(x, y, .{ .gid = gid });
            }
        }
    }
};

/// Map object (from object layer)
pub const MapObject = struct {
    id: u32 = 0,
    name: []const u8 = "",
    object_type: []const u8 = "",
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    rotation: f32 = 0,
    visible: bool = true,
    gid: u32 = 0, // For tile objects
    ellipse: bool = false,
    point: bool = false,
    polygon: ?[]const Vec2 = null,
    polyline: ?[]const Vec2 = null,
    user_data: ?*anyopaque = null,
};

/// Object layer
pub const ObjectLayer = struct {
    allocator: std.mem.Allocator,
    name: []const u8 = "",
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    opacity: f32 = 1.0,
    visible: bool = true,
    tint: Color = Color.white,
    objects: std.ArrayListUnmanaged(MapObject) = .{},
    draw_order: enum { topdown, index } = .topdown,

    pub fn init(allocator: std.mem.Allocator) ObjectLayer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ObjectLayer) void {
        self.objects.deinit(self.allocator);
    }

    pub fn addObject(self: *ObjectLayer, obj: MapObject) !void {
        try self.objects.append(self.allocator, obj);
    }

    pub fn findByName(self: *const ObjectLayer, name: []const u8) ?*const MapObject {
        for (self.objects.items) |*obj| {
            if (std.mem.eql(u8, obj.name, name)) {
                return obj;
            }
        }
        return null;
    }

    pub fn findByType(self: *const ObjectLayer, allocator: std.mem.Allocator, object_type: []const u8) !std.ArrayList(*const MapObject) {
        var result = std.ArrayList(*const MapObject).init(allocator);
        errdefer result.deinit();
        for (self.objects.items) |*obj| {
            if (std.mem.eql(u8, obj.object_type, object_type)) {
                try result.append(obj);
            }
        }
        return result;
    }
};

/// Complete tile map
pub const TileMap = struct {
    allocator: std.mem.Allocator,

    // Map properties
    width: u32 = 0, // Width in tiles
    height: u32 = 0, // Height in tiles
    tile_width: u32 = 32,
    tile_height: u32 = 32,
    orientation: MapOrientation = .orthogonal,
    stagger_axis: StaggerAxis = .y,
    stagger_index: StaggerIndex = .odd,
    hex_side_length: u32 = 0,
    background_color: Color = Color.transparent,

    // Data
    tilesets: std.ArrayListUnmanaged(TileSet) = .{},
    tile_layers: std.ArrayListUnmanaged(TileLayer) = .{},
    object_layers: std.ArrayListUnmanaged(ObjectLayer) = .{},

    // Rendering
    visible: bool = true,
    position: Vec2 = .{},
    scale: Vec2 = .{ .x = 1, .y = 1 },

    pub fn init(allocator: std.mem.Allocator) TileMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TileMap) void {
        for (self.tilesets.items) |*ts| {
            ts.deinit();
        }
        self.tilesets.deinit(self.allocator);

        for (self.tile_layers.items) |*layer| {
            layer.deinit();
        }
        self.tile_layers.deinit(self.allocator);

        for (self.object_layers.items) |*layer| {
            layer.deinit();
        }
        self.object_layers.deinit(self.allocator);
    }

    pub fn addTileset(self: *TileMap, tileset: TileSet) !void {
        try self.tilesets.append(self.allocator, tileset);
    }

    pub fn addTileLayer(self: *TileMap, layer: TileLayer) !void {
        try self.tile_layers.append(self.allocator, layer);
    }

    pub fn addObjectLayer(self: *TileMap, layer: ObjectLayer) !void {
        try self.object_layers.append(self.allocator, layer);
    }

    /// Get tileset for a global tile ID
    pub fn getTilesetForGid(self: *const TileMap, gid: u32) ?*const TileSet {
        var result: ?*const TileSet = null;
        for (self.tilesets.items) |*ts| {
            if (ts.first_gid <= gid) {
                if (result == null or ts.first_gid > result.?.first_gid) {
                    result = ts;
                }
            }
        }
        return result;
    }

    /// Convert tile coordinates to world position
    pub fn tileToWorld(self: *const TileMap, tile_x: i32, tile_y: i32) Vec2 {
        const tw = @as(f32, @floatFromInt(self.tile_width));
        const th = @as(f32, @floatFromInt(self.tile_height));
        const tx = @as(f32, @floatFromInt(tile_x));
        const ty = @as(f32, @floatFromInt(tile_y));

        switch (self.orientation) {
            .orthogonal => {
                return .{
                    .x = tx * tw * self.scale.x + self.position.x,
                    .y = ty * th * self.scale.y + self.position.y,
                };
            },
            .isometric => {
                return .{
                    .x = (tx - ty) * (tw / 2) * self.scale.x + self.position.x,
                    .y = (tx + ty) * (th / 2) * self.scale.y + self.position.y,
                };
            },
            .staggered_isometric => {
                const stagger_offset = if (self.stagger_index == .odd)
                    @as(f32, @floatFromInt(@mod(tile_y, 2)))
                else
                    @as(f32, @floatFromInt(1 - @mod(tile_y, 2)));

                return .{
                    .x = (tx + stagger_offset * 0.5) * tw * self.scale.x + self.position.x,
                    .y = ty * (th / 2) * self.scale.y + self.position.y,
                };
            },
            .hexagonal => {
                const hex_offset = @as(f32, @floatFromInt(self.hex_side_length));
                const col_width = tw - (tw - hex_offset) / 2;
                const row_height = th;

                const stagger_offset = if (self.stagger_axis == .x)
                    if (self.stagger_index == .odd)
                        @as(f32, @floatFromInt(@mod(tile_x, 2))) * (row_height / 2)
                    else
                        @as(f32, @floatFromInt(1 - @mod(tile_x, 2))) * (row_height / 2)
                else if (self.stagger_index == .odd)
                    @as(f32, @floatFromInt(@mod(tile_y, 2))) * (col_width / 2)
                else
                    @as(f32, @floatFromInt(1 - @mod(tile_y, 2))) * (col_width / 2);

                if (self.stagger_axis == .x) {
                    return .{
                        .x = tx * col_width * self.scale.x + self.position.x,
                        .y = (ty * row_height + stagger_offset) * self.scale.y + self.position.y,
                    };
                } else {
                    return .{
                        .x = (tx * tw + stagger_offset) * self.scale.x + self.position.x,
                        .y = ty * (th - (th - hex_offset) / 2) * self.scale.y + self.position.y,
                    };
                }
            },
        }
    }

    /// Convert world position to tile coordinates
    pub fn worldToTile(self: *const TileMap, world_x: f32, world_y: f32) struct { x: i32, y: i32 } {
        const tw = @as(f32, @floatFromInt(self.tile_width));
        const th = @as(f32, @floatFromInt(self.tile_height));
        const wx = (world_x - self.position.x) / self.scale.x;
        const wy = (world_y - self.position.y) / self.scale.y;

        switch (self.orientation) {
            .orthogonal => {
                return .{
                    .x = @intFromFloat(@floor(wx / tw)),
                    .y = @intFromFloat(@floor(wy / th)),
                };
            },
            .isometric => {
                const half_w = tw / 2;
                const half_h = th / 2;
                return .{
                    .x = @intFromFloat(@floor((wx / half_w + wy / half_h) / 2)),
                    .y = @intFromFloat(@floor((wy / half_h - wx / half_w) / 2)),
                };
            },
            else => {
                // Simplified for staggered and hex
                return .{
                    .x = @intFromFloat(@floor(wx / tw)),
                    .y = @intFromFloat(@floor(wy / th)),
                };
            },
        }
    }

    /// Check collision at world position
    pub fn checkCollision(self: *const TileMap, world_x: f32, world_y: f32, layer_index: usize) bool {
        if (layer_index >= self.tile_layers.items.len) return false;

        const tile_pos = self.worldToTile(world_x, world_y);
        if (tile_pos.x < 0 or tile_pos.y < 0) return false;

        const layer = &self.tile_layers.items[layer_index];
        const tile = layer.getTile(@intCast(tile_pos.x), @intCast(tile_pos.y)) orelse return false;

        if (tile.isEmpty()) return false;

        if (self.getTilesetForGid(tile.gid)) |tileset| {
            const local_id = tile.gid - tileset.first_gid;
            if (tileset.getProperties(local_id)) |props| {
                return props.collision;
            }
        }

        return false;
    }

    /// Get bounding box in world coordinates
    pub fn getBounds(self: *const TileMap) Rect {
        const map_width = @as(f32, @floatFromInt(self.width * self.tile_width)) * self.scale.x;
        const map_height = @as(f32, @floatFromInt(self.height * self.tile_height)) * self.scale.y;

        return .{
            .x = self.position.x,
            .y = self.position.y,
            .width = map_width,
            .height = map_height,
        };
    }

    /// Get visible tile range for rendering
    pub fn getVisibleTileRange(self: *const TileMap, viewport: Rect) struct {
        x_start: u32,
        y_start: u32,
        x_end: u32,
        y_end: u32,
    } {
        const start = self.worldToTile(viewport.x, viewport.y);
        const end = self.worldToTile(viewport.x + viewport.width, viewport.y + viewport.height);

        return .{
            .x_start = @intCast(@max(0, start.x - 1)),
            .y_start = @intCast(@max(0, start.y - 1)),
            .x_end = @min(self.width, @as(u32, @intCast(@max(0, end.x + 2)))),
            .y_end = @min(self.height, @as(u32, @intCast(@max(0, end.y + 2)))),
        };
    }
};

/// Tiled JSON format parser
pub const TiledParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TiledParser {
        return .{ .allocator = allocator };
    }

    /// Helper to extract number from JSON value (handles both integer and float)
    fn getNumber(val: std.json.Value) ?f64 {
        return switch (val) {
            .integer => |i| @floatFromInt(i),
            .float => |f| f,
            else => null,
        };
    }

    /// Helper to extract integer from JSON value
    fn getInt(comptime T: type, val: std.json.Value) ?T {
        return switch (val) {
            .integer => |i| @intCast(i),
            .float => |f| @intFromFloat(f),
            else => null,
        };
    }

    pub fn parse(self: *TiledParser, json_data: []const u8) !TileMap {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidFormat;

        var map = TileMap.init(self.allocator);
        errdefer map.deinit();

        // Parse map properties (Tiled uses integers)
        if (root.object.get("width")) |w| if (getInt(u32, w)) |n| {
            map.width = n;
        };
        if (root.object.get("height")) |h| if (getInt(u32, h)) |n| {
            map.height = n;
        };
        if (root.object.get("tilewidth")) |tw| if (getInt(u32, tw)) |n| {
            map.tile_width = n;
        };
        if (root.object.get("tileheight")) |th| if (getInt(u32, th)) |n| {
            map.tile_height = n;
        };

        if (root.object.get("orientation")) |o| {
            const orient_str = o.string;
            if (std.mem.eql(u8, orient_str, "orthogonal")) {
                map.orientation = .orthogonal;
            } else if (std.mem.eql(u8, orient_str, "isometric")) {
                map.orientation = .isometric;
            } else if (std.mem.eql(u8, orient_str, "staggered")) {
                map.orientation = .staggered_isometric;
            } else if (std.mem.eql(u8, orient_str, "hexagonal")) {
                map.orientation = .hexagonal;
            }
        }

        // Parse tilesets
        if (root.object.get("tilesets")) |tilesets| {
            if (tilesets == .array) {
                for (tilesets.array.items) |ts_data| {
                    var tileset = try self.parseTileset(ts_data);
                    try map.addTileset(tileset);
                }
            }
        }

        // Parse layers
        if (root.object.get("layers")) |layers| {
            if (layers == .array) {
                for (layers.array.items) |layer_data| {
                    try self.parseLayer(&map, layer_data);
                }
            }
        }

        return map;
    }

    fn parseTileset(self: *TiledParser, data: std.json.Value) !TileSet {
        if (data != .object) return error.InvalidTileset;

        var tileset = TileSet.init(self.allocator);

        if (data.object.get("firstgid")) |fg| if (getInt(u32, fg)) |n| {
            tileset.first_gid = n;
        };
        if (data.object.get("tilewidth")) |tw| if (getInt(u32, tw)) |n| {
            tileset.tile_width = n;
        };
        if (data.object.get("tileheight")) |th| if (getInt(u32, th)) |n| {
            tileset.tile_height = n;
        };
        if (data.object.get("spacing")) |s| if (getInt(u32, s)) |n| {
            tileset.spacing = n;
        };
        if (data.object.get("margin")) |m| if (getInt(u32, m)) |n| {
            tileset.margin = n;
        };
        if (data.object.get("tilecount")) |tc| if (getInt(u32, tc)) |n| {
            tileset.tile_count = n;
        };
        if (data.object.get("columns")) |c| if (getInt(u32, c)) |n| {
            tileset.columns = n;
        };
        if (data.object.get("imagewidth")) |iw| if (getInt(u32, iw)) |n| {
            tileset.image_width = n;
        };
        if (data.object.get("imageheight")) |ih| if (getInt(u32, ih)) |n| {
            tileset.image_height = n;
        };

        return tileset;
    }

    fn parseLayer(self: *TiledParser, map: *TileMap, data: std.json.Value) !void {
        if (data != .object) return;

        const layer_type = data.object.get("type") orelse return;
        if (layer_type != .string) return;

        if (std.mem.eql(u8, layer_type.string, "tilelayer")) {
            var layer = try TileLayer.init(self.allocator, map.width, map.height);

            if (data.object.get("offsetx")) |ox| if (getNumber(ox)) |n| {
                layer.offset_x = @floatCast(n);
            };
            if (data.object.get("offsety")) |oy| if (getNumber(oy)) |n| {
                layer.offset_y = @floatCast(n);
            };
            if (data.object.get("opacity")) |op| if (getNumber(op)) |n| {
                layer.opacity = @floatCast(n);
            };
            if (data.object.get("visible")) |v| if (v == .bool) {
                layer.visible = v.bool;
            };

            // Parse tile data
            if (data.object.get("data")) |tile_data| {
                if (tile_data == .array) {
                    for (tile_data.array.items, 0..) |gid_val, i| {
                        if (i < layer.tiles.items.len) {
                            const gid: u32 = getInt(u32, gid_val) orelse 0;
                            // Extract flip flags from high bits
                            const flip_h = (gid & 0x80000000) != 0;
                            const flip_v = (gid & 0x40000000) != 0;
                            const flip_d = (gid & 0x20000000) != 0;
                            const clean_gid = gid & 0x1FFFFFFF;

                            layer.tiles.items[i] = .{
                                .gid = clean_gid,
                                .flags = .{
                                    .flip_horizontal = flip_h,
                                    .flip_vertical = flip_v,
                                    .flip_diagonal = flip_d,
                                },
                            };
                        }
                    }
                }
            }

            try map.addTileLayer(layer);
        } else if (std.mem.eql(u8, layer_type.string, "objectgroup")) {
            var layer = ObjectLayer.init(self.allocator);

            if (data.object.get("objects")) |objects| {
                if (objects == .array) {
                    for (objects.array.items) |obj_data| {
                        var obj = MapObject{};
                        if (obj_data.object.get("id")) |id| if (getInt(u32, id)) |n| {
                            obj.id = n;
                        };
                        if (obj_data.object.get("x")) |x| if (getNumber(x)) |n| {
                            obj.x = @floatCast(n);
                        };
                        if (obj_data.object.get("y")) |y| if (getNumber(y)) |n| {
                            obj.y = @floatCast(n);
                        };
                        if (obj_data.object.get("width")) |w| if (getNumber(w)) |n| {
                            obj.width = @floatCast(n);
                        };
                        if (obj_data.object.get("height")) |h| if (getNumber(h)) |n| {
                            obj.height = @floatCast(n);
                        };
                        if (obj_data.object.get("rotation")) |r| if (getNumber(r)) |n| {
                            obj.rotation = @floatCast(n);
                        };
                        if (obj_data.object.get("visible")) |v| if (v == .bool) {
                            obj.visible = v.bool;
                        };
                        if (obj_data.object.get("gid")) |g| if (getInt(u32, g)) |n| {
                            obj.gid = n;
                        };
                        if (obj_data.object.get("ellipse")) |e| if (e == .bool) {
                            obj.ellipse = e.bool;
                        };
                        if (obj_data.object.get("point")) |p| if (p == .bool) {
                            obj.point = p.bool;
                        };

                        try layer.addObject(obj);
                    }
                }
            }

            try map.addObjectLayer(layer);
        }
    }
};

test "TileLayer basic" {
    const allocator = std.testing.allocator;
    var layer = try TileLayer.init(allocator, 10, 10);
    defer layer.deinit();

    layer.setTile(5, 5, .{ .gid = 1 });
    const tile = layer.getTile(5, 5);
    try std.testing.expect(tile != null);
    try std.testing.expectEqual(@as(u32, 1), tile.?.gid);
}

test "TileMap coordinate conversion" {
    const allocator = std.testing.allocator;
    var map = TileMap.init(allocator);
    defer map.deinit();

    map.width = 10;
    map.height = 10;
    map.tile_width = 32;
    map.tile_height = 32;

    const world_pos = map.tileToWorld(5, 5);
    try std.testing.expectEqual(@as(f32, 160), world_pos.x);
    try std.testing.expectEqual(@as(f32, 160), world_pos.y);

    const tile_pos = map.worldToTile(160, 160);
    try std.testing.expectEqual(@as(i32, 5), tile_pos.x);
    try std.testing.expectEqual(@as(i32, 5), tile_pos.y);
}

test "TileSet region calculation" {
    const allocator = std.testing.allocator;
    var tileset = TileSet.init(allocator);
    defer tileset.deinit();

    tileset.tile_width = 32;
    tileset.tile_height = 32;
    tileset.tile_count = 16;
    tileset.columns = 4;
    tileset.image_width = 128;
    tileset.image_height = 128;

    const region = tileset.getTileRegion(5); // Row 1, Col 1
    try std.testing.expectEqual(@as(f32, 0.25), region.u0);
    try std.testing.expectEqual(@as(f32, 0.25), region.v0);
}
