//! FT6336U Capacitive Touch Controller Driver
//!
//! Driver for FT6336U touch controller used in M5Stack CoreS3.
//! Supports up to 2 simultaneous touch points.
//!
//! I2C Address: 0x38
//! Interrupt: Active Low

const std = @import("std");
const hal = @import("../hal/hal.zig");

/// FT6336U Register addresses
pub const Register = enum(u8) {
    // Device mode
    dev_mode = 0x00, // Device mode (0: normal, 4: test)

    // Gesture ID
    gest_id = 0x01, // Gesture ID

    // Touch data
    td_status = 0x02, // Number of touch points (0-2)

    // Touch point 1
    p1_xh = 0x03, // P1 X position high byte + event flag
    p1_xl = 0x04, // P1 X position low byte
    p1_yh = 0x05, // P1 Y position high byte + touch ID
    p1_yl = 0x06, // P1 Y position low byte
    p1_weight = 0x07, // P1 touch weight
    p1_misc = 0x08, // P1 misc (area)

    // Touch point 2
    p2_xh = 0x09,
    p2_xl = 0x0A,
    p2_yh = 0x0B,
    p2_yl = 0x0C,
    p2_weight = 0x0D,
    p2_misc = 0x0E,

    // Thresholds
    th_group = 0x80, // Touch threshold
    th_diff = 0x85, // Filter
    ctrl = 0x86, // Power mode
    timeentermonitor = 0x87, // Time to enter monitor mode
    periodactive = 0x88, // Report rate in active mode
    periodmonitor = 0x89, // Report rate in monitor mode

    // System
    radian_value = 0x91,
    offset_left_right = 0x92,
    offset_up_down = 0x93,
    distance_left_right = 0x94,
    distance_up_down = 0x95,
    distance_zoom = 0x96,

    // Chip info
    lib_ver_h = 0xA1, // Library version high
    lib_ver_l = 0xA2, // Library version low
    cipher = 0xA3, // Chip code
    g_mode = 0xA4, // Interrupt mode
    pwr_mode = 0xA5, // Power mode
    firmid = 0xA6, // Firmware ID
    focaltech_id = 0xA8, // FocalTech panel ID
    release_code_id = 0xAF, // Release code ID
    state = 0xBC, // Running state
};

/// Touch event type
pub const EventFlag = enum(u2) {
    press_down = 0,
    lift_up = 1,
    contact = 2,
    no_event = 3,
};

/// Gesture ID
pub const GestureId = enum(u8) {
    none = 0x00,
    move_up = 0x10,
    move_left = 0x14,
    move_down = 0x18,
    move_right = 0x1C,
    zoom_in = 0x48,
    zoom_out = 0x49,
};

/// Touch point data
pub const TouchPoint = struct {
    x: u16,
    y: u16,
    event: EventFlag,
    id: u4,
    weight: u8,
    area: u4,
};

/// Touch data (up to 2 points)
pub const TouchData = struct {
    points: [2]?TouchPoint = .{ null, null },
    count: u2 = 0,
    gesture: GestureId = .none,
};

/// FT6336U Configuration
pub const Config = struct {
    threshold: u8 = 22, // Touch threshold (0-255)
    interrupt_mode: InterruptMode = .trigger,
    active_period: u8 = 12, // Active scan period (ms)
    monitor_period: u8 = 40, // Monitor scan period (ms)

    pub const InterruptMode = enum(u1) {
        polling = 0, // Polling mode
        trigger = 1, // Trigger mode (interrupt)
    };
};

/// FT6336U Driver
pub const FT6336U = struct {
    address: u7,
    config: Config,
    i2c: ?hal.I2c = null,

    /// Initialize the touch controller
    pub fn init(address: u7) !FT6336U {
        var self = FT6336U{
            .address = address,
            .config = .{},
        };

        // Initialize I2C
        self.i2c = try hal.I2c.init(.i2c0, .{
            .sda_pin = 12,
            .scl_pin = 11,
            .clock_speed_hz = 400_000,
        });

        // Configure touch controller
        try self.configure();

        return self;
    }

    /// Deinitialize the touch controller
    pub fn deinit(self: *FT6336U) void {
        if (self.i2c) |*i2c| {
            i2c.deinit();
        }
    }

    /// Configure the touch controller
    fn configure(self: *FT6336U) !void {
        // Set touch threshold
        try self.writeRegister(.th_group, self.config.threshold);

        // Set interrupt mode
        try self.writeRegister(.g_mode, @intFromEnum(self.config.interrupt_mode));

        // Set scan periods
        try self.writeRegister(.periodactive, self.config.active_period);
        try self.writeRegister(.periodmonitor, self.config.monitor_period);
    }

    /// Write to register
    fn writeRegister(self: *FT6336U, reg: Register, value: u8) !void {
        if (self.i2c) |*i2c| {
            try i2c.writeRegister(self.address, @intFromEnum(reg), value);
        }
    }

    /// Read from register
    fn readRegister(self: *FT6336U, reg: Register) !u8 {
        if (self.i2c) |*i2c| {
            return try i2c.readRegister(self.address, @intFromEnum(reg));
        }
        return 0;
    }

    /// Read multiple registers
    fn readRegisters(self: *FT6336U, start_reg: Register, buffer: []u8) !void {
        if (self.i2c) |*i2c| {
            try i2c.writeRead(self.address, &[_]u8{@intFromEnum(start_reg)}, buffer);
        }
    }

    /// Read single touch point (simplified API)
    pub fn read(self: *FT6336U) ?TouchPoint {
        const data = self.readAll() catch return null;
        if (data.count > 0) {
            return data.points[0];
        }
        return null;
    }

    /// Read all touch data
    pub fn readAll(self: *FT6336U) !TouchData {
        var result = TouchData{};

        // Read gesture and touch count
        var header: [3]u8 = undefined;
        try self.readRegisters(.dev_mode, &header);

        result.gesture = @enumFromInt(header[1]);
        result.count = @intCast(header[2] & 0x0F);

        if (result.count == 0) return result;

        // Read touch point data
        var touch_data: [12]u8 = undefined; // 6 bytes per point
        try self.readRegisters(.p1_xh, touch_data[0..(@as(usize, result.count) * 6)]);

        // Parse touch point 1
        if (result.count >= 1) {
            result.points[0] = parseTouchPoint(touch_data[0..6]);
        }

        // Parse touch point 2
        if (result.count >= 2) {
            result.points[1] = parseTouchPoint(touch_data[6..12]);
        }

        return result;
    }

    /// Parse touch point from raw data
    fn parseTouchPoint(data: []const u8) TouchPoint {
        const xh = data[0];
        const xl = data[1];
        const yh = data[2];
        const yl = data[3];
        const weight = data[4];
        const misc = data[5];

        return TouchPoint{
            .x = (@as(u16, xh & 0x0F) << 8) | @as(u16, xl),
            .y = (@as(u16, yh & 0x0F) << 8) | @as(u16, yl),
            .event = @enumFromInt((xh >> 6) & 0x03),
            .id = @intCast((yh >> 4) & 0x0F),
            .weight = weight,
            .area = @intCast((misc >> 4) & 0x0F),
        };
    }

    /// Check if touch is active
    pub fn isTouched(self: *FT6336U) bool {
        const count = self.readRegister(.td_status) catch return false;
        return (count & 0x0F) > 0;
    }

    /// Get chip ID
    pub fn getChipId(self: *FT6336U) !u8 {
        return try self.readRegister(.cipher);
    }

    /// Get firmware version
    pub fn getFirmwareVersion(self: *FT6336U) !u8 {
        return try self.readRegister(.firmid);
    }

    /// Get library version
    pub fn getLibraryVersion(self: *FT6336U) !u16 {
        const high = try self.readRegister(.lib_ver_h);
        const low = try self.readRegister(.lib_ver_l);
        return (@as(u16, high) << 8) | @as(u16, low);
    }

    /// Set touch threshold
    pub fn setThreshold(self: *FT6336U, threshold: u8) !void {
        self.config.threshold = threshold;
        try self.writeRegister(.th_group, threshold);
    }

    /// Enter power saving mode
    pub fn enterSleep(self: *FT6336U) !void {
        try self.writeRegister(.pwr_mode, 0x03);
    }

    /// Exit power saving mode
    pub fn exitSleep(self: *FT6336U) !void {
        try self.writeRegister(.pwr_mode, 0x00);
    }
};

// Tests
test "Register enum values" {
    try std.testing.expectEqual(@as(u8, 0x02), @intFromEnum(Register.td_status));
    try std.testing.expectEqual(@as(u8, 0x03), @intFromEnum(Register.p1_xh));
    try std.testing.expectEqual(@as(u8, 0x38), @intFromEnum(Register.focaltech_id));
}

test "EventFlag enum" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(EventFlag.press_down));
    try std.testing.expectEqual(@as(u2, 1), @intFromEnum(EventFlag.lift_up));
    try std.testing.expectEqual(@as(u2, 2), @intFromEnum(EventFlag.contact));
}

test "parseTouchPoint" {
    const data = [_]u8{ 0x01, 0x00, 0x00, 0x78, 0x50, 0x10 };
    const point = FT6336U.parseTouchPoint(&data);
    try std.testing.expectEqual(@as(u16, 256), point.x);
    try std.testing.expectEqual(@as(u16, 120), point.y);
}
