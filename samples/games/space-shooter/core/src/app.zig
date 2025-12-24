//! Space Shooter - Game State

const std = @import("std");

pub const GameState = enum(u8) {
    menu = 0,
    playing = 1,
    paused = 2,
    game_over = 3,
    victory = 4,
};

pub const EnemyType = enum(u8) {
    basic = 0,
    fast = 1,
    tanky = 2,
    shooter = 3,
    boss = 4,

    pub fn health(self: EnemyType) u8 {
        return switch (self) {
            .basic => 1,
            .fast => 1,
            .tanky => 3,
            .shooter => 2,
            .boss => 50,
        };
    }

    pub fn speed(self: EnemyType) f32 {
        return switch (self) {
            .basic => 80,
            .fast => 150,
            .tanky => 40,
            .shooter => 60,
            .boss => 30,
        };
    }

    pub fn points(self: EnemyType) u32 {
        return switch (self) {
            .basic => 100,
            .fast => 150,
            .tanky => 200,
            .shooter => 175,
            .boss => 5000,
        };
    }

    pub fn color(self: EnemyType) u32 {
        return switch (self) {
            .basic => 0xFFE74C3C,
            .fast => 0xFFF1C40F,
            .tanky => 0xFF9B59B6,
            .shooter => 0xFFE67E22,
            .boss => 0xFFC0392B,
        };
    }
};

pub const PowerUpType = enum(u8) {
    weapon_upgrade = 0,
    shield = 1,
    speed = 2,
    special = 3,

    pub fn color(self: PowerUpType) u32 {
        return switch (self) {
            .weapon_upgrade => 0xFFFFD700,
            .shield => 0xFF3498DB,
            .speed => 0xFF2ECC71,
            .special => 0xFFFF69B4,
        };
    }
};

const MAX_BULLETS: usize = 50;
const MAX_ENEMIES: usize = 30;
const MAX_ENEMY_BULLETS: usize = 40;
const MAX_POWERUPS: usize = 5;

pub const Bullet = struct {
    x: f32 = 0,
    y: f32 = 0,
    vx: f32 = 0,
    vy: f32 = 0,
    active: bool = false,
    damage: u8 = 1,
};

pub const Enemy = struct {
    x: f32 = 0,
    y: f32 = 0,
    enemy_type: EnemyType = .basic,
    health: u8 = 1,
    active: bool = false,
    shoot_timer: f32 = 0,
};

pub const PowerUp = struct {
    x: f32 = 0,
    y: f32 = 0,
    power_type: PowerUpType = .weapon_upgrade,
    active: bool = false,
};

pub const Player = struct {
    x: f32 = 400,
    y: f32 = 500,
    width: f32 = 40,
    height: f32 = 40,
    speed: f32 = 300,
    weapon_level: u8 = 1,
    shield: u8 = 0,
    special_ammo: u8 = 3,
    invincible_timer: f32 = 0,
};

pub const GameData = struct {
    initialized: bool = false,
    state: GameState = .menu,
    player: Player = .{},

    bullets: [MAX_BULLETS]Bullet = [_]Bullet{.{}} ** MAX_BULLETS,
    enemies: [MAX_ENEMIES]Enemy = [_]Enemy{.{}} ** MAX_ENEMIES,
    enemy_bullets: [MAX_ENEMY_BULLETS]Bullet = [_]Bullet{.{}} ** MAX_ENEMY_BULLETS,
    powerups: [MAX_POWERUPS]PowerUp = [_]PowerUp{.{}} ** MAX_POWERUPS,

    score: u32 = 0,
    high_score: u32 = 0,
    lives: u8 = 3,
    current_wave: u8 = 1,
    wave_timer: f32 = 0,
    spawn_timer: f32 = 0,
    enemies_remaining: u8 = 0,
    combo: u8 = 0,
    combo_timer: f32 = 0,

    // Input
    move_x: f32 = 0,
    move_y: f32 = 0,
    firing: bool = false,
    fire_timer: f32 = 0,
};

const SCREEN_WIDTH: f32 = 800;
const SCREEN_HEIGHT: f32 = 600;
const FIRE_RATE: f32 = 0.15;
const BULLET_SPEED: f32 = 600;
const ENEMY_BULLET_SPEED: f32 = 250;

var game_data: GameData = .{};
var rng_state: u64 = 54321;

fn simpleRandom() u32 {
    rng_state = rng_state *% 1103515245 +% 12345;
    return @truncate(rng_state >> 16);
}

fn randomFloat(min: f32, max: f32) f32 {
    const r = @as(f32, @floatFromInt(simpleRandom() % 1000)) / 1000.0;
    return min + r * (max - min);
}

pub fn init() void {
    game_data = .{ .initialized = true };
}

pub fn deinit() void {
    game_data.initialized = false;
}

pub fn getState() *const GameData {
    return &game_data;
}

pub fn startGame() void {
    game_data.state = .playing;
    game_data.player = .{};
    game_data.score = 0;
    game_data.lives = 3;
    game_data.current_wave = 1;
    game_data.wave_timer = 0;
    game_data.spawn_timer = 0;
    game_data.enemies_remaining = 10;

    // Clear entities
    for (&game_data.bullets) |*b| b.active = false;
    for (&game_data.enemies) |*e| e.active = false;
    for (&game_data.enemy_bullets) |*b| b.active = false;
    for (&game_data.powerups) |*p| p.active = false;
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

pub fn returnToMenu() void {
    game_data.state = .menu;
}

// Input
pub fn setMove(dx: f32, dy: f32) void {
    game_data.move_x = std.math.clamp(dx, -1.0, 1.0);
    game_data.move_y = std.math.clamp(dy, -1.0, 1.0);
}

pub fn setFiring(firing: bool) void {
    game_data.firing = firing;
}

pub fn fireSpecial() void {
    if (game_data.state != .playing) return;
    if (game_data.player.special_ammo == 0) return;

    game_data.player.special_ammo -= 1;

    // Clear all enemy bullets
    for (&game_data.enemy_bullets) |*b| {
        b.active = false;
    }

    // Damage all enemies
    for (&game_data.enemies) |*e| {
        if (e.active) {
            e.health -|= 5;
            if (e.health == 0) {
                e.active = false;
                game_data.score += e.enemy_type.points();
                game_data.enemies_remaining -|= 1;
            }
        }
    }
}

pub fn update(delta: f32) void {
    if (game_data.state != .playing) return;

    updatePlayer(delta);
    updateBullets(delta);
    updateEnemies(delta);
    updateEnemyBullets(delta);
    updatePowerups(delta);
    updateSpawning(delta);
    checkCollisions();
    updateCombo(delta);

    // Check wave complete
    if (game_data.enemies_remaining == 0) {
        nextWave();
    }
}

fn updatePlayer(delta: f32) void {
    var p = &game_data.player;

    // Movement
    p.x += game_data.move_x * p.speed * delta;
    p.y += game_data.move_y * p.speed * delta;

    // Bounds
    p.x = std.math.clamp(p.x, 0, SCREEN_WIDTH - p.width);
    p.y = std.math.clamp(p.y, SCREEN_HEIGHT / 2, SCREEN_HEIGHT - p.height);

    // Invincibility timer
    if (p.invincible_timer > 0) {
        p.invincible_timer -= delta;
    }

    // Firing
    game_data.fire_timer -= delta;
    if (game_data.firing and game_data.fire_timer <= 0) {
        fireBullet();
        game_data.fire_timer = FIRE_RATE;
    }
}

fn fireBullet() void {
    const p = &game_data.player;
    const level = p.weapon_level;

    // Find inactive bullets and spawn based on level
    const positions = switch (level) {
        1 => &[_]f32{0},
        2 => &[_]f32{ -10, 10 },
        3 => &[_]f32{ -15, 0, 15 },
        else => &[_]f32{ -20, -8, 8, 20 },
    };

    for (positions) |offset| {
        for (&game_data.bullets) |*b| {
            if (!b.active) {
                b.x = p.x + p.width / 2 + offset;
                b.y = p.y;
                b.vx = 0;
                b.vy = -BULLET_SPEED;
                b.damage = 1;
                b.active = true;
                break;
            }
        }
    }
}

fn updateBullets(delta: f32) void {
    for (&game_data.bullets) |*b| {
        if (b.active) {
            b.x += b.vx * delta;
            b.y += b.vy * delta;

            // Remove if off screen
            if (b.y < -10 or b.y > SCREEN_HEIGHT + 10) {
                b.active = false;
            }
        }
    }
}

fn updateEnemies(delta: f32) void {
    for (&game_data.enemies) |*e| {
        if (!e.active) continue;

        // Movement
        e.y += e.enemy_type.speed() * delta;

        // Shooting (for shooter type)
        if (e.enemy_type == .shooter or e.enemy_type == .boss) {
            e.shoot_timer -= delta;
            if (e.shoot_timer <= 0) {
                spawnEnemyBullet(e.x + 15, e.y + 30);
                e.shoot_timer = if (e.enemy_type == .boss) 0.5 else 1.5;
            }
        }

        // Remove if off screen
        if (e.y > SCREEN_HEIGHT + 50) {
            e.active = false;
            game_data.enemies_remaining -|= 1;
        }
    }
}

fn spawnEnemyBullet(x: f32, y: f32) void {
    for (&game_data.enemy_bullets) |*b| {
        if (!b.active) {
            b.x = x;
            b.y = y;
            b.vx = 0;
            b.vy = ENEMY_BULLET_SPEED;
            b.active = true;
            break;
        }
    }
}

fn updateEnemyBullets(delta: f32) void {
    for (&game_data.enemy_bullets) |*b| {
        if (b.active) {
            b.x += b.vx * delta;
            b.y += b.vy * delta;

            if (b.y > SCREEN_HEIGHT + 10) {
                b.active = false;
            }
        }
    }
}

fn updatePowerups(delta: f32) void {
    for (&game_data.powerups) |*p| {
        if (p.active) {
            p.y += 60 * delta;

            if (p.y > SCREEN_HEIGHT + 20) {
                p.active = false;
            }
        }
    }
}

fn updateSpawning(delta: f32) void {
    game_data.spawn_timer -= delta;

    if (game_data.spawn_timer <= 0 and game_data.enemies_remaining > 0) {
        spawnEnemy();
        game_data.spawn_timer = 1.5 - @as(f32, @floatFromInt(game_data.current_wave)) * 0.1;
        if (game_data.spawn_timer < 0.3) game_data.spawn_timer = 0.3;
    }
}

fn spawnEnemy() void {
    for (&game_data.enemies) |*e| {
        if (!e.active) {
            e.x = randomFloat(50, SCREEN_WIDTH - 80);
            e.y = -40;

            // Determine type based on wave
            const roll = simpleRandom() % 100;
            if (game_data.current_wave >= 5 and roll < 5) {
                e.enemy_type = .boss;
            } else if (game_data.current_wave >= 3 and roll < 20) {
                e.enemy_type = .shooter;
            } else if (roll < 40) {
                e.enemy_type = .fast;
            } else if (roll < 60) {
                e.enemy_type = .tanky;
            } else {
                e.enemy_type = .basic;
            }

            e.health = e.enemy_type.health();
            e.shoot_timer = 1.0;
            e.active = true;
            break;
        }
    }
}

fn checkCollisions() void {
    const p = &game_data.player;

    // Player bullets vs enemies
    for (&game_data.bullets) |*b| {
        if (!b.active) continue;

        for (&game_data.enemies) |*e| {
            if (!e.active) continue;

            if (checkBoxCollision(b.x - 4, b.y - 8, 8, 16, e.x, e.y, 30, 30)) {
                b.active = false;
                e.health -|= b.damage;

                if (e.health == 0) {
                    e.active = false;
                    game_data.score += e.enemy_type.points() * (@as(u32, game_data.combo) + 1);
                    game_data.enemies_remaining -|= 1;
                    game_data.combo += 1;
                    game_data.combo_timer = 2.0;

                    // Chance to spawn powerup
                    if (simpleRandom() % 100 < 15) {
                        spawnPowerup(e.x, e.y);
                    }
                }
                break;
            }
        }
    }

    // Enemy bullets vs player
    if (p.invincible_timer <= 0) {
        for (&game_data.enemy_bullets) |*b| {
            if (!b.active) continue;

            if (checkBoxCollision(b.x - 4, b.y - 4, 8, 8, p.x, p.y, p.width, p.height)) {
                b.active = false;
                playerHit();
                break;
            }
        }

        // Enemies vs player
        for (&game_data.enemies) |*e| {
            if (!e.active) continue;

            if (checkBoxCollision(e.x, e.y, 30, 30, p.x, p.y, p.width, p.height)) {
                e.active = false;
                game_data.enemies_remaining -|= 1;
                playerHit();
                break;
            }
        }
    }

    // Powerups vs player
    for (&game_data.powerups) |*pow| {
        if (!pow.active) continue;

        if (checkBoxCollision(pow.x, pow.y, 20, 20, p.x, p.y, p.width, p.height)) {
            pow.active = false;
            collectPowerup(pow.power_type);
        }
    }
}

fn checkBoxCollision(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2;
}

fn playerHit() void {
    var p = &game_data.player;

    if (p.shield > 0) {
        p.shield -= 1;
    } else {
        game_data.lives -|= 1;
        p.invincible_timer = 2.0;
        game_data.combo = 0;

        if (game_data.lives == 0) {
            game_data.state = .game_over;
            if (game_data.score > game_data.high_score) {
                game_data.high_score = game_data.score;
            }
        }
    }
}

fn spawnPowerup(x: f32, y: f32) void {
    for (&game_data.powerups) |*p| {
        if (!p.active) {
            p.x = x;
            p.y = y;
            p.power_type = @enumFromInt(simpleRandom() % 4);
            p.active = true;
            break;
        }
    }
}

fn collectPowerup(power_type: PowerUpType) void {
    var p = &game_data.player;

    switch (power_type) {
        .weapon_upgrade => {
            if (p.weapon_level < 4) p.weapon_level += 1;
        },
        .shield => {
            if (p.shield < 3) p.shield += 1;
        },
        .speed => {
            p.speed = 400;
        },
        .special => {
            if (p.special_ammo < 5) p.special_ammo += 1;
        },
    }

    game_data.score += 50;
}

fn updateCombo(delta: f32) void {
    if (game_data.combo_timer > 0) {
        game_data.combo_timer -= delta;
        if (game_data.combo_timer <= 0) {
            game_data.combo = 0;
        }
    }
}

fn nextWave() void {
    game_data.current_wave += 1;
    game_data.enemies_remaining = 10 + game_data.current_wave * 2;
    game_data.wave_timer = 3.0;

    // Bonus points
    game_data.score += @as(u32, game_data.current_wave) * 500;

    if (game_data.current_wave > 10) {
        game_data.state = .victory;
        if (game_data.score > game_data.high_score) {
            game_data.high_score = game_data.score;
        }
    }
}

// Tests
test "game init" {
    init();
    defer deinit();
    try std.testing.expect(game_data.initialized);
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
    const initial_x = game_data.player.x;
    setMove(1.0, 0);
    update(0.1);
    try std.testing.expect(game_data.player.x > initial_x);
}

test "firing" {
    init();
    defer deinit();
    startGame();
    setFiring(true);
    game_data.fire_timer = 0;
    update(0.01);

    var bullet_count: usize = 0;
    for (game_data.bullets) |b| {
        if (b.active) bullet_count += 1;
    }
    try std.testing.expect(bullet_count > 0);
}
