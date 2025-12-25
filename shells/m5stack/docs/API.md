# M5Stack CoreS3 API Reference

API reference for the Zylix M5Stack CoreS3 SE shell.

## Platform Module

```zig
const platform = @import("platform/mod.zig");
```

### Platform

Main platform abstraction for M5Stack CoreS3.

```zig
const Platform = struct {
    /// Initialize platform with configuration
    pub fn init(config: PlatformConfig) PlatformError!Platform;

    /// Clean up resources
    pub fn deinit(self: *Platform) void;

    /// Set application callbacks
    pub fn setCallbacks(self: *Platform, callbacks: AppCallbacks) void;

    /// Run the main application loop
    pub fn run(self: *Platform) void;

    /// Check if display is touched
    pub fn isTouched(self: *Platform) bool;

    /// Get current touch point
    pub fn getTouch(self: *Platform) ?Touch;
};
```

### PlatformConfig

```zig
const PlatformConfig = struct {
    rotation: Rotation = .portrait,
    backlight_percent: u8 = 100,
    target_fps: u8 = 60,
    enable_gestures: bool = true,
    touch_threshold: u8 = 40,
};

const Rotation = enum {
    portrait,
    landscape,
    portrait_inverted,
    landscape_inverted,
};
```

### AppCallbacks

```zig
const AppCallbacks = struct {
    on_init: ?*const fn (*anyopaque) void = null,
    on_update: ?*const fn (*anyopaque) void = null,
    on_draw: ?*const fn (*anyopaque, *Graphics) void = null,
    on_touch: ?*const fn (*anyopaque, Touch) void = null,
    on_gesture: ?*const fn (*anyopaque, GestureEvent) void = null,
    on_deinit: ?*const fn (*anyopaque) void = null,
    user_data: ?*anyopaque = null,
};
```

## Graphics Module

```zig
const graphics = @import("graphics/graphics.zig");
```

### Graphics

2D graphics primitives for display rendering.

```zig
const Graphics = struct {
    /// Clear entire screen
    pub fn clear(self: *Graphics, color: u16) void;

    /// Draw single pixel
    pub fn drawPixel(self: *Graphics, x: i32, y: i32, color: u16) void;

    /// Draw line between two points
    pub fn drawLine(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, color: u16) void;

    /// Draw horizontal line
    pub fn drawHLine(self: *Graphics, x: i32, y: i32, length: u16, color: u16) void;

    /// Draw vertical line
    pub fn drawVLine(self: *Graphics, x: i32, y: i32, length: u16, color: u16) void;

    /// Draw rectangle outline
    pub fn drawRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, color: u16) void;

    /// Fill rectangle
    pub fn fillRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, color: u16) void;

    /// Draw rounded rectangle outline
    pub fn drawRoundedRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, radius: u16, color: u16) void;

    /// Fill rounded rectangle
    pub fn fillRoundedRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, radius: u16, color: u16) void;

    /// Draw circle outline
    pub fn drawCircle(self: *Graphics, cx: i32, cy: i32, radius: u16, color: u16) void;

    /// Fill circle
    pub fn fillCircle(self: *Graphics, cx: i32, cy: i32, radius: u16, color: u16) void;

    /// Draw arc
    pub fn drawArc(self: *Graphics, cx: i32, cy: i32, radius: u16, start_angle: i32, end_angle: i32, color: u16) void;

    /// Draw text
    pub fn drawText(self: *Graphics, x: i32, y: i32, text: []const u8, color: u16) void;

    /// Draw scaled text
    pub fn drawTextScaled(self: *Graphics, x: i32, y: i32, text: []const u8, color: u16, scale: u8) void;
};
```

### Color Constants

```zig
const Color = struct {
    pub const black: u16 = 0x0000;
    pub const white: u16 = 0xFFFF;
    pub const red: u16 = 0xF800;
    pub const green: u16 = 0x07E0;
    pub const blue: u16 = 0x001F;
    pub const yellow: u16 = 0xFFE0;
    pub const cyan: u16 = 0x07FF;
    pub const magenta: u16 = 0xF81F;
};

/// Convert RGB888 to RGB565
pub fn rgb565(r: u8, g: u8, b: u8) u16;
```

## Touch Module

```zig
const touch = @import("touch/input.zig");
```

### Touch

Touch point information.

```zig
const Touch = struct {
    x: i32,
    y: i32,
    phase: TouchPhase,
    touch_id: u8,
    touch_count: u8,
    pressure: f32,
    timestamp: u64,
};

const TouchPhase = enum {
    began,
    moved,
    stationary,
    ended,
    cancelled,
};
```

## Gesture Module

```zig
const gesture = @import("touch/gesture.zig");
```

### GestureEvent

```zig
const GestureEvent = struct {
    gesture_type: GestureType,
    x: i32,
    y: i32,
    delta_x: i32,
    delta_y: i32,
    scale: ?f32,
    rotation: ?f32,
    velocity_x: f32,
    velocity_y: f32,
    touch_count: u8,
    timestamp: u64,
};

const GestureType = enum {
    tap,
    double_tap,
    long_press,
    swipe_left,
    swipe_right,
    swipe_up,
    swipe_down,
    pinch,
    rotate,
    pan,
};
```

## UI Components

```zig
const ui = @import("ui/mod.zig");
```

### Theme

Default theme colors.

```zig
const Theme = struct {
    pub const primary: u16 = 0x2D7F;
    pub const primary_light: u16 = 0x5DBF;
    pub const primary_dark: u16 = 0x1C5F;
    pub const secondary: u16 = 0x7BEF;
    pub const secondary_light: u16 = 0xC618;
    pub const background: u16 = 0xFFFF;
    pub const surface: u16 = 0xF7BE;
    pub const error_color: u16 = 0xF800;
    pub const success: u16 = 0x07E0;
    pub const warning: u16 = 0xFE00;
    pub const text_primary: u16 = 0x2104;
    pub const text_secondary: u16 = 0x7BEF;
    pub const text_disabled: u16 = 0xBDF7;
    pub const border: u16 = 0xDEFB;
};
```

### Button

```zig
const Button = struct {
    pub fn init(config: ButtonConfig) Button;
    pub fn asComponent(self: *Button) *Component;
    pub fn handleTouch(self: *Button, touch: Touch) void;
    pub fn draw(self: *Button, graphics: *Graphics) void;
};

const ButtonConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 100,
    height: u16 = 40,
    label: []const u8 = "",
    style: ButtonStyle = .filled,
    background: u16 = Theme.primary,
    text_color: u16 = 0xFFFF,
    on_press: ?*const fn (*Button) void = null,
    on_release: ?*const fn (*Button) void = null,
};

const ButtonStyle = enum {
    filled,
    outlined,
    text,
    elevated,
};
```

### Label

```zig
const Label = struct {
    pub fn init(config: LabelConfig) Label;
    pub fn setText(self: *Label, text: []const u8) void;
    pub fn setInt(self: *Label, value: i32) void;
    pub fn setFloat(self: *Label, value: f32, decimals: u8) void;
    pub fn draw(self: *Label, graphics: *Graphics) void;
};

const LabelConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 100,
    height: u16 = 20,
    text: []const u8 = "",
    alignment: TextAlignment = .left,
    font_size: u8 = 1,
    color: u16 = Theme.text_primary,
};
```

### ProgressBar

```zig
const ProgressBar = struct {
    pub fn init(config: ProgressConfig) ProgressBar;
    pub fn setValue(self: *ProgressBar, value: f32) void;
    pub fn setValueInt(self: *ProgressBar, value: i32, max: i32) void;
    pub fn getPercentage(self: *const ProgressBar) u8;
    pub fn draw(self: *ProgressBar, graphics: *Graphics) void;
};

const ProgressStyle = enum {
    bar,
    bar_vertical,
    circular,
};
```

### ListView

```zig
const ListView = struct {
    pub fn init(config: ListConfig) ListView;
    pub fn addItem(self: *ListView, item: ListItem) bool;
    pub fn addTextItem(self: *ListView, text: []const u8) bool;
    pub fn removeItem(self: *ListView, index: usize) bool;
    pub fn clear(self: *ListView) void;
    pub fn setSelectedIndex(self: *ListView, index: ?usize) void;
    pub fn scrollToItem(self: *ListView, index: usize) void;
    pub fn handleTouch(self: *ListView, touch: Touch) void;
    pub fn draw(self: *ListView, graphics: *Graphics) void;
};

const ListItem = struct {
    text: []const u8,
    subtext: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    tag: u32 = 0,
    enabled: bool = true,
    selected: bool = false,
};
```

## Virtual DOM

```zig
const renderer = @import("renderer/mod.zig");
```

### Renderer

```zig
const Renderer = struct {
    pub fn init(config: RendererConfig) !Renderer;
    pub fn deinit(self: *Renderer) void;
    pub fn setGraphics(self: *Renderer, graphics: *Graphics) void;
    pub fn begin(self: *Renderer) !*VDom;
    pub fn render(self: *Renderer) !void;
    pub fn forceRedraw(self: *Renderer) !void;
    pub fn getStats(self: *const Renderer) RenderStats;
};
```

### VDom

```zig
const VDom = struct {
    pub fn create(allocator: Allocator, max_nodes: usize) !*VDom;
    pub fn destroy(self: *VDom, allocator: Allocator) void;
    pub fn clear(self: *VDom) void;
    pub fn createNode(self: *VDom, node_type: VNodeType, props: VNodeProps) !*VNode;
    pub fn createChildNode(self: *VDom, parent: *VNode, node_type: VNodeType, props: VNodeProps) !*VNode;
    pub fn getNodeById(self: *VDom, id: u32) ?*VNode;
    pub fn hitTest(self: *VDom, x: i32, y: i32) ?*VNode;
};
```

### VNodeType

```zig
const VNodeType = enum(u8) {
    // Primitives
    rect,
    circle,
    line,
    text,
    image,

    // Components
    button,
    label,
    panel,
    progress,
    list,
    list_item,

    // Layout
    container,
    scroll_view,
    stack_h,
    stack_v,

    // Special
    root,
    fragment,
};
```

## Example Usage

```zig
const std = @import("std");
const platform = @import("platform/mod.zig");
const ui = @import("ui/mod.zig");

pub fn main() !void {
    // Initialize platform
    var plat = try platform.Platform.init(.{
        .rotation = .portrait,
        .backlight_percent = 80,
    });
    defer plat.deinit();

    // Set up callbacks
    plat.setCallbacks(.{
        .on_draw = draw,
        .on_touch = onTouch,
    });

    // Run application
    plat.run();
}

fn draw(_: *anyopaque, graphics: *platform.Graphics) void {
    graphics.clear(ui.Theme.background);
    graphics.fillRect(50, 50, 100, 60, ui.Theme.primary);
    graphics.drawText(60, 70, "Hello!", platform.Color.white);
}

fn onTouch(_: *anyopaque, touch: platform.Touch) void {
    std.debug.print("Touch at ({}, {})\n", .{ touch.x, touch.y });
}
```
