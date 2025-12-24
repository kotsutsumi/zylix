//! Component Gallery - Application State
//!
//! Manages the gallery state including selected category, theme, and component settings.

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

/// Component category for navigation
pub const ComponentCategory = enum(u32) {
    layout = 0,
    inputs = 1,
    display = 2,
    navigation = 3,
    feedback = 4,
    lists = 5,

    pub fn name(self: ComponentCategory) []const u8 {
        return switch (self) {
            .layout => "Layout",
            .inputs => "Inputs",
            .display => "Display",
            .navigation => "Navigation",
            .feedback => "Feedback",
            .lists => "Lists",
        };
    }

    pub fn icon(self: ComponentCategory) []const u8 {
        return switch (self) {
            .layout => "grid",
            .inputs => "edit",
            .display => "image",
            .navigation => "compass",
            .feedback => "bell",
            .lists => "list",
        };
    }
};

/// Application theme
pub const Theme = enum {
    light,
    dark,

    pub fn colors(self: Theme) ThemeColors {
        return switch (self) {
            .light => .{
                .background = Color{ .r = 255, .g = 255, .b = 255 },
                .surface = Color{ .r = 243, .g = 244, .b = 246 },
                .primary = Color{ .r = 59, .g = 130, .b = 246 },
                .secondary = Color{ .r = 107, .g = 114, .b = 128 },
                .text = Color{ .r = 0, .g = 0, .b = 0 },
                .text_secondary = Color{ .r = 107, .g = 114, .b = 128 },
                .border = Color{ .r = 229, .g = 231, .b = 235 },
            },
            .dark => .{
                .background = Color{ .r = 17, .g = 24, .b = 39 },
                .surface = Color{ .r = 31, .g = 41, .b = 55 },
                .primary = Color{ .r = 96, .g = 165, .b = 250 },
                .secondary = Color{ .r = 156, .g = 163, .b = 175 },
                .text = Color{ .r = 255, .g = 255, .b = 255 },
                .text_secondary = Color{ .r = 156, .g = 163, .b = 175 },
                .border = Color{ .r = 55, .g = 65, .b = 81 },
            },
        };
    }
};

pub const ThemeColors = struct {
    background: Color,
    surface: Color,
    primary: Color,
    secondary: Color,
    text: Color,
    text_secondary: Color,
    border: Color,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

/// Application state
pub const AppState = struct {
    initialized: bool = false,
    selected_category: ComponentCategory = .layout,
    current_theme: Theme = .light,
    show_code: bool = false,
    selected_component: ?[]const u8 = null,

    // Component customization
    button_variant: ButtonVariant = .primary,
    button_size: Size = .medium,
    text_size: u32 = 16,
    spacing: u32 = 16,
};

pub const ButtonVariant = enum { primary, secondary, outline, ghost };
pub const Size = enum { small, medium, large };

// ============================================================================
// Global State
// ============================================================================

var app_state: AppState = .{};

// ============================================================================
// Public API
// ============================================================================

pub fn init() void {
    app_state = .{
        .initialized = true,
    };
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

pub fn getStateMut() *AppState {
    return &app_state;
}

pub fn selectCategory(category: ComponentCategory) void {
    app_state.selected_category = category;
    app_state.selected_component = null;
}

pub fn toggleTheme() void {
    app_state.current_theme = if (app_state.current_theme == .light) .dark else .light;
}

pub fn toggleShowCode() void {
    app_state.show_code = !app_state.show_code;
}

pub fn selectComponent(component: []const u8) void {
    app_state.selected_component = component;
}

pub fn setButtonVariant(variant: ButtonVariant) void {
    app_state.button_variant = variant;
}

pub fn setButtonSize(size: Size) void {
    app_state.button_size = size;
}

// ============================================================================
// Tests
// ============================================================================

test "state initialization" {
    init();
    defer deinit();

    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(ComponentCategory.layout, app_state.selected_category);
    try std.testing.expectEqual(Theme.light, app_state.current_theme);
}

test "category selection" {
    init();
    defer deinit();

    selectCategory(.inputs);
    try std.testing.expectEqual(ComponentCategory.inputs, app_state.selected_category);
}

test "theme toggle" {
    init();
    defer deinit();

    try std.testing.expectEqual(Theme.light, app_state.current_theme);
    toggleTheme();
    try std.testing.expectEqual(Theme.dark, app_state.current_theme);
    toggleTheme();
    try std.testing.expectEqual(Theme.light, app_state.current_theme);
}

test "component category names" {
    try std.testing.expectEqualStrings("Layout", ComponentCategory.layout.name());
    try std.testing.expectEqualStrings("Inputs", ComponentCategory.inputs.name());
    try std.testing.expectEqualStrings("Display", ComponentCategory.display.name());
}

test "theme colors" {
    const light = Theme.light.colors();
    try std.testing.expectEqual(@as(u8, 255), light.background.r);

    const dark = Theme.dark.colors();
    try std.testing.expectEqual(@as(u8, 17), dark.background.r);
}
