//! ZigDom Particle System
//!
//! GPU-accelerated particle system using WebGPU compute shaders.
//! Zig handles initialization and parameter configuration.
//! GPU compute shaders handle physics simulation.

const std = @import("std");
const gpu = @import("gpu.zig");

/// Maximum particle count
pub const MAX_PARTICLES: usize = 100_000;

/// Default particle count
pub const DEFAULT_PARTICLE_COUNT: usize = 50_000;

/// Particle data structure (32 bytes, GPU-aligned)
pub const Particle = extern struct {
    // Position (x, y) - 8 bytes
    pos_x: f32 = 0,
    pos_y: f32 = 0,

    // Velocity (x, y) - 8 bytes
    vel_x: f32 = 0,
    vel_y: f32 = 0,

    // Color (r, g, b, a) - 16 bytes
    color_r: f32 = 1,
    color_g: f32 = 1,
    color_b: f32 = 1,
    color_a: f32 = 1,
};

/// Simulation parameters (uniform buffer, 64 bytes)
pub const SimParams = extern struct {
    // Time
    delta_time: f32 = 0.016,
    total_time: f32 = 0,

    // Physics
    gravity_x: f32 = 0,
    gravity_y: f32 = -0.5,

    // Bounds (-1 to 1 normalized)
    bounds_min_x: f32 = -1.0,
    bounds_min_y: f32 = -1.0,
    bounds_max_x: f32 = 1.0,
    bounds_max_y: f32 = 1.0,

    // Particle behavior
    damping: f32 = 0.99,
    bounce: f32 = 0.8,

    // Count
    particle_count: u32 = DEFAULT_PARTICLE_COUNT,
    _pad1: u32 = 0,

    // Mouse interaction
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    mouse_strength: f32 = 0,
    mouse_radius: f32 = 0.2,
};

// === Global State ===

var particles: [MAX_PARTICLES]Particle = undefined;
var sim_params: SimParams = .{};
var particle_count: usize = DEFAULT_PARTICLE_COUNT;
var initialized: bool = false;

// Simple PRNG (xorshift32)
var rng_state: u32 = 12345;

fn xorshift32() u32 {
    var x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng_state = x;
    return x;
}

fn randomFloat() f32 {
    return @as(f32, @floatFromInt(xorshift32())) / @as(f32, @floatFromInt(std.math.maxInt(u32)));
}

fn randomRange(min: f32, max: f32) f32 {
    return min + randomFloat() * (max - min);
}

// === Initialization ===

/// Initialize particle system with given count
pub fn init(count: usize) void {
    particle_count = @min(count, MAX_PARTICLES);
    sim_params.particle_count = @intCast(particle_count);

    // Initialize particles with random positions and velocities
    for (0..particle_count) |i| {
        particles[i] = .{
            // Random position in center area
            .pos_x = randomRange(-0.5, 0.5),
            .pos_y = randomRange(0.0, 0.8),

            // Random velocity (upward burst)
            .vel_x = randomRange(-0.3, 0.3),
            .vel_y = randomRange(0.2, 0.8),

            // Random color (warm palette)
            .color_r = randomRange(0.8, 1.0),
            .color_g = randomRange(0.3, 0.8),
            .color_b = randomRange(0.1, 0.4),
            .color_a = randomRange(0.6, 1.0),
        };
    }

    sim_params.total_time = 0;
    initialized = true;
}

/// Deinitialize particle system
pub fn deinit() void {
    initialized = false;
}

/// Reset particles to initial state
pub fn reset() void {
    if (initialized) {
        init(particle_count);
    }
}

// === Parameter Control ===

/// Update simulation time
pub fn updateTime(delta: f32) void {
    sim_params.delta_time = delta;
    sim_params.total_time += delta;
}

/// Set gravity
pub fn setGravity(x: f32, y: f32) void {
    sim_params.gravity_x = x;
    sim_params.gravity_y = y;
}

/// Set mouse interaction
pub fn setMouse(x: f32, y: f32, strength: f32) void {
    sim_params.mouse_x = x;
    sim_params.mouse_y = y;
    sim_params.mouse_strength = strength;
}

/// Set damping (0-1, higher = less slowdown)
pub fn setDamping(d: f32) void {
    sim_params.damping = d;
}

/// Set bounce factor (0-1)
pub fn setBounce(b: f32) void {
    sim_params.bounce = b;
}

// === Buffer Access ===

/// Get pointer to particle buffer
pub fn getParticleBuffer() *const [MAX_PARTICLES]Particle {
    return &particles;
}

/// Get particle buffer size in bytes (for current count)
pub fn getParticleBufferSize() usize {
    return particle_count * @sizeOf(Particle);
}

/// Get pointer to simulation parameters
pub fn getSimParams() *const SimParams {
    return &sim_params;
}

/// Get simulation parameters size
pub fn getSimParamsSize() usize {
    return @sizeOf(SimParams);
}

/// Get current particle count
pub fn getParticleCount() u32 {
    return @intCast(particle_count);
}

/// Set particle count (will reinitialize)
pub fn setParticleCount(count: usize) void {
    init(count);
}

// === Emitter Functions ===

/// Emit particles from a point
pub fn emitFrom(x: f32, y: f32, count: usize, spread: f32, speed: f32) void {
    if (!initialized) return;

    const emit_count = @min(count, particle_count);

    for (0..emit_count) |i| {
        const angle = randomRange(0, std.math.pi * 2);
        const vel = randomRange(speed * 0.5, speed);

        particles[i] = .{
            .pos_x = x + randomRange(-0.01, 0.01),
            .pos_y = y + randomRange(-0.01, 0.01),
            .vel_x = @cos(angle) * vel * spread,
            .vel_y = @sin(angle) * vel,
            .color_r = randomRange(0.9, 1.0),
            .color_g = randomRange(0.5, 0.9),
            .color_b = randomRange(0.2, 0.5),
            .color_a = 1.0,
        };
    }
}

/// Create fountain effect
pub fn fountainPreset() void {
    setGravity(0, -0.8);
    setDamping(0.995);
    setBounce(0.6);
    emitFrom(0, -0.8, particle_count, 0.3, 1.5);
}

/// Create explosion effect
pub fn explosionPreset() void {
    setGravity(0, -0.2);
    setDamping(0.98);
    setBounce(0.4);
    emitFrom(0, 0, particle_count, 1.0, 2.0);
}

/// Create rain effect
pub fn rainPreset() void {
    setGravity(0, -1.5);
    setDamping(0.999);
    setBounce(0.3);

    for (0..particle_count) |i| {
        particles[i] = .{
            .pos_x = randomRange(-1.0, 1.0),
            .pos_y = randomRange(0.5, 1.0),
            .vel_x = randomRange(-0.05, 0.05),
            .vel_y = randomRange(-0.5, -0.2),
            .color_r = 0.4,
            .color_g = 0.6,
            .color_b = 1.0,
            .color_a = randomRange(0.3, 0.7),
        };
    }
}

// === Tests ===

test "Particle struct size is 32 bytes" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Particle));
}

test "SimParams struct size is 64 bytes" {
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(SimParams));
}

test "particle initialization" {
    init(1000);
    try std.testing.expect(initialized);
    try std.testing.expectEqual(@as(u32, 1000), getParticleCount());

    const buffer = getParticleBuffer();
    // Check first particle has valid position
    try std.testing.expect(buffer[0].pos_x >= -1.0 and buffer[0].pos_x <= 1.0);
    try std.testing.expect(buffer[0].pos_y >= -1.0 and buffer[0].pos_y <= 1.0);

    deinit();
}
