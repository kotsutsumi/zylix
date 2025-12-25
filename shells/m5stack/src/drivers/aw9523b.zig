//! AW9523B I/O Expander Driver
//!
//! Driver for AW9523B 16-bit I/O expander used in M5Stack CoreS3.
//! Controls LCD reset, touch reset, and other peripheral control signals.
//!
//! I2C Address: 0x58
//! Features:
//! - 16 GPIO pins (P0_0-P0_7, P1_0-P1_7)
//! - Push-pull or open-drain output
//! - LED current source mode
//! - Interrupt support

const std = @import("std");
const hal = @import("../hal/hal.zig");

/// AW9523B Register addresses
pub const Register = enum(u8) {
    // Input registers (read-only)
    input_p0 = 0x00, // Port 0 input (P0_0 - P0_7)
    input_p1 = 0x01, // Port 1 input (P1_0 - P1_7)

    // Output registers
    output_p0 = 0x02, // Port 0 output
    output_p1 = 0x03, // Port 1 output

    // Configuration registers
    config_p0 = 0x04, // Port 0 direction (0=output, 1=input)
    config_p1 = 0x05, // Port 1 direction

    // Interrupt enable
    int_en_p0 = 0x06, // Port 0 interrupt enable
    int_en_p1 = 0x07, // Port 1 interrupt enable

    // Device ID
    id = 0x10, // Device ID (should be 0x23)

    // Global control
    ctl = 0x11, // Global control register

    // LED mode
    led_mode_p0 = 0x12, // Port 0 LED mode (0=LED, 1=GPIO)
    led_mode_p1 = 0x13, // Port 1 LED mode

    // LED current control (dimming)
    dim_p0_0 = 0x20, // P0_0 dimming
    dim_p0_1 = 0x21,
    dim_p0_2 = 0x22,
    dim_p0_3 = 0x23,
    dim_p0_4 = 0x24,
    dim_p0_5 = 0x25,
    dim_p0_6 = 0x26,
    dim_p0_7 = 0x27,
    dim_p1_0 = 0x28,
    dim_p1_1 = 0x29,
    dim_p1_2 = 0x2A,
    dim_p1_3 = 0x2B,
    dim_p1_4 = 0x2C,
    dim_p1_5 = 0x2D,
    dim_p1_6 = 0x2E,
    dim_p1_7 = 0x2F,

    // Software reset
    sw_reset = 0x7F, // Write 0x00 to reset
};

/// Pin identifiers for M5Stack CoreS3
pub const Pin = enum(u8) {
    // Port 0 pins
    p0_0 = 0,
    p0_1 = 1,
    p0_2 = 2,
    p0_3 = 3,
    p0_4 = 4,
    p0_5 = 5,
    p0_6 = 6,
    p0_7 = 7,

    // Port 1 pins
    p1_0 = 8, // Touch reset
    p1_1 = 9, // LCD reset
    p1_2 = 10,
    p1_3 = 11,
    p1_4 = 12,
    p1_5 = 13,
    p1_6 = 14,
    p1_7 = 15,

    // M5Stack CoreS3 specific aliases
    touch_reset = 8, // P1_0
    lcd_reset = 9, // P1_1
    bus_out_en = 10, // P1_2
    speaker_en = 11, // P1_3

    pub fn port(self: Pin) u1 {
        return if (@intFromEnum(self) < 8) 0 else 1;
    }

    pub fn bit(self: Pin) u3 {
        return @intCast(@intFromEnum(self) & 0x07);
    }

    pub fn mask(self: Pin) u8 {
        return @as(u8, 1) << self.bit();
    }
};

/// Output mode
pub const OutputMode = enum(u1) {
    open_drain = 0,
    push_pull = 1,
};

/// AW9523B Configuration
pub const Config = struct {
    output_mode_p0: OutputMode = .push_pull,
    output_mode_p1: OutputMode = .push_pull,
    initial_output_p0: u8 = 0xFF, // All high
    initial_output_p1: u8 = 0xFF, // All high
};

/// AW9523B Driver
pub const AW9523B = struct {
    address: u7,
    config: Config,
    i2c: ?hal.I2c = null,
    output_state: [2]u8 = .{ 0xFF, 0xFF }, // Shadow registers

    pub const DEVICE_ID: u8 = 0x23;

    /// Initialize the I/O expander
    pub fn init(address: u7) !AW9523B {
        var self = AW9523B{
            .address = address,
            .config = .{},
        };

        // Initialize I2C
        self.i2c = try hal.I2c.init(.i2c0, .{
            .sda_pin = 12,
            .scl_pin = 11,
            .clock_speed_hz = 400_000,
        });

        // Software reset
        try self.reset();

        // Verify device ID
        const id = try self.readRegister(.id);
        if (id != DEVICE_ID) {
            return error.InvalidDeviceId;
        }

        // Configure device
        try self.configure();

        return self;
    }

    /// Deinitialize the I/O expander
    pub fn deinit(self: *AW9523B) void {
        if (self.i2c) |*i2c| {
            i2c.deinit();
        }
    }

    /// Software reset
    fn reset(self: *AW9523B) !void {
        try self.writeRegister(.sw_reset, 0x00);
        hal.delay_ms(10);
    }

    /// Configure the device
    fn configure(self: *AW9523B) !void {
        // Set output mode (push-pull for both ports)
        const ctl = (@as(u8, @intFromEnum(self.config.output_mode_p0)) << 4) |
            @as(u8, @intFromEnum(self.config.output_mode_p1));
        try self.writeRegister(.ctl, ctl);

        // Set all pins as GPIO (not LED mode)
        try self.writeRegister(.led_mode_p0, 0xFF);
        try self.writeRegister(.led_mode_p1, 0xFF);

        // Set all pins as outputs
        try self.writeRegister(.config_p0, 0x00);
        try self.writeRegister(.config_p1, 0x00);

        // Set initial output state
        self.output_state[0] = self.config.initial_output_p0;
        self.output_state[1] = self.config.initial_output_p1;
        try self.writeRegister(.output_p0, self.output_state[0]);
        try self.writeRegister(.output_p1, self.output_state[1]);
    }

    /// Write to register
    fn writeRegister(self: *AW9523B, reg: Register, value: u8) !void {
        if (self.i2c) |*i2c| {
            try i2c.writeRegister(self.address, @intFromEnum(reg), value);
        }
    }

    /// Read from register
    fn readRegister(self: *AW9523B, reg: Register) !u8 {
        if (self.i2c) |*i2c| {
            return try i2c.readRegister(self.address, @intFromEnum(reg));
        }
        return 0;
    }

    /// Set a single pin
    pub fn setPin(self: *AW9523B, pin: Pin, high: bool) !void {
        const port_idx = pin.port();
        const mask = pin.mask();

        if (high) {
            self.output_state[port_idx] |= mask;
        } else {
            self.output_state[port_idx] &= ~mask;
        }

        const reg: Register = if (port_idx == 0) .output_p0 else .output_p1;
        try self.writeRegister(reg, self.output_state[port_idx]);
    }

    /// Get a single pin state
    pub fn getPin(self: *AW9523B, pin: Pin) !bool {
        const port_idx = pin.port();
        const mask = pin.mask();

        const reg: Register = if (port_idx == 0) .input_p0 else .input_p1;
        const value = try self.readRegister(reg);

        return (value & mask) != 0;
    }

    /// Set port direction (0=output, 1=input for each bit)
    pub fn setPortDirection(self: *AW9523B, port: u1, direction: u8) !void {
        const reg: Register = if (port == 0) .config_p0 else .config_p1;
        try self.writeRegister(reg, direction);
    }

    /// Set entire port output
    pub fn setPort(self: *AW9523B, port: u1, value: u8) !void {
        self.output_state[port] = value;
        const reg: Register = if (port == 0) .output_p0 else .output_p1;
        try self.writeRegister(reg, value);
    }

    /// Read entire port input
    pub fn readPort(self: *AW9523B, port: u1) !u8 {
        const reg: Register = if (port == 0) .input_p0 else .input_p1;
        return try self.readRegister(reg);
    }

    /// Set pin to LED mode with dimming
    pub fn setLedDim(self: *AW9523B, pin: Pin, brightness: u8) !void {
        const port_idx = pin.port();
        const pin_bit = pin.bit();

        // Enable LED mode for this pin
        const led_reg: Register = if (port_idx == 0) .led_mode_p0 else .led_mode_p1;
        const led_mode = try self.readRegister(led_reg);
        try self.writeRegister(led_reg, led_mode & ~pin.mask());

        // Set dimming value
        const dim_base: u8 = if (port_idx == 0) @intFromEnum(Register.dim_p0_0) else @intFromEnum(Register.dim_p1_0);
        const dim_reg: Register = @enumFromInt(dim_base + pin_bit);
        try self.writeRegister(dim_reg, brightness);
    }

    /// Get device ID
    pub fn getDeviceId(self: *AW9523B) !u8 {
        return try self.readRegister(.id);
    }

    /// Toggle a pin
    pub fn togglePin(self: *AW9523B, pin: Pin) !void {
        const port_idx = pin.port();
        const mask = pin.mask();

        self.output_state[port_idx] ^= mask;

        const reg: Register = if (port_idx == 0) .output_p0 else .output_p1;
        try self.writeRegister(reg, self.output_state[port_idx]);
    }
};

// Tests
test "Pin port and bit" {
    try std.testing.expectEqual(@as(u1, 0), Pin.p0_0.port());
    try std.testing.expectEqual(@as(u1, 0), Pin.p0_7.port());
    try std.testing.expectEqual(@as(u1, 1), Pin.p1_0.port());
    try std.testing.expectEqual(@as(u1, 1), Pin.lcd_reset.port());

    try std.testing.expectEqual(@as(u3, 0), Pin.p0_0.bit());
    try std.testing.expectEqual(@as(u3, 7), Pin.p0_7.bit());
    try std.testing.expectEqual(@as(u3, 0), Pin.p1_0.bit());
    try std.testing.expectEqual(@as(u3, 1), Pin.lcd_reset.bit());
}

test "Pin mask" {
    try std.testing.expectEqual(@as(u8, 0x01), Pin.p0_0.mask());
    try std.testing.expectEqual(@as(u8, 0x80), Pin.p0_7.mask());
    try std.testing.expectEqual(@as(u8, 0x01), Pin.touch_reset.mask());
    try std.testing.expectEqual(@as(u8, 0x02), Pin.lcd_reset.mask());
}

test "Register enum values" {
    try std.testing.expectEqual(@as(u8, 0x00), @intFromEnum(Register.input_p0));
    try std.testing.expectEqual(@as(u8, 0x02), @intFromEnum(Register.output_p0));
    try std.testing.expectEqual(@as(u8, 0x10), @intFromEnum(Register.id));
}
