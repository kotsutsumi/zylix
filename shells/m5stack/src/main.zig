//! M5Stack CoreS3 Shell for Zylix
//!
//! Native Zig implementation for ESP32-S3 based M5Stack CoreS3 SE.
//! Provides hardware abstraction for display, touch, power management,
//! and I/O expansion.
//!
//! Hardware Overview:
//! - MCU: ESP32-S3 (Xtensa LX7 dual-core @ 240MHz)
//! - Display: ILI9342C (320x240, SPI)
//! - Touch: FT6336U (I2C @ 0x38)
//! - PMIC: AXP2101 (I2C @ 0x34)
//! - I/O Expander: AW9523B (I2C @ 0x58)

const std = @import("std");

// Hardware Abstraction Layer
pub const hal = @import("hal/hal.zig");

// Device Drivers
pub const drivers = struct {
    pub const ili9342c = @import("drivers/ili9342c.zig");
    pub const ft6336u = @import("drivers/ft6336u.zig");
    pub const aw9523b = @import("drivers/aw9523b.zig");
    pub const axp2101 = @import("drivers/axp2101.zig");
};

/// M5Stack CoreS3 Configuration
pub const Config = struct {
    /// Display configuration
    pub const Display = struct {
        width: u16 = 320,
        height: u16 = 240,
        rotation: Rotation = .portrait,

        pub const Rotation = enum(u8) {
            portrait = 0,
            landscape = 1,
            portrait_inverted = 2,
            landscape_inverted = 3,
        };
    };

    /// GPIO Pin assignments for CoreS3 SE
    pub const Pins = struct {
        // Display (SPI)
        pub const spi_sclk: u8 = 36;
        pub const spi_mosi: u8 = 37;
        pub const spi_miso: u8 = 35;
        pub const lcd_cs: u8 = 3;
        pub const lcd_dc: u8 = 35;

        // Internal I2C Bus
        pub const i2c_sda: u8 = 12;
        pub const i2c_scl: u8 = 11;

        // Touch interrupt
        pub const touch_int: u8 = 21;

        // Grove Port A
        pub const grove_sda: u8 = 2;
        pub const grove_scl: u8 = 1;

        // SD Card
        pub const sd_cs: u8 = 4;
    };

    /// I2C Device addresses
    pub const I2CAddress = struct {
        pub const axp2101: u7 = 0x34; // PMIC
        pub const ft6336u: u7 = 0x38; // Touch
        pub const bm8563: u7 = 0x51; // RTC
        pub const aw9523b: u7 = 0x58; // I/O Expander
    };

    display: Display = .{},
};

/// M5Stack CoreS3 device handle
pub const M5Stack = struct {
    config: Config,
    display: ?drivers.ili9342c.ILI9342C = null,
    touch: ?drivers.ft6336u.FT6336U = null,
    io_expander: ?drivers.aw9523b.AW9523B = null,
    pmic: ?drivers.axp2101.AXP2101 = null,

    /// Initialize the M5Stack CoreS3 device
    pub fn init(config: Config) !M5Stack {
        var self = M5Stack{
            .config = config,
        };

        // Initialize I/O expander first (controls reset pins)
        self.io_expander = try drivers.aw9523b.AW9523B.init(Config.I2CAddress.aw9523b);

        // Initialize PMIC for backlight control
        self.pmic = try drivers.axp2101.AXP2101.init(Config.I2CAddress.axp2101);

        // Reset display via I/O expander
        if (self.io_expander) |*io| {
            try io.setPin(.lcd_reset, false);
            hal.delay_ms(10);
            try io.setPin(.lcd_reset, true);
            hal.delay_ms(120);
        }

        // Initialize display
        self.display = try drivers.ili9342c.ILI9342C.init(.{
            .width = config.display.width,
            .height = config.display.height,
        });

        // Reset and initialize touch controller
        if (self.io_expander) |*io| {
            try io.setPin(.touch_reset, false);
            hal.delay_ms(10);
            try io.setPin(.touch_reset, true);
            hal.delay_ms(50);
        }

        self.touch = try drivers.ft6336u.FT6336U.init(Config.I2CAddress.ft6336u);

        // Enable backlight
        if (self.pmic) |*pmic| {
            try pmic.setBacklight(100);
        }

        return self;
    }

    /// Deinitialize the device
    pub fn deinit(self: *M5Stack) void {
        if (self.display) |*d| d.deinit();
        if (self.touch) |*t| t.deinit();
        if (self.io_expander) |*io| io.deinit();
        if (self.pmic) |*pmic| pmic.deinit();
    }

    /// Clear display with specified color
    pub fn clearScreen(self: *M5Stack, color: u16) void {
        if (self.display) |*d| {
            d.fillScreen(color);
        }
    }

    /// Draw a pixel at (x, y) with specified color
    pub fn drawPixel(self: *M5Stack, x: u16, y: u16, color: u16) void {
        if (self.display) |*d| {
            d.drawPixel(x, y, color);
        }
    }

    /// Read touch input
    pub fn readTouch(self: *M5Stack) ?TouchPoint {
        if (self.touch) |*t| {
            return t.read();
        }
        return null;
    }

    /// Set backlight brightness (0-100)
    pub fn setBacklight(self: *M5Stack, brightness: u8) void {
        if (self.pmic) |*pmic| {
            pmic.setBacklight(brightness) catch {};
        }
    }
};

/// Touch point data
pub const TouchPoint = struct {
    x: u16,
    y: u16,
    pressure: u8,
    id: u8,
};

/// RGB565 color utilities
pub const Color = struct {
    pub const black: u16 = 0x0000;
    pub const white: u16 = 0xFFFF;
    pub const red: u16 = 0xF800;
    pub const green: u16 = 0x07E0;
    pub const blue: u16 = 0x001F;
    pub const yellow: u16 = 0xFFE0;
    pub const cyan: u16 = 0x07FF;
    pub const magenta: u16 = 0xF81F;

    /// Convert RGB888 to RGB565
    pub fn rgb(r: u8, g: u8, b: u8) u16 {
        const r5: u16 = @as(u16, r >> 3) << 11;
        const g6: u16 = @as(u16, g >> 2) << 5;
        const b5: u16 = @as(u16, b >> 3);
        return r5 | g6 | b5;
    }
};

// Tests
test "Color.rgb conversion" {
    try std.testing.expectEqual(@as(u16, 0xFFFF), Color.rgb(255, 255, 255));
    try std.testing.expectEqual(@as(u16, 0x0000), Color.rgb(0, 0, 0));
    try std.testing.expectEqual(@as(u16, 0xF800), Color.rgb(255, 0, 0));
    try std.testing.expectEqual(@as(u16, 0x07E0), Color.rgb(0, 255, 0));
    try std.testing.expectEqual(@as(u16, 0x001F), Color.rgb(0, 0, 255));
}

test "Config defaults" {
    const config = Config{};
    try std.testing.expectEqual(@as(u16, 320), config.display.width);
    try std.testing.expectEqual(@as(u16, 240), config.display.height);
}
