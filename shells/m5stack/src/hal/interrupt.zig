//! Interrupt Handling for ESP32-S3
//!
//! GPIO interrupt and timer interrupt support for M5Stack CoreS3.
//! Provides interrupt-driven touch input handling.
//!
//! Touch Interrupt: GPIO21 (FT6336U INT pin, active low)

const std = @import("std");

/// Interrupt trigger type
pub const TriggerType = enum(u3) {
    disable = 0,
    rising_edge = 1,
    falling_edge = 2,
    any_edge = 3,
    low_level = 4,
    high_level = 5,
};

/// Interrupt handler function type
pub const InterruptHandler = *const fn (pin: u8, user_data: ?*anyopaque) void;

/// GPIO Interrupt configuration
pub const GpioInterruptConfig = struct {
    pin: u8,
    trigger: TriggerType = .falling_edge,
    handler: ?InterruptHandler = null,
    user_data: ?*anyopaque = null,
    pull_up: bool = true,
    pull_down: bool = false,
    debounce_us: u32 = 1000, // 1ms debounce
};

/// Predefined pins for M5Stack CoreS3
pub const CoreS3Pins = struct {
    pub const touch_int: u8 = 21; // FT6336U interrupt
    pub const button_a: u8 = 0; // Boot button (directly wired)
    // Note: Other buttons use touch controller
};

/// GPIO Interrupt controller
pub const GpioInterrupt = struct {
    const MAX_HANDLERS = 16;

    handlers: [MAX_HANDLERS]?HandlerEntry = [_]?HandlerEntry{null} ** MAX_HANDLERS,
    handler_count: usize = 0,

    // Interrupt statistics
    interrupt_count: u64 = 0,
    last_interrupt_time: u64 = 0,

    const HandlerEntry = struct {
        config: GpioInterruptConfig,
        last_trigger_time: u64 = 0,
        enabled: bool = true,
    };

    /// Initialize GPIO interrupt controller
    pub fn init() GpioInterrupt {
        var controller = GpioInterrupt{};

        // ESP-IDF: gpio_install_isr_service()
        // Placeholder - would call into ESP-IDF

        return controller;
    }

    /// Deinitialize interrupt controller
    pub fn deinit(self: *GpioInterrupt) void {
        // Disable all interrupts
        for (&self.handlers) |*entry| {
            if (entry.*) |*handler| {
                handler.enabled = false;
            }
            entry.* = null;
        }
        self.handler_count = 0;

        // ESP-IDF: gpio_uninstall_isr_service()
    }

    /// Register interrupt handler
    pub fn registerHandler(self: *GpioInterrupt, config: GpioInterruptConfig) !usize {
        if (self.handler_count >= MAX_HANDLERS) {
            return error.TooManyHandlers;
        }

        // Find empty slot
        for (self.handlers, 0..) |maybe_entry, index| {
            if (maybe_entry == null) {
                self.handlers[index] = .{
                    .config = config,
                };
                self.handler_count += 1;

                // Configure GPIO
                try self.configureGpio(config);

                return index;
            }
        }

        return error.NoEmptySlot;
    }

    /// Unregister interrupt handler
    pub fn unregisterHandler(self: *GpioInterrupt, index: usize) void {
        if (index >= MAX_HANDLERS) return;

        if (self.handlers[index]) |*entry| {
            // Disable interrupt on this pin
            self.disablePin(entry.config.pin);
            self.handlers[index] = null;
            self.handler_count -= 1;
        }
    }

    /// Configure GPIO for interrupt
    fn configureGpio(self: *GpioInterrupt, config: GpioInterruptConfig) !void {
        _ = self;

        // ESP-IDF: gpio_config() + gpio_isr_handler_add()
        // Placeholder implementation

        _ = config;

        // Would configure:
        // 1. Pin as input
        // 2. Pull-up/pull-down
        // 3. Interrupt trigger type
        // 4. Register ISR handler
    }

    /// Disable interrupt on pin
    fn disablePin(self: *GpioInterrupt, pin: u8) void {
        _ = self;
        _ = pin;
        // ESP-IDF: gpio_isr_handler_remove() + gpio_intr_disable()
    }

    /// Enable interrupt for handler
    pub fn enable(self: *GpioInterrupt, index: usize) void {
        if (index >= MAX_HANDLERS) return;
        if (self.handlers[index]) |*entry| {
            entry.enabled = true;
            // ESP-IDF: gpio_intr_enable()
        }
    }

    /// Disable interrupt for handler
    pub fn disable(self: *GpioInterrupt, index: usize) void {
        if (index >= MAX_HANDLERS) return;
        if (self.handlers[index]) |*entry| {
            entry.enabled = false;
            // ESP-IDF: gpio_intr_disable()
        }
    }

    /// Handle interrupt (called from ISR)
    pub fn handleInterrupt(self: *GpioInterrupt, pin: u8, current_time: u64) void {
        self.interrupt_count += 1;
        self.last_interrupt_time = current_time;

        for (&self.handlers) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                if (entry.config.pin == pin and entry.enabled) {
                    // Check debounce
                    const time_since_last = current_time -| entry.last_trigger_time;
                    if (time_since_last >= entry.config.debounce_us) {
                        entry.last_trigger_time = current_time;

                        // Call handler
                        if (entry.config.handler) |handler| {
                            handler(pin, entry.config.user_data);
                        }
                    }
                }
            }
        }
    }

    /// Get interrupt statistics
    pub fn getStats(self: *const GpioInterrupt) struct { count: u64, last_time: u64 } {
        return .{
            .count = self.interrupt_count,
            .last_time = self.last_interrupt_time,
        };
    }
};

/// Timer interrupt for periodic operations
pub const TimerInterrupt = struct {
    const MAX_TIMERS = 4;

    timers: [MAX_TIMERS]?TimerEntry = [_]?TimerEntry{null} ** MAX_TIMERS,
    timer_count: usize = 0,

    const TimerEntry = struct {
        period_us: u64,
        handler: *const fn (timer_id: usize, user_data: ?*anyopaque) void,
        user_data: ?*anyopaque,
        last_trigger: u64,
        enabled: bool,
        one_shot: bool,
    };

    /// Initialize timer interrupt controller
    pub fn init() TimerInterrupt {
        return .{};
    }

    /// Deinitialize timer controller
    pub fn deinit(self: *TimerInterrupt) void {
        for (&self.timers) |*entry| {
            entry.* = null;
        }
        self.timer_count = 0;
    }

    /// Register periodic timer
    pub fn registerTimer(
        self: *TimerInterrupt,
        period_us: u64,
        handler: *const fn (usize, ?*anyopaque) void,
        user_data: ?*anyopaque,
        one_shot: bool,
    ) !usize {
        if (self.timer_count >= MAX_TIMERS) {
            return error.TooManyTimers;
        }

        for (self.timers, 0..) |maybe_entry, index| {
            if (maybe_entry == null) {
                self.timers[index] = .{
                    .period_us = period_us,
                    .handler = handler,
                    .user_data = user_data,
                    .last_trigger = 0,
                    .enabled = true,
                    .one_shot = one_shot,
                };
                self.timer_count += 1;
                return index;
            }
        }

        return error.NoEmptySlot;
    }

    /// Unregister timer
    pub fn unregisterTimer(self: *TimerInterrupt, index: usize) void {
        if (index >= MAX_TIMERS) return;
        if (self.timers[index] != null) {
            self.timers[index] = null;
            self.timer_count -= 1;
        }
    }

    /// Process timers (call from main loop or timer ISR)
    pub fn process(self: *TimerInterrupt, current_time: u64) void {
        for (&self.timers, 0..) |*maybe_entry, index| {
            if (maybe_entry.*) |*entry| {
                if (entry.enabled) {
                    const elapsed = current_time -| entry.last_trigger;
                    if (elapsed >= entry.period_us) {
                        entry.last_trigger = current_time;
                        entry.handler(index, entry.user_data);

                        if (entry.one_shot) {
                            entry.enabled = false;
                        }
                    }
                }
            }
        }
    }

    /// Enable timer
    pub fn enable(self: *TimerInterrupt, index: usize) void {
        if (index >= MAX_TIMERS) return;
        if (self.timers[index]) |*entry| {
            entry.enabled = true;
        }
    }

    /// Disable timer
    pub fn disable(self: *TimerInterrupt, index: usize) void {
        if (index >= MAX_TIMERS) return;
        if (self.timers[index]) |*entry| {
            entry.enabled = false;
        }
    }

    /// Reset timer period
    pub fn setPeriod(self: *TimerInterrupt, index: usize, period_us: u64) void {
        if (index >= MAX_TIMERS) return;
        if (self.timers[index]) |*entry| {
            entry.period_us = period_us;
        }
    }
};

/// Touch interrupt handler for FT6336U
pub const TouchInterruptHandler = struct {
    gpio_interrupt: *GpioInterrupt,
    handler_index: ?usize = null,
    touch_pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    /// Initialize touch interrupt on GPIO21
    pub fn init(gpio_interrupt: *GpioInterrupt) !TouchInterruptHandler {
        var handler = TouchInterruptHandler{
            .gpio_interrupt = gpio_interrupt,
        };

        // Register interrupt for touch INT pin (GPIO21)
        handler.handler_index = try gpio_interrupt.registerHandler(.{
            .pin = CoreS3Pins.touch_int,
            .trigger = .falling_edge, // FT6336U INT is active low
            .handler = touchIsr,
            .user_data = @ptrCast(&handler),
            .pull_up = true,
            .debounce_us = 1000,
        });

        return handler;
    }

    /// Deinitialize touch interrupt
    pub fn deinit(self: *TouchInterruptHandler) void {
        if (self.handler_index) |index| {
            self.gpio_interrupt.unregisterHandler(index);
            self.handler_index = null;
        }
    }

    /// Check if touch is pending
    pub fn isPending(self: *TouchInterruptHandler) bool {
        return self.touch_pending.load(.acquire);
    }

    /// Clear pending flag
    pub fn clearPending(self: *TouchInterruptHandler) void {
        self.touch_pending.store(false, .release);
    }

    /// Touch ISR callback
    fn touchIsr(pin: u8, user_data: ?*anyopaque) void {
        _ = pin;
        if (user_data) |data| {
            const handler: *TouchInterruptHandler = @ptrCast(@alignCast(data));
            handler.touch_pending.store(true, .release);
        }
    }
};

/// Critical section guard
pub const CriticalSection = struct {
    // On ESP32, this would save/restore interrupt state

    pub fn enter() CriticalSection {
        // ESP-IDF: portENTER_CRITICAL() or taskENTER_CRITICAL()
        return .{};
    }

    pub fn leave(self: CriticalSection) void {
        _ = self;
        // ESP-IDF: portEXIT_CRITICAL() or taskEXIT_CRITICAL()
    }
};

/// Atomic operations wrapper
pub fn atomicLoad(comptime T: type, ptr: *const std.atomic.Value(T)) T {
    return ptr.load(.acquire);
}

pub fn atomicStore(comptime T: type, ptr: *std.atomic.Value(T), value: T) void {
    ptr.store(value, .release);
}

pub fn atomicExchange(comptime T: type, ptr: *std.atomic.Value(T), value: T) T {
    return ptr.swap(value, .acq_rel);
}

// Tests
test "TriggerType enum" {
    try std.testing.expectEqual(@as(u3, 0), @intFromEnum(TriggerType.disable));
    try std.testing.expectEqual(@as(u3, 2), @intFromEnum(TriggerType.falling_edge));
}

test "GpioInterrupt initialization" {
    var controller = GpioInterrupt.init();
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.handler_count);
    try std.testing.expectEqual(@as(u64, 0), controller.interrupt_count);
}

test "TimerInterrupt initialization" {
    var timer = TimerInterrupt.init();
    defer timer.deinit();

    try std.testing.expectEqual(@as(usize, 0), timer.timer_count);
}

test "CoreS3Pins values" {
    try std.testing.expectEqual(@as(u8, 21), CoreS3Pins.touch_int);
    try std.testing.expectEqual(@as(u8, 0), CoreS3Pins.button_a);
}

test "GpioInterruptConfig defaults" {
    const config = GpioInterruptConfig{
        .pin = 21,
    };
    try std.testing.expectEqual(TriggerType.falling_edge, config.trigger);
    try std.testing.expect(config.pull_up);
    try std.testing.expectEqual(@as(u32, 1000), config.debounce_us);
}
