//! Platformer Adventure - Game State

const std = @import("std");

pub const GameState = enum(u8) {
    menu = 0,
    playing = 1,
    paused = 2,
    game_over = 3,
    victory = 4,

    pub fn label(self: GameState) []const u8 {
        return switch (self) {
            .menu => "Main Menu",
            .playing => "Playing",
            .paused => "Paused",
            .game_over => "Game Over",
            .victory => "Victory!",
        };
    }
};

pub const Direction = enum(u8) {
    none = 0,
    left = 1,
    right = 2,
};

pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn scale(self: Vec2, s: f32) Vec2 {
        return .{ .x = self.x * s, .y = self.y * s };
    }
};

pub const Player = struct {
    position: Vec2 = .{ .x = 50, .y = 200 },
    velocity: Vec2 = .{},
    width: f32 = 32,
    height: f32 = 48,
    on_ground: bool = false,
    facing: Direction = .right,
    jumps_remaining: u8 = 2,
    speed_boost: bool = false,
    jump_boost: bool = false,
};

pub const PlatformType = enum(u8) {
    static = 0,
    moving = 1,
    one_way = 2,
};

pub const Platform = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    platform_type: PlatformType = .static,
    move_range: f32 = 0,
    move_speed: f32 = 0,
    move_offset: f32 = 0,
};

pub const CollectibleType = enum(u8) {
    coin = 0,
    speed_boost = 1,
    jump_boost = 2,
    health = 3,
};

pub const Collectible = struct {
    x: f32,
    y: f32,
    collectible_type: CollectibleType = .coin,
    collected: bool = false,

    pub fn value(self: Collectible) u32 {
        return switch (self.collectible_type) {
            .coin => 100,
            .speed_boost => 200,
            .jump_boost => 200,
            .health => 50,
        };
    }
};

pub const EnemyType = enum(u8) {
    patrol = 0,
    chase = 1,
    stationary = 2,
};

pub const Enemy = struct {
    x: f32,
    y: f32,
    width: f32 = 32,
    height: f32 = 32,
    enemy_type: EnemyType = .patrol,
    direction: Direction = .right,
    patrol_start: f32 = 0,
    patrol_end: f32 = 100,
    speed: f32 = 50,
    active: bool = true,
};

pub const Level = struct {
    width: f32 = 800,
    height: f32 = 600,
    goal_x: f32 = 750,
    goal_y: f32 = 100,
    goal_width: f32 = 40,
    goal_height: f32 = 60,
};

pub const GameData = struct {
    initialized: bool = false,
    state: GameState = .menu,
    player: Player = .{},
    level: Level = .{},
    score: u32 = 0,
    lives: u8 = 3,
    current_level: u8 = 1,
    time_elapsed: f32 = 0,
    input_direction: Direction = .none,
    jump_pressed: bool = false,

    // Static level data
    platforms: [10]Platform = undefined,
    platform_count: usize = 0,
    collectibles: [20]Collectible = undefined,
    collectible_count: usize = 0,
    enemies: [5]Enemy = undefined,
    enemy_count: usize = 0,
};

const GRAVITY: f32 = 800;
const JUMP_VELOCITY: f32 = -400;
const MOVE_SPEED: f32 = 200;
const BOOSTED_SPEED: f32 = 300;
const BOOSTED_JUMP: f32 = -500;

var game_data: GameData = .{};

pub fn init() void {
    game_data = .{ .initialized = true };
    loadLevel(1);
}

pub fn deinit() void {
    game_data.initialized = false;
}

pub fn getState() *const GameData {
    return &game_data;
}

fn loadLevel(level: u8) void {
    game_data.current_level = level;
    game_data.player = .{};
    game_data.time_elapsed = 0;

    // Ground
    game_data.platforms[0] = .{ .x = 0, .y = 550, .width = 800, .height = 50 };
    // Platforms
    game_data.platforms[1] = .{ .x = 100, .y = 450, .width = 120, .height = 20 };
    game_data.platforms[2] = .{ .x = 300, .y = 380, .width = 100, .height = 20, .platform_type = .moving, .move_range = 100, .move_speed = 50 };
    game_data.platforms[3] = .{ .x = 500, .y = 300, .width = 120, .height = 20 };
    game_data.platforms[4] = .{ .x = 650, .y = 200, .width = 100, .height = 20, .platform_type = .one_way };
    game_data.platform_count = 5;

    // Collectibles
    game_data.collectibles[0] = .{ .x = 150, .y = 420, .collectible_type = .coin };
    game_data.collectibles[1] = .{ .x = 350, .y = 350, .collectible_type = .coin };
    game_data.collectibles[2] = .{ .x = 550, .y = 270, .collectible_type = .speed_boost };
    game_data.collectibles[3] = .{ .x = 700, .y = 170, .collectible_type = .coin };
    game_data.collectible_count = 4;

    // Enemies
    game_data.enemies[0] = .{ .x = 200, .y = 518, .patrol_start = 150, .patrol_end = 350 };
    game_data.enemies[1] = .{ .x = 450, .y = 518, .enemy_type = .chase, .patrol_start = 400, .patrol_end = 600 };
    game_data.enemy_count = 2;
}

pub fn startGame() void {
    game_data.state = .playing;
    game_data.score = 0;
    game_data.lives = 3;
    loadLevel(1);
}

pub fn pauseGame() void {
    if (game_data.state == .playing) {
        game_data.state = .paused;
    }
}

pub fn resumeGame() void {
    if (game_data.state == .paused) {
        game_data.state = .playing;
    }
}

pub fn restartLevel() void {
    loadLevel(game_data.current_level);
    game_data.state = .playing;
}

pub fn returnToMenu() void {
    game_data.state = .menu;
}

// Input
pub fn moveLeft() void {
    game_data.input_direction = .left;
}

pub fn moveRight() void {
    game_data.input_direction = .right;
}

pub fn stopMove() void {
    game_data.input_direction = .none;
}

pub fn jump() void {
    game_data.jump_pressed = true;
}

pub fn update(delta: f32) void {
    if (game_data.state != .playing) return;

    game_data.time_elapsed += delta;

    // Update player
    updatePlayer(delta);

    // Update platforms
    updatePlatforms(delta);

    // Update enemies
    updateEnemies(delta);

    // Check collisions
    checkCollisions();

    // Check victory
    checkVictory();
}

fn updatePlayer(delta: f32) void {
    var player = &game_data.player;

    // Horizontal movement
    const speed = if (player.speed_boost) BOOSTED_SPEED else MOVE_SPEED;
    player.velocity.x = switch (game_data.input_direction) {
        .left => -speed,
        .right => speed,
        .none => 0,
    };

    if (game_data.input_direction == .left) player.facing = .left;
    if (game_data.input_direction == .right) player.facing = .right;

    // Jumping
    if (game_data.jump_pressed and player.jumps_remaining > 0) {
        const jump_vel = if (player.jump_boost) BOOSTED_JUMP else JUMP_VELOCITY;
        player.velocity.y = jump_vel;
        player.jumps_remaining -= 1;
        player.on_ground = false;
    }
    game_data.jump_pressed = false;

    // Gravity
    if (!player.on_ground) {
        player.velocity.y += GRAVITY * delta;
    }

    // Apply velocity
    player.position.x += player.velocity.x * delta;
    player.position.y += player.velocity.y * delta;

    // Screen bounds
    if (player.position.x < 0) player.position.x = 0;
    if (player.position.x > game_data.level.width - player.width) {
        player.position.x = game_data.level.width - player.width;
    }

    // Platform collision
    player.on_ground = false;
    for (game_data.platforms[0..game_data.platform_count]) |platform| {
        if (checkPlatformCollision(player, &platform)) {
            player.on_ground = true;
            player.jumps_remaining = 2;
            player.velocity.y = 0;
            player.position.y = platform.y - player.height;
        }
    }

    // Fall death
    if (player.position.y > game_data.level.height) {
        loseLife();
    }
}

fn checkPlatformCollision(player: *const Player, platform: *const Platform) bool {
    const px = player.position.x;
    const py = player.position.y;
    const pw = player.width;
    const ph = player.height;

    const plat_x = platform.x + platform.move_offset;

    // Only check if falling
    if (player.velocity.y < 0) return false;

    // Check if player feet are at platform level
    const feet_y = py + ph;
    const was_above = feet_y - player.velocity.y * 0.016 <= platform.y;

    if (!was_above) return false;

    // Check horizontal overlap
    if (px + pw < plat_x or px > plat_x + platform.width) return false;

    // Check vertical intersection
    if (feet_y >= platform.y and feet_y <= platform.y + platform.height + 10) {
        return true;
    }

    return false;
}

fn updatePlatforms(delta: f32) void {
    for (game_data.platforms[0..game_data.platform_count]) |*platform| {
        if (platform.platform_type == .moving) {
            platform.move_offset += platform.move_speed * delta;
            if (platform.move_offset > platform.move_range or platform.move_offset < 0) {
                platform.move_speed = -platform.move_speed;
            }
        }
    }
}

fn updateEnemies(delta: f32) void {
    const player = &game_data.player;

    for (game_data.enemies[0..game_data.enemy_count]) |*enemy| {
        if (!enemy.active) continue;

        switch (enemy.enemy_type) {
            .patrol => {
                if (enemy.direction == .right) {
                    enemy.x += enemy.speed * delta;
                    if (enemy.x >= enemy.patrol_end) enemy.direction = .left;
                } else {
                    enemy.x -= enemy.speed * delta;
                    if (enemy.x <= enemy.patrol_start) enemy.direction = .right;
                }
            },
            .chase => {
                const dx = player.position.x - enemy.x;
                if (@abs(dx) < 200) {
                    if (dx > 0) {
                        enemy.x += enemy.speed * delta;
                        enemy.direction = .right;
                    } else {
                        enemy.x -= enemy.speed * delta;
                        enemy.direction = .left;
                    }
                }
            },
            .stationary => {},
        }
    }
}

fn checkCollisions() void {
    const player = &game_data.player;

    // Collectibles
    for (game_data.collectibles[0..game_data.collectible_count]) |*collectible| {
        if (collectible.collected) continue;

        if (checkBoxCollision(player.position.x, player.position.y, player.width, player.height, collectible.x, collectible.y, 24, 24)) {
            collectible.collected = true;
            game_data.score += collectible.value();

            switch (collectible.collectible_type) {
                .speed_boost => player.speed_boost = true,
                .jump_boost => player.jump_boost = true,
                .health => {
                    if (game_data.lives < 5) game_data.lives += 1;
                },
                .coin => {},
            }
        }
    }

    // Enemies
    for (game_data.enemies[0..game_data.enemy_count]) |*enemy| {
        if (!enemy.active) continue;

        if (checkBoxCollision(player.position.x, player.position.y, player.width, player.height, enemy.x, enemy.y, enemy.width, enemy.height)) {
            // Check if player is jumping on enemy
            if (player.velocity.y > 0 and player.position.y + player.height < enemy.y + enemy.height / 2) {
                enemy.active = false;
                game_data.score += 150;
                player.velocity.y = JUMP_VELOCITY * 0.5;
            } else {
                loseLife();
            }
        }
    }
}

fn checkBoxCollision(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2;
}

fn checkVictory() void {
    const player = &game_data.player;
    const level = &game_data.level;

    if (checkBoxCollision(player.position.x, player.position.y, player.width, player.height, level.goal_x, level.goal_y, level.goal_width, level.goal_height)) {
        game_data.state = .victory;
        game_data.score += 1000;
    }
}

fn loseLife() void {
    if (game_data.lives > 1) {
        game_data.lives -= 1;
        loadLevel(game_data.current_level);
    } else {
        game_data.lives = 0;
        game_data.state = .game_over;
    }
}

// Tests
test "game init" {
    init();
    defer deinit();
    try std.testing.expect(game_data.initialized);
    try std.testing.expectEqual(GameState.menu, game_data.state);
}

test "start game" {
    init();
    defer deinit();
    startGame();
    try std.testing.expectEqual(GameState.playing, game_data.state);
    try std.testing.expectEqual(@as(u8, 3), game_data.lives);
}

test "pause resume" {
    init();
    defer deinit();
    startGame();
    pauseGame();
    try std.testing.expectEqual(GameState.paused, game_data.state);
    resumeGame();
    try std.testing.expectEqual(GameState.playing, game_data.state);
}

test "player movement" {
    init();
    defer deinit();
    startGame();
    const initial_x = game_data.player.position.x;
    moveRight();
    update(0.1);
    try std.testing.expect(game_data.player.position.x > initial_x);
}

test "collectible collision" {
    init();
    defer deinit();
    startGame();
    game_data.player.position = .{ .x = 150, .y = 420 };
    checkCollisions();
    try std.testing.expect(game_data.score > 0);
}
