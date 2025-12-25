//! ILI9342C Display Driver
//!
//! Driver for ILI9342C LCD controller used in M5Stack CoreS3.
//! 320x240 resolution, RGB565 color format, SPI interface.
//!
//! Key differences from ILI9341:
//! - Different initialization sequence
//! - Inverted color mode by default
//! - Slightly different gamma correction

const std = @import("std");
const hal = @import("../hal/hal.zig");

/// ILI9342C Command definitions
pub const Command = enum(u8) {
    // System commands
    nop = 0x00,
    swreset = 0x01, // Software reset
    rddid = 0x04, // Read display ID
    rddst = 0x09, // Read display status

    // Power control
    slpin = 0x10, // Enter sleep mode
    slpout = 0x11, // Exit sleep mode
    ptlon = 0x12, // Partial mode on
    noron = 0x13, // Normal mode on

    // Display control
    invoff = 0x20, // Display inversion off
    invon = 0x21, // Display inversion on
    gamset = 0x26, // Gamma set
    dispoff = 0x28, // Display off
    dispon = 0x29, // Display on

    // Memory access
    caset = 0x2A, // Column address set
    paset = 0x2B, // Page address set
    ramwr = 0x2C, // Memory write
    ramrd = 0x2E, // Memory read

    // Partial area
    ptlar = 0x30, // Partial area
    vscrdef = 0x33, // Vertical scrolling definition
    teoff = 0x34, // Tearing effect off
    teon = 0x35, // Tearing effect on
    madctl = 0x36, // Memory access control
    vscrsadd = 0x37, // Vertical scrolling start address
    idmoff = 0x38, // Idle mode off
    idmon = 0x39, // Idle mode on
    colmod = 0x3A, // Pixel format set
    ramwrc = 0x3C, // Memory write continue
    ramrdc = 0x3E, // Memory read continue

    // Frame rate control
    frmctr1 = 0xB1, // Frame rate control (normal mode)
    frmctr2 = 0xB2, // Frame rate control (idle mode)
    frmctr3 = 0xB3, // Frame rate control (partial mode)
    invctr = 0xB4, // Display inversion control

    // Display function control
    dfunctr = 0xB6, // Display function control

    // Power control
    pwctr1 = 0xC0, // Power control 1
    pwctr2 = 0xC1, // Power control 2
    pwctr3 = 0xC2, // Power control 3
    pwctr4 = 0xC3, // Power control 4
    pwctr5 = 0xC4, // Power control 5
    vmctr1 = 0xC5, // VCOM control 1
    vmctr2 = 0xC7, // VCOM control 2

    // Gamma control
    gmctrp1 = 0xE0, // Positive gamma correction
    gmctrn1 = 0xE1, // Negative gamma correction

    // Other
    rdid1 = 0xDA, // Read ID1
    rdid2 = 0xDB, // Read ID2
    rdid3 = 0xDC, // Read ID3
    rdid4 = 0xDD, // Read ID4
};

/// MADCTL (Memory Access Control) bits
pub const MadCtl = struct {
    pub const my: u8 = 0x80; // Row address order
    pub const mx: u8 = 0x40; // Column address order
    pub const mv: u8 = 0x20; // Row/Column exchange
    pub const ml: u8 = 0x10; // Vertical refresh order
    pub const bgr: u8 = 0x08; // BGR order
    pub const mh: u8 = 0x04; // Horizontal refresh order
};

/// Display configuration
pub const Config = struct {
    width: u16 = 320,
    height: u16 = 240,
    rotation: Rotation = .portrait,
    invert_colors: bool = true, // ILI9342C typically needs inversion

    pub const Rotation = enum(u2) {
        portrait = 0,
        landscape = 1,
        portrait_inverted = 2,
        landscape_inverted = 3,
    };
};

/// ILI9342C Driver
pub const ILI9342C = struct {
    config: Config,
    spi: ?hal.Spi = null,
    width: u16,
    height: u16,

    /// Initialize the display
    pub fn init(config: Config) !ILI9342C {
        var self = ILI9342C{
            .config = config,
            .width = config.width,
            .height = config.height,
        };

        // Initialize SPI
        self.spi = try hal.Spi.init(.spi2, .{
            .clock_speed_hz = 40_000_000, // 40MHz
            .mode = .mode0,
        });

        // Run initialization sequence
        try self.initSequence();

        return self;
    }

    /// Deinitialize the display
    pub fn deinit(self: *ILI9342C) void {
        if (self.spi) |*spi| {
            spi.deinit();
        }
    }

    /// Send command to display
    fn sendCommand(self: *ILI9342C, cmd: Command) !void {
        _ = self;
        _ = cmd;
        // Set D/C pin low (command mode)
        // Send via SPI
    }

    /// Send data to display
    fn sendData(self: *ILI9342C, data: []const u8) !void {
        _ = self;
        _ = data;
        // Set D/C pin high (data mode)
        // Send via SPI
    }

    /// Send command with data
    fn sendCommandWithData(self: *ILI9342C, cmd: Command, data: []const u8) !void {
        try self.sendCommand(cmd);
        if (data.len > 0) {
            try self.sendData(data);
        }
    }

    /// Initialize display with ILI9342C-specific sequence
    fn initSequence(self: *ILI9342C) !void {
        // Software reset
        try self.sendCommand(.swreset);
        hal.delay_ms(150);

        // Exit sleep mode
        try self.sendCommand(.slpout);
        hal.delay_ms(120);

        // Pixel format: 16-bit RGB565
        try self.sendCommandWithData(.colmod, &[_]u8{0x55});

        // Frame rate control (normal mode): 70Hz
        try self.sendCommandWithData(.frmctr1, &[_]u8{ 0x00, 0x18 });

        // Display function control
        try self.sendCommandWithData(.dfunctr, &[_]u8{ 0x08, 0x82, 0x27 });

        // Power control 1
        try self.sendCommandWithData(.pwctr1, &[_]u8{0x23});

        // Power control 2
        try self.sendCommandWithData(.pwctr2, &[_]u8{0x10});

        // VCOM control 1
        try self.sendCommandWithData(.vmctr1, &[_]u8{ 0x3E, 0x28 });

        // VCOM control 2
        try self.sendCommandWithData(.vmctr2, &[_]u8{0x86});

        // Memory access control (rotation)
        const madctl = self.getMadCtl();
        try self.sendCommandWithData(.madctl, &[_]u8{madctl});

        // Positive gamma correction
        try self.sendCommandWithData(.gmctrp1, &[_]u8{
            0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
            0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
        });

        // Negative gamma correction
        try self.sendCommandWithData(.gmctrn1, &[_]u8{
            0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
            0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
        });

        // Inversion (ILI9342C specific)
        if (self.config.invert_colors) {
            try self.sendCommand(.invon);
        } else {
            try self.sendCommand(.invoff);
        }

        // Display on
        try self.sendCommand(.dispon);
        hal.delay_ms(120);
    }

    /// Get MADCTL value for current rotation
    fn getMadCtl(self: *ILI9342C) u8 {
        return switch (self.config.rotation) {
            .portrait => MadCtl.mx | MadCtl.bgr,
            .landscape => MadCtl.mv | MadCtl.bgr,
            .portrait_inverted => MadCtl.my | MadCtl.bgr,
            .landscape_inverted => MadCtl.mx | MadCtl.my | MadCtl.mv | MadCtl.bgr,
        };
    }

    /// Set address window for drawing
    fn setAddressWindow(self: *ILI9342C, x0: u16, y0: u16, x1: u16, y1: u16) !void {
        // Column address set
        try self.sendCommandWithData(.caset, &[_]u8{
            @intCast(x0 >> 8),
            @intCast(x0 & 0xFF),
            @intCast(x1 >> 8),
            @intCast(x1 & 0xFF),
        });

        // Page address set
        try self.sendCommandWithData(.paset, &[_]u8{
            @intCast(y0 >> 8),
            @intCast(y0 & 0xFF),
            @intCast(y1 >> 8),
            @intCast(y1 & 0xFF),
        });

        // Memory write
        try self.sendCommand(.ramwr);
    }

    /// Draw a single pixel
    pub fn drawPixel(self: *ILI9342C, x: u16, y: u16, color: u16) void {
        if (x >= self.width or y >= self.height) return;

        self.setAddressWindow(x, y, x, y) catch return;

        const data = [_]u8{
            @intCast(color >> 8),
            @intCast(color & 0xFF),
        };
        self.sendData(&data) catch return;
    }

    /// Fill screen with color
    pub fn fillScreen(self: *ILI9342C, color: u16) void {
        self.fillRect(0, 0, self.width, self.height, color);
    }

    /// Fill rectangle with color
    pub fn fillRect(self: *ILI9342C, x: u16, y: u16, w: u16, h: u16, color: u16) void {
        if (x >= self.width or y >= self.height) return;

        const x1 = @min(x + w - 1, self.width - 1);
        const y1 = @min(y + h - 1, self.height - 1);

        self.setAddressWindow(x, y, x1, y1) catch return;

        const hi: u8 = @intCast(color >> 8);
        const lo: u8 = @intCast(color & 0xFF);

        // Send pixel data
        const pixel_count = @as(u32, w) * @as(u32, h);
        var i: u32 = 0;
        while (i < pixel_count) : (i += 1) {
            self.sendData(&[_]u8{ hi, lo }) catch return;
        }
    }

    /// Draw horizontal line
    pub fn drawHLine(self: *ILI9342C, x: u16, y: u16, length: u16, color: u16) void {
        self.fillRect(x, y, length, 1, color);
    }

    /// Draw vertical line
    pub fn drawVLine(self: *ILI9342C, x: u16, y: u16, length: u16, color: u16) void {
        self.fillRect(x, y, 1, length, color);
    }

    /// Set rotation
    pub fn setRotation(self: *ILI9342C, rotation: Config.Rotation) !void {
        self.config.rotation = rotation;

        // Swap width/height for landscape
        switch (rotation) {
            .portrait, .portrait_inverted => {
                self.width = self.config.width;
                self.height = self.config.height;
            },
            .landscape, .landscape_inverted => {
                self.width = self.config.height;
                self.height = self.config.width;
            },
        }

        const madctl = self.getMadCtl();
        try self.sendCommandWithData(.madctl, &[_]u8{madctl});
    }

    /// Enter sleep mode
    pub fn sleep(self: *ILI9342C) !void {
        try self.sendCommand(.dispoff);
        hal.delay_ms(20);
        try self.sendCommand(.slpin);
        hal.delay_ms(120);
    }

    /// Exit sleep mode
    pub fn wake(self: *ILI9342C) !void {
        try self.sendCommand(.slpout);
        hal.delay_ms(120);
        try self.sendCommand(.dispon);
        hal.delay_ms(20);
    }
};

// Tests
test "Command enum values" {
    try std.testing.expectEqual(@as(u8, 0x00), @intFromEnum(Command.nop));
    try std.testing.expectEqual(@as(u8, 0x01), @intFromEnum(Command.swreset));
    try std.testing.expectEqual(@as(u8, 0x2C), @intFromEnum(Command.ramwr));
}

test "Config defaults" {
    const config = Config{};
    try std.testing.expectEqual(@as(u16, 320), config.width);
    try std.testing.expectEqual(@as(u16, 240), config.height);
    try std.testing.expect(config.invert_colors);
}

test "MadCtl bit values" {
    try std.testing.expectEqual(@as(u8, 0x80), MadCtl.my);
    try std.testing.expectEqual(@as(u8, 0x40), MadCtl.mx);
    try std.testing.expectEqual(@as(u8, 0x08), MadCtl.bgr);
}
