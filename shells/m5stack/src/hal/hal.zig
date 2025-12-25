//! Hardware Abstraction Layer for ESP32-S3
//!
//! Provides low-level access to ESP32-S3 peripherals.
//! This module abstracts the ESP-IDF driver layer.
//!
//! Modules:
//! - spi: SPI driver with DMA support
//! - i2c: I2C driver with device abstraction

const std = @import("std");

// Re-export advanced HAL modules
pub const spi_driver = @import("spi.zig");
pub const i2c_driver = @import("i2c.zig");

/// SPI peripheral interface
pub const Spi = struct {
    host: SpiHost,
    config: Config,

    pub const SpiHost = enum(u8) {
        spi2 = 1,
        spi3 = 2,
    };

    pub const Config = struct {
        clock_speed_hz: u32 = 40_000_000, // 40MHz
        mode: Mode = .mode0,
        dma_channel: u8 = 1,

        pub const Mode = enum(u2) {
            mode0 = 0, // CPOL=0, CPHA=0
            mode1 = 1, // CPOL=0, CPHA=1
            mode2 = 2, // CPOL=1, CPHA=0
            mode3 = 3, // CPOL=1, CPHA=1
        };
    };

    /// Initialize SPI peripheral
    pub fn init(host: SpiHost, config: Config) !Spi {
        // ESP-IDF: spi_bus_initialize()
        // Placeholder implementation
        return Spi{
            .host = host,
            .config = config,
        };
    }

    /// Deinitialize SPI
    pub fn deinit(self: *Spi) void {
        _ = self;
        // ESP-IDF: spi_bus_free()
    }

    /// Transmit data
    pub fn transmit(self: *Spi, data: []const u8) !void {
        _ = self;
        _ = data;
        // ESP-IDF: spi_device_transmit()
    }

    /// Transmit and receive data
    pub fn transfer(self: *Spi, tx: []const u8, rx: []u8) !void {
        _ = self;
        _ = tx;
        _ = rx;
        // ESP-IDF: spi_device_transmit() with rx_buffer
    }
};

/// I2C peripheral interface
pub const I2c = struct {
    port: Port,
    config: Config,

    pub const Port = enum(u8) {
        i2c0 = 0,
        i2c1 = 1,
    };

    pub const Config = struct {
        sda_pin: u8 = 12,
        scl_pin: u8 = 11,
        clock_speed_hz: u32 = 400_000, // 400kHz Fast Mode
        pull_up_enable: bool = true,
    };

    /// Initialize I2C peripheral
    pub fn init(port: Port, config: Config) !I2c {
        // ESP-IDF: i2c_param_config() + i2c_driver_install()
        return I2c{
            .port = port,
            .config = config,
        };
    }

    /// Deinitialize I2C
    pub fn deinit(self: *I2c) void {
        _ = self;
        // ESP-IDF: i2c_driver_delete()
    }

    /// Write to I2C device
    pub fn write(self: *I2c, address: u7, data: []const u8) !void {
        _ = self;
        _ = address;
        _ = data;
        // ESP-IDF: i2c_master_write_to_device()
    }

    /// Read from I2C device
    pub fn read(self: *I2c, address: u7, buffer: []u8) !void {
        _ = self;
        _ = address;
        _ = buffer;
        // ESP-IDF: i2c_master_read_from_device()
    }

    /// Write then read (combined transaction)
    pub fn writeRead(self: *I2c, address: u7, write_data: []const u8, read_buffer: []u8) !void {
        _ = self;
        _ = address;
        _ = write_data;
        _ = read_buffer;
        // ESP-IDF: i2c_master_write_read_device()
    }

    /// Write single register
    pub fn writeRegister(self: *I2c, address: u7, register: u8, value: u8) !void {
        const data = [_]u8{ register, value };
        try self.write(address, &data);
    }

    /// Read single register
    pub fn readRegister(self: *I2c, address: u7, register: u8) !u8 {
        var buffer: [1]u8 = undefined;
        try self.writeRead(address, &[_]u8{register}, &buffer);
        return buffer[0];
    }
};

/// GPIO interface
pub const Gpio = struct {
    pin: u8,
    mode: Mode,

    pub const Mode = enum(u8) {
        input = 0,
        output = 1,
        input_output = 2,
    };

    pub const Pull = enum(u8) {
        none = 0,
        up = 1,
        down = 2,
    };

    /// Configure GPIO pin
    pub fn init(pin: u8, mode: Mode, pull: Pull) !Gpio {
        _ = pull;
        // ESP-IDF: gpio_config()
        return Gpio{
            .pin = pin,
            .mode = mode,
        };
    }

    /// Set output level
    pub fn set(self: *Gpio, high: bool) void {
        _ = self;
        _ = high;
        // ESP-IDF: gpio_set_level()
    }

    /// Get input level
    pub fn get(self: *Gpio) bool {
        _ = self;
        // ESP-IDF: gpio_get_level()
        return false;
    }
};

/// Timer/delay utilities
pub fn delay_ms(ms: u32) void {
    // ESP-IDF: vTaskDelay() or esp_rom_delay_us()
    _ = ms;
}

pub fn delay_us(us: u32) void {
    // ESP-IDF: esp_rom_delay_us()
    _ = us;
}

/// Get system time in milliseconds
pub fn millis() u64 {
    // ESP-IDF: esp_timer_get_time() / 1000
    return 0;
}

/// Get system time in microseconds
pub fn micros() u64 {
    // ESP-IDF: esp_timer_get_time()
    return 0;
}

/// Memory-mapped I/O helpers
pub fn writeReg(addr: u32, value: u32) void {
    const ptr: *volatile u32 = @ptrFromInt(addr);
    ptr.* = value;
}

pub fn readReg(addr: u32) u32 {
    const ptr: *volatile u32 = @ptrFromInt(addr);
    return ptr.*;
}

// Tests
test "Gpio Mode enum" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(Gpio.Mode.input));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(Gpio.Mode.output));
}

test "Spi Config defaults" {
    const config = Spi.Config{};
    try std.testing.expectEqual(@as(u32, 40_000_000), config.clock_speed_hz);
}
