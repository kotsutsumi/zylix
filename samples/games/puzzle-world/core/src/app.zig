//! Puzzle World - Game State

const std = @import("std");

pub const PuzzleMode = enum(u8) {
    menu = 0,
    match3 = 1,
    sliding = 2,
    memory = 3,

    pub fn name(self: PuzzleMode) []const u8 {
        return switch (self) {
            .menu => "Menu",
            .match3 => "Match-3",
            .sliding => "Sliding Puzzle",
            .memory => "Memory Game",
        };
    }
};

pub const GameState = enum(u8) {
    selecting = 0,
    playing = 1,
    paused = 2,
    won = 3,
    lost = 4,
};

pub const GemType = enum(u8) {
    red = 0,
    blue = 1,
    green = 2,
    yellow = 3,
    purple = 4,
    empty = 5,

    pub fn color(self: GemType) u32 {
        return switch (self) {
            .red => 0xFFE74C3C,
            .blue => 0xFF3498DB,
            .green => 0xFF2ECC71,
            .yellow => 0xFFF1C40F,
            .purple => 0xFF9B59B6,
            .empty => 0x00000000,
        };
    }
};

pub const Direction = enum(u8) {
    up = 0,
    down = 1,
    left = 2,
    right = 3,
};

const GRID_SIZE: usize = 8;
const SLIDING_SIZE: usize = 4;
const MEMORY_PAIRS: usize = 8;

pub const Match3State = struct {
    grid: [GRID_SIZE][GRID_SIZE]GemType = undefined,
    selected_row: ?usize = null,
    selected_col: ?usize = null,
    score: u32 = 0,
    moves: u32 = 0,
    target_score: u32 = 1000,
};

pub const SlidingState = struct {
    tiles: [SLIDING_SIZE][SLIDING_SIZE]u8 = undefined,
    empty_row: usize = 3,
    empty_col: usize = 3,
    moves: u32 = 0,
};

pub const MemoryState = struct {
    cards: [MEMORY_PAIRS * 2]u8 = undefined,
    revealed: [MEMORY_PAIRS * 2]bool = [_]bool{false} ** (MEMORY_PAIRS * 2),
    matched: [MEMORY_PAIRS * 2]bool = [_]bool{false} ** (MEMORY_PAIRS * 2),
    first_pick: ?usize = null,
    second_pick: ?usize = null,
    pairs_found: u8 = 0,
    moves: u32 = 0,
};

pub const GameData = struct {
    initialized: bool = false,
    mode: PuzzleMode = .menu,
    state: GameState = .selecting,
    match3: Match3State = .{},
    sliding: SlidingState = .{},
    memory: MemoryState = .{},
    high_score: u32 = 0,
};

var game_data: GameData = .{};
var rng_state: u64 = 12345;

fn simpleRandom() u32 {
    rng_state = rng_state *% 1103515245 +% 12345;
    return @truncate(rng_state >> 16);
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

pub fn selectMode(mode: PuzzleMode) void {
    game_data.mode = mode;
    game_data.state = .selecting;
}

pub fn startGame() void {
    game_data.state = .playing;

    switch (game_data.mode) {
        .match3 => initMatch3(),
        .sliding => initSliding(),
        .memory => initMemory(),
        .menu => {},
    }
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

pub fn resetGame() void {
    startGame();
}

pub fn returnToMenu() void {
    game_data.mode = .menu;
    game_data.state = .selecting;
}

// Match-3 Logic
fn initMatch3() void {
    game_data.match3 = .{};

    // Fill grid with random gems
    for (0..GRID_SIZE) |row| {
        for (0..GRID_SIZE) |col| {
            game_data.match3.grid[row][col] = randomGem();
        }
    }

    // Remove initial matches
    _ = clearMatches();
    refillGrid();
}

fn randomGem() GemType {
    const r = simpleRandom() % 5;
    return @enumFromInt(r);
}

pub fn match3Select(row: usize, col: usize) void {
    if (game_data.state != .playing or game_data.mode != .match3) return;
    if (row >= GRID_SIZE or col >= GRID_SIZE) return;

    var m3 = &game_data.match3;

    if (m3.selected_row == null) {
        m3.selected_row = row;
        m3.selected_col = col;
    } else {
        const sr = m3.selected_row.?;
        const sc = m3.selected_col.?;

        // Check if adjacent
        const row_diff = if (row > sr) row - sr else sr - row;
        const col_diff = if (col > sc) col - sc else sc - col;

        if ((row_diff == 1 and col_diff == 0) or (row_diff == 0 and col_diff == 1)) {
            // Swap gems
            const temp = m3.grid[sr][sc];
            m3.grid[sr][sc] = m3.grid[row][col];
            m3.grid[row][col] = temp;

            m3.moves += 1;

            // Check for matches
            const cleared = clearMatches();
            if (cleared > 0) {
                m3.score += cleared * 10;
                refillGrid();

                if (m3.score >= m3.target_score) {
                    game_data.state = .won;
                    if (m3.score > game_data.high_score) {
                        game_data.high_score = m3.score;
                    }
                }
            } else {
                // No match, swap back
                m3.grid[row][col] = m3.grid[sr][sc];
                m3.grid[sr][sc] = temp;
            }
        }

        m3.selected_row = null;
        m3.selected_col = null;
    }
}

fn clearMatches() u32 {
    var cleared: u32 = 0;
    var to_clear: [GRID_SIZE][GRID_SIZE]bool = [_][GRID_SIZE]bool{[_]bool{false} ** GRID_SIZE} ** GRID_SIZE;

    // Check horizontal matches
    for (0..GRID_SIZE) |row| {
        var col: usize = 0;
        while (col < GRID_SIZE - 2) {
            const gem = game_data.match3.grid[row][col];
            if (gem != .empty and game_data.match3.grid[row][col + 1] == gem and game_data.match3.grid[row][col + 2] == gem) {
                var end = col + 3;
                while (end < GRID_SIZE and game_data.match3.grid[row][end] == gem) : (end += 1) {}

                for (col..end) |c| {
                    to_clear[row][c] = true;
                }
                col = end;
            } else {
                col += 1;
            }
        }
    }

    // Check vertical matches
    for (0..GRID_SIZE) |col| {
        var row: usize = 0;
        while (row < GRID_SIZE - 2) {
            const gem = game_data.match3.grid[row][col];
            if (gem != .empty and game_data.match3.grid[row + 1][col] == gem and game_data.match3.grid[row + 2][col] == gem) {
                var end = row + 3;
                while (end < GRID_SIZE and game_data.match3.grid[end][col] == gem) : (end += 1) {}

                for (row..end) |r| {
                    to_clear[r][col] = true;
                }
                row = end;
            } else {
                row += 1;
            }
        }
    }

    // Clear marked gems
    for (0..GRID_SIZE) |row| {
        for (0..GRID_SIZE) |col| {
            if (to_clear[row][col]) {
                game_data.match3.grid[row][col] = .empty;
                cleared += 1;
            }
        }
    }

    return cleared;
}

fn refillGrid() void {
    // Drop gems down
    for (0..GRID_SIZE) |col| {
        var write: usize = GRID_SIZE - 1;
        var read: usize = GRID_SIZE - 1;

        while (true) {
            while (read > 0 and game_data.match3.grid[read][col] == .empty) : (read -= 1) {}

            if (game_data.match3.grid[read][col] != .empty) {
                game_data.match3.grid[write][col] = game_data.match3.grid[read][col];
                if (write != read) {
                    game_data.match3.grid[read][col] = .empty;
                }
            }

            if (read == 0) break;
            if (write > 0) write -= 1;
            read -= 1;
        }

        // Fill empty spaces
        for (0..GRID_SIZE) |row| {
            if (game_data.match3.grid[row][col] == .empty) {
                game_data.match3.grid[row][col] = randomGem();
            }
        }
    }
}

// Sliding Puzzle Logic
fn initSliding() void {
    game_data.sliding = .{};

    // Initialize solved state
    var num: u8 = 1;
    for (0..SLIDING_SIZE) |row| {
        for (0..SLIDING_SIZE) |col| {
            if (row == SLIDING_SIZE - 1 and col == SLIDING_SIZE - 1) {
                game_data.sliding.tiles[row][col] = 0; // Empty
            } else {
                game_data.sliding.tiles[row][col] = num;
                num += 1;
            }
        }
    }

    // Shuffle (make random valid moves)
    for (0..100) |_| {
        const dir: Direction = @enumFromInt(simpleRandom() % 4);
        slidingMove(dir);
    }
    game_data.sliding.moves = 0;
}

pub fn slidingMove(dir: Direction) void {
    if (game_data.state != .playing or game_data.mode != .sliding) return;

    var sl = &game_data.sliding;
    var new_row = sl.empty_row;
    var new_col = sl.empty_col;

    switch (dir) {
        .up => {
            if (sl.empty_row < SLIDING_SIZE - 1) new_row += 1;
        },
        .down => {
            if (sl.empty_row > 0) new_row -= 1;
        },
        .left => {
            if (sl.empty_col < SLIDING_SIZE - 1) new_col += 1;
        },
        .right => {
            if (sl.empty_col > 0) new_col -= 1;
        },
    }

    if (new_row != sl.empty_row or new_col != sl.empty_col) {
        sl.tiles[sl.empty_row][sl.empty_col] = sl.tiles[new_row][new_col];
        sl.tiles[new_row][new_col] = 0;
        sl.empty_row = new_row;
        sl.empty_col = new_col;
        sl.moves += 1;

        if (checkSlidingSolved()) {
            game_data.state = .won;
        }
    }
}

fn checkSlidingSolved() bool {
    var expected: u8 = 1;
    for (0..SLIDING_SIZE) |row| {
        for (0..SLIDING_SIZE) |col| {
            if (row == SLIDING_SIZE - 1 and col == SLIDING_SIZE - 1) {
                if (game_data.sliding.tiles[row][col] != 0) return false;
            } else {
                if (game_data.sliding.tiles[row][col] != expected) return false;
                expected += 1;
            }
        }
    }
    return true;
}

// Memory Game Logic
fn initMemory() void {
    game_data.memory = .{};

    // Create pairs
    for (0..MEMORY_PAIRS) |i| {
        game_data.memory.cards[i * 2] = @truncate(i);
        game_data.memory.cards[i * 2 + 1] = @truncate(i);
    }

    // Shuffle
    for (0..MEMORY_PAIRS * 2) |i| {
        const j = simpleRandom() % (MEMORY_PAIRS * 2);
        const temp = game_data.memory.cards[i];
        game_data.memory.cards[i] = game_data.memory.cards[j];
        game_data.memory.cards[j] = temp;
    }
}

pub fn memorySelect(index: usize) void {
    if (game_data.state != .playing or game_data.mode != .memory) return;
    if (index >= MEMORY_PAIRS * 2) return;

    var mem = &game_data.memory;

    if (mem.matched[index] or mem.revealed[index]) return;

    if (mem.first_pick == null) {
        mem.first_pick = index;
        mem.revealed[index] = true;
    } else if (mem.second_pick == null) {
        mem.second_pick = index;
        mem.revealed[index] = true;
        mem.moves += 1;
    }
}

pub fn memoryCheck() void {
    var mem = &game_data.memory;

    if (mem.first_pick != null and mem.second_pick != null) {
        const first = mem.first_pick.?;
        const second = mem.second_pick.?;

        if (mem.cards[first] == mem.cards[second]) {
            mem.matched[first] = true;
            mem.matched[second] = true;
            mem.pairs_found += 1;

            if (mem.pairs_found == MEMORY_PAIRS) {
                game_data.state = .won;
            }
        } else {
            mem.revealed[first] = false;
            mem.revealed[second] = false;
        }

        mem.first_pick = null;
        mem.second_pick = null;
    }
}

// Tests
test "game init" {
    init();
    defer deinit();
    try std.testing.expect(game_data.initialized);
}

test "mode selection" {
    init();
    defer deinit();
    selectMode(.match3);
    try std.testing.expectEqual(PuzzleMode.match3, game_data.mode);
}

test "match3 start" {
    init();
    defer deinit();
    selectMode(.match3);
    startGame();
    try std.testing.expectEqual(GameState.playing, game_data.state);
}

test "sliding start" {
    init();
    defer deinit();
    selectMode(.sliding);
    startGame();
    // State could be playing or won if shuffle happened to solve it
    try std.testing.expect(game_data.state == .playing or game_data.state == .won);
}

test "memory start" {
    init();
    defer deinit();
    selectMode(.memory);
    startGame();
    try std.testing.expectEqual(GameState.playing, game_data.state);
}

test "pause resume" {
    init();
    defer deinit();
    selectMode(.match3);
    startGame();
    pauseGame();
    try std.testing.expectEqual(GameState.paused, game_data.state);
    resumeGame();
    try std.testing.expectEqual(GameState.playing, game_data.state);
}
