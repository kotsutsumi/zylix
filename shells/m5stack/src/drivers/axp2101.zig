//! AXP2101 Power Management IC Driver
//!
//! Driver for AXP2101 PMIC used in M5Stack CoreS3.
//! Provides power rail control, battery management, and backlight control.
//!
//! I2C Address: 0x34
//! Features:
//! - Multiple DC-DC converters
//! - Multiple LDO regulators
//! - Battery charging
//! - ADC for voltage/current monitoring
//! - GPIO for peripheral control (including backlight)

const std = @import("std");
const hal = @import("../hal/hal.zig");

/// AXP2101 Register addresses
pub const Register = enum(u8) {
    // Power status
    status1 = 0x00, // Power status 1
    status2 = 0x01, // Power status 2

    // Data buffer
    data_buffer0 = 0x04, // User data buffer
    data_buffer1 = 0x05,
    data_buffer2 = 0x06,
    data_buffer3 = 0x07,

    // Power on/off control
    power_on_setting = 0x10, // Power on settings
    power_off_ctrl = 0x11, // Power off control
    power_off_en = 0x12, // Power off enable

    // DC-DC control
    dcdc_ctrl = 0x80, // DC-DC enable control
    dcdc1_voltage = 0x82, // DC-DC1 voltage (0.5-1.54V)
    dcdc2_voltage = 0x83, // DC-DC2 voltage (0.5-1.54V)
    dcdc3_voltage = 0x84, // DC-DC3 voltage (0.5-1.84V)
    dcdc4_voltage = 0x85, // DC-DC4 voltage (0.5-1.84V)
    dcdc5_voltage = 0x86, // DC-DC5 voltage (1.4-3.7V)

    // LDO control
    ldo_onoff_ctrl0 = 0x90, // LDO enable control 0
    ldo_onoff_ctrl1 = 0x91, // LDO enable control 1
    aldo1_voltage = 0x92, // ALDO1 voltage (0.5-3.5V)
    aldo2_voltage = 0x93, // ALDO2 voltage
    aldo3_voltage = 0x94, // ALDO3 voltage
    aldo4_voltage = 0x95, // ALDO4 voltage
    bldo1_voltage = 0x96, // BLDO1 voltage
    bldo2_voltage = 0x97, // BLDO2 voltage
    cpusldo_voltage = 0x98, // CPUSLDO voltage
    dldo1_voltage = 0x99, // DLDO1 voltage (backlight)
    dldo2_voltage = 0x9A, // DLDO2 voltage

    // Charging control
    charge_ctrl1 = 0x62, // Charging control 1
    charge_ctrl2 = 0x63, // Charging control 2
    charge_ctrl3 = 0x64, // Charging control 3
    charge_status = 0x01, // Charging status (same as status2)

    // Battery voltage ADC
    bat_voltage_h = 0x34, // Battery voltage high byte
    bat_voltage_l = 0x35, // Battery voltage low byte

    // Battery percentage
    bat_percent = 0xA4, // Battery percentage (0-100)

    // ADC control
    adc_enable = 0x30, // ADC enable
    adc_rate = 0x31, // ADC sampling rate

    // Temperature ADC
    ts_h = 0x36, // Temperature sensor high
    ts_l = 0x37, // Temperature sensor low
    die_temp_h = 0x3C, // Die temperature high
    die_temp_l = 0x3D, // Die temperature low

    // VBUS voltage ADC
    vbus_voltage_h = 0x38, // VBUS voltage high
    vbus_voltage_l = 0x39, // VBUS voltage low

    // System voltage ADC
    sys_voltage_h = 0x3A, // System voltage high
    sys_voltage_l = 0x3B, // System voltage low

    // IRQ control
    irq_enable0 = 0x40, // IRQ enable 0
    irq_enable1 = 0x41, // IRQ enable 1
    irq_enable2 = 0x42, // IRQ enable 2
    irq_status0 = 0x48, // IRQ status 0
    irq_status1 = 0x49, // IRQ status 1
    irq_status2 = 0x4A, // IRQ status 2
};

/// Charging status
pub const ChargeStatus = enum(u2) {
    not_charging = 0,
    pre_charge = 1,
    constant_current = 2,
    constant_voltage = 3,
};

/// Power on source
pub const PowerOnSource = enum(u3) {
    button = 0,
    usb = 1,
    battery = 2,
    irq = 3,
    unknown = 7,
};

/// AXP2101 Configuration
pub const Config = struct {
    backlight_voltage_mv: u16 = 3300, // Default 3.3V for backlight
    enable_charging: bool = true,
    charge_current_ma: u16 = 500, // Charging current
};

/// AXP2101 Driver
pub const AXP2101 = struct {
    address: u7,
    config: Config,
    i2c: ?hal.I2c = null,

    /// Initialize the PMIC
    pub fn init(address: u7) !AXP2101 {
        var self = AXP2101{
            .address = address,
            .config = .{},
        };

        // Initialize I2C
        self.i2c = try hal.I2c.init(.i2c0, .{
            .sda_pin = 12,
            .scl_pin = 11,
            .clock_speed_hz = 400_000,
        });

        // Configure device
        try self.configure();

        return self;
    }

    /// Deinitialize the PMIC
    pub fn deinit(self: *AXP2101) void {
        if (self.i2c) |*i2c| {
            i2c.deinit();
        }
    }

    /// Configure the PMIC
    fn configure(self: *AXP2101) !void {
        // Enable ADC for battery voltage
        try self.writeRegister(.adc_enable, 0x03);

        // Configure DLDO1 for backlight (default 3.3V)
        try self.setDldo1Voltage(self.config.backlight_voltage_mv);

        // Enable DLDO1 for backlight
        try self.enableDldo1(true);

        // Configure charging if enabled
        if (self.config.enable_charging) {
            try self.setChargeCurrent(self.config.charge_current_ma);
        }
    }

    /// Write to register
    fn writeRegister(self: *AXP2101, reg: Register, value: u8) !void {
        if (self.i2c) |*i2c| {
            try i2c.writeRegister(self.address, @intFromEnum(reg), value);
        }
    }

    /// Read from register
    fn readRegister(self: *AXP2101, reg: Register) !u8 {
        if (self.i2c) |*i2c| {
            return try i2c.readRegister(self.address, @intFromEnum(reg));
        }
        return 0;
    }

    /// Set backlight brightness (0-100)
    pub fn setBacklight(self: *AXP2101, brightness: u8) !void {
        if (brightness == 0) {
            try self.enableDldo1(false);
            return;
        }

        // Map brightness to voltage (2.5V - 3.3V)
        const min_mv: u16 = 2500;
        const max_mv: u16 = 3300;
        const range = max_mv - min_mv;
        const clamped = @min(brightness, 100);
        const voltage = min_mv + (range * @as(u16, clamped)) / 100;

        try self.setDldo1Voltage(voltage);
        try self.enableDldo1(true);
    }

    /// Set DLDO1 voltage (for backlight)
    fn setDldo1Voltage(self: *AXP2101, voltage_mv: u16) !void {
        // DLDO1: 500mV - 3400mV in 100mV steps
        // Register value: (voltage - 500) / 100
        const clamped = std.math.clamp(voltage_mv, 500, 3400);
        const value: u8 = @intCast((clamped - 500) / 100);
        try self.writeRegister(.dldo1_voltage, value);
    }

    /// Enable/disable DLDO1
    fn enableDldo1(self: *AXP2101, enable: bool) !void {
        const current = try self.readRegister(.ldo_onoff_ctrl1);
        const new_value = if (enable)
            current | 0x01
        else
            current & ~@as(u8, 0x01);
        try self.writeRegister(.ldo_onoff_ctrl1, new_value);
    }

    /// Set charging current
    fn setChargeCurrent(self: *AXP2101, current_ma: u16) !void {
        // Charge current: 100mA - 2000mA
        // Register value depends on range
        const clamped = std.math.clamp(current_ma, 100, 2000);
        const value: u8 = @intCast((clamped - 100) / 50);
        try self.writeRegister(.charge_ctrl2, value);
    }

    /// Get battery voltage in mV
    pub fn getBatteryVoltage(self: *AXP2101) !u16 {
        const high = try self.readRegister(.bat_voltage_h);
        const low = try self.readRegister(.bat_voltage_l);
        // 12-bit ADC, 1.1mV per LSB
        const raw = (@as(u16, high) << 4) | (@as(u16, low) & 0x0F);
        return raw * 11 / 10; // Approximate mV
    }

    /// Get battery percentage (0-100)
    pub fn getBatteryPercent(self: *AXP2101) !u8 {
        return try self.readRegister(.bat_percent);
    }

    /// Check if charging
    pub fn isCharging(self: *AXP2101) !bool {
        const status = try self.readRegister(.status2);
        return (status & 0x40) != 0;
    }

    /// Get charging status
    pub fn getChargeStatus(self: *AXP2101) !ChargeStatus {
        const status = try self.readRegister(.status2);
        return @enumFromInt((status >> 5) & 0x03);
    }

    /// Check if USB connected
    pub fn isUsbConnected(self: *AXP2101) !bool {
        const status = try self.readRegister(.status1);
        return (status & 0x20) != 0;
    }

    /// Check if battery present
    pub fn isBatteryPresent(self: *AXP2101) !bool {
        const status = try self.readRegister(.status1);
        return (status & 0x08) != 0;
    }

    /// Get die temperature in 0.1C units
    pub fn getDieTemperature(self: *AXP2101) !i16 {
        const high = try self.readRegister(.die_temp_h);
        const low = try self.readRegister(.die_temp_l);
        const raw = (@as(u16, high) << 4) | (@as(u16, low) & 0x0F);
        // Convert to temperature (formula from datasheet)
        return @as(i16, @intCast(raw)) - 1447;
    }

    /// Power off the device
    pub fn powerOff(self: *AXP2101) !void {
        const current = try self.readRegister(.power_off_ctrl);
        try self.writeRegister(.power_off_ctrl, current | 0x01);
    }

    /// Enable/disable DC-DC converter
    pub fn enableDcdc(self: *AXP2101, channel: u3, enable: bool) !void {
        if (channel > 4) return;
        const current = try self.readRegister(.dcdc_ctrl);
        const mask: u8 = @as(u8, 1) << channel;
        const new_value = if (enable)
            current | mask
        else
            current & ~mask;
        try self.writeRegister(.dcdc_ctrl, new_value);
    }

    /// Set ALDO voltage
    pub fn setAldoVoltage(self: *AXP2101, channel: u2, voltage_mv: u16) !void {
        // ALDO: 500mV - 3500mV in 100mV steps
        const clamped = std.math.clamp(voltage_mv, 500, 3500);
        const value: u8 = @intCast((clamped - 500) / 100);
        const reg: Register = switch (channel) {
            0 => .aldo1_voltage,
            1 => .aldo2_voltage,
            2 => .aldo3_voltage,
            3 => .aldo4_voltage,
        };
        try self.writeRegister(reg, value);
    }
};

// Tests
test "Register enum values" {
    try std.testing.expectEqual(@as(u8, 0x00), @intFromEnum(Register.status1));
    try std.testing.expectEqual(@as(u8, 0x80), @intFromEnum(Register.dcdc_ctrl));
    try std.testing.expectEqual(@as(u8, 0x99), @intFromEnum(Register.dldo1_voltage));
}

test "Backlight voltage calculation" {
    // Test DLDO1 voltage register calculation
    // 3300mV: (3300 - 500) / 100 = 28
    const voltage: u16 = 3300;
    const value: u8 = @intCast((voltage - 500) / 100);
    try std.testing.expectEqual(@as(u8, 28), value);
}

test "ChargeStatus enum" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(ChargeStatus.not_charging));
    try std.testing.expectEqual(@as(u2, 2), @intFromEnum(ChargeStatus.constant_current));
}
