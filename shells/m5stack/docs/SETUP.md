# M5Stack CoreS3 SE + Zylix Setup Guide

This guide walks you through setting up the development environment for running Zylix on M5Stack CoreS3 SE.

## Prerequisites

### Hardware

- **M5Stack CoreS3 SE** (ESP32-S3 based)
- USB-C cable for programming
- Computer running macOS, Linux, or Windows

### Software Requirements

- Git
- Python 3.8+
- CMake 3.16+

## 1. Install ESP-IDF

ESP-IDF (Espressif IoT Development Framework) is required for ESP32-S3 development.

```bash
# Clone ESP-IDF v5.3
git clone -b v5.3 --recursive https://github.com/espressif/esp-idf.git ~/esp/esp-idf
cd ~/esp/esp-idf

# Run the installer (installs toolchain for ESP32-S3)
./install.sh esp32s3

# Set up environment variables
source export.sh

# Verify installation
idf.py --version
```

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
alias get_idf='. $HOME/esp/esp-idf/export.sh'
```

## 2. Install Zig-Xtensa Toolchain

Standard Zig does not support ESP32-S3 (Xtensa architecture). Use one of these options:

### Option A: zig-esp-idf-sample (Recommended)

```bash
git clone https://github.com/kassane/zig-esp-idf-sample.git
cd zig-esp-idf-sample

# Follow the project's setup instructions
```

### Option B: zig-xtensa Fork

```bash
git clone https://github.com/INetBowser/zig-xtensa.git
cd zig-xtensa
git checkout xtensa

# Build Zig with Xtensa LLVM backend
# (Requires LLVM with Xtensa support)
```

## 3. Clone Zylix

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 4. Build for M5Stack CoreS3

### Native Build (for testing on host)

```bash
cd shells/m5stack
zig build
```

### ESP32-S3 Build

```bash
# Ensure ESP-IDF is active
get_idf

# Build for ESP32-S3
cd shells/m5stack
zig build -Dtarget=xtensa-esp32s3-none
```

## 5. Flash to Device

Connect your M5Stack CoreS3 SE via USB-C, then:

```bash
# Find the port (usually /dev/ttyUSB0 on Linux, /dev/cu.usbserial-* on macOS)
ls /dev/tty*

# Flash
idf.py -p /dev/ttyUSB0 flash

# Monitor serial output
idf.py -p /dev/ttyUSB0 monitor
```

## 6. Run Samples

### Hello World

```bash
cd shells/m5stack/samples/hello-world
zig build
# Flash and run
```

### Counter

```bash
cd shells/m5stack/samples/counter
zig build
```

### Touch Demo

```bash
cd shells/m5stack/samples/touch-demo
zig build
```

## Hardware Reference

### Pin Assignments

| Component | Interface | Pins |
|-----------|-----------|------|
| Display (ILI9342C) | SPI | SCLK=GPIO36, MOSI=GPIO37, CS=GPIO3, D/C=GPIO35 |
| Touch (FT6336U) | I2C | SDA=GPIO12, SCL=GPIO11, INT=GPIO21 |
| I/O Expander (AW9523B) | I2C | Address 0x58 |
| PMIC (AXP2101) | I2C | Address 0x34 |

### I2C Bus

All internal peripherals share I2C bus on GPIO11 (SCL) / GPIO12 (SDA):

| Device | Address | Function |
|--------|---------|----------|
| AXP2101 | 0x34 | Power management |
| FT6336U | 0x38 | Touch controller |
| BM8563 | 0x51 | RTC |
| AW9523B | 0x58 | I/O expander |

## Troubleshooting

### Device Not Detected

1. Check USB cable (use data cable, not charge-only)
2. Install USB drivers if needed
3. Check permissions: `sudo usermod -a -G dialout $USER` (Linux)

### Build Errors

1. Ensure ESP-IDF environment is active: `get_idf`
2. Check Zig-Xtensa is in PATH
3. Clean build: `rm -rf zig-cache .zig-cache`

### Display Not Working

1. Verify SPI connections
2. Check AW9523B initialization (controls LCD reset)
3. Verify AXP2101 backlight power

### Touch Not Responding

1. Check I2C connections
2. Verify FT6336U initialization
3. Check interrupt pin (GPIO21)

## Resources

- [M5Stack CoreS3 SE Documentation](https://docs.m5stack.com/en/core/M5CoreS3%20SE)
- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/)
- [zig-esp-idf-sample](https://github.com/kassane/zig-esp-idf-sample)
- [Zylix Documentation](https://zylix.dev)

## Next Steps

1. Read the [API Reference](API.md)
2. Explore the [sample applications](../samples/)
3. Build your own Zylix application for M5Stack
