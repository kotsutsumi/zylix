//! Game Loop System
//!
//! Provides a robust game loop with fixed timestep physics, variable rendering,
//! and frame rate management.

const std = @import("std");

/// Time source abstraction for testing
pub const TimeSource = struct {
    get_time_ns: *const fn () i128,

    pub const system = TimeSource{
        .get_time_ns = struct {
            fn f() i128 {
                return std.time.nanoTimestamp();
            }
        }.f,
    };
};

/// Frame timing statistics
pub const FrameStats = struct {
    frame_count: u64 = 0,
    total_time: f64 = 0,
    delta_time: f64 = 0,
    fps: f32 = 0,
    avg_fps: f32 = 0,
    min_fps: f32 = std.math.floatMax(f32),
    max_fps: f32 = 0,
    physics_time: f64 = 0,
    render_time: f64 = 0,
    update_time: f64 = 0,
    idle_time: f64 = 0,

    pub fn reset(self: *FrameStats) void {
        self.frame_count = 0;
        self.total_time = 0;
        self.min_fps = std.math.floatMax(f32);
        self.max_fps = 0;
    }
};

/// Fixed timestep configuration
pub const FixedTimestep = struct {
    /// Target physics updates per second
    target_fps: u32 = 60,
    /// Maximum accumulated time (prevents spiral of death)
    max_frame_time: f64 = 0.25,
    /// Interpolation alpha for rendering between physics states
    alpha: f64 = 0,

    accumulator: f64 = 0,
    fixed_delta: f64 = 1.0 / 60.0,

    pub fn init(target_fps: u32) FixedTimestep {
        return .{
            .target_fps = target_fps,
            .fixed_delta = 1.0 / @as(f64, @floatFromInt(target_fps)),
        };
    }

    /// Update accumulator and return number of physics steps needed
    pub fn update(self: *FixedTimestep, delta_time: f64) u32 {
        // Clamp frame time to prevent spiral of death
        const frame_time = @min(delta_time, self.max_frame_time);
        self.accumulator += frame_time;

        var steps: u32 = 0;
        while (self.accumulator >= self.fixed_delta) {
            self.accumulator -= self.fixed_delta;
            steps += 1;
        }

        // Calculate interpolation alpha for smooth rendering
        self.alpha = self.accumulator / self.fixed_delta;

        return steps;
    }

    /// Get fixed delta time in seconds
    pub fn getDelta(self: *const FixedTimestep) f64 {
        return self.fixed_delta;
    }

    /// Get interpolation alpha (0-1) for rendering
    pub fn getAlpha(self: *const FixedTimestep) f64 {
        return self.alpha;
    }
};

/// Game loop state
pub const LoopState = enum(u8) {
    stopped = 0,
    running = 1,
    paused = 2,
};

/// Game loop callbacks
pub const GameCallbacks = struct {
    /// Called once per physics step (fixed timestep)
    fixed_update: ?*const fn (delta: f64, user_data: ?*anyopaque) void = null,
    /// Called every frame (variable timestep)
    update: ?*const fn (delta: f64, user_data: ?*anyopaque) void = null,
    /// Called every frame for rendering
    render: ?*const fn (alpha: f64, user_data: ?*anyopaque) void = null,
    /// Called when loop starts
    on_start: ?*const fn (user_data: ?*anyopaque) void = null,
    /// Called when loop stops
    on_stop: ?*const fn (user_data: ?*anyopaque) void = null,
    /// Called when loop pauses
    on_pause: ?*const fn (user_data: ?*anyopaque) void = null,
    /// Called when loop resumes
    on_resume: ?*const fn (user_data: ?*anyopaque) void = null,
    /// User data passed to callbacks
    user_data: ?*anyopaque = null,
};

/// Main game loop manager
pub const GameLoop = struct {
    // Configuration
    target_fps: u32 = 60,
    fixed_timestep: FixedTimestep,
    vsync: bool = true,
    frame_rate_limit: ?u32 = null,

    // State
    state: LoopState = .stopped,
    callbacks: GameCallbacks = .{},
    stats: FrameStats = .{},

    // Timing
    time_source: TimeSource = TimeSource.system,
    last_time: i128 = 0,
    start_time: i128 = 0,
    pause_time: i128 = 0,
    total_pause_time: i128 = 0,

    // Frame pacing
    frame_duration_ns: i128 = 16_666_667, // ~60fps in nanoseconds

    pub fn init(target_fps: u32) GameLoop {
        return .{
            .target_fps = target_fps,
            .fixed_timestep = FixedTimestep.init(target_fps),
            .frame_duration_ns = @divFloor(1_000_000_000, target_fps),
        };
    }

    pub fn setCallbacks(self: *GameLoop, callbacks: GameCallbacks) void {
        self.callbacks = callbacks;
    }

    pub fn setTargetFps(self: *GameLoop, fps: u32) void {
        self.target_fps = fps;
        self.fixed_timestep = FixedTimestep.init(fps);
        self.frame_duration_ns = @divFloor(1_000_000_000, fps);
    }

    pub fn setFrameRateLimit(self: *GameLoop, fps: ?u32) void {
        self.frame_rate_limit = fps;
        if (fps) |f| {
            self.frame_duration_ns = @divFloor(1_000_000_000, f);
        }
    }

    pub fn start(self: *GameLoop) void {
        if (self.state != .stopped) return;

        self.state = .running;
        self.start_time = self.time_source.get_time_ns();
        self.last_time = self.start_time;
        self.total_pause_time = 0;
        self.stats.reset();

        if (self.callbacks.on_start) |callback| {
            callback(self.callbacks.user_data);
        }
    }

    pub fn stop(self: *GameLoop) void {
        if (self.state == .stopped) return;

        self.state = .stopped;

        if (self.callbacks.on_stop) |callback| {
            callback(self.callbacks.user_data);
        }
    }

    pub fn pause(self: *GameLoop) void {
        if (self.state != .running) return;

        self.state = .paused;
        self.pause_time = self.time_source.get_time_ns();

        if (self.callbacks.on_pause) |callback| {
            callback(self.callbacks.user_data);
        }
    }

    pub fn resume(self: *GameLoop) void {
        if (self.state != .paused) return;

        self.state = .running;
        const current_time = self.time_source.get_time_ns();
        self.total_pause_time += current_time - self.pause_time;
        self.last_time = current_time;

        if (self.callbacks.on_resume) |callback| {
            callback(self.callbacks.user_data);
        }
    }

    pub fn toggle(self: *GameLoop) void {
        if (self.state == .running) {
            self.pause();
        } else if (self.state == .paused) {
            self.resume();
        }
    }

    /// Process one frame. Returns true if the loop should continue.
    pub fn tick(self: *GameLoop) bool {
        if (self.state != .running) return self.state != .stopped;

        const current_time = self.time_source.get_time_ns();
        const elapsed_ns = current_time - self.last_time;
        const delta_time = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;

        // Update timing
        self.last_time = current_time;
        self.stats.delta_time = delta_time;
        self.stats.total_time = @as(f64, @floatFromInt(current_time - self.start_time - self.total_pause_time)) / 1_000_000_000.0;
        self.stats.frame_count += 1;

        // Calculate FPS
        if (delta_time > 0) {
            self.stats.fps = @floatCast(1.0 / delta_time);
            self.stats.min_fps = @min(self.stats.min_fps, self.stats.fps);
            self.stats.max_fps = @max(self.stats.max_fps, self.stats.fps);
            if (self.stats.frame_count > 0) {
                self.stats.avg_fps = @floatCast(@as(f64, @floatFromInt(self.stats.frame_count)) / self.stats.total_time);
            }
        }

        // Fixed timestep physics updates
        const physics_start = self.time_source.get_time_ns();
        const physics_steps = self.fixed_timestep.update(delta_time);

        if (self.callbacks.fixed_update) |fixed_update| {
            const fixed_delta = self.fixed_timestep.getDelta();
            var i: u32 = 0;
            while (i < physics_steps) : (i += 1) {
                fixed_update(fixed_delta, self.callbacks.user_data);
            }
        }
        self.stats.physics_time = @as(f64, @floatFromInt(self.time_source.get_time_ns() - physics_start)) / 1_000_000_000.0;

        // Variable timestep update
        const update_start = self.time_source.get_time_ns();
        if (self.callbacks.update) |update| {
            update(delta_time, self.callbacks.user_data);
        }
        self.stats.update_time = @as(f64, @floatFromInt(self.time_source.get_time_ns() - update_start)) / 1_000_000_000.0;

        // Render with interpolation
        const render_start = self.time_source.get_time_ns();
        if (self.callbacks.render) |render| {
            render(self.fixed_timestep.getAlpha(), self.callbacks.user_data);
        }
        self.stats.render_time = @as(f64, @floatFromInt(self.time_source.get_time_ns() - render_start)) / 1_000_000_000.0;

        // Frame rate limiting
        if (self.frame_rate_limit != null and !self.vsync) {
            const frame_end = self.time_source.get_time_ns();
            const frame_elapsed = frame_end - current_time;
            const sleep_time = self.frame_duration_ns - frame_elapsed;

            if (sleep_time > 0) {
                std.time.sleep(@intCast(sleep_time));
                self.stats.idle_time = @as(f64, @floatFromInt(sleep_time)) / 1_000_000_000.0;
            } else {
                self.stats.idle_time = 0;
            }
        }

        return true;
    }

    /// Run the game loop until stopped
    pub fn run(self: *GameLoop) void {
        self.start();
        while (self.tick()) {}
    }

    pub fn isRunning(self: *const GameLoop) bool {
        return self.state == .running;
    }

    pub fn isPaused(self: *const GameLoop) bool {
        return self.state == .paused;
    }

    pub fn isStopped(self: *const GameLoop) bool {
        return self.state == .stopped;
    }

    pub fn getStats(self: *const GameLoop) FrameStats {
        return self.stats;
    }

    pub fn getDeltaTime(self: *const GameLoop) f64 {
        return self.stats.delta_time;
    }

    pub fn getTotalTime(self: *const GameLoop) f64 {
        return self.stats.total_time;
    }

    pub fn getFrameCount(self: *const GameLoop) u64 {
        return self.stats.frame_count;
    }

    pub fn getFps(self: *const GameLoop) f32 {
        return self.stats.fps;
    }
};

/// Simple timer for game events
pub const Timer = struct {
    duration: f64,
    elapsed: f64 = 0,
    repeat: bool = false,
    running: bool = false,
    callback: ?*const fn (*Timer, ?*anyopaque) void = null,
    user_data: ?*anyopaque = null,

    pub fn init(duration: f64, repeat: bool) Timer {
        return .{
            .duration = duration,
            .repeat = repeat,
        };
    }

    pub fn start(self: *Timer) void {
        self.running = true;
        self.elapsed = 0;
    }

    pub fn stop(self: *Timer) void {
        self.running = false;
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }

    pub fn update(self: *Timer, delta_time: f64) bool {
        if (!self.running) return false;

        self.elapsed += delta_time;

        if (self.elapsed >= self.duration) {
            if (self.callback) |cb| {
                cb(self, self.user_data);
            }

            if (self.repeat) {
                self.elapsed -= self.duration;
                return true;
            } else {
                self.running = false;
                return true;
            }
        }

        return false;
    }

    pub fn getProgress(self: *const Timer) f64 {
        return @min(1.0, self.elapsed / self.duration);
    }

    pub fn getRemainingTime(self: *const Timer) f64 {
        return @max(0, self.duration - self.elapsed);
    }
};

/// Timer manager for multiple timers
pub const TimerManager = struct {
    allocator: std.mem.Allocator,
    timers: std.ArrayListUnmanaged(Timer) = .{},

    pub fn init(allocator: std.mem.Allocator) TimerManager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TimerManager) void {
        self.timers.deinit(self.allocator);
    }

    pub fn add(self: *TimerManager, timer: Timer) !*Timer {
        try self.timers.append(self.allocator, timer);
        return &self.timers.items[self.timers.items.len - 1];
    }

    pub fn setTimeout(self: *TimerManager, duration: f64, callback: *const fn (*Timer, ?*anyopaque) void, user_data: ?*anyopaque) !*Timer {
        var timer = Timer.init(duration, false);
        timer.callback = callback;
        timer.user_data = user_data;
        timer.start();
        return self.add(timer);
    }

    pub fn setInterval(self: *TimerManager, duration: f64, callback: *const fn (*Timer, ?*anyopaque) void, user_data: ?*anyopaque) !*Timer {
        var timer = Timer.init(duration, true);
        timer.callback = callback;
        timer.user_data = user_data;
        timer.start();
        return self.add(timer);
    }

    pub fn update(self: *TimerManager, delta_time: f64) void {
        // Update all timers and remove completed non-repeating ones
        var i: usize = 0;
        while (i < self.timers.items.len) {
            const completed = self.timers.items[i].update(delta_time);
            if (completed and !self.timers.items[i].repeat and !self.timers.items[i].running) {
                _ = self.timers.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn clear(self: *TimerManager) void {
        self.timers.clearRetainingCapacity();
    }
};

test "FixedTimestep basic" {
    var timestep = FixedTimestep.init(60);

    // Simulate 17ms frame (slightly over 16.67ms)
    const steps = timestep.update(0.017);
    try std.testing.expectEqual(@as(u32, 1), steps);

    // Accumulator should have remainder
    try std.testing.expect(timestep.alpha > 0);
}

test "FixedTimestep spiral of death prevention" {
    var timestep = FixedTimestep.init(60);

    // Simulate very long frame (1 second)
    const steps = timestep.update(1.0);

    // Should be clamped to max_frame_time (0.25s)
    // 0.25s / (1/60)s = 15 steps max
    try std.testing.expect(steps <= 15);
}

test "Timer basic" {
    var timer = Timer.init(1.0, false);
    timer.start();

    try std.testing.expect(timer.running);

    // Update for 0.5 seconds
    _ = timer.update(0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), timer.getProgress(), 0.001);

    // Update for another 0.6 seconds (should complete)
    const completed = timer.update(0.6);
    try std.testing.expect(completed);
    try std.testing.expect(!timer.running);
}

test "GameLoop state transitions" {
    var loop = GameLoop.init(60);

    try std.testing.expect(loop.isStopped());

    loop.start();
    try std.testing.expect(loop.isRunning());

    loop.pause();
    try std.testing.expect(loop.isPaused());

    loop.resume();
    try std.testing.expect(loop.isRunning());

    loop.stop();
    try std.testing.expect(loop.isStopped());
}
