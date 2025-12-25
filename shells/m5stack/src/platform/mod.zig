//! M5Stack CoreS3 Platform Module for Zylix
//!
//! High-level platform abstraction that integrates:
//! - Display (ILI9342C via SPI)
//! - Touch (FT6336U via I2C)
//! - Power management (AXP2101)
//! - I/O expansion (AW9523B)
//!
//! Provides the main entry point for Zylix applications on M5Stack.

const std = @import("std");

// Hardware drivers
const ili9342c = @import("../drivers/ili9342c.zig");
const ft6336u = @import("../drivers/ft6336u.zig");
const axp2101 = @import("../drivers/axp2101.zig");
const aw9523b = @import("../drivers/aw9523b.zig");

// HAL modules
const spi_driver = @import("../hal/spi.zig");
const i2c_driver = @import("../hal/i2c.zig");
const interrupt = @import("../hal/interrupt.zig");

// Graphics modules
const display_mod = @import("../graphics/display.zig");
const graphics_mod = @import("../graphics/graphics.zig");
const framebuffer_mod = @import("../graphics/framebuffer.zig");

// Touch modules
const touch_input = @import("../touch/input.zig");
const gesture_mod = @import("../touch/gesture.zig");
const events_mod = @import("../touch/events.zig");

// Platform sub-modules
pub const platform_events = @import("events.zig");

/// Display dimensions
pub const DISPLAY_WIDTH: u16 = 320;
pub const DISPLAY_HEIGHT: u16 = 240;

/// Platform configuration
pub const PlatformConfig = struct {
    /// Display rotation
    rotation: display_mod.DisplayConfig.Rotation = .landscape,

    /// Initial backlight brightness (0-100)
    backlight: u8 = 80,

    /// Target frame rate
    target_fps: u8 = 60,

    /// Enable touch input
    enable_touch: bool = true,

    /// Enable gesture recognition
    enable_gestures: bool = true,

    /// Double buffer for smoother rendering
    double_buffer: bool = true,

    /// Allocator for dynamic allocations
    allocator: ?std.mem.Allocator = null,
};

/// Platform error types
pub const PlatformError = error{
    InitFailed,
    DisplayError,
    TouchError,
    PowerError,
    IoExpanderError,
    MemoryError,
    AlreadyInitialized,
    NotInitialized,
};

/// Application callback interface
pub const AppCallbacks = struct {
    /// Called once when app starts
    on_init: ?*const fn (*Platform) void = null,

    /// Called every frame
    on_update: ?*const fn (*Platform, u64) void = null,

    /// Called when app terminates
    on_deinit: ?*const fn (*Platform) void = null,

    /// Called on touch event
    on_touch: ?*const fn (*Platform, events_mod.Event) void = null,

    /// Called on gesture event
    on_gesture: ?*const fn (*Platform, gesture_mod.GestureEvent) void = null,

    /// User data pointer
    user_data: ?*anyopaque = null,
};

/// M5Stack CoreS3 Platform
pub const Platform = struct {
    // Configuration
    config: PlatformConfig,
    allocator: std.mem.Allocator,

    // Display subsystem
    display: ?display_mod.Display = null,
    graphics: ?graphics_mod.Graphics = null,

    // Touch subsystem
    touch_input: ?touch_input.TouchInput = null,
    gesture_recognizer: ?gesture_mod.GestureRecognizer = null,
    event_dispatcher: events_mod.EventDispatcher = .{},

    // Interrupt handling
    gpio_interrupt: ?interrupt.GpioInterrupt = null,
    touch_interrupt: ?interrupt.TouchInterruptHandler = null,

    // Timing
    frame_start_time: u64 = 0,
    frame_count: u64 = 0,
    last_fps_time: u64 = 0,
    current_fps: f32 = 0,

    // State
    running: bool = false,
    initialized: bool = false,

    // Callbacks
    callbacks: AppCallbacks = .{},

    /// Initialize the M5Stack platform
    pub fn init(config: PlatformConfig) PlatformError!Platform {
        const allocator = config.allocator orelse return PlatformError.MemoryError;

        var platform = Platform{
            .config = config,
            .allocator = allocator,
        };

        // Initialize display
        platform.display = display_mod.Display.init(allocator, .{
            .rotation = config.rotation,
            .double_buffer = config.double_buffer,
        }) catch return PlatformError.DisplayError;

        // Get graphics context
        if (platform.display) |*disp| {
            platform.graphics = disp.getGraphics();

            // Set initial backlight
            disp.setBacklight(config.backlight) catch {};
        }

        // Initialize touch input
        if (config.enable_touch) {
            platform.touch_input = touch_input.TouchInput.init(.{
                .display_width = DISPLAY_WIDTH,
                .display_height = DISPLAY_HEIGHT,
                .rotation = switch (config.rotation) {
                    .portrait => .portrait,
                    .landscape => .landscape,
                    .portrait_inverted => .portrait_inverted,
                    .landscape_inverted => .landscape_inverted,
                },
            }) catch null;

            // Initialize gesture recognizer
            if (config.enable_gestures) {
                platform.gesture_recognizer = gesture_mod.GestureRecognizer.init(.{});
            }

            // Initialize GPIO interrupt for touch
            platform.gpio_interrupt = interrupt.GpioInterrupt.init();
            if (platform.gpio_interrupt) |*gpio_int| {
                platform.touch_interrupt = interrupt.TouchInterruptHandler.init(gpio_int) catch null;
            }
        }

        platform.initialized = true;
        return platform;
    }

    /// Deinitialize the platform
    pub fn deinit(self: *Platform) void {
        self.running = false;

        // Call app deinit callback
        if (self.callbacks.on_deinit) |callback| {
            callback(self);
        }

        // Cleanup touch interrupt
        if (self.touch_interrupt) |*ti| {
            ti.deinit();
        }
        if (self.gpio_interrupt) |*gi| {
            gi.deinit();
        }

        // Cleanup touch input
        if (self.touch_input) |*ti| {
            ti.deinit();
        }

        // Cleanup display
        if (self.display) |*disp| {
            disp.deinit();
        }

        self.initialized = false;
    }

    /// Set application callbacks
    pub fn setCallbacks(self: *Platform, callbacks: AppCallbacks) void {
        self.callbacks = callbacks;
    }

    /// Run the main application loop
    pub fn run(self: *Platform) void {
        if (!self.initialized) return;

        self.running = true;
        self.frame_start_time = self.getCurrentTime();
        self.last_fps_time = self.frame_start_time;

        // Call app init callback
        if (self.callbacks.on_init) |callback| {
            callback(self);
        }

        // Main loop
        while (self.running) {
            const current_time = self.getCurrentTime();

            // Process touch input
            self.processTouchInput(current_time);

            // Call app update callback
            if (self.callbacks.on_update) |callback| {
                callback(self, current_time);
            }

            // Dispatch queued events
            self.event_dispatcher.dispatchQueued();

            // Flush display
            if (self.display) |*disp| {
                disp.flush() catch {};
            }

            // Frame timing
            self.frame_count += 1;
            self.updateFps(current_time);
            self.waitForNextFrame(current_time);
        }
    }

    /// Stop the main loop
    pub fn stop(self: *Platform) void {
        self.running = false;
    }

    /// Process touch input and dispatch events
    fn processTouchInput(self: *Platform, current_time: u64) void {
        // Check touch interrupt
        if (self.touch_interrupt) |*ti| {
            if (ti.isPending()) {
                ti.clearPending();

                // Update touch state
                if (self.touch_input) |*input| {
                    input.update(current_time);

                    // Get active touches
                    const touches = input.getActiveTouches();

                    // Create touch event
                    if (touches.len > 0) {
                        const event = events_mod.Event{
                            .touch = .{
                                .touches = touches,
                                .primary = touches[0],
                                .timestamp = current_time,
                            },
                        };

                        // Dispatch to app callback
                        if (self.callbacks.on_touch) |callback| {
                            callback(self, event);
                        }

                        // Queue for event dispatcher
                        _ = self.event_dispatcher.queueEvent(event, .normal, current_time);

                        // Process gestures
                        if (self.gesture_recognizer) |*gr| {
                            gr.processTouchEvent(touches[0], current_time);

                            // Handle multi-touch gestures
                            if (touches.len >= 2) {
                                gr.processMultiTouch(touches, current_time);
                            }

                            // Check for completed gestures
                            if (gr.getLastGesture()) |gesture_event| {
                                const gesture_ev = events_mod.Event{
                                    .gesture = gesture_event,
                                };
                                _ = self.event_dispatcher.queueEvent(gesture_ev, .normal, current_time);

                                if (self.callbacks.on_gesture) |callback| {
                                    callback(self, gesture_event);
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Polling mode (no interrupt)
            if (self.touch_input) |*input| {
                input.update(current_time);
            }
        }
    }

    /// Update FPS calculation
    fn updateFps(self: *Platform, current_time: u64) void {
        const elapsed = current_time - self.last_fps_time;
        if (elapsed >= 1_000_000) { // 1 second
            self.current_fps = @as(f32, @floatFromInt(self.frame_count)) / (@as(f32, @floatFromInt(elapsed)) / 1_000_000.0);
            self.frame_count = 0;
            self.last_fps_time = current_time;
        }
    }

    /// Wait for next frame to maintain target FPS
    fn waitForNextFrame(self: *Platform, current_time: u64) void {
        const frame_time_us = 1_000_000 / @as(u64, self.config.target_fps);
        const elapsed = current_time - self.frame_start_time;

        if (elapsed < frame_time_us) {
            const wait_time = frame_time_us - elapsed;
            // Placeholder: would use esp_timer_get_time() or similar
            _ = wait_time;
        }

        self.frame_start_time = self.getCurrentTime();
    }

    /// Get current timestamp in microseconds
    fn getCurrentTime(self: *Platform) u64 {
        _ = self;
        // Placeholder: would use esp_timer_get_time() on ESP32
        // For now, return a simulated time
        return 0;
    }

    // === Graphics API ===

    /// Get graphics context
    pub fn getGraphics(self: *Platform) ?*graphics_mod.Graphics {
        return if (self.graphics) |*g| g else null;
    }

    /// Clear screen with color
    pub fn clearScreen(self: *Platform, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.clear(color);
        }
    }

    /// Draw pixel
    pub fn drawPixel(self: *Platform, x: i32, y: i32, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.drawPixel(x, y, color);
        }
    }

    /// Draw line
    pub fn drawLine(self: *Platform, x0: i32, y0: i32, x1: i32, y1: i32, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.drawLine(x0, y0, x1, y1, color);
        }
    }

    /// Draw rectangle
    pub fn drawRect(self: *Platform, x: i32, y: i32, w: u16, h: u16, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.drawRect(x, y, w, h, color);
        }
    }

    /// Fill rectangle
    pub fn fillRect(self: *Platform, x: i32, y: i32, w: u16, h: u16, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.fillRect(x, y, w, h, color);
        }
    }

    /// Draw circle
    pub fn drawCircle(self: *Platform, cx: i32, cy: i32, radius: u16, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.drawCircle(cx, cy, radius, color);
        }
    }

    /// Fill circle
    pub fn fillCircle(self: *Platform, cx: i32, cy: i32, radius: u16, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.fillCircle(cx, cy, radius, color);
        }
    }

    /// Draw text
    pub fn drawText(self: *Platform, x: i32, y: i32, text: []const u8, color: framebuffer_mod.Color) void {
        if (self.graphics) |*g| {
            g.drawText(x, y, text, color);
        }
    }

    // === Touch API ===

    /// Check if screen is being touched
    pub fn isTouched(self: *Platform) bool {
        if (self.touch_input) |*input| {
            return input.isTouched();
        }
        return false;
    }

    /// Get primary touch point
    pub fn getTouch(self: *Platform) ?touch_input.Touch {
        if (self.touch_input) |*input| {
            return input.getPrimaryTouch();
        }
        return null;
    }

    /// Check if multi-touch is active
    pub fn isMultiTouch(self: *Platform) bool {
        if (self.touch_input) |*input| {
            return input.isMultiTouch();
        }
        return false;
    }

    // === Display API ===

    /// Set backlight brightness (0-100)
    pub fn setBacklight(self: *Platform, percent: u8) void {
        if (self.display) |*disp| {
            disp.setBacklight(percent) catch {};
        }
    }

    /// Get current FPS
    pub fn getFps(self: *Platform) f32 {
        return self.current_fps;
    }

    /// Get display width
    pub fn getWidth(self: *Platform) u16 {
        _ = self;
        return DISPLAY_WIDTH;
    }

    /// Get display height
    pub fn getHeight(self: *Platform) u16 {
        _ = self;
        return DISPLAY_HEIGHT;
    }

    // === Event API ===

    /// Add event listener
    pub fn addEventListener(
        self: *Platform,
        event_type: ?events_mod.EventType,
        handler: events_mod.EventHandler,
        user_data: ?*anyopaque,
    ) bool {
        return self.event_dispatcher.addListener(event_type, handler, user_data, .normal, false);
    }

    /// Remove event listener
    pub fn removeEventListener(self: *Platform, handler: events_mod.EventHandler) bool {
        return self.event_dispatcher.removeListener(handler);
    }
};

/// Convenience function to create and run a simple app
pub fn runApp(
    config: PlatformConfig,
    init_fn: ?*const fn (*Platform) void,
    update_fn: ?*const fn (*Platform, u64) void,
    deinit_fn: ?*const fn (*Platform) void,
) PlatformError!void {
    var platform = try Platform.init(config);
    defer platform.deinit();

    platform.setCallbacks(.{
        .on_init = init_fn,
        .on_update = update_fn,
        .on_deinit = deinit_fn,
    });

    platform.run();
}

// Pre-defined colors for convenience
pub const Color = struct {
    pub const black: u16 = 0x0000;
    pub const white: u16 = 0xFFFF;
    pub const red: u16 = 0xF800;
    pub const green: u16 = 0x07E0;
    pub const blue: u16 = 0x001F;
    pub const yellow: u16 = 0xFFE0;
    pub const cyan: u16 = 0x07FF;
    pub const magenta: u16 = 0xF81F;
    pub const orange: u16 = 0xFD20;
    pub const purple: u16 = 0x8010;
    pub const gray: u16 = 0x8410;
    pub const darkgray: u16 = 0x4208;
    pub const lightgray: u16 = 0xC618;
};

// Tests
test "Platform configuration defaults" {
    const config = PlatformConfig{};
    try std.testing.expectEqual(@as(u8, 80), config.backlight);
    try std.testing.expectEqual(@as(u8, 60), config.target_fps);
    try std.testing.expect(config.enable_touch);
    try std.testing.expect(config.enable_gestures);
}

test "Color constants" {
    try std.testing.expectEqual(@as(u16, 0x0000), Color.black);
    try std.testing.expectEqual(@as(u16, 0xFFFF), Color.white);
    try std.testing.expectEqual(@as(u16, 0xF800), Color.red);
    try std.testing.expectEqual(@as(u16, 0x07E0), Color.green);
    try std.testing.expectEqual(@as(u16, 0x001F), Color.blue);
}
