//! Zylix Device - Haptics Module
//!
//! Haptic feedback for all platforms.
//! Supports impact, notification, and selection feedback types.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;

// === Haptic Feedback Types ===

/// Impact feedback style
pub const ImpactStyle = enum(u8) {
    light = 0,
    medium = 1,
    heavy = 2,
    soft = 3, // iOS 13+
    rigid = 4, // iOS 13+
};

/// Notification feedback type
pub const NotificationType = enum(u8) {
    success = 0,
    warning = 1,
    @"error" = 2,
};

/// Selection feedback (single tick)
pub const SelectionType = enum(u8) {
    selection_changed = 0,
};

/// Custom haptic pattern element
pub const PatternElement = union(enum) {
    /// Transient (short) haptic
    transient: struct {
        intensity: f32 = 1.0, // 0.0 - 1.0
        sharpness: f32 = 1.0, // 0.0 - 1.0
    },

    /// Continuous haptic
    continuous: struct {
        intensity: f32 = 1.0,
        sharpness: f32 = 1.0,
        duration: f64 = 0.1, // seconds
    },

    /// Pause between elements
    pause: f64, // seconds
};

/// Custom haptic pattern
pub const HapticPattern = struct {
    elements: [16]?PatternElement = [_]?PatternElement{null} ** 16,
    element_count: usize = 0,

    pub fn addTransient(self: *HapticPattern, intensity: f32, sharpness: f32) bool {
        if (self.element_count >= 16) return false;
        self.elements[self.element_count] = .{
            .transient = .{ .intensity = intensity, .sharpness = sharpness },
        };
        self.element_count += 1;
        return true;
    }

    pub fn addContinuous(self: *HapticPattern, intensity: f32, sharpness: f32, duration: f64) bool {
        if (self.element_count >= 16) return false;
        self.elements[self.element_count] = .{
            .continuous = .{ .intensity = intensity, .sharpness = sharpness, .duration = duration },
        };
        self.element_count += 1;
        return true;
    }

    pub fn addPause(self: *HapticPattern, duration: f64) bool {
        if (self.element_count >= 16) return false;
        self.elements[self.element_count] = .{ .pause = duration };
        self.element_count += 1;
        return true;
    }

    pub fn clear(self: *HapticPattern) void {
        for (&self.elements) |*e| e.* = null;
        self.element_count = 0;
    }
};

// === Haptics Engine ===

/// Haptics engine
pub const HapticsEngine = struct {
    is_available: bool = false,
    is_enabled: bool = true,
    intensity_multiplier: f32 = 1.0, // Global intensity adjustment

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{ .is_available = checkHardwareSupport() };
    }

    pub fn deinit(self: *Self) void {
        self.platform_handle = null;
    }

    /// Check if haptics hardware is available
    fn checkHardwareSupport() bool {
        // Platform-specific implementation
        return true; // Assume available, actual check done at runtime
    }

    /// Enable/disable haptics globally
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.is_enabled = enabled;
    }

    /// Set global intensity multiplier (0.0 - 1.0)
    pub fn setIntensityMultiplier(self: *Self, multiplier: f32) Result {
        if (multiplier < 0 or multiplier > 1) {
            return .invalid_arg;
        }
        self.intensity_multiplier = multiplier;
        return .ok;
    }

    /// Generate impact feedback
    pub fn impact(self: *Self, style: ImpactStyle, intensity: f32) Result {
        if (!self.is_enabled or !self.is_available) {
            return .not_available;
        }
        _ = style;
        _ = intensity;
        // Platform-specific implementation
        return .ok;
    }

    /// Generate notification feedback
    pub fn notification(self: *Self, notification_type: NotificationType) Result {
        if (!self.is_enabled or !self.is_available) {
            return .not_available;
        }
        _ = notification_type;
        // Platform-specific implementation
        return .ok;
    }

    /// Generate selection feedback
    pub fn selection(self: *Self) Result {
        if (!self.is_enabled or !self.is_available) {
            return .not_available;
        }
        // Platform-specific implementation
        return .ok;
    }

    /// Play custom haptic pattern
    pub fn playPattern(self: *Self, pattern: *const HapticPattern) Result {
        if (!self.is_enabled or !self.is_available) {
            return .not_available;
        }
        if (pattern.element_count == 0) {
            return .invalid_arg;
        }
        // Platform-specific implementation
        return .ok;
    }

    /// Stop any playing haptic pattern
    pub fn stop(self: *Self) void {
        if (!self.is_available) return;
        // Platform-specific implementation
    }

    /// Prepare haptic engine (reduces latency for first haptic)
    pub fn prepare(self: *Self) Result {
        if (!self.is_available) {
            return .not_available;
        }
        // Platform-specific implementation
        return .ok;
    }
};

// === Global Instance ===

var global_engine: ?HapticsEngine = null;

pub fn getEngine() *HapticsEngine {
    if (global_engine == null) {
        global_engine = HapticsEngine.init();
    }
    return &global_engine.?;
}

pub fn init() Result {
    if (global_engine != null) return .ok;
    global_engine = HapticsEngine.init();
    return .ok;
}

pub fn deinit() void {
    if (global_engine) |*e| e.deinit();
    global_engine = null;
}

// === Convenience Functions ===

/// Light impact
pub fn lightImpact() Result {
    return getEngine().impact(.light, 1.0);
}

/// Medium impact
pub fn mediumImpact() Result {
    return getEngine().impact(.medium, 1.0);
}

/// Heavy impact
pub fn heavyImpact() Result {
    return getEngine().impact(.heavy, 1.0);
}

/// Success notification
pub fn successNotification() Result {
    return getEngine().notification(.success);
}

/// Warning notification
pub fn warningNotification() Result {
    return getEngine().notification(.warning);
}

/// Error notification
pub fn errorNotification() Result {
    return getEngine().notification(.@"error");
}

/// Selection changed
pub fn selectionChanged() Result {
    return getEngine().selection();
}

// === Simplified Pulse API (#45) ===

/// Pulse intensity presets
pub const PulseIntensity = enum(u8) {
    soft = 0,
    light = 1,
    medium = 2,
    strong = 3,
    heavy = 4,

    /// Get normalized intensity value (0.0 - 1.0)
    pub fn toFloat(self: PulseIntensity) f32 {
        return switch (self) {
            .soft => 0.2,
            .light => 0.4,
            .medium => 0.6,
            .strong => 0.8,
            .heavy => 1.0,
        };
    }

    /// Get corresponding impact style
    pub fn toImpactStyle(self: PulseIntensity) ImpactStyle {
        return switch (self) {
            .soft => .soft,
            .light => .light,
            .medium => .medium,
            .strong => .heavy,
            .heavy => .rigid,
        };
    }
};

/// Simple haptic pulse with default medium intensity
/// This is the simplest cross-platform haptic API
pub fn pulse() Result {
    return pulseWithIntensity(.medium);
}

/// Haptic pulse with specified intensity preset
pub fn pulseWithIntensity(intensity: PulseIntensity) Result {
    const engine = getEngine();
    if (!engine.is_enabled or !engine.is_available) {
        return .not_available;
    }

    const style = intensity.toImpactStyle();
    const intensity_value = intensity.toFloat() * engine.intensity_multiplier;

    return engine.impact(style, intensity_value);
}

/// Haptic pulse with custom intensity (0.0 - 1.0)
pub fn pulseWithCustomIntensity(intensity: f32) Result {
    if (intensity < 0.0 or intensity > 1.0) {
        return .invalid_arg;
    }

    const engine = getEngine();
    if (!engine.is_enabled or !engine.is_available) {
        return .not_available;
    }

    // Map intensity to appropriate style
    const style: ImpactStyle = if (intensity < 0.2)
        .soft
    else if (intensity < 0.4)
        .light
    else if (intensity < 0.7)
        .medium
    else if (intensity < 0.9)
        .heavy
    else
        .rigid;

    const adjusted_intensity = intensity * engine.intensity_multiplier;

    return engine.impact(style, adjusted_intensity);
}

/// Double pulse pattern (useful for confirmations)
pub fn doublePulse() Result {
    const engine = getEngine();
    if (!engine.is_enabled or !engine.is_available) {
        return .not_available;
    }

    var pattern = HapticPattern{};
    _ = pattern.addTransient(0.8, 0.7);
    _ = pattern.addPause(0.05);
    _ = pattern.addTransient(0.6, 0.5);

    return engine.playPattern(&pattern);
}

/// Triple pulse pattern (useful for alerts)
pub fn triplePulse() Result {
    const engine = getEngine();
    if (!engine.is_enabled or !engine.is_available) {
        return .not_available;
    }

    var pattern = HapticPattern{};
    _ = pattern.addTransient(0.7, 0.6);
    _ = pattern.addPause(0.04);
    _ = pattern.addTransient(0.7, 0.6);
    _ = pattern.addPause(0.04);
    _ = pattern.addTransient(0.7, 0.6);

    return engine.playPattern(&pattern);
}

/// Quick tick pulse (for UI interactions)
pub fn tick() Result {
    return pulseWithIntensity(.light);
}

/// Buzz pulse (longer, continuous feel)
pub fn buzz() Result {
    const engine = getEngine();
    if (!engine.is_enabled or !engine.is_available) {
        return .not_available;
    }

    var pattern = HapticPattern{};
    _ = pattern.addContinuous(0.5, 0.4, 0.1);

    return engine.playPattern(&pattern);
}

// === Tests ===

test "HapticsEngine initialization" {
    var engine = HapticsEngine.init();
    defer engine.deinit();

    try std.testing.expect(engine.is_enabled);
    try std.testing.expectEqual(@as(f32, 1.0), engine.intensity_multiplier);
}

test "HapticPattern building" {
    var pattern = HapticPattern{};

    try std.testing.expect(pattern.addTransient(1.0, 0.5));
    try std.testing.expect(pattern.addPause(0.1));
    try std.testing.expect(pattern.addContinuous(0.8, 0.6, 0.2));
    try std.testing.expectEqual(@as(usize, 3), pattern.element_count);

    pattern.clear();
    try std.testing.expectEqual(@as(usize, 0), pattern.element_count);
}

test "Intensity multiplier validation" {
    var engine = HapticsEngine.init();
    defer engine.deinit();

    try std.testing.expectEqual(Result.ok, engine.setIntensityMultiplier(0.5));
    try std.testing.expectEqual(Result.invalid_arg, engine.setIntensityMultiplier(1.5));
    try std.testing.expectEqual(Result.invalid_arg, engine.setIntensityMultiplier(-0.1));
}

test "PulseIntensity conversions" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), PulseIntensity.soft.toFloat(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), PulseIntensity.light.toFloat(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), PulseIntensity.medium.toFloat(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), PulseIntensity.strong.toFloat(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), PulseIntensity.heavy.toFloat(), 0.01);

    try std.testing.expectEqual(ImpactStyle.soft, PulseIntensity.soft.toImpactStyle());
    try std.testing.expectEqual(ImpactStyle.light, PulseIntensity.light.toImpactStyle());
    try std.testing.expectEqual(ImpactStyle.medium, PulseIntensity.medium.toImpactStyle());
    try std.testing.expectEqual(ImpactStyle.heavy, PulseIntensity.strong.toImpactStyle());
    try std.testing.expectEqual(ImpactStyle.rigid, PulseIntensity.heavy.toImpactStyle());
}

test "Pulse API basic functionality" {
    // These test the code path, actual haptic feedback would require platform support
    _ = pulse();
    _ = pulseWithIntensity(.light);
    _ = pulseWithIntensity(.heavy);
    _ = tick();
    _ = doublePulse();
    _ = triplePulse();
    _ = buzz();
}

test "Custom intensity validation" {
    try std.testing.expectEqual(Result.invalid_arg, pulseWithCustomIntensity(-0.1));
    try std.testing.expectEqual(Result.invalid_arg, pulseWithCustomIntensity(1.5));
}
