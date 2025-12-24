# Zylix API Reference

> **Version**: v0.17.0
> **Last Updated**: 2025-12-25

## Overview

This document provides a comprehensive API reference for the Zylix Framework, covering:
- **Core Modules**: Animation, Layout, CSS, Hot Reload, WASM, AI
- **Test Framework**: E2E testing across iOS, watchOS, Android, macOS, Windows, Linux, and Web

---

## Table of Contents

### Core Modules
1. [Animation Module](#animation-module)
2. [Layout Engine](#layout-engine)
3. [CSS Utility System](#css-utility-system)
4. [Hot Reload System](#hot-reload-system)
5. [WASM Entry Point](#wasm-entry-point)
6. [AI Module (llama.cpp)](#ai-module-llamacpp)

### Test Framework
7. [Test Framework Core Types](#test-framework-core-types)
8. [Driver Interface](#driver-interface)
9. [Selector API](#selector-api)
10. [Element API](#element-api)
11. [Platform Drivers](#platform-drivers)
12. [E2E Test Framework](#e2e-test-framework)
13. [Build Commands](#build-commands)

---

# Core Modules

## Animation Module

The animation module provides comprehensive animation support including easing functions, timelines, state machines, and format-specific implementations (Lottie, Live2D).

### Easing Functions (`animation/easing.zig`)

```zig
pub const EasingType = enum {
    linear,
    ease_in_quad, ease_out_quad, ease_in_out_quad,
    ease_in_cubic, ease_out_cubic, ease_in_out_cubic,
    ease_in_quart, ease_out_quart, ease_in_out_quart,
    ease_in_quint, ease_out_quint, ease_in_out_quint,
    ease_in_sine, ease_out_sine, ease_in_out_sine,
    ease_in_expo, ease_out_expo, ease_in_out_expo,
    ease_in_circ, ease_out_circ, ease_in_out_circ,
    ease_in_back, ease_out_back, ease_in_out_back,
    ease_in_elastic, ease_out_elastic, ease_in_out_elastic,
    ease_in_bounce, ease_out_bounce, ease_in_out_bounce,
    step_start, step_end,
    custom,
};

/// Apply easing function to a normalized time value (0.0 to 1.0)
pub fn apply(easing: EasingType, t: f32) f32;

/// Apply easing with custom parameters
pub fn applyWithParams(easing: EasingType, t: f32, params: ?*const CustomParams) f32;

pub const CustomParams = struct {
    c1: f32 = 1.70158,  // Back easing overshoot
    c2: f32 = 2.5949,   // Back in-out overshoot
    c3: f32 = 2.70158,  // Back out overshoot
    c4: f32 = 2.0944,   // Elastic period (2π/3)
    c5: f32 = 1.3963,   // Elastic in-out period (2π/4.5)
    n1: f32 = 7.5625,   // Bounce coefficient
    d1: f32 = 2.75,     // Bounce divisor
};
```

### Animation Types (`animation/types.zig`)

```zig
pub const AnimationState = enum {
    idle, playing, paused, completed, cancelled,
};

pub const PlaybackDirection = enum {
    forward, reverse, alternate, alternate_reverse,
};

pub const FillMode = enum {
    none, forwards, backwards, both,
};

pub const AnimationConfig = struct {
    duration_ms: u32 = 1000,
    delay_ms: u32 = 0,
    iteration_count: IterationCount = .{ .finite = 1 },
    direction: PlaybackDirection = .forward,
    fill_mode: FillMode = .none,
    easing: EasingType = .linear,
    auto_reverse: bool = false,
};

pub const IterationCount = union(enum) {
    finite: u32,
    infinite,

    pub fn isInfinite(self: IterationCount) bool;
    pub fn getCount(self: IterationCount) ?u32;
};

pub const AnimationValue = union(enum) {
    number: f32,
    color: Color,
    vec2: Vec2,
    vec3: Vec3,
    transform: Transform,

    pub fn lerp(from: AnimationValue, to: AnimationValue, t: f32) AnimationValue;
};
```

### Timeline (`animation/timeline.zig`)

```zig
pub const Timeline = struct {
    /// Create a new timeline
    pub fn init(allocator: std.mem.Allocator) Timeline;
    pub fn deinit(self: *Timeline) void;

    /// Add a keyframe
    pub fn addKeyframe(self: *Timeline, time: f32, value: f32, easing: EasingType) !void;

    /// Get interpolated value at time
    pub fn getValue(self: *const Timeline, time: f32) f32;

    /// Get duration
    pub fn getDuration(self: *const Timeline) f32;

    /// Check if timeline has keyframes
    pub fn hasKeyframes(self: *const Timeline) bool;
};

pub const Keyframe = struct {
    time: f32,
    value: f32,
    easing: EasingType,
};
```

### State Machine (`animation/state_machine.zig`)

```zig
pub const StateMachine = struct {
    /// Create a new state machine
    pub fn init(allocator: std.mem.Allocator) StateMachine;
    pub fn deinit(self: *StateMachine) void;

    /// State management
    pub fn addState(self: *StateMachine, name: []const u8) !StateId;
    pub fn setInitialState(self: *StateMachine, id: StateId) void;
    pub fn getCurrentState(self: *const StateMachine) ?StateId;

    /// Transitions
    pub fn addTransition(self: *StateMachine, from: StateId, to: StateId, trigger: []const u8) !void;
    pub fn canTransition(self: *const StateMachine, trigger: []const u8) bool;
    pub fn trigger(self: *StateMachine, event: []const u8) bool;

    /// Update (for timed transitions)
    pub fn update(self: *StateMachine, delta_time: f32) void;
};
```

### Lottie Support (`animation/lottie.zig`)

```zig
pub const LottieAnimation = struct {
    pub fn init(allocator: std.mem.Allocator) LottieAnimation;
    pub fn deinit(self: *LottieAnimation) void;

    /// Playback control
    pub fn play(self: *LottieAnimation) void;
    pub fn pause(self: *LottieAnimation) void;
    pub fn stop(self: *LottieAnimation) void;

    /// Frame control
    pub fn setFrame(self: *LottieAnimation, frame: f32) void;
    pub fn getFrame(self: *const LottieAnimation) f32;
    pub fn getTotalFrames(self: *const LottieAnimation) u32;

    /// Update animation
    pub fn update(self: *LottieAnimation, delta_time: f32) void;
};
```

### Live2D Support (`animation/live2d.zig`)

```zig
pub const Live2DModel = struct {
    pub fn init(allocator: std.mem.Allocator) Live2DModel;
    pub fn deinit(self: *Live2DModel) void;

    /// Parameter control
    pub fn setParameter(self: *Live2DModel, id: []const u8, value: f32) void;
    pub fn getParameter(self: *Live2DModel, id: []const u8) ?f32;

    /// Motion playback
    pub fn playMotion(self: *Live2DModel, group: []const u8, index: u32) void;
    pub fn stopMotion(self: *Live2DModel) void;

    /// Expression
    pub fn setExpression(self: *Live2DModel, name: []const u8) void;

    /// Lip sync
    pub fn updateLipSync(self: *Live2DModel, amplitude: f32) void;

    /// Eye blink
    pub fn updateEyeBlink(self: *Live2DModel, delta_time: f32) void;
};

/// Standard Live2D parameter IDs
pub const StandardParams = struct {
    pub const ParamAngleX = "ParamAngleX";
    pub const ParamAngleY = "ParamAngleY";
    pub const ParamAngleZ = "ParamAngleZ";
    pub const ParamEyeLOpen = "ParamEyeLOpen";
    pub const ParamEyeROpen = "ParamEyeROpen";
    pub const ParamMouthOpenY = "ParamMouthOpenY";
    pub const ParamBodyAngleX = "ParamBodyAngleX";
};
```

---

## Layout Engine

Flexbox/Grid-inspired layout system for computing element positions.

### Layout Types (`layout.zig`)

```zig
pub const Display = enum { none, block, flex, grid, inline_block };
pub const FlexDirection = enum { row, column, row_reverse, column_reverse };
pub const FlexWrap = enum { nowrap, wrap, wrap_reverse };
pub const JustifyContent = enum { flex_start, flex_end, center, space_between, space_around, space_evenly };
pub const AlignItems = enum { flex_start, flex_end, center, stretch, baseline };
pub const Position = enum { static, relative, absolute, fixed };

pub const LayoutResult = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const BoxModel = struct {
    content_width: f32 = 0,
    content_height: f32 = 0,
    padding_top: f32 = 0,
    padding_right: f32 = 0,
    padding_bottom: f32 = 0,
    padding_left: f32 = 0,
    border_top: f32 = 0,
    border_right: f32 = 0,
    border_bottom: f32 = 0,
    border_left: f32 = 0,
    margin_top: f32 = 0,
    margin_right: f32 = 0,
    margin_bottom: f32 = 0,
    margin_left: f32 = 0,

    pub fn totalWidth(self: BoxModel) f32;
    pub fn totalHeight(self: BoxModel) f32;
    pub fn innerWidth(self: BoxModel) f32;
    pub fn innerHeight(self: BoxModel) f32;
};
```

### Layout Node

```zig
pub const LayoutNode = struct {
    // Display
    display: Display = .block,

    // Flex container properties
    flex_direction: FlexDirection = .row,
    flex_wrap: FlexWrap = .nowrap,
    justify_content: JustifyContent = .flex_start,
    align_items: AlignItems = .stretch,

    // Flex item properties
    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,
    flex_basis: f32 = -1,  // -1 = auto

    // Sizing
    width: f32 = -1,  // -1 = auto
    height: f32 = -1,
    min_width: f32 = 0,
    min_height: f32 = 0,
    max_width: f32 = std.math.inf(f32),
    max_height: f32 = std.math.inf(f32),

    // Spacing
    gap: f32 = 0,
    padding_top: f32 = 0,
    padding_right: f32 = 0,
    padding_bottom: f32 = 0,
    padding_left: f32 = 0,
    margin_top: f32 = 0,
    margin_right: f32 = 0,
    margin_bottom: f32 = 0,
    margin_left: f32 = 0,

    // Computed result
    result: LayoutResult = .{},

    // Helper methods
    pub fn isFlexContainer(self: *const LayoutNode) bool;
    pub fn isRow(self: *const LayoutNode) bool;
    pub fn isReverse(self: *const LayoutNode) bool;
    pub fn addChild(self: *LayoutNode, child: *LayoutNode) !void;
};
```

### Layout Engine

```zig
pub const LayoutEngine = struct {
    pub fn init() LayoutEngine;

    /// Node management
    pub fn createNode(self: *LayoutEngine) u32;
    pub fn getNode(self: *LayoutEngine, id: u32) ?*LayoutNode;
    pub fn setRoot(self: *LayoutEngine, id: u32) void;
    pub fn addChild(self: *LayoutEngine, parent_id: u32, child_id: u32) bool;

    /// Compute layout
    pub fn compute(self: *LayoutEngine, container_width: f32, container_height: f32) void;

    /// Get node count
    pub fn getNodeCount(self: *const LayoutEngine) u32;
};
```

---

## CSS Utility System

TailwindCSS-inspired utility system for styling.

### CSS Types (`css.zig`)

```zig
pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color;
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color;
    pub fn hex(value: u32) Color;
    pub fn toHexString(self: Color) [9]u8;
};

/// Predefined colors (TailwindCSS palette)
pub const colors = struct {
    pub const white = Color.rgb(255, 255, 255);
    pub const black = Color.rgb(0, 0, 0);
    pub const transparent = Color.rgba(0, 0, 0, 0);

    // Gray scale
    pub const gray_50 = Color.hex(0xF9FAFB);
    pub const gray_500 = Color.hex(0x6B7280);
    pub const gray_900 = Color.hex(0x111827);

    // Blue
    pub const blue_500 = Color.hex(0x3B82F6);

    // Red
    pub const red_500 = Color.hex(0xEF4444);

    // Green
    pub const green_500 = Color.hex(0x22C55E);

    // ... and more
};

pub const Spacing = enum {
    s0, s1, s2, s3, s4, s5, s6, s8, s10, s12, s16, s20, s24, s32, s40, s48, s56, s64,

    pub fn toPixels(self: Spacing) f32;
};

pub const FontSize = enum {
    xs, sm, base, lg, xl, xl2, xl3, xl4, xl5, xl6, xl7, xl8, xl9,

    pub fn toPixels(self: FontSize) f32;
};

pub const BorderRadius = enum {
    none, sm, base, md, lg, xl, xl2, xl3, full,

    pub fn toPixels(self: BorderRadius) f32;
};

pub const Shadow = enum {
    none, sm, base, md, lg, xl, xl2, inner,
};
```

### Style Builder

```zig
pub const Style = struct {
    display: Display = .block,
    flex_direction: FlexDirection = .row,
    justify_content: JustifyContent = .flex_start,
    align_items: AlignItems = .stretch,
    gap: Spacing = .s0,

    padding_top: Spacing = .s0,
    padding_right: Spacing = .s0,
    padding_bottom: Spacing = .s0,
    padding_left: Spacing = .s0,

    margin_top: Spacing = .s0,
    margin_right: Spacing = .s0,
    margin_bottom: Spacing = .s0,
    margin_left: Spacing = .s0,

    background_color: Color = colors.transparent,
    color: Color = colors.black,

    font_size: FontSize = .base,
    font_weight: FontWeight = .normal,
    text_align: TextAlign = .left,

    border_radius: BorderRadius = .none,
    shadow: Shadow = .none,

    // Fluent builder methods
    pub fn flex() Style;
    pub fn flexCol() Style;
    pub fn center() Style;

    pub fn p(self: Style, spacing: Spacing) Style;
    pub fn px(self: Style, spacing: Spacing) Style;
    pub fn py(self: Style, spacing: Spacing) Style;
    pub fn m(self: Style, spacing: Spacing) Style;
    pub fn mx(self: Style, spacing: Spacing) Style;
    pub fn my(self: Style, spacing: Spacing) Style;

    pub fn withGap(self: Style, spacing: Spacing) Style;
    pub fn bg(self: Style, color: Color) Style;
    pub fn textColor(self: Style, color: Color) Style;
    pub fn rounded(self: Style, radius: BorderRadius) Style;
    pub fn withShadow(self: Style, shadow: Shadow) Style;
    pub fn text(self: Style, size: FontSize) Style;
    pub fn weight(self: Style, w: FontWeight) Style;
};
```

**Example Usage:**
```zig
const cardStyle = Style.flex()
    .flexCol()
    .p(.s4)
    .withGap(.s2)
    .bg(colors.white)
    .rounded(.lg)
    .withShadow(.md);
```

---

## Hot Reload System

Development server with hot reloading capabilities.

### Hot Reload Types (`hot_reload.zig`)

```zig
pub const FileChangeType = enum {
    created, modified, deleted, renamed,
};

pub const BuildStatus = enum {
    idle, building, success, failed,
};

pub const ErrorSeverity = enum {
    hint, info, warning, err,
};
```

### File Watcher

```zig
pub const FileWatcher = struct {
    pub fn init(allocator: std.mem.Allocator) FileWatcher;
    pub fn deinit(self: *FileWatcher) void;

    /// Add watch path
    pub fn addPath(self: *FileWatcher, path: []const u8) !void;

    /// Set file patterns to watch
    pub fn setPatterns(self: *FileWatcher, include: []const []const u8, exclude: []const []const u8) void;

    /// Check for changes
    pub fn poll(self: *FileWatcher) ?FileChange;

    /// Pattern matching
    pub fn matchPattern(path: []const u8, pattern: []const u8) bool;
};
```

### State Manager

```zig
pub const StateType = enum { string, integer, float, boolean, object };

pub const StateValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    object: []const u8,
};

pub const StateManager = struct {
    pub fn init(allocator: std.mem.Allocator) StateManager;
    pub fn deinit(self: *StateManager) void;

    /// State operations
    pub fn set(self: *StateManager, key: []const u8, value: StateValue) !void;
    pub fn get(self: *const StateManager, key: []const u8) ?StateValue;
    pub fn remove(self: *StateManager, key: []const u8) bool;
    pub fn clear(self: *StateManager) void;

    /// Snapshots
    pub fn createSnapshot(self: *StateManager) ![]const u8;
    pub fn restoreSnapshot(self: *StateManager, data: []const u8) !void;
};
```

### Dev Server

```zig
pub const DevServerConfig = struct {
    port: u16 = 3000,
    host: []const u8 = "127.0.0.1",
    watch_paths: []const []const u8 = &.{},
    auto_reload: bool = true,
    open_browser: bool = false,
};

pub const DevServer = struct {
    pub fn init(allocator: std.mem.Allocator, config: DevServerConfig) DevServer;
    pub fn deinit(self: *DevServer) void;

    /// Server lifecycle
    pub fn start(self: *DevServer) !void;
    pub fn stop(self: *DevServer) void;
    pub fn isRunning(self: *const DevServer) bool;

    /// Notify clients of changes
    pub fn notifyClients(self: *DevServer, message: []const u8) void;
};
```

---

## WASM Entry Point

WebAssembly-specific exports for JavaScript interop.

### WASM Utilities (`wasm.zig`)

```zig
// Memory management
export fn zylix_wasm_alloc(size: usize) ?[*]u8;
export fn zylix_wasm_free_scratch() void;
export fn zylix_wasm_memory_used() usize;
export fn zylix_wasm_memory_peak() usize;

// GPU exports
export fn zigdom_gpu_init() void;
export fn zigdom_gpu_deinit() void;
export fn zigdom_gpu_update(delta_time: f32) void;
export fn zigdom_gpu_set_aspect(aspect: f32) void;
export fn zigdom_gpu_get_vertex_buffer() ?*const anyopaque;
export fn zigdom_gpu_get_vertex_buffer_size() usize;

// Particle system exports
export fn zigdom_particles_init(count: u32) void;
export fn zigdom_particles_update_time(delta: f32) void;
export fn zigdom_particles_set_gravity(x: f32, y: f32) void;
export fn zigdom_particles_preset_fountain() void;
export fn zigdom_particles_preset_explosion() void;
export fn zigdom_particles_preset_rain() void;

// Scheduler exports
export fn zigdom_scheduler_init() void;
export fn zigdom_scheduler_update(delta_time: f32) void;
export fn zigdom_scheduler_pause() void;
export fn zigdom_scheduler_resume() void;
export fn zigdom_scheduler_set_time_scale(scale: f32) void;

// Timer API
export fn zigdom_timer_create(delay_seconds: f32, tag: u32) u32;
export fn zigdom_timer_create_interval(interval_seconds: f32, tag: u32) u32;
export fn zigdom_timer_cancel(task_id: u32) bool;

// CSS exports
export fn zigdom_css_init() void;
export fn zigdom_css_create_style() u32;
export fn zigdom_css_set_display(id: u32, display: u8) void;
export fn zigdom_css_set_flex_direction(id: u32, direction: u8) void;
export fn zigdom_css_set_bg_color(id: u32, r: u8, g: u8, b: u8, a: u8) void;

// Layout exports
export fn zigdom_layout_init() void;
export fn zigdom_layout_create_node() u32;
export fn zigdom_layout_set_root(id: u32) void;
export fn zigdom_layout_add_child(parent_id: u32, child_id: u32) bool;
export fn zigdom_layout_compute(container_width: f32, container_height: f32) void;

// Component system exports
export fn zigdom_component_init() void;
export fn zigdom_component_create_container() u32;
export fn zigdom_component_create_text(text_ptr: [*]const u8, text_len: usize) u32;
export fn zigdom_component_create_button(label_ptr: [*]const u8, label_len: usize) u32;
export fn zigdom_component_add_child(parent_id: u32, child_id: u32) bool;
export fn zigdom_component_on_click(id: u32, callback_id: u32) void;

// Virtual DOM exports
export fn zigdom_vdom_init() void;
export fn zigdom_vdom_create_element(tag: u8) u32;
export fn zigdom_vdom_create_text(text_ptr: [*]const u8, text_len: usize) u32;
export fn zigdom_vdom_add_child(parent_id: u32, child_id: u32) bool;
export fn zigdom_vdom_commit() u32;
```

---

## AI Module (llama.cpp)

Low-level bindings to llama.cpp for LLM inference.

### Types (`ai/llama_cpp.zig`)

```zig
pub const llama_model = c.llama_model;
pub const llama_context = c.llama_context;
pub const llama_token = c.llama_token;
pub const llama_batch = c.llama_batch;
pub const llama_sampler = c.llama_sampler;

// Pooling types
pub const LLAMA_POOLING_TYPE_NONE = c.LLAMA_POOLING_TYPE_NONE;
pub const LLAMA_POOLING_TYPE_MEAN = c.LLAMA_POOLING_TYPE_MEAN;
pub const LLAMA_POOLING_TYPE_CLS = c.LLAMA_POOLING_TYPE_CLS;
pub const LLAMA_POOLING_TYPE_LAST = c.LLAMA_POOLING_TYPE_LAST;
```

### Backend Initialization

```zig
/// Initialize llama backend (call once at startup)
pub fn backendInit() void;

/// Free llama backend (call at shutdown)
pub fn backendFree() void;

/// Check GPU offload support
pub fn supportsGpuOffload() bool;

/// Check mmap support
pub fn supportsMmap() bool;
```

### Model Loading

```zig
/// Get default model parameters
pub fn modelDefaultParams() llama_model_params;

/// Get default context parameters
pub fn contextDefaultParams() llama_context_params;

/// Load model from file
pub fn modelLoadFromFile(path: [*:0]const u8, params: llama_model_params) ?*llama_model;

/// Free model
pub fn modelFree(model: *llama_model) void;

/// Create context from model
pub fn initFromModel(model: *llama_model, params: llama_context_params) ?*llama_context;

/// Free context
pub fn free(ctx: *llama_context) void;
```

### Tokenization

```zig
/// Tokenize text
pub fn tokenize(
    vocab: *const c.llama_vocab,
    text: [*]const u8,
    text_len: i32,
    tokens: [*]llama_token,
    n_tokens_max: i32,
    add_special: bool,
    parse_special: bool,
) i32;

/// Convert token back to text
pub fn tokenToPiece(
    vocab: *const c.llama_vocab,
    token: llama_token,
    buf: [*]u8,
    length: i32,
    lstrip: i32,
    special: bool,
) i32;
```

### Inference

```zig
/// Initialize batch
pub fn batchInit(n_tokens: i32, embd: i32, n_seq_max: i32) llama_batch;

/// Free batch
pub fn batchFree(batch: llama_batch) void;

/// Decode batch (run inference)
pub fn decode(ctx: *llama_context, batch: llama_batch) i32;

/// Get logits for token
pub fn getLogitsIth(ctx: *llama_context, i: i32) ?[*]f32;
```

### Sampling

```zig
/// Create sampler chain
pub fn samplerChainInit(params: c.llama_sampler_chain_params) ?*llama_sampler;

/// Add sampler to chain
pub fn samplerChainAdd(chain: *llama_sampler, smpl: *llama_sampler) void;

/// Create greedy sampler
pub fn samplerInitGreedy() ?*llama_sampler;

/// Create temperature sampler
pub fn samplerInitTemp(temp: f32) ?*llama_sampler;

/// Create top-p sampler
pub fn samplerInitTopP(p: f32, min_keep: usize) ?*llama_sampler;

/// Create top-k sampler
pub fn samplerInitTopK(k: i32) ?*llama_sampler;

/// Sample next token
pub fn samplerSample(smpl: *llama_sampler, ctx: *llama_context, idx: i32) llama_token;
```

---

# Test Framework

### Platform Enum

```zig
pub const Platform = enum {
    ios,
    watchos,
    android,
    macos,
    windows,
    linux,
    web,
    auto,

    /// Check if platform is Apple mobile (iOS or watchOS)
    pub fn isAppleMobile(self: Platform) bool;
};
```

### CrownRotationDirection (watchOS)

```zig
pub const CrownRotationDirection = enum {
    up,
    down,
};
```

### SwipeDirection

```zig
pub const SwipeDirection = enum {
    up,
    down,
    left,
    right,
};
```

### DriverError

```zig
pub const DriverError = error{
    ConnectionFailed,
    SessionNotCreated,
    ElementNotFound,
    Timeout,
    CommandFailed,
    InvalidResponse,
    NotSupported,
};
```

---

## Driver Interface

### Base Driver Configuration

```zig
pub const DriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16,
    timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,
};
```

### iOS Driver Configuration

```zig
pub const IOSDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8100,
    device_udid: ?[]const u8 = null,
    bundle_id: ?[]const u8 = null,
    use_simulator: bool = true,
    simulator_type: SimulatorType = .iphone_15_pro,
    launch_timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,

    // watchOS-specific
    is_watchos: bool = false,
    watchos_version: []const u8 = "11.0",
    companion_device_udid: ?[]const u8 = null,

    pub fn isWatchOS(self: *const Self) bool;
    pub fn platformVersion(self: *const Self) []const u8;
    pub fn platformName(self: *const Self) []const u8;
    pub fn simulatorName(self: *const Self) []const u8;
};
```

### SimulatorType (iOS/watchOS)

```zig
pub const SimulatorType = enum {
    // iPhone devices
    iphone_15,
    iphone_15_pro,
    iphone_15_pro_max,
    iphone_se,

    // iPad devices
    ipad_pro_11,
    ipad_pro_12_9,
    ipad_air,

    // Apple Watch devices (watchOS)
    apple_watch_series_9_41mm,
    apple_watch_series_9_45mm,
    apple_watch_series_10_42mm,
    apple_watch_series_10_46mm,
    apple_watch_ultra_2,
    apple_watch_se_40mm,
    apple_watch_se_44mm,
};
```

### Android Driver Configuration

```zig
pub const AndroidDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 4723,
    device_id: ?[]const u8 = null,
    package_name: ?[]const u8 = null,
    activity_name: ?[]const u8 = null,
    platform_version: []const u8 = "14",
    automation_name: []const u8 = "UiAutomator2",
    command_timeout_ms: u32 = 10000,
};
```

### Web Driver Configuration

```zig
pub const WebDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 9515,
    browser: BrowserType = .chrome,
    headless: bool = false,
    viewport_width: u16 = 1920,
    viewport_height: u16 = 1080,
    timeout_ms: u32 = 30000,
};

pub const BrowserType = enum {
    chrome,
    firefox,
    safari,
    edge,
};
```

---

## Selector API

### Selector Structure

```zig
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    xpath: ?[]const u8 = null,
    css: ?[]const u8 = null,
    class_chain: ?[]const u8 = null,
    predicate: ?[]const u8 = null,
    ui_automator: ?[]const u8 = null,

    // Factory methods
    pub fn byTestId(id: []const u8) Selector;
    pub fn byAccessibilityId(id: []const u8) Selector;
    pub fn byText(text: []const u8) Selector;
    pub fn byTextContains(text: []const u8) Selector;
    pub fn byXPath(xpath: []const u8) Selector;
    pub fn css(selector: []const u8) Selector;
    pub fn classChain(chain: []const u8) Selector;
    pub fn predicate(pred: []const u8) Selector;
    pub fn uiAutomator(selector: []const u8) Selector;
};
```

---

## Element API

### Element Actions

```zig
pub const Element = struct {
    /// Tap/click the element
    pub fn tap(self: *Element) DriverError!void;

    /// Double tap the element
    pub fn doubleTap(self: *Element) DriverError!void;

    /// Long press the element
    pub fn longPress(self: *Element, duration_ms: u32) DriverError!void;

    /// Type text into the element
    pub fn type(self: *Element, text: []const u8) DriverError!void;

    /// Clear the element's text
    pub fn clear(self: *Element) DriverError!void;

    /// Swipe on the element
    pub fn swipe(self: *Element, direction: SwipeDirection) DriverError!void;

    /// Check if element exists
    pub fn exists(self: *Element) bool;

    /// Check if element is visible
    pub fn isVisible(self: *Element) bool;

    /// Check if element is enabled
    pub fn isEnabled(self: *Element) bool;

    /// Get element's text content
    pub fn getText(self: *Element) DriverError![]const u8;

    /// Get element's attribute
    pub fn getAttribute(self: *Element, name: []const u8) DriverError![]const u8;

    /// Get element's bounding rectangle
    pub fn getRect(self: *Element) DriverError!Rect;
};

pub const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};
```

---

## Platform Drivers

### iOS/watchOS Actions

```zig
// iOS-specific actions
pub fn tapAtCoordinates(ctx: *DriverContext, x: u32, y: u32) DriverError!void;
pub fn swipe(ctx: *DriverContext, start_x: u32, start_y: u32, end_x: u32, end_y: u32) DriverError!void;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;

// watchOS-specific actions
pub fn rotateDigitalCrown(ctx: *DriverContext, direction: CrownDirection, velocity: f32) DriverError!void;
pub fn pressSideButton(ctx: *DriverContext, duration_ms: u32) DriverError!void;
pub fn doublePresssSideButton(ctx: *DriverContext) DriverError!void;
pub fn getCompanionDeviceInfo(ctx: *DriverContext) DriverError!?[]const u8;
```

### Android Actions

```zig
pub fn pressBack(ctx: *DriverContext) DriverError!void;
pub fn pressHome(ctx: *DriverContext) DriverError!void;
pub fn pressRecentApps(ctx: *DriverContext) DriverError!void;
pub fn getSource(ctx: *DriverContext) DriverError![]const u8;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;
```

### Web Actions

```zig
pub fn navigateTo(ctx: *DriverContext, url: []const u8) DriverError!void;
pub fn getTitle(ctx: *DriverContext) DriverError![]const u8;
pub fn getUrl(ctx: *DriverContext) DriverError![]const u8;
pub fn executeScript(ctx: *DriverContext, script: []const u8) DriverError![]const u8;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;
```

---

## E2E Test Framework

### E2E Configuration

```zig
pub const E2EConfig = struct {
    skip_unavailable: bool = true,
    connection_timeout_ms: u32 = 5000,
    command_timeout_ms: u32 = 30000,
    retry_count: u8 = 3,
    verbose: bool = false,
};
```

### Production Ports

```zig
pub const ProductionPorts = struct {
    pub const web: u16 = 9515;       // ChromeDriver/Playwright
    pub const ios: u16 = 8100;       // WebDriverAgent
    pub const android: u16 = 4723;   // Appium/UIAutomator2
    pub const macos: u16 = 8200;     // Accessibility bridge
    pub const linux: u16 = 8300;     // AT-SPI bridge
    pub const windows: u16 = 4723;   // WinAppDriver
};
```

### Test Ports (for Mock Servers)

```zig
pub const TestPorts = struct {
    pub const web: u16 = 19515;
    pub const ios: u16 = 18100;
    pub const watchos: u16 = 18101;
    pub const android: u16 = 16790;
    pub const macos: u16 = 18200;
    pub const linux: u16 = 18300;
};
```

### Helper Functions

```zig
/// Check if a server is available
pub fn isServerAvailable(host: []const u8, port: u16, timeout_ms: u32) bool;

/// Send HTTP request and get response
pub fn sendHttpRequest(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    method: []const u8,
    path: []const u8,
    body: ?[]const u8,
) ![]u8;

/// Parse session ID from JSON response
pub fn parseSessionId(response: []const u8) ?[]const u8;

/// Parse status code from JSON response
pub fn parseStatus(response: []const u8) ?i32;
```

### E2E Test Runner

```zig
pub const E2ERunner = struct {
    pub fn init(allocator: std.mem.Allocator, config: E2EConfig) E2ERunner;
    pub fn deinit(self: *E2ERunner) void;
    pub fn addResult(self: *E2ERunner, result: TestResult) !void;
    pub fn printSummary(self: *E2ERunner) void;
};

pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    skipped: bool,
    duration_ms: u64,
    error_message: ?[]const u8,
};
```

---

## Build Commands

### Unit Tests

```bash
cd core
zig build test                # Run unit tests
```

### Integration Tests

```bash
cd core
zig build test-integration    # Run integration tests (with mock servers)
```

### E2E Tests

```bash
cd core
zig build test-e2e            # Run E2E tests (requires running bridge servers)
```

### All Tests

```bash
cd core
zig build test-all            # Run unit + integration tests
zig build test-everything     # Run all tests including E2E
```

### Cross-Compilation

```bash
cd core

# iOS
zig build ios                 # iOS arm64
zig build ios-sim             # iOS Simulator arm64

# Android
zig build android             # All ABIs
zig build android-arm64       # arm64-v8a only
zig build android-x64         # x86_64 only

# macOS
zig build macos-arm64         # Apple Silicon
zig build macos-x64           # Intel

# Windows
zig build windows-x64         # x86_64
zig build windows-arm64       # ARM64

# Linux
zig build linux-x64           # x86_64
zig build linux-arm64         # ARM64

# WebAssembly
zig build wasm                # WASM32

# All platforms
zig build all                 # Build for all platforms
```

---

## WebDriver Protocol Endpoints

### Session Management

| Method | Path | Description |
|--------|------|-------------|
| POST | /session | Create new session |
| DELETE | /session/{id} | Delete session |
| GET | /status | Get server status |

### Element Operations

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/element | Find element |
| POST | /session/{id}/elements | Find elements |
| POST | /session/{id}/element/{eid}/click | Click element |
| POST | /session/{id}/element/{eid}/value | Send keys |
| GET | /session/{id}/element/{eid}/text | Get text |
| GET | /session/{id}/element/{eid}/displayed | Check visibility |
| GET | /session/{id}/element/{eid}/enabled | Check enabled |
| GET | /session/{id}/element/{eid}/rect | Get bounding rect |

### Platform-Specific Endpoints

#### iOS/watchOS (WebDriverAgent)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/wda/tap/0 | Tap at coordinates |
| POST | /session/{id}/wda/dragfromtoforduration | Swipe |
| POST | /session/{id}/wda/digitalCrown/rotate | Rotate Digital Crown |
| POST | /session/{id}/wda/sideButton/press | Press Side Button |
| POST | /session/{id}/wda/sideButton/doublePress | Double-press Side Button |
| GET | /session/{id}/wda/companion/info | Get companion device info |
| GET | /session/{id}/source | Get UI hierarchy |
| GET | /session/{id}/screenshot | Take screenshot |

#### Android (UIAutomator2)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/back | Press back button |
| GET | /session/{id}/source | Get UI hierarchy |
| GET | /session/{id}/screenshot | Take screenshot |

#### Web (WebDriver)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/url | Navigate to URL |
| GET | /session/{id}/url | Get current URL |
| GET | /session/{id}/title | Get page title |
| POST | /session/{id}/execute/sync | Execute JavaScript |
| GET | /session/{id}/screenshot | Take screenshot |

---

## Error Handling

### Error Response Format

```json
{
    "status": 7,
    "value": {
        "error": "no such element",
        "message": "An element could not be located on the page using the given search parameters.",
        "stacktrace": "..."
    }
}
```

### Common Status Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | Success | Command completed successfully |
| 6 | NoSuchDriver | Session does not exist |
| 7 | NoSuchElement | Element not found |
| 11 | ElementNotVisible | Element is not visible |
| 12 | InvalidElementState | Element state prevents interaction |
| 13 | UnknownError | Unknown server error |
| 21 | Timeout | Operation timed out |

---

## Performance Optimization

### Layout Engine Optimization

The layout engine includes several performance optimizations:

```zig
pub const LayoutNode = struct {
    // Performance: Style hash for dirty tracking (FNV-1a)
    style_hash: u32 = 0,
    // Cached direction flags (avoid repeated enum checks)
    cached_is_row: bool = true,
    cached_is_reverse: bool = false,
    cached_is_flex: bool = false,
    // Dirty flag for incremental updates
    dirty: bool = true,
    // ...
};

pub const LayoutEngine = struct {
    // Skip layout if nothing changed
    needs_layout: bool = true,
    last_container_width: f32 = 0,
    last_container_height: f32 = 0,
    // ...
};
```

**Key Features:**
- **Style hash caching**: FNV-1a hash to detect style changes
- **Dirty flag propagation**: Skip layout when nothing changed
- **Container size detection**: Only recompute when dimensions change

### Animation System Optimization

```zig
pub fn PropertyTrack(comptime T: type) type {
    return struct {
        // Binary search threshold (8+ keyframes)
        const BINARY_SEARCH_THRESHOLD = 8;

        // Performance: cached duration
        cached_duration: TimeMs = 0,
        // Temporal coherence for sequential playback
        last_keyframe_idx: usize = 0,
    };
}
```

**Key Features:**
- **Binary search**: O(log n) keyframe lookup for 8+ keyframes
- **Temporal coherence**: Cache last keyframe index for sequential playback
- **Duration caching**: Avoid recalculating track duration

### Hot Reload Optimization

```zig
pub const FileWatcher = struct {
    // O(1) suffix pattern matching (e.g., *.tmp)
    suffix_ignore_patterns: std.ArrayList([]const u8),
    // O(1) exact match patterns
    exact_ignore_patterns: std.StringHashMap(void),
    // Deduplication of pending changes
    pending_paths: std.StringHashMap(void),
};

pub const WebSocketServer = struct {
    // O(1) client count (cached)
    cached_client_count: usize = 0,
};
```

**Key Features:**
- **Pattern categorization**: Fast path for suffix and exact match patterns
- **Change deduplication**: Prevent duplicate file change entries
- **Cached client count**: O(1) instead of O(n) iteration

### WASM Bundle Size

Build optimizations in `build.zig`:

| Optimization | Impact |
|-------------|--------|
| ReleaseSmall | Smallest binary size |
| Single-threaded | Reduce WASM overhead |
| Strip symbols | Remove debug info |
| Link-Time Optimization | Cross-module optimization |

**Result**: 2.6MB → 1.4MB (**46% reduction**)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.17.0 | 2025-12-25 | Performance optimization (layout, animation, hot reload, WASM) |
| 0.8.0 | 2025-12-23 | Added watchOS support, E2E test framework |
| 0.7.0 | 2025-12 | Initial test framework release |
