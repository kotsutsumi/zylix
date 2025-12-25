//! I2C Driver for ESP32-S3
//!
//! I2C master implementation for M5Stack CoreS3.
//! Supports multiple devices on internal I2C bus.
//!
//! Hardware Configuration:
//! - I2C0: Internal bus (GPIO12/SDA, GPIO11/SCL)
//!   - AXP2101 (0x34): Power management
//!   - FT6336U (0x38): Touch controller
//!   - BM8563 (0x51): RTC
//!   - AW9523B (0x58): I/O expander
//! - I2C1: Grove Port A (GPIO2/SDA, GPIO1/SCL)

const std = @import("std");

/// I2C Error types
pub const I2cError = error{
    InitFailed,
    Timeout,
    Nack,
    InvalidParameter,
    BusBusy,
    AckError,
    ArbitrationLost,
};

/// I2C Port selection
pub const I2cPort = enum(u8) {
    i2c0 = 0, // Internal bus
    i2c1 = 1, // Grove port
};

/// I2C Speed mode
pub const SpeedMode = enum(u32) {
    standard = 100_000, // 100 kHz
    fast = 400_000, // 400 kHz
    fast_plus = 1_000_000, // 1 MHz
};

/// I2C Bus Configuration
pub const BusConfig = struct {
    sda_pin: u8,
    scl_pin: u8,
    speed: SpeedMode = .fast,
    sda_pullup: bool = true,
    scl_pullup: bool = true,
    timeout_ms: u32 = 1000,
    glitch_filter_ns: u32 = 7,
};

/// Predefined configurations for M5Stack CoreS3
pub const CoreS3Config = struct {
    /// Internal I2C bus (AXP2101, FT6336U, AW9523B, BM8563)
    pub const internal: BusConfig = .{
        .sda_pin = 12,
        .scl_pin = 11,
        .speed = .fast,
    };

    /// Grove Port A
    pub const grove: BusConfig = .{
        .sda_pin = 2,
        .scl_pin = 1,
        .speed = .fast,
    };
};

/// I2C Transaction flags
pub const TransactionFlags = packed struct {
    write: bool = true,
    read: bool = false,
    stop: bool = true,
    restart: bool = false,
    _reserved: u4 = 0,
};

/// I2C Bus handle
pub const I2cBus = struct {
    port: I2cPort,
    config: BusConfig,
    initialized: bool = false,
    mutex_taken: bool = false,

    /// Initialize I2C bus
    pub fn init(port: I2cPort, config: BusConfig) I2cError!I2cBus {
        var bus = I2cBus{
            .port = port,
            .config = config,
        };

        // ESP-IDF: i2c_param_config() + i2c_driver_install()
        // Placeholder for actual implementation

        bus.initialized = true;
        return bus;
    }

    /// Deinitialize I2C bus
    pub fn deinit(self: *I2cBus) void {
        if (!self.initialized) return;
        // ESP-IDF: i2c_driver_delete()
        self.initialized = false;
    }

    /// Acquire bus mutex for multi-device access
    pub fn acquire(self: *I2cBus) I2cError!void {
        if (self.mutex_taken) return I2cError.BusBusy;
        self.mutex_taken = true;
    }

    /// Release bus mutex
    pub fn release(self: *I2cBus) void {
        self.mutex_taken = false;
    }

    /// Write data to device
    pub fn write(self: *I2cBus, address: u7, data: []const u8) I2cError!void {
        _ = self;
        _ = address;
        _ = data;
        // ESP-IDF: i2c_master_write_to_device()
    }

    /// Read data from device
    pub fn read(self: *I2cBus, address: u7, buffer: []u8) I2cError!void {
        _ = self;
        _ = address;
        _ = buffer;
        // ESP-IDF: i2c_master_read_from_device()
    }

    /// Write then read (combined transaction)
    pub fn writeRead(self: *I2cBus, address: u7, write_data: []const u8, read_buffer: []u8) I2cError!void {
        _ = self;
        _ = address;
        _ = write_data;
        _ = read_buffer;
        // ESP-IDF: i2c_master_write_read_device()
    }

    /// Write single register
    pub fn writeRegister(self: *I2cBus, address: u7, register: u8, value: u8) I2cError!void {
        const data = [_]u8{ register, value };
        try self.write(address, &data);
    }

    /// Write multiple bytes to register
    pub fn writeRegisters(self: *I2cBus, address: u7, register: u8, data: []const u8) I2cError!void {
        // Allocate buffer for register + data
        var buffer: [256]u8 = undefined;
        if (data.len + 1 > buffer.len) return I2cError.InvalidParameter;

        buffer[0] = register;
        @memcpy(buffer[1 .. data.len + 1], data);
        try self.write(address, buffer[0 .. data.len + 1]);
    }

    /// Read single register
    pub fn readRegister(self: *I2cBus, address: u7, register: u8) I2cError!u8 {
        var buffer: [1]u8 = undefined;
        try self.writeRead(address, &[_]u8{register}, &buffer);
        return buffer[0];
    }

    /// Read multiple registers
    pub fn readRegisters(self: *I2cBus, address: u7, start_register: u8, buffer: []u8) I2cError!void {
        try self.writeRead(address, &[_]u8{start_register}, buffer);
    }

    /// Modify register bits
    pub fn modifyRegister(self: *I2cBus, address: u7, register: u8, mask: u8, value: u8) I2cError!void {
        const current = try self.readRegister(address, register);
        const new_value = (current & ~mask) | (value & mask);
        try self.writeRegister(address, register, new_value);
    }

    /// Set bits in register
    pub fn setBits(self: *I2cBus, address: u7, register: u8, bits: u8) I2cError!void {
        try self.modifyRegister(address, register, bits, bits);
    }

    /// Clear bits in register
    pub fn clearBits(self: *I2cBus, address: u7, register: u8, bits: u8) I2cError!void {
        try self.modifyRegister(address, register, bits, 0);
    }

    /// Check if device is present
    pub fn probe(self: *I2cBus, address: u7) bool {
        var dummy: [1]u8 = undefined;
        self.read(address, &dummy) catch return false;
        return true;
    }

    /// Scan bus for devices
    pub fn scan(self: *I2cBus, allocator: std.mem.Allocator) ![]u7 {
        var found = std.ArrayList(u7).init(allocator);
        errdefer found.deinit();

        var addr: u8 = 0x08;
        while (addr < 0x78) : (addr += 1) {
            if (self.probe(@intCast(addr))) {
                try found.append(@intCast(addr));
            }
        }

        return found.toOwnedSlice();
    }
};

/// I2C Device handle for convenience
pub const I2cDevice = struct {
    bus: *I2cBus,
    address: u7,

    pub fn init(bus: *I2cBus, address: u7) I2cDevice {
        return .{
            .bus = bus,
            .address = address,
        };
    }

    pub fn write(self: *I2cDevice, data: []const u8) I2cError!void {
        try self.bus.write(self.address, data);
    }

    pub fn read(self: *I2cDevice, buffer: []u8) I2cError!void {
        try self.bus.read(self.address, buffer);
    }

    pub fn writeRead(self: *I2cDevice, write_data: []const u8, read_buffer: []u8) I2cError!void {
        try self.bus.writeRead(self.address, write_data, read_buffer);
    }

    pub fn writeRegister(self: *I2cDevice, register: u8, value: u8) I2cError!void {
        try self.bus.writeRegister(self.address, register, value);
    }

    pub fn readRegister(self: *I2cDevice, register: u8) I2cError!u8 {
        return try self.bus.readRegister(self.address, register);
    }

    pub fn readRegisters(self: *I2cDevice, start_register: u8, buffer: []u8) I2cError!void {
        try self.bus.readRegisters(self.address, start_register, buffer);
    }

    pub fn modifyRegister(self: *I2cDevice, register: u8, mask: u8, value: u8) I2cError!void {
        try self.bus.modifyRegister(self.address, register, mask, value);
    }

    pub fn setBits(self: *I2cDevice, register: u8, bits: u8) I2cError!void {
        try self.bus.setBits(self.address, register, bits);
    }

    pub fn clearBits(self: *I2cDevice, register: u8, bits: u8) I2cError!void {
        try self.bus.clearBits(self.address, register, bits);
    }
};

/// Known I2C addresses for M5Stack CoreS3
pub const KnownDevices = struct {
    pub const axp2101: u7 = 0x34; // PMIC
    pub const ft6336u: u7 = 0x38; // Touch
    pub const bm8563: u7 = 0x51; // RTC
    pub const aw9523b: u7 = 0x58; // I/O Expander
};

// Tests
test "I2cPort enum" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(I2cPort.i2c0));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(I2cPort.i2c1));
}

test "SpeedMode values" {
    try std.testing.expectEqual(@as(u32, 100_000), @intFromEnum(SpeedMode.standard));
    try std.testing.expectEqual(@as(u32, 400_000), @intFromEnum(SpeedMode.fast));
    try std.testing.expectEqual(@as(u32, 1_000_000), @intFromEnum(SpeedMode.fast_plus));
}

test "CoreS3Config internal bus" {
    try std.testing.expectEqual(@as(u8, 12), CoreS3Config.internal.sda_pin);
    try std.testing.expectEqual(@as(u8, 11), CoreS3Config.internal.scl_pin);
}

test "KnownDevices addresses" {
    try std.testing.expectEqual(@as(u7, 0x34), KnownDevices.axp2101);
    try std.testing.expectEqual(@as(u7, 0x38), KnownDevices.ft6336u);
    try std.testing.expectEqual(@as(u7, 0x58), KnownDevices.aw9523b);
}
