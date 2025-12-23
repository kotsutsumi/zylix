//! Sprite System - PIXI.js-inspired sprite rendering
//!
//! Provides efficient 2D sprite rendering with batching, texture atlases,
//! and animation support.

const std = @import("std");

/// 2D Vector
pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vec2, s: f32) Vec2 {
        return .{ .x = self.x * s, .y = self.y * s };
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len == 0) return self;
        return .{ .x = self.x / len, .y = self.y / len };
    }

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }
};

/// Color with alpha
pub const Color = struct {
    r: f32 = 1.0,
    g: f32 = 1.0,
    b: f32 = 1.0,
    a: f32 = 1.0,

    pub const white = Color{ .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 1 };
    pub const red = Color{ .r = 1, .g = 0, .b = 0, .a = 1 };
    pub const green = Color{ .r = 0, .g = 1, .b = 0, .a = 1 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 1, .a = 1 };
    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
            .a = @as(f32, @floatFromInt(a)) / 255.0,
        };
    }

    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @as(f32, @floatFromInt((hex >> 24) & 0xFF)) / 255.0,
            .g = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
            .b = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
            .a = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
        };
    }
};

/// Rectangle for texture regions and bounds
pub const Rect = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn contains(self: Rect, point: Vec2) bool {
        return point.x >= self.x and point.x < self.x + self.width and
            point.y >= self.y and point.y < self.y + self.height;
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }
};

/// Texture handle
pub const TextureId = u32;

/// Texture region within an atlas
pub const TextureRegion = struct {
    texture_id: TextureId = 0,
    /// UV coordinates (0-1 normalized)
    u0: f32 = 0,
    v0: f32 = 0,
    u1: f32 = 1,
    v1: f32 = 1,
    /// Original frame size (for trimmed sprites)
    frame_width: f32 = 0,
    frame_height: f32 = 0,
    /// Source rectangle in pixels
    source_x: f32 = 0,
    source_y: f32 = 0,
    source_width: f32 = 0,
    source_height: f32 = 0,
    /// Is sprite rotated 90 degrees in atlas
    rotated: bool = false,
    /// Is sprite trimmed
    trimmed: bool = false,
    /// Trim offset
    trim_x: f32 = 0,
    trim_y: f32 = 0,
};

/// Blend mode for sprite rendering
pub const BlendMode = enum(u8) {
    normal = 0,
    additive = 1,
    multiply = 2,
    screen = 3,
    overlay = 4,
};

/// Sprite - basic 2D renderable object
pub const Sprite = struct {
    allocator: std.mem.Allocator,

    // Transform
    position: Vec2 = .{},
    scale: Vec2 = .{ .x = 1, .y = 1 },
    rotation: f32 = 0,
    anchor: Vec2 = .{ .x = 0.5, .y = 0.5 },
    pivot: Vec2 = .{},

    // Appearance
    texture: TextureRegion = .{},
    tint: Color = Color.white,
    alpha: f32 = 1.0,
    blend_mode: BlendMode = .normal,
    visible: bool = true,

    // Bounds
    width: f32 = 0,
    height: f32 = 0,

    // Hierarchy
    parent: ?*Sprite = null,
    children: std.ArrayListUnmanaged(*Sprite) = .{},

    // Cached world transform
    world_transform: [6]f32 = .{ 1, 0, 0, 1, 0, 0 },
    world_alpha: f32 = 1.0,
    dirty: bool = true,

    // User data
    name: ?[]const u8 = null,
    user_data: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) Sprite {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Sprite) void {
        // Remove from parent
        if (self.parent) |p| {
            p.removeChild(self);
        }

        // Deinit children
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
    }

    pub fn setTexture(self: *Sprite, region: TextureRegion) void {
        self.texture = region;
        if (self.width == 0) self.width = region.source_width;
        if (self.height == 0) self.height = region.source_height;
        self.dirty = true;
    }

    pub fn setPosition(self: *Sprite, x: f32, y: f32) void {
        self.position = .{ .x = x, .y = y };
        self.dirty = true;
    }

    pub fn setScale(self: *Sprite, sx: f32, sy: f32) void {
        self.scale = .{ .x = sx, .y = sy };
        self.dirty = true;
    }

    pub fn setRotation(self: *Sprite, radians: f32) void {
        self.rotation = radians;
        self.dirty = true;
    }

    pub fn setAnchor(self: *Sprite, ax: f32, ay: f32) void {
        self.anchor = .{ .x = ax, .y = ay };
        self.dirty = true;
    }

    pub fn addChild(self: *Sprite, child: *Sprite) !void {
        if (child.parent) |p| {
            p.removeChild(child);
        }
        child.parent = self;
        try self.children.append(self.allocator, child);
        child.dirty = true;
    }

    pub fn removeChild(self: *Sprite, child: *Sprite) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.swapRemove(i);
                child.parent = null;
                child.dirty = true;
                break;
            }
        }
    }

    pub fn updateTransform(self: *Sprite) void {
        if (!self.dirty and self.parent != null and !self.parent.?.dirty) {
            return;
        }

        const cos_r = @cos(self.rotation);
        const sin_r = @sin(self.rotation);
        const sx = self.scale.x;
        const sy = self.scale.y;

        // Local transform: scale -> rotate -> translate
        var a = cos_r * sx;
        var b = sin_r * sx;
        var c = -sin_r * sy;
        var d = cos_r * sy;
        var tx = self.position.x - (self.anchor.x * self.width * sx * cos_r) + (self.anchor.y * self.height * sy * sin_r);
        var ty = self.position.y - (self.anchor.x * self.width * sx * sin_r) - (self.anchor.y * self.height * sy * cos_r);

        // Apply parent transform
        if (self.parent) |p| {
            const pa = p.world_transform[0];
            const pb = p.world_transform[1];
            const pc = p.world_transform[2];
            const pd = p.world_transform[3];
            const ptx = p.world_transform[4];
            const pty = p.world_transform[5];

            self.world_transform[0] = a * pa + b * pc;
            self.world_transform[1] = a * pb + b * pd;
            self.world_transform[2] = c * pa + d * pc;
            self.world_transform[3] = c * pb + d * pd;
            self.world_transform[4] = tx * pa + ty * pc + ptx;
            self.world_transform[5] = tx * pb + ty * pd + pty;
            self.world_alpha = self.alpha * p.world_alpha;
        } else {
            self.world_transform = .{ a, b, c, d, tx, ty };
            self.world_alpha = self.alpha;
        }

        self.dirty = false;

        // Update children
        for (self.children.items) |child| {
            child.dirty = true;
            child.updateTransform();
        }
    }

    pub fn getBounds(self: *const Sprite) Rect {
        const w = self.width * self.scale.x;
        const h = self.height * self.scale.y;
        return .{
            .x = self.position.x - self.anchor.x * w,
            .y = self.position.y - self.anchor.y * h,
            .width = w,
            .height = h,
        };
    }

    pub fn containsPoint(self: *const Sprite, point: Vec2) bool {
        return self.getBounds().contains(point);
    }
};

/// Animation frame data
pub const AnimationFrame = struct {
    texture: TextureRegion,
    duration: f32, // seconds
};

/// Animated sprite with frame-based animation
pub const AnimatedSprite = struct {
    base: Sprite,
    frames: std.ArrayListUnmanaged(AnimationFrame) = .{},
    current_frame: usize = 0,
    elapsed_time: f32 = 0,
    playing: bool = false,
    loop: bool = true,
    speed: f32 = 1.0,
    on_complete: ?*const fn (*AnimatedSprite) void = null,

    pub fn init(allocator: std.mem.Allocator) AnimatedSprite {
        return .{
            .base = Sprite.init(allocator),
        };
    }

    pub fn deinit(self: *AnimatedSprite) void {
        self.frames.deinit(self.base.allocator);
        self.base.deinit();
    }

    pub fn addFrame(self: *AnimatedSprite, texture: TextureRegion, duration: f32) !void {
        try self.frames.append(self.base.allocator, .{
            .texture = texture,
            .duration = duration,
        });
        if (self.frames.items.len == 1) {
            self.base.setTexture(texture);
        }
    }

    pub fn play(self: *AnimatedSprite) void {
        self.playing = true;
    }

    pub fn pause(self: *AnimatedSprite) void {
        self.playing = false;
    }

    pub fn stop(self: *AnimatedSprite) void {
        self.playing = false;
        self.current_frame = 0;
        self.elapsed_time = 0;
        if (self.frames.items.len > 0) {
            self.base.setTexture(self.frames.items[0].texture);
        }
    }

    pub fn gotoAndPlay(self: *AnimatedSprite, frame: usize) void {
        if (frame < self.frames.items.len) {
            self.current_frame = frame;
            self.elapsed_time = 0;
            self.base.setTexture(self.frames.items[frame].texture);
            self.playing = true;
        }
    }

    pub fn gotoAndStop(self: *AnimatedSprite, frame: usize) void {
        if (frame < self.frames.items.len) {
            self.current_frame = frame;
            self.elapsed_time = 0;
            self.base.setTexture(self.frames.items[frame].texture);
            self.playing = false;
        }
    }

    pub fn update(self: *AnimatedSprite, delta_time: f32) void {
        if (!self.playing or self.frames.items.len == 0) return;

        self.elapsed_time += delta_time * self.speed;

        while (self.elapsed_time >= self.frames.items[self.current_frame].duration) {
            self.elapsed_time -= self.frames.items[self.current_frame].duration;
            self.current_frame += 1;

            if (self.current_frame >= self.frames.items.len) {
                if (self.loop) {
                    self.current_frame = 0;
                } else {
                    self.current_frame = self.frames.items.len - 1;
                    self.playing = false;
                    if (self.on_complete) |callback| {
                        callback(self);
                    }
                    break;
                }
            }

            self.base.setTexture(self.frames.items[self.current_frame].texture);
        }
    }
};

/// Texture atlas for efficient sprite sheet management
pub const TextureAtlas = struct {
    allocator: std.mem.Allocator,
    texture_id: TextureId,
    texture_width: u32,
    texture_height: u32,
    regions: std.StringHashMapUnmanaged(TextureRegion) = .{},

    pub fn init(allocator: std.mem.Allocator, texture_id: TextureId, width: u32, height: u32) TextureAtlas {
        return .{
            .allocator = allocator,
            .texture_id = texture_id,
            .texture_width = width,
            .texture_height = height,
        };
    }

    pub fn deinit(self: *TextureAtlas) void {
        self.regions.deinit(self.allocator);
    }

    pub fn addRegion(self: *TextureAtlas, name: []const u8, x: u32, y: u32, width: u32, height: u32) !void {
        const tw = @as(f32, @floatFromInt(self.texture_width));
        const th = @as(f32, @floatFromInt(self.texture_height));

        const region = TextureRegion{
            .texture_id = self.texture_id,
            .u0 = @as(f32, @floatFromInt(x)) / tw,
            .v0 = @as(f32, @floatFromInt(y)) / th,
            .u1 = @as(f32, @floatFromInt(x + width)) / tw,
            .v1 = @as(f32, @floatFromInt(y + height)) / th,
            .source_x = @floatFromInt(x),
            .source_y = @floatFromInt(y),
            .source_width = @floatFromInt(width),
            .source_height = @floatFromInt(height),
            .frame_width = @floatFromInt(width),
            .frame_height = @floatFromInt(height),
        };

        try self.regions.put(self.allocator, name, region);
    }

    pub fn getRegion(self: *const TextureAtlas, name: []const u8) ?TextureRegion {
        return self.regions.get(name);
    }

    /// Parse from JSON atlas format (TexturePacker compatible)
    pub fn parseJson(self: *TextureAtlas, json_data: []const u8) !void {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidFormat;

        const frames = root.object.get("frames") orelse return error.MissingFrames;

        switch (frames) {
            .object => |obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    try self.parseFrame(entry.key_ptr.*, entry.value_ptr.*);
                }
            },
            .array => |arr| {
                for (arr.items) |item| {
                    if (item.object.get("filename")) |filename| {
                        try self.parseFrame(filename.string, item);
                    }
                }
            },
            else => return error.InvalidFramesFormat,
        }
    }

    fn parseFrame(self: *TextureAtlas, name: []const u8, frame_data: std.json.Value) !void {
        if (frame_data != .object) return;

        const frame = frame_data.object.get("frame") orelse return;
        if (frame != .object) return;

        const x = @as(u32, @intFromFloat(frame.object.get("x").?.float));
        const y = @as(u32, @intFromFloat(frame.object.get("y").?.float));
        const w = @as(u32, @intFromFloat(frame.object.get("w").?.float));
        const h = @as(u32, @intFromFloat(frame.object.get("h").?.float));

        try self.addRegion(name, x, y, w, h);
    }
};

/// Vertex for sprite batch rendering
pub const SpriteVertex = struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

/// Sprite batch for efficient rendering of many sprites
pub const SpriteBatch = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayListUnmanaged(SpriteVertex) = .{},
    indices: std.ArrayListUnmanaged(u16) = .{},
    current_texture: TextureId = 0,
    max_sprites: usize,
    sprite_count: usize = 0,
    drawing: bool = false,

    /// Maximum sprites per batch (limited by u16 index range: 65536 / 4 vertices = 16384)
    pub const MAX_BATCH_SPRITES: usize = 16383;

    pub fn init(allocator: std.mem.Allocator, max_sprites: usize) !SpriteBatch {
        // Ensure indices fit in u16 (4 vertices per sprite)
        const effective_max = @min(max_sprites, MAX_BATCH_SPRITES);

        var batch = SpriteBatch{
            .allocator = allocator,
            .max_sprites = effective_max,
        };

        // Pre-allocate vertex and index buffers
        try batch.vertices.ensureTotalCapacity(allocator, effective_max * 4);
        try batch.indices.ensureTotalCapacity(allocator, effective_max * 6);

        return batch;
    }

    pub fn deinit(self: *SpriteBatch) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
    }

    pub fn begin(self: *SpriteBatch) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.sprite_count = 0;
        self.drawing = true;
    }

    pub fn end(self: *SpriteBatch) void {
        self.flush();
        self.drawing = false;
    }

    pub fn flush(self: *SpriteBatch) void {
        if (self.sprite_count == 0) return;

        // Here would be the actual GPU draw call
        // For now, this is a placeholder for platform-specific implementation

        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.sprite_count = 0;
    }

    pub fn draw(self: *SpriteBatch, sprite: *const Sprite) !void {
        if (!self.drawing) return;
        if (!sprite.visible or sprite.world_alpha <= 0) return;

        // Flush if texture changes or batch is full
        if (sprite.texture.texture_id != self.current_texture or
            self.sprite_count >= self.max_sprites)
        {
            self.flush();
            self.current_texture = sprite.texture.texture_id;
        }

        const t = sprite.world_transform;
        const w = sprite.width;
        const h = sprite.height;
        const color = sprite.tint;
        const alpha = sprite.world_alpha;
        const tex = sprite.texture;

        // Calculate corner positions
        const x0: f32 = 0;
        const y0: f32 = 0;
        const x1 = w;
        const y1 = h;

        // Transform corners
        const ax = x0 * t[0] + y0 * t[2] + t[4];
        const ay = x0 * t[1] + y0 * t[3] + t[5];
        const bx = x1 * t[0] + y0 * t[2] + t[4];
        const by = x1 * t[1] + y0 * t[3] + t[5];
        const cx = x1 * t[0] + y1 * t[2] + t[4];
        const cy = x1 * t[1] + y1 * t[3] + t[5];
        const dx = x0 * t[0] + y1 * t[2] + t[4];
        const dy = x0 * t[1] + y1 * t[3] + t[5];

        const base_index = @as(u16, @intCast(self.vertices.items.len));

        // Add vertices
        try self.vertices.append(self.allocator, .{
            .x = ax,
            .y = ay,
            .u = tex.u0,
            .v = tex.v0,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = alpha,
        });
        try self.vertices.append(self.allocator, .{
            .x = bx,
            .y = by,
            .u = tex.u1,
            .v = tex.v0,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = alpha,
        });
        try self.vertices.append(self.allocator, .{
            .x = cx,
            .y = cy,
            .u = tex.u1,
            .v = tex.v1,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = alpha,
        });
        try self.vertices.append(self.allocator, .{
            .x = dx,
            .y = dy,
            .u = tex.u0,
            .v = tex.v1,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = alpha,
        });

        // Add indices (two triangles)
        try self.indices.append(self.allocator, base_index);
        try self.indices.append(self.allocator, base_index + 1);
        try self.indices.append(self.allocator, base_index + 2);
        try self.indices.append(self.allocator, base_index);
        try self.indices.append(self.allocator, base_index + 2);
        try self.indices.append(self.allocator, base_index + 3);

        self.sprite_count += 1;
    }

    pub fn drawRect(self: *SpriteBatch, x: f32, y: f32, width: f32, height: f32, color: Color) !void {
        if (!self.drawing) return;
        if (self.sprite_count >= self.max_sprites) {
            self.flush();
        }

        const base_index = @as(u16, @intCast(self.vertices.items.len));

        // White texture UV (assuming 0,0 is white pixel)
        const u: f32 = 0;
        const v: f32 = 0;

        try self.vertices.append(self.allocator, .{ .x = x, .y = y, .u = u, .v = v, .r = color.r, .g = color.g, .b = color.b, .a = color.a });
        try self.vertices.append(self.allocator, .{ .x = x + width, .y = y, .u = u, .v = v, .r = color.r, .g = color.g, .b = color.b, .a = color.a });
        try self.vertices.append(self.allocator, .{ .x = x + width, .y = y + height, .u = u, .v = v, .r = color.r, .g = color.g, .b = color.b, .a = color.a });
        try self.vertices.append(self.allocator, .{ .x = x, .y = y + height, .u = u, .v = v, .r = color.r, .g = color.g, .b = color.b, .a = color.a });

        try self.indices.append(self.allocator, base_index);
        try self.indices.append(self.allocator, base_index + 1);
        try self.indices.append(self.allocator, base_index + 2);
        try self.indices.append(self.allocator, base_index);
        try self.indices.append(self.allocator, base_index + 2);
        try self.indices.append(self.allocator, base_index + 3);

        self.sprite_count += 1;
    }
};

test "Vec2 operations" {
    const a = Vec2{ .x = 3, .y = 4 };
    const b = Vec2{ .x = 1, .y = 2 };

    const sum = a.add(b);
    try std.testing.expectEqual(@as(f32, 4), sum.x);
    try std.testing.expectEqual(@as(f32, 6), sum.y);

    try std.testing.expectEqual(@as(f32, 5), a.length());
}

test "Sprite init and deinit" {
    const allocator = std.testing.allocator;
    var sprite = Sprite.init(allocator);
    defer sprite.deinit();

    sprite.setPosition(100, 200);
    try std.testing.expectEqual(@as(f32, 100), sprite.position.x);
    try std.testing.expectEqual(@as(f32, 200), sprite.position.y);
}

test "AnimatedSprite basic" {
    const allocator = std.testing.allocator;
    var anim = AnimatedSprite.init(allocator);
    defer anim.deinit();

    try anim.addFrame(.{}, 0.1);
    try anim.addFrame(.{}, 0.1);

    try std.testing.expectEqual(@as(usize, 2), anim.frames.items.len);
}

test "TextureAtlas basic" {
    const allocator = std.testing.allocator;
    var atlas = TextureAtlas.init(allocator, 1, 512, 512);
    defer atlas.deinit();

    try atlas.addRegion("player", 0, 0, 64, 64);

    const region = atlas.getRegion("player");
    try std.testing.expect(region != null);
    try std.testing.expectEqual(@as(f32, 64), region.?.source_width);
}

test "SpriteBatch basic" {
    const allocator = std.testing.allocator;
    var batch = try SpriteBatch.init(allocator, 1000);
    defer batch.deinit();

    batch.begin();
    try batch.drawRect(0, 0, 100, 100, Color.red);
    batch.end();

    try std.testing.expectEqual(@as(usize, 0), batch.sprite_count);
}
