# M5Stack CoreS3 + Zylix ネイティブ実装計画

## 概要

M5Stack CoreS3 SE 上で Zylix を **ネイティブ Zig** で動作させるための詳細実装計画書です。

**作成日**: 2025-12-26
**アプローチ**: ネイティブ Zig on ESP32-S3 (Xtensa)

---

## 1. ハードウェア仕様

### 1.1 M5Stack CoreS3 SE ピンアサイン

#### ディスプレイ (ILI9342C) - SPI接続

| 信号 | GPIO | 説明 |
|------|------|------|
| SCLK | GPIO36 | SPI クロック |
| MOSI | GPIO37 | SPI データ出力 |
| CS | GPIO3 | チップセレクト (Active Low) |
| D/C | GPIO35 | Data/Command 選択 |
| RST | AW9523 P1_1 | リセット (I/O エクスパンダ経由) |
| BL | AXP2101 | バックライト (PMIC経由) |

#### タッチパネル (FT6336U) - I2C接続

| 信号 | GPIO | 説明 |
|------|------|------|
| SDA | GPIO12 | I2C データ |
| SCL | GPIO11 | I2C クロック |
| INT | GPIO21 | タッチ割り込み |
| RST | AW9523 P1_0 | リセット (I/O エクスパンダ経由) |

**I2C アドレス**: `0x38`

#### 内部 I2C バス (GPIO12/GPIO11)

| デバイス | アドレス | 機能 |
|----------|----------|------|
| AXP2101 | 0x34 | 電源管理 (PMIC) |
| AW9523B | 0x58 | I/O エクスパンダ |
| FT6336U | 0x38 | タッチコントローラー |
| BM8563 | 0x51 | RTC |

#### Grove Port A (GPIO1/GPIO2)

| 信号 | GPIO |
|------|------|
| SDA | GPIO2 |
| SCL | GPIO1 |

#### SD カード (SPI共有)

| 信号 | GPIO |
|------|------|
| CS | GPIO4 |
| SCLK | GPIO36 (共有) |
| MOSI | GPIO37 (共有) |
| MISO | GPIO35 |

---

## 2. 開発環境セットアップ

### 2.1 必要ツール

```bash
# ディレクトリ構造
~/m5stack-zylix/
├── zig-xtensa/          # Xtensa対応 Zig フォーク
├── esp-idf/             # ESP-IDF v5.x
├── zylix/               # Zylix プロジェクト
└── m5stack-cores3/      # M5Stack CoreS3 プロジェクト
```

### 2.2 Zig-Xtensa ツールチェーン

```bash
# Option 1: kassane/zig-esp-idf-sample を使用
git clone https://github.com/kassane/zig-esp-idf-sample.git
cd zig-esp-idf-sample

# Option 2: zig-xtensa フォークをビルド
git clone https://github.com/INetBowser/zig-xtensa.git
cd zig-xtensa
git checkout xtensa
# LLVM Xtensa バックエンド付きでビルド
```

### 2.3 ESP-IDF セットアップ

```bash
# ESP-IDF v5.3 インストール
git clone -b v5.3 --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh esp32s3
source export.sh

# 環境確認
idf.py --version
```

### 2.4 プロジェクト構成

```bash
# Zylix M5Stack Shell 作成
mkdir -p zylix/shells/m5stack
cd zylix/shells/m5stack

# ESP-IDF プロジェクト初期化
idf.py create-project m5stack_zylix
```

---

## 3. ディスプレイプロトコル詳細設計

### 3.1 ILI9342C コマンド仕様

#### 初期化シーケンス

```zig
const ILI9342C = struct {
    // コマンド定義
    pub const CMD = enum(u8) {
        NOP = 0x00,
        SWRESET = 0x01,      // ソフトウェアリセット
        SLPIN = 0x10,        // スリープイン
        SLPOUT = 0x11,       // スリープアウト
        INVOFF = 0x20,       // 反転オフ
        INVON = 0x21,        // 反転オン
        DISPOFF = 0x28,      // ディスプレイオフ
        DISPON = 0x29,       // ディスプレイオン
        CASET = 0x2A,        // カラムアドレス設定
        PASET = 0x2B,        // ページアドレス設定
        RAMWR = 0x2C,        // メモリ書き込み
        MADCTL = 0x36,       // メモリアクセス制御
        COLMOD = 0x3A,       // ピクセルフォーマット
        FRMCTR1 = 0xB1,      // フレームレート制御
        DFUNCTR = 0xB6,      // ディスプレイ機能制御
        PWCTR1 = 0xC0,       // 電源制御1
        PWCTR2 = 0xC1,       // 電源制御2
        VMCTR1 = 0xC5,       // VCOM制御1
        GMCTRP1 = 0xE0,      // ポジティブガンマ補正
        GMCTRN1 = 0xE1,      // ネガティブガンマ補正
    };

    // MADCTL ビット定義
    pub const MADCTL_MY = 0x80;   // Row Address Order
    pub const MADCTL_MX = 0x40;   // Column Address Order
    pub const MADCTL_MV = 0x20;   // Row/Column Exchange
    pub const MADCTL_ML = 0x10;   // Vertical Refresh Order
    pub const MADCTL_BGR = 0x08;  // BGR Order
    pub const MADCTL_MH = 0x04;   // Horizontal Refresh Order

    // ピクセルフォーマット
    pub const PIXEL_FORMAT_16BIT = 0x55;  // RGB565
    pub const PIXEL_FORMAT_18BIT = 0x66;  // RGB666
};
```

#### 初期化コード

```zig
pub fn init(self: *ILI9342C) !void {
    // ハードウェアリセット (AW9523経由)
    try self.resetHardware();

    // ソフトウェアリセット
    try self.writeCommand(.SWRESET);
    std.time.sleep(150 * std.time.ns_per_ms);

    // スリープアウト
    try self.writeCommand(.SLPOUT);
    std.time.sleep(50 * std.time.ns_per_ms);

    // ピクセルフォーマット設定 (RGB565)
    try self.writeCommand(.COLMOD);
    try self.writeData(&.{PIXEL_FORMAT_16BIT});

    // メモリアクセス制御 (回転・色順序)
    try self.writeCommand(.MADCTL);
    try self.writeData(&.{MADCTL_MX | MADCTL_BGR});

    // 色反転 (M5Stack特有)
    try self.writeCommand(.INVON);

    // ディスプレイオン
    try self.writeCommand(.DISPON);
    std.time.sleep(100 * std.time.ns_per_ms);
}
```

### 3.2 SPI ドライバー実装

```zig
const SpiConfig = struct {
    sclk_pin: u8 = 36,
    mosi_pin: u8 = 37,
    miso_pin: u8 = 35,
    cs_pin: u8 = 3,
    dc_pin: u8 = 35,
    freq_hz: u32 = 40_000_000,  // 40MHz
};

pub const SpiDisplay = struct {
    config: SpiConfig,
    spi_handle: ?*anyopaque = null,

    pub fn init(self: *SpiDisplay) !void {
        // ESP-IDF SPI バス初期化
        const bus_config = esp_idf.spi_bus_config_t{
            .mosi_io_num = self.config.mosi_pin,
            .miso_io_num = self.config.miso_pin,
            .sclk_io_num = self.config.sclk_pin,
            .quadwp_io_num = -1,
            .quadhd_io_num = -1,
            .max_transfer_sz = 320 * 240 * 2,  // フルフレーム
        };

        try esp_idf.spi_bus_initialize(
            esp_idf.SPI2_HOST,
            &bus_config,
            esp_idf.SPI_DMA_CH_AUTO
        );

        // デバイス追加
        const dev_config = esp_idf.spi_device_interface_config_t{
            .clock_speed_hz = self.config.freq_hz,
            .mode = 0,
            .spics_io_num = self.config.cs_pin,
            .queue_size = 7,
            .flags = esp_idf.SPI_DEVICE_NO_DUMMY,
        };

        try esp_idf.spi_bus_add_device(
            esp_idf.SPI2_HOST,
            &dev_config,
            &self.spi_handle
        );
    }

    pub fn writeCommand(self: *SpiDisplay, cmd: u8) !void {
        // D/C = 0 (Command)
        esp_idf.gpio_set_level(self.config.dc_pin, 0);
        try self.transmit(&.{cmd});
    }

    pub fn writeData(self: *SpiDisplay, data: []const u8) !void {
        // D/C = 1 (Data)
        esp_idf.gpio_set_level(self.config.dc_pin, 1);
        try self.transmit(data);
    }

    fn transmit(self: *SpiDisplay, data: []const u8) !void {
        var trans = esp_idf.spi_transaction_t{
            .length = data.len * 8,
            .tx_buffer = data.ptr,
        };
        try esp_idf.spi_device_polling_transmit(self.spi_handle, &trans);
    }
};
```

### 3.3 フレームバッファ管理

```zig
pub const FrameBuffer = struct {
    pub const WIDTH = 320;
    pub const HEIGHT = 240;
    pub const BYTES_PER_PIXEL = 2;  // RGB565
    pub const BUFFER_SIZE = WIDTH * HEIGHT * BYTES_PER_PIXEL;

    buffer: [BUFFER_SIZE]u8 align(4) = undefined,
    dirty_rect: ?Rect = null,

    pub const Rect = struct {
        x: u16,
        y: u16,
        width: u16,
        height: u16,
    };

    /// RGB888 を RGB565 に変換
    pub fn rgb565(r: u8, g: u8, b: u8) u16 {
        return (@as(u16, r >> 3) << 11) |
               (@as(u16, g >> 2) << 5) |
               @as(u16, b >> 3);
    }

    /// ピクセル設定
    pub fn setPixel(self: *FrameBuffer, x: u16, y: u16, color: u16) void {
        if (x >= WIDTH or y >= HEIGHT) return;
        const offset = (@as(usize, y) * WIDTH + x) * BYTES_PER_PIXEL;
        // Big Endian (MSB first)
        self.buffer[offset] = @intCast(color >> 8);
        self.buffer[offset + 1] = @intCast(color & 0xFF);
        self.markDirty(x, y, 1, 1);
    }

    /// 矩形塗りつぶし
    pub fn fillRect(self: *FrameBuffer, x: u16, y: u16, w: u16, h: u16, color: u16) void {
        const x_end = @min(x + w, WIDTH);
        const y_end = @min(y + h, HEIGHT);

        var py = y;
        while (py < y_end) : (py += 1) {
            var px = x;
            while (px < x_end) : (px += 1) {
                self.setPixel(px, py, color);
            }
        }
        self.markDirty(x, y, w, h);
    }

    /// ダーティ領域マーク
    fn markDirty(self: *FrameBuffer, x: u16, y: u16, w: u16, h: u16) void {
        if (self.dirty_rect) |*rect| {
            const new_x = @min(rect.x, x);
            const new_y = @min(rect.y, y);
            rect.width = @max(rect.x + rect.width, x + w) - new_x;
            rect.height = @max(rect.y + rect.height, y + h) - new_y;
            rect.x = new_x;
            rect.y = new_y;
        } else {
            self.dirty_rect = .{ .x = x, .y = y, .width = w, .height = h };
        }
    }

    /// フラッシュ (差分更新)
    pub fn flush(self: *FrameBuffer, display: *SpiDisplay) !void {
        if (self.dirty_rect) |rect| {
            try display.setWindow(rect.x, rect.y,
                                  rect.x + rect.width - 1,
                                  rect.y + rect.height - 1);

            // 差分領域のみ転送
            var y: u16 = rect.y;
            while (y < rect.y + rect.height) : (y += 1) {
                const offset = (@as(usize, y) * WIDTH + rect.x) * BYTES_PER_PIXEL;
                const line_size = rect.width * BYTES_PER_PIXEL;
                try display.writeData(self.buffer[offset..offset + line_size]);
            }

            self.dirty_rect = null;
        }
    }
};
```

---

## 4. タッチコントローラー実装

### 4.1 FT6336U ドライバー

```zig
pub const FT6336U = struct {
    pub const I2C_ADDR = 0x38;

    // レジスタ定義
    pub const REG = enum(u8) {
        DEV_MODE = 0x00,
        GEST_ID = 0x01,
        TD_STATUS = 0x02,
        P1_XH = 0x03,
        P1_XL = 0x04,
        P1_YH = 0x05,
        P1_YL = 0x06,
        P1_WEIGHT = 0x07,
        P1_MISC = 0x08,
        P2_XH = 0x09,
        P2_XL = 0x0A,
        P2_YH = 0x0B,
        P2_YL = 0x0C,
        TH_GROUP = 0x80,
        PERIODACTIVE = 0x88,
        LIB_VER_H = 0xA1,
        LIB_VER_L = 0xA2,
        CIPHER = 0xA3,
        G_MODE = 0xA4,
        FIRMID = 0xA6,
        FOCALTECH_ID = 0xA8,
    };

    pub const TouchPoint = struct {
        x: u16,
        y: u16,
        weight: u8,
        event: TouchEvent,
    };

    pub const TouchEvent = enum(u2) {
        press_down = 0,
        lift_up = 1,
        contact = 2,
        no_event = 3,
    };

    i2c_bus: *I2cBus,

    pub fn init(self: *FT6336U) !void {
        // タッチリセット (AW9523経由)
        try self.resetHardware();

        // デバイスID確認
        const chip_id = try self.readRegister(.FOCALTECH_ID);
        if (chip_id != 0x11) {  // FT6336U
            return error.InvalidDevice;
        }

        // アクティブモード設定
        try self.writeRegister(.DEV_MODE, 0x00);
        try self.writeRegister(.TH_GROUP, 22);  // 感度
        try self.writeRegister(.PERIODACTIVE, 12);  // レポートレート
    }

    pub fn read(self: *FT6336U) !?TouchPoint {
        const status = try self.readRegister(.TD_STATUS);
        const touch_count = status & 0x0F;

        if (touch_count == 0) return null;

        var buf: [6]u8 = undefined;
        try self.readRegisters(.P1_XH, &buf);

        const event: TouchEvent = @enumFromInt((buf[0] >> 6) & 0x03);
        const x = (@as(u16, buf[0] & 0x0F) << 8) | buf[1];
        const y = (@as(u16, buf[2] & 0x0F) << 8) | buf[3];
        const weight = buf[4];

        return .{
            .x = x,
            .y = y,
            .weight = weight,
            .event = event,
        };
    }

    fn readRegister(self: *FT6336U, reg: REG) !u8 {
        var buf: [1]u8 = undefined;
        try self.i2c_bus.writeRead(I2C_ADDR, &.{@intFromEnum(reg)}, &buf);
        return buf[0];
    }

    fn readRegisters(self: *FT6336U, start_reg: REG, buf: []u8) !void {
        try self.i2c_bus.writeRead(I2C_ADDR, &.{@intFromEnum(start_reg)}, buf);
    }

    fn writeRegister(self: *FT6336U, reg: REG, value: u8) !void {
        try self.i2c_bus.write(I2C_ADDR, &.{ @intFromEnum(reg), value });
    }
};
```

---

## 5. 電源管理実装

### 5.1 AW9523B I/O エクスパンダ

```zig
pub const AW9523B = struct {
    pub const I2C_ADDR = 0x58;

    // レジスタ
    pub const REG = enum(u8) {
        INPUT_P0 = 0x00,
        INPUT_P1 = 0x01,
        OUTPUT_P0 = 0x02,
        OUTPUT_P1 = 0x03,
        CONFIG_P0 = 0x04,
        CONFIG_P1 = 0x05,
        INT_P0 = 0x06,
        INT_P1 = 0x07,
        ID = 0x10,
        CTL = 0x11,
        LED_MODE_P0 = 0x12,
        LED_MODE_P1 = 0x13,
        P1_LED_DIM = 0x20,
        SOFT_RESET = 0x7F,
    };

    // CoreS3 ピン割り当て
    pub const PIN = struct {
        pub const TOUCH_RST = 0;   // P1_0
        pub const LCD_RST = 1;     // P1_1
        pub const SD_CS = 4;       // P1_4 (使用しない場合)
        pub const BOOST_EN = 5;    // P1_5
    };

    i2c_bus: *I2cBus,
    output_state: u16 = 0xFFFF,

    pub fn init(self: *AW9523B) !void {
        // ソフトリセット
        try self.writeRegister(.SOFT_RESET, 0x00);
        std.time.sleep(10 * std.time.ns_per_ms);

        // デバイスID確認
        const id = try self.readRegister(.ID);
        if (id != 0x23) return error.InvalidDevice;

        // P1 をプッシュプル出力に設定
        try self.writeRegister(.CTL, 0x10);
        try self.writeRegister(.CONFIG_P0, 0x00);
        try self.writeRegister(.CONFIG_P1, 0x00);
        try self.writeRegister(.LED_MODE_P1, 0x00);
    }

    pub fn setPin(self: *AW9523B, pin: u4, high: bool) !void {
        const bit: u16 = @as(u16, 1) << pin;
        if (high) {
            self.output_state |= bit;
        } else {
            self.output_state &= ~bit;
        }

        try self.writeRegister(.OUTPUT_P0, @intCast(self.output_state & 0xFF));
        try self.writeRegister(.OUTPUT_P1, @intCast(self.output_state >> 8));
    }

    pub fn resetLcd(self: *AW9523B) !void {
        try self.setPin(PIN.LCD_RST + 8, false);  // P1 オフセット
        std.time.sleep(10 * std.time.ns_per_ms);
        try self.setPin(PIN.LCD_RST + 8, true);
        std.time.sleep(50 * std.time.ns_per_ms);
    }

    pub fn resetTouch(self: *AW9523B) !void {
        try self.setPin(PIN.TOUCH_RST + 8, false);
        std.time.sleep(10 * std.time.ns_per_ms);
        try self.setPin(PIN.TOUCH_RST + 8, true);
        std.time.sleep(50 * std.time.ns_per_ms);
    }

    fn readRegister(self: *AW9523B, reg: REG) !u8 {
        var buf: [1]u8 = undefined;
        try self.i2c_bus.writeRead(I2C_ADDR, &.{@intFromEnum(reg)}, &buf);
        return buf[0];
    }

    fn writeRegister(self: *AW9523B, reg: REG, value: u8) !void {
        try self.i2c_bus.write(I2C_ADDR, &.{ @intFromEnum(reg), value });
    }
};
```

### 5.2 AXP2101 電源管理

```zig
pub const AXP2101 = struct {
    pub const I2C_ADDR = 0x34;

    pub const REG = enum(u8) {
        PMU_STATUS1 = 0x00,
        PMU_STATUS2 = 0x01,
        CHIP_ID = 0x03,
        DATA_BUFFER0 = 0x04,
        PMU_CONFIG = 0x10,
        BATFET_CTRL = 0x12,
        DIE_TEMP_H = 0x3C,
        DIE_TEMP_L = 0x3D,
        TS_PIN_CTRL = 0x50,
        VBAT_H = 0x34,
        VBAT_L = 0x35,
        VSYS_H = 0x38,
        VSYS_L = 0x39,
        DCDC1_CTRL = 0x80,
        DCDC2_CTRL = 0x81,
        DCDC3_CTRL = 0x82,
        DCDC4_CTRL = 0x83,
        DCDC5_CTRL = 0x84,
        ALDO1_CTRL = 0x90,
        ALDO2_CTRL = 0x91,
        ALDO3_CTRL = 0x92,
        ALDO4_CTRL = 0x93,
        BLDO1_CTRL = 0x94,
        BLDO2_CTRL = 0x95,
        DLDO1_CTRL = 0x96,
        DLDO2_CTRL = 0x97,
        LDO_ENABLE = 0x90,
    };

    i2c_bus: *I2cBus,

    pub fn init(self: *AXP2101) !void {
        // チップID確認
        const chip_id = try self.readRegister(.CHIP_ID);
        if ((chip_id & 0xCF) != 0x47) return error.InvalidDevice;

        // LCD バックライト電源 (DLDO1) 有効化
        try self.enableBacklight(true);
    }

    pub fn enableBacklight(self: *AXP2101, enable: bool) !void {
        var reg = try self.readRegister(.DLDO1_CTRL);
        if (enable) {
            reg |= 0x01;
        } else {
            reg &= 0xFE;
        }
        try self.writeRegister(.DLDO1_CTRL, reg);
    }

    pub fn setBacklightBrightness(self: *AXP2101, brightness: u8) !void {
        // DLDO1 電圧調整 (0.5V - 3.5V, 100mV step)
        const voltage = @min(brightness, 30);  // Max 3.5V
        try self.writeRegister(.DLDO1_CTRL, 0x80 | voltage);
    }

    pub fn getBatteryVoltage(self: *AXP2101) !u16 {
        const high = try self.readRegister(.VBAT_H);
        const low = try self.readRegister(.VBAT_L);
        return (@as(u16, high) << 4) | (low & 0x0F);
    }

    fn readRegister(self: *AXP2101, reg: REG) !u8 {
        var buf: [1]u8 = undefined;
        try self.i2c_bus.writeRead(I2C_ADDR, &.{@intFromEnum(reg)}, &buf);
        return buf[0];
    }

    fn writeRegister(self: *AXP2101, reg: REG, value: u8) !void {
        try self.i2c_bus.write(I2C_ADDR, &.{ @intFromEnum(reg), value });
    }
};
```

---

## 6. Zylix 統合アーキテクチャ

### 6.1 ディレクトリ構造

```
zylix/
├── core/
│   └── src/
│       ├── main.zig
│       ├── state.zig
│       ├── events.zig
│       └── platforms/
│           └── m5stack/
│               ├── mod.zig           # プラットフォームエントリ
│               ├── display.zig       # ILI9342C ドライバー
│               ├── touch.zig         # FT6336U ドライバー
│               ├── power.zig         # AXP2101 管理
│               ├── gpio_expander.zig # AW9523B 制御
│               └── spi.zig           # SPI 抽象化
├── shells/
│   └── m5stack/
│       ├── build.zig
│       ├── CMakeLists.txt        # ESP-IDF 統合
│       ├── main/
│       │   ├── main.c            # ESP-IDF エントリ
│       │   └── zig_bridge.c      # Zig ⇔ C ブリッジ
│       └── sdkconfig.defaults
└── samples/
    └── m5stack/
        ├── hello-world/
        ├── counter/
        └── touch-demo/
```

### 6.2 Zylix M5Stack Platform モジュール

```zig
// core/src/platforms/m5stack/mod.zig

const std = @import("std");
const display = @import("display.zig");
const touch = @import("touch.zig");
const power = @import("power.zig");
const gpio_exp = @import("gpio_expander.zig");

pub const Platform = struct {
    display: display.ILI9342C,
    touch: touch.FT6336U,
    pmic: power.AXP2101,
    io_expander: gpio_exp.AW9523B,
    frame_buffer: display.FrameBuffer,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Platform {
        const self = try allocator.create(Platform);

        // I2C バス初期化
        const i2c = try I2cBus.init(.{
            .sda_pin = 12,
            .scl_pin = 11,
            .freq_hz = 400_000,
        });

        // I/O エクスパンダ初期化
        self.io_expander = .{ .i2c_bus = i2c };
        try self.io_expander.init();

        // PMIC 初期化
        self.pmic = .{ .i2c_bus = i2c };
        try self.pmic.init();

        // LCD リセット & 初期化
        try self.io_expander.resetLcd();
        try self.display.init();

        // タッチ リセット & 初期化
        try self.io_expander.resetTouch();
        self.touch = .{ .i2c_bus = i2c };
        try self.touch.init();

        self.allocator = allocator;
        return self;
    }

    pub fn deinit(self: *Platform) void {
        self.allocator.destroy(self);
    }

    /// イベントループ実行
    pub fn run(self: *Platform, app: *anyopaque, update_fn: *const fn(*anyopaque) void) void {
        while (true) {
            // タッチイベント処理
            if (self.touch.read()) |point| {
                self.handleTouch(point);
            } else |_| {}

            // アプリ更新
            update_fn(app);

            // フレームバッファをディスプレイに転送
            self.frame_buffer.flush(&self.display) catch {};

            // フレームレート制御 (60fps)
            std.time.sleep(16 * std.time.ns_per_ms);
        }
    }

    fn handleTouch(self: *Platform, point: touch.FT6336U.TouchPoint) void {
        _ = self;
        // Zylix イベントシステムに変換
        const event = zylix.events.TouchEvent{
            .x = point.x,
            .y = point.y,
            .phase = switch (point.event) {
                .press_down => .began,
                .contact => .moved,
                .lift_up => .ended,
                .no_event => .cancelled,
            },
        };
        zylix.events.dispatch(.touch, event);
    }
};
```

### 6.3 ESP-IDF 統合

```c
// shells/m5stack/main/main.c

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "driver/i2c.h"

// Zig エントリポイント
extern void zylix_main(void);

static const char *TAG = "m5stack_zylix";

void app_main(void) {
    ESP_LOGI(TAG, "M5Stack CoreS3 + Zylix Starting...");

    // ハードウェア初期化
    init_gpio();
    init_i2c();
    init_spi();

    // Zylix メイン実行
    zylix_main();
}

static void init_i2c(void) {
    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = 12,
        .scl_io_num = 11,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = 400000,
    };
    i2c_param_config(I2C_NUM_0, &conf);
    i2c_driver_install(I2C_NUM_0, conf.mode, 0, 0, 0);
}

static void init_spi(void) {
    spi_bus_config_t buscfg = {
        .mosi_io_num = 37,
        .miso_io_num = 35,
        .sclk_io_num = 36,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = 320 * 240 * 2,
    };
    spi_bus_initialize(SPI2_HOST, &buscfg, SPI_DMA_CH_AUTO);
}
```

---

## 7. 実装フェーズ

### Phase 1: 開発環境構築 (1週間)

| タスク | 詳細 | 成果物 |
|--------|------|--------|
| Zig-Xtensa ツールチェーン構築 | kassane/zig-esp-idf-sample ベース | 動作するツールチェーン |
| ESP-IDF v5.3 セットアップ | CoreS3 用設定 | sdkconfig |
| Hello World | LED点滅 or シリアル出力 | 動作確認 |

### Phase 2: ディスプレイドライバー (2週間)

| タスク | 詳細 | 成果物 |
|--------|------|--------|
| SPI ドライバー実装 | Zig ラッパー | spi.zig |
| I2C ドライバー実装 | AW9523B/AXP2101 制御 | i2c.zig |
| ILI9342C 初期化 | 初期化シーケンス | display.zig |
| フレームバッファ | RGB565 管理 | framebuffer.zig |
| 基本描画 | ピクセル、矩形、線 | graphics.zig |

### Phase 3: タッチ入力 (1週間)

| タスク | 詳細 | 成果物 |
|--------|------|--------|
| FT6336U ドライバー | I2C 通信 | touch.zig |
| イベント変換 | Zylix イベント形式 | events.zig 拡張 |
| ジェスチャー認識 | タップ、スワイプ | gesture.zig |

### Phase 4: Zylix Core 統合 (2週間)

| タスク | 詳細 | 成果物 |
|--------|------|--------|
| Platform 抽象化 | M5Stack Shell | platforms/m5stack/ |
| State 連携 | 状態管理統合 | state.zig 拡張 |
| UI コンポーネント | ボタン、テキスト等 | ui/*.zig |
| ビルドシステム | ESP-IDF + Zig 統合 | build.zig |

### Phase 5: サンプル & ドキュメント (1週間)

| タスク | 詳細 | 成果物 |
|--------|------|--------|
| Hello World | 基本表示 | samples/m5stack/hello-world/ |
| Counter | 状態管理デモ | samples/m5stack/counter/ |
| Touch Demo | タッチ入力デモ | samples/m5stack/touch-demo/ |
| セットアップガイド | 環境構築手順 | docs/M5STACK_SETUP.md |
| API リファレンス | M5Stack Platform | docs/API/m5stack.md |

---

## 8. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| Zig-Xtensa ツールチェーン不安定 | 高 | ESP-IDF C コード併用、段階的移行 |
| メモリ不足 (8MB PSRAM) | 中 | フレームバッファ分割、遅延ロード |
| SPI 転送速度 | 中 | DMA 使用、差分更新 |
| 電源管理複雑 | 低 | AXP2101 最小限設定から開始 |

---

## 9. 参考資料

### ハードウェア
- [M5Stack CoreS3 SE 公式](https://docs.m5stack.com/en/core/M5CoreS3%20SE)
- [ILI9342C データシート](https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/docs/datasheet/core/ILI9342C-ILITEK.pdf)
- [FT6336U データシート](https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/docs/datasheet/unit/touch/FT6336U.pdf)
- [AXP2101 データシート](https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/docs/datasheet/core/AXP2101_Datasheet_V1.0_en.pdf)
- [AW9523B データシート](https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/docs/datasheet/core/AW9523B.pdf)

### Zig + ESP32
- [zig-esp-idf-sample](https://github.com/kassane/zig-esp-idf-sample)
- [zig-xtensa](https://github.com/INetBowser/zig-xtensa)
- [ESP-IDF LCD Driver](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/api-reference/peripherals/lcd.html)

### ESPHome (参考実装)
- [M5Stack CoreS3 ESPHome](https://devices.esphome.io/devices/m5stack-cores3/)
