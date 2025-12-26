//! SPI Driver for ESP32-S3
//!
//! High-performance SPI implementation for M5Stack CoreS3.
//! Supports DMA transfers for efficient display updates.
//!
//! Hardware Configuration:
//! - SPI2 (HSPI): Display interface
//! - Clock: Up to 80MHz (40MHz typical for ILI9342C)
//! - DMA: Auto channel selection for large transfers

const std = @import("std");

/// SPI Error types
pub const SpiError = error{
    InitFailed,
    TransferFailed,
    Timeout,
    InvalidParameter,
    DmaError,
    BusyError,
};

/// SPI Host selection
pub const SpiHost = enum(u8) {
    spi1 = 0, // Reserved for flash
    spi2 = 1, // HSPI - Available for peripherals
    spi3 = 2, // VSPI - Available for peripherals
};

/// SPI Clock mode (CPOL/CPHA)
pub const SpiMode = enum(u2) {
    mode0 = 0, // CPOL=0, CPHA=0
    mode1 = 1, // CPOL=0, CPHA=1
    mode2 = 2, // CPOL=1, CPHA=0
    mode3 = 3, // CPOL=1, CPHA=1
};

/// SPI Bit order
pub const BitOrder = enum(u1) {
    msb_first = 0,
    lsb_first = 1,
};

/// SPI Bus Configuration
pub const BusConfig = struct {
    mosi_pin: u8 = 37, // GPIO37 for CoreS3
    miso_pin: ?u8 = 35, // GPIO35, optional for write-only
    sclk_pin: u8 = 36, // GPIO36
    quadwp_pin: ?u8 = null,
    quadhd_pin: ?u8 = null,
    max_transfer_size: u32 = 320 * 240 * 2, // Full frame buffer
    dma_channel: DmaChannel = .auto,

    pub const DmaChannel = enum(u8) {
        disabled = 0,
        channel1 = 1,
        channel2 = 2,
        auto = 3,
    };
};

/// SPI Device Configuration
pub const DeviceConfig = struct {
    clock_speed_hz: u32 = 40_000_000, // 40MHz default
    mode: SpiMode = .mode0,
    cs_pin: ?u8 = 3, // GPIO3 for LCD CS
    queue_size: u8 = 7, // Transaction queue depth
    pre_cb: ?*const fn () void = null,
    post_cb: ?*const fn () void = null,
    flags: Flags = .{},

    pub const Flags = packed struct {
        half_duplex: bool = false,
        no_cs: bool = false,
        positive_cs: bool = false,
        _reserved: u5 = 0,
    };
};

/// SPI Transaction
pub const Transaction = struct {
    flags: Flags = .{},
    command: u16 = 0,
    command_bits: u8 = 0,
    address: u64 = 0,
    address_bits: u8 = 0,
    tx_data: ?[]const u8 = null,
    rx_data: ?[]u8 = null,
    length_bits: usize = 0,
    user_data: ?*anyopaque = null,

    pub const Flags = packed struct {
        transmit_command: bool = false,
        transmit_address: bool = false,
        use_dma: bool = true,
        _reserved: u5 = 0,
    };

    /// Create a simple transmit transaction
    pub fn transmit(data: []const u8) Transaction {
        return .{
            .tx_data = data,
            .length_bits = data.len * 8,
        };
    }

    /// Create a transmit transaction with command byte
    pub fn transmitWithCommand(cmd: u8, data: []const u8) Transaction {
        return .{
            .flags = .{ .transmit_command = true },
            .command = cmd,
            .command_bits = 8,
            .tx_data = data,
            .length_bits = data.len * 8,
        };
    }

    /// Create a receive transaction
    pub fn receive(buffer: []u8) Transaction {
        return .{
            .rx_data = buffer,
            .length_bits = buffer.len * 8,
        };
    }

    /// Create a full-duplex transaction
    pub fn transfer(tx: []const u8, rx: []u8) Transaction {
        return .{
            .tx_data = tx,
            .rx_data = rx,
            .length_bits = @max(tx.len, rx.len) * 8,
        };
    }
};

/// SPI Bus handle
pub const SpiBus = struct {
    host: SpiHost,
    config: BusConfig,
    initialized: bool = false,

    /// Initialize SPI bus
    pub fn init(host: SpiHost, config: BusConfig) SpiError!SpiBus {
        var bus = SpiBus{
            .host = host,
            .config = config,
        };

        // ESP-IDF: spi_bus_initialize()
        // This would call into ESP-IDF via C ABI
        // Placeholder for actual implementation

        bus.initialized = true;
        return bus;
    }

    /// Deinitialize SPI bus
    pub fn deinit(self: *SpiBus) void {
        if (!self.initialized) return;
        // ESP-IDF: spi_bus_free()
        self.initialized = false;
    }

    /// Add a device to the bus
    pub fn addDevice(self: *SpiBus, config: DeviceConfig) SpiError!SpiDevice {
        if (!self.initialized) return SpiError.InitFailed;
        return SpiDevice.init(self, config);
    }
};

/// SPI Device handle
pub const SpiDevice = struct {
    bus: *SpiBus,
    config: DeviceConfig,
    handle: usize = 0, // ESP-IDF spi_device_handle_t

    /// Initialize SPI device
    pub fn init(bus: *SpiBus, config: DeviceConfig) SpiError!SpiDevice {
        const device = SpiDevice{
            .bus = bus,
            .config = config,
        };

        // ESP-IDF: spi_bus_add_device()
        // Placeholder for actual implementation

        return device;
    }

    /// Remove device from bus
    pub fn deinit(self: *SpiDevice) void {
        // ESP-IDF: spi_bus_remove_device()
        _ = self;
    }

    /// Execute a single transaction (blocking)
    pub fn transmit(self: *SpiDevice, trans: Transaction) SpiError!void {
        _ = self;
        _ = trans;
        // ESP-IDF: spi_device_transmit()
        // Placeholder for actual implementation
    }

    /// Queue a transaction (non-blocking)
    pub fn queueTransaction(self: *SpiDevice, trans: Transaction) SpiError!void {
        _ = self;
        _ = trans;
        // ESP-IDF: spi_device_queue_trans()
    }

    /// Get result of queued transaction
    pub fn getTransactionResult(self: *SpiDevice, timeout_ms: u32) SpiError!Transaction {
        _ = self;
        _ = timeout_ms;
        // ESP-IDF: spi_device_get_trans_result()
        return .{};
    }

    /// Acquire bus for exclusive access
    pub fn acquireBus(self: *SpiDevice) SpiError!void {
        _ = self;
        // ESP-IDF: spi_device_acquire_bus()
    }

    /// Release bus
    pub fn releaseBus(self: *SpiDevice) void {
        _ = self;
        // ESP-IDF: spi_device_release_bus()
    }

    /// Send data with CS control
    pub fn send(self: *SpiDevice, data: []const u8) SpiError!void {
        try self.transmit(Transaction.transmit(data));
    }

    /// Send command byte followed by data
    pub fn sendCommand(self: *SpiDevice, cmd: u8, data: []const u8) SpiError!void {
        try self.transmit(Transaction.transmitWithCommand(cmd, data));
    }

    /// Send command byte only
    pub fn sendCommandOnly(self: *SpiDevice, cmd: u8) SpiError!void {
        try self.transmit(.{
            .flags = .{ .transmit_command = true },
            .command = cmd,
            .command_bits = 8,
            .length_bits = 0,
        });
    }

    /// Polling transmit for small data
    pub fn pollingTransmit(self: *SpiDevice, data: []const u8) SpiError!void {
        _ = self;
        _ = data;
        // ESP-IDF: spi_device_polling_transmit()
    }
};

/// High-level display SPI interface
pub const DisplaySpi = struct {
    device: SpiDevice,
    dc_pin: u8, // Data/Command pin

    /// GPIO control for D/C pin (placeholder)
    fn setDcPin(self: *DisplaySpi, is_data: bool) void {
        _ = self;
        _ = is_data;
        // ESP-IDF: gpio_set_level()
    }

    /// Send command to display
    pub fn writeCommand(self: *DisplaySpi, cmd: u8) SpiError!void {
        self.setDcPin(false); // Command mode
        const data = [_]u8{cmd};
        try self.device.send(&data);
    }

    /// Send data to display
    pub fn writeData(self: *DisplaySpi, data: []const u8) SpiError!void {
        self.setDcPin(true); // Data mode
        try self.device.send(data);
    }

    /// Send command followed by data
    pub fn writeCommandData(self: *DisplaySpi, cmd: u8, data: []const u8) SpiError!void {
        try self.writeCommand(cmd);
        if (data.len > 0) {
            try self.writeData(data);
        }
    }

    /// Send pixel data with DMA (for frame buffer flush)
    pub fn writePixelsDma(self: *DisplaySpi, pixels: []const u8) SpiError!void {
        self.setDcPin(true); // Data mode

        // Use DMA for large transfers
        const trans = Transaction{
            .flags = .{ .use_dma = true },
            .tx_data = pixels,
            .length_bits = pixels.len * 8,
        };
        try self.device.transmit(trans);
    }

    /// Batch write for multiple small writes
    pub fn writeBatch(self: *DisplaySpi, commands: []const CommandData) SpiError!void {
        for (commands) |cmd| {
            try self.writeCommandData(cmd.command, cmd.data);
        }
    }

    pub const CommandData = struct {
        command: u8,
        data: []const u8,
    };
};

// Tests
test "Transaction creation" {
    const data = [_]u8{ 0x01, 0x02, 0x03 };
    const tx = Transaction.transmit(&data);
    try std.testing.expectEqual(@as(usize, 24), tx.length_bits);
    try std.testing.expect(tx.tx_data != null);
}

test "SpiMode values" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(SpiMode.mode0));
    try std.testing.expectEqual(@as(u2, 3), @intFromEnum(SpiMode.mode3));
}

test "BusConfig defaults" {
    const config = BusConfig{};
    try std.testing.expectEqual(@as(u8, 37), config.mosi_pin);
    try std.testing.expectEqual(@as(u8, 36), config.sclk_pin);
    try std.testing.expectEqual(@as(u32, 320 * 240 * 2), config.max_transfer_size);
}

test "DeviceConfig defaults" {
    const config = DeviceConfig{};
    try std.testing.expectEqual(@as(u32, 40_000_000), config.clock_speed_hz);
    try std.testing.expectEqual(SpiMode.mode0, config.mode);
}
