//! Game Arcade - Application State

const std = @import("std");

pub const Game = enum(u32) {
    breakout = 0,
    snake = 1,
    pong = 2,
    memory = 3,

    pub fn title(self: Game) []const u8 {
        return switch (self) {
            .breakout => "Breakout",
            .snake => "Snake",
            .pong => "Pong",
            .memory => "Memory Match",
        };
    }

    pub fn description(self: Game) []const u8 {
        return switch (self) {
            .breakout => "Break all the bricks!",
            .snake => "Eat and grow longer!",
            .pong => "Classic paddle game",
            .memory => "Find matching pairs",
        };
    }
};

pub const GameState = enum(u8) {
    menu,
    playing,
    paused,
    game_over,
    victory,
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

// Breakout specific
pub const Paddle = struct {
    position: Vec2 = .{ .x = 160, .y = 280 },
    width: f32 = 60,
    height: f32 = 10,
    speed: f32 = 300,
};

pub const Ball = struct {
    position: Vec2 = .{ .x = 160, .y = 200 },
    velocity: Vec2 = .{ .x = 150, .y = -200 },
    radius: f32 = 6,
    active: bool = true,
};

pub const Brick = struct {
    x: u8,
    y: u8,
    active: bool = true,
    color: u8 = 0,
};

// Snake specific
pub const Direction = enum(u8) {
    up,
    down,
    left,
    right,
};

pub const SnakeSegment = struct {
    x: i16,
    y: i16,
};

// Pong specific
pub const PongPaddle = struct {
    y: f32,
    score: u32 = 0,
};

// Memory specific
pub const Card = struct {
    value: u8,
    flipped: bool = false,
    matched: bool = false,
};

pub const AppState = struct {
    initialized: bool = false,
    current_game: Game = .breakout,
    game_state: GameState = .menu,

    // Timing
    delta_time: f32 = 0,
    total_time: f32 = 0,
    frame_count: u64 = 0,

    // Score
    score: u32 = 0,
    high_score: u32 = 0,
    lives: u8 = 3,

    // Breakout state
    paddle: Paddle = .{},
    ball: Ball = .{},
    bricks: [40]Brick = undefined,
    brick_count: usize = 0,

    // Snake state
    snake: [100]SnakeSegment = undefined,
    snake_length: usize = 3,
    snake_direction: Direction = .right,
    food_x: i16 = 10,
    food_y: i16 = 10,
    move_timer: f32 = 0,
    move_interval: f32 = 0.15,

    // Pong state
    pong_ball: Ball = .{},
    player1: PongPaddle = .{ .y = 140 },
    player2: PongPaddle = .{ .y = 140 },

    // Memory state
    cards: [16]Card = undefined,
    first_card: ?usize = null,
    second_card: ?usize = null,
    matches_found: u8 = 0,
    flip_timer: f32 = 0,

    // Input
    input_x: f32 = 0,
    input_y: f32 = 0,
    action_pressed: bool = false,
};

var app_state: AppState = .{};
var prng: std.Random.Xoshiro256 = undefined;

pub fn init() void {
    prng = std.Random.Xoshiro256.init(12345);
    app_state = .{ .initialized = true };
    setupBreakout();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

pub fn getStateMut() *AppState {
    return &app_state;
}

fn setupBreakout() void {
    app_state.paddle = .{};
    app_state.ball = .{};
    app_state.brick_count = 0;

    // Create brick grid (8x5)
    for (0..5) |row| {
        for (0..8) |col| {
            if (app_state.brick_count < app_state.bricks.len) {
                app_state.bricks[app_state.brick_count] = .{
                    .x = @intCast(col),
                    .y = @intCast(row),
                    .color = @intCast(row),
                };
                app_state.brick_count += 1;
            }
        }
    }
}

fn setupSnake() void {
    app_state.snake_length = 3;
    app_state.snake_direction = .right;
    for (0..3) |i| {
        app_state.snake[i] = .{ .x = @intCast(5 - i), .y = 10 };
    }
    spawnFood();
}

fn setupPong() void {
    app_state.pong_ball = .{ .position = .{ .x = 160, .y = 120 }, .velocity = .{ .x = 150, .y = 100 } };
    app_state.player1 = .{ .y = 100 };
    app_state.player2 = .{ .y = 100 };
}

fn setupMemory() void {
    // Create pairs of cards (8 pairs = 16 cards)
    var values: [16]u8 = undefined;
    for (0..8) |i| {
        values[i * 2] = @intCast(i);
        values[i * 2 + 1] = @intCast(i);
    }
    // Shuffle
    var random = prng.random();
    for (0..16) |i| {
        const j = random.intRangeAtMost(usize, 0, 15);
        const tmp = values[i];
        values[i] = values[j];
        values[j] = tmp;
    }
    for (0..16) |i| {
        app_state.cards[i] = .{ .value = values[i] };
    }
    app_state.matches_found = 0;
    app_state.first_card = null;
    app_state.second_card = null;
}

fn spawnFood() void {
    var random = prng.random();
    app_state.food_x = random.intRangeAtMost(i16, 1, 18);
    app_state.food_y = random.intRangeAtMost(i16, 1, 18);
}

pub fn selectGame(game: Game) void {
    app_state.current_game = game;
    app_state.game_state = .menu;
    app_state.score = 0;
    app_state.lives = 3;

    switch (game) {
        .breakout => setupBreakout(),
        .snake => setupSnake(),
        .pong => setupPong(),
        .memory => setupMemory(),
    }
}

pub fn startGame() void {
    app_state.game_state = .playing;
}

pub fn pauseGame() void {
    if (app_state.game_state == .playing) {
        app_state.game_state = .paused;
    } else if (app_state.game_state == .paused) {
        app_state.game_state = .playing;
    }
}

pub fn setInput(x: f32, y: f32, action: bool) void {
    app_state.input_x = x;
    app_state.input_y = y;
    app_state.action_pressed = action;
}

pub fn update(dt: f32) void {
    if (app_state.game_state != .playing) return;

    app_state.delta_time = dt;
    app_state.total_time += dt;
    app_state.frame_count += 1;

    switch (app_state.current_game) {
        .breakout => updateBreakout(dt),
        .snake => updateSnake(dt),
        .pong => updatePong(dt),
        .memory => updateMemory(dt),
    }
}

fn updateBreakout(dt: f32) void {
    // Move paddle
    app_state.paddle.position.x += app_state.input_x * app_state.paddle.speed * dt;
    app_state.paddle.position.x = @max(30, @min(app_state.paddle.position.x, 290));

    // Move ball
    if (app_state.ball.active) {
        app_state.ball.position = app_state.ball.position.add(app_state.ball.velocity.scale(dt));

        // Wall bounce
        if (app_state.ball.position.x <= 6 or app_state.ball.position.x >= 314) {
            app_state.ball.velocity.x = -app_state.ball.velocity.x;
        }
        if (app_state.ball.position.y <= 6) {
            app_state.ball.velocity.y = -app_state.ball.velocity.y;
        }

        // Paddle collision
        if (app_state.ball.position.y >= 270 and app_state.ball.position.y <= 280) {
            const paddle_left = app_state.paddle.position.x - 30;
            const paddle_right = app_state.paddle.position.x + 30;
            if (app_state.ball.position.x >= paddle_left and app_state.ball.position.x <= paddle_right) {
                app_state.ball.velocity.y = -@abs(app_state.ball.velocity.y);
                const offset = (app_state.ball.position.x - app_state.paddle.position.x) / 30;
                app_state.ball.velocity.x = offset * 200;
            }
        }

        // Ball lost
        if (app_state.ball.position.y >= 300) {
            app_state.lives -= 1;
            if (app_state.lives == 0) {
                app_state.game_state = .game_over;
            } else {
                app_state.ball = .{};
            }
        }
    }

    // Check win condition
    var active_bricks: usize = 0;
    for (0..app_state.brick_count) |i| {
        if (app_state.bricks[i].active) active_bricks += 1;
    }
    if (active_bricks == 0) {
        app_state.game_state = .victory;
    }
}

fn updateSnake(dt: f32) void {
    app_state.move_timer += dt;
    if (app_state.move_timer < app_state.move_interval) return;
    app_state.move_timer = 0;

    // Calculate new head position
    var new_x = app_state.snake[0].x;
    var new_y = app_state.snake[0].y;

    switch (app_state.snake_direction) {
        .up => new_y -= 1,
        .down => new_y += 1,
        .left => new_x -= 1,
        .right => new_x += 1,
    }

    // Check wall collision
    if (new_x < 0 or new_x >= 20 or new_y < 0 or new_y >= 20) {
        app_state.game_state = .game_over;
        return;
    }

    // Check self collision
    for (0..app_state.snake_length) |i| {
        if (app_state.snake[i].x == new_x and app_state.snake[i].y == new_y) {
            app_state.game_state = .game_over;
            return;
        }
    }

    // Check food
    const ate_food = new_x == app_state.food_x and new_y == app_state.food_y;
    if (ate_food) {
        app_state.score += 10;
        if (app_state.snake_length < 100) {
            app_state.snake_length += 1;
        }
        spawnFood();
    }

    // Move body
    var i = app_state.snake_length;
    while (i > 0) : (i -= 1) {
        app_state.snake[i] = app_state.snake[i - 1];
    }
    app_state.snake[0] = .{ .x = new_x, .y = new_y };
}

fn updatePong(dt: f32) void {
    // Move ball
    app_state.pong_ball.position = app_state.pong_ball.position.add(app_state.pong_ball.velocity.scale(dt));

    // Wall bounce
    if (app_state.pong_ball.position.y <= 6 or app_state.pong_ball.position.y >= 234) {
        app_state.pong_ball.velocity.y = -app_state.pong_ball.velocity.y;
    }

    // Score
    if (app_state.pong_ball.position.x <= 0) {
        app_state.player2.score += 1;
        app_state.pong_ball = .{ .position = .{ .x = 160, .y = 120 }, .velocity = .{ .x = 150, .y = 100 } };
    }
    if (app_state.pong_ball.position.x >= 320) {
        app_state.player1.score += 1;
        app_state.pong_ball = .{ .position = .{ .x = 160, .y = 120 }, .velocity = .{ .x = -150, .y = -100 } };
    }
}

fn updateMemory(dt: f32) void {
    if (app_state.flip_timer > 0) {
        app_state.flip_timer -= dt;
        if (app_state.flip_timer <= 0) {
            // Flip cards back
            if (app_state.first_card) |c1| {
                app_state.cards[c1].flipped = false;
            }
            if (app_state.second_card) |c2| {
                app_state.cards[c2].flipped = false;
            }
            app_state.first_card = null;
            app_state.second_card = null;
        }
    }

    // Check win
    if (app_state.matches_found == 8) {
        app_state.game_state = .victory;
    }
}

pub fn flipCard(index: usize) void {
    if (index >= 16) return;
    if (app_state.cards[index].matched) return;
    if (app_state.flip_timer > 0) return;

    if (app_state.first_card == null) {
        app_state.first_card = index;
        app_state.cards[index].flipped = true;
    } else if (app_state.second_card == null and app_state.first_card != index) {
        app_state.second_card = index;
        app_state.cards[index].flipped = true;

        // Check match
        const c1 = app_state.first_card.?;
        const c2 = index;
        if (app_state.cards[c1].value == app_state.cards[c2].value) {
            app_state.cards[c1].matched = true;
            app_state.cards[c2].matched = true;
            app_state.matches_found += 1;
            app_state.score += 100;
            app_state.first_card = null;
            app_state.second_card = null;
        } else {
            app_state.flip_timer = 1.0;
        }
    }
}

pub fn setSnakeDirection(dir: Direction) void {
    // Prevent 180-degree turns
    const opposite: Direction = switch (app_state.snake_direction) {
        .up => .down,
        .down => .up,
        .left => .right,
        .right => .left,
    };
    if (dir != opposite) {
        app_state.snake_direction = dir;
    }
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.brick_count > 0);
}

test "game selection" {
    init();
    defer deinit();
    selectGame(.snake);
    try std.testing.expectEqual(Game.snake, app_state.current_game);
}

test "game start" {
    init();
    defer deinit();
    startGame();
    try std.testing.expectEqual(GameState.playing, app_state.game_state);
}

test "game metadata" {
    try std.testing.expectEqualStrings("Breakout", Game.breakout.title());
}
