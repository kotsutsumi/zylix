# M5Stack CoreS3 Shell for Zylix

Native Zig implementation for M5Stack CoreS3 SE (ESP32-S3).

## Overview

This shell provides Zylix framework support for the M5Stack CoreS3 SE embedded device, enabling native Zig applications to run on ESP32-S3 hardware.

## Hardware Specifications

| Component | Part Number | Interface | Description |
|-----------|-------------|-----------|-------------|
| **MCU** | ESP32-S3 | - | Xtensa LX7 dual-core @ 240MHz |
| **Display** | ILI9342C | SPI | 320x240 IPS LCD, RGB565 |
| **Touch** | FT6336U | I2C @ 0x38 | Capacitive touch, 2-point |
| **PMIC** | AXP2101 | I2C @ 0x34 | Power management, backlight |
| **I/O Expander** | AW9523B | I2C @ 0x58 | Reset control, GPIO expansion |

## Pin Assignments

### Display (SPI)

| Signal | GPIO |
|--------|------|
| SCLK | GPIO36 |
| MOSI | GPIO37 |
| CS | GPIO3 |
| D/C | GPIO35 |
| RST | AW9523B P1_1 |

### Touch (I2C)

| Signal | GPIO |
|--------|------|
| SDA | GPIO12 |
| SCL | GPIO11 |
| INT | GPIO21 |
| RST | AW9523B P1_0 |

## Requirements

### Toolchain

Standard upstream Zig does **not** support ESP32-S3 (Xtensa architecture). You need one of:

1. **zig-xtensa** fork: https://github.com/INetBowser/zig-xtensa
2. **zig-esp-idf-sample**: https://github.com/kassane/zig-esp-idf-sample

### ESP-IDF

```bash
# Install ESP-IDF v5.3
git clone -b v5.3 --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh esp32s3
source export.sh
```

## Project Structure

```
shells/m5stack/
├── build.zig              # Build configuration
├── README.md              # This file
└── src/
    ├── main.zig           # Entry point and M5Stack API
    ├── hal/
    │   ├── hal.zig        # Hardware abstraction layer
    │   ├── spi.zig        # SPI driver with DMA support
    │   └── i2c.zig        # I2C driver with device abstraction
    ├── graphics/
    │   ├── framebuffer.zig # RGB565 frame buffer management
    │   ├── graphics.zig   # 2D graphics primitives
    │   └── display.zig    # Display controller integration
    └── drivers/
        ├── ili9342c.zig   # Display controller
        ├── ft6336u.zig    # Touch controller
        ├── aw9523b.zig    # I/O expander
        └── axp2101.zig    # Power management
```

## Quick Start

```zig
const m5stack = @import("m5stack");

pub fn main() !void {
    // Initialize M5Stack
    var device = try m5stack.M5Stack.init(.{});
    defer device.deinit();

    // Clear screen
    device.clearScreen(m5stack.Color.black);

    // Draw something
    device.drawPixel(160, 120, m5stack.Color.white);

    // Read touch
    if (device.readTouch()) |point| {
        // Handle touch at point.x, point.y
    }

    // Set backlight
    device.setBacklight(80); // 80%
}
```

## Building

```bash
# Build for ESP32-S3 (requires zig-xtensa)
zig build

# Run tests (host target)
zig build test

# Generate documentation
zig build docs
```

## Implementation Status

### Phase 1: Foundation ✅

- [x] Project structure
- [x] ILI9342C display driver
- [x] FT6336U touch driver
- [x] AW9523B I/O expander driver
- [x] AXP2101 PMIC driver
- [x] Basic HAL (GPIO, timers)

### Phase 2: Display Integration ✅

- [x] SPI driver with DMA support
- [x] I2C driver with device abstraction
- [x] Frame buffer management (RGB565, double buffering)
- [x] Graphics primitives (lines, circles, rectangles, bezier)
- [x] Text rendering with bitmap fonts
- [x] Dirty region tracking for partial updates
- [x] Display controller with DMA transfers

### Phase 3: Touch Integration

- [ ] Gesture recognition
- [ ] Multi-touch support
- [ ] Interrupt handling

### Phase 4: Zylix Core Integration

- [ ] Virtual DOM renderer
- [ ] Event system integration
- [ ] Component library support

### Phase 5: Samples and Testing

- [ ] Hello World sample
- [ ] Counter sample
- [ ] Touch demo
- [ ] On-device testing

## References

- [M5Stack CoreS3 SE Documentation](https://docs.m5stack.com/en/products/sku/K128-SE)
- [ILI9342C Datasheet](https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/docs/datasheet/core/ILI9342C-ILITEK.pdf)
- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/)
- [zig-xtensa](https://github.com/INetBowser/zig-xtensa)
- [zig-esp-idf-sample](https://github.com/kassane/zig-esp-idf-sample)

## License

Apache License 2.0
