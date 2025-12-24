//! Component Gallery - Zylix UI Component Showcase
//!
//! A comprehensive demonstration of all Zylix UI components with
//! interactive examples and customization options.

const std = @import("std");
const app = @import("app.zig");
const gallery = @import("gallery.zig");

// Re-export public API
pub const AppState = app.AppState;
pub const ComponentCategory = app.ComponentCategory;
pub const Theme = app.Theme;

/// Initialize the gallery application
pub fn init() void {
    app.init();
}

/// Deinitialize the application
pub fn deinit() void {
    app.deinit();
}

/// Get current application state
pub fn getState() *const AppState {
    return app.getState();
}

/// Render the gallery UI
pub fn render() gallery.VNode {
    return gallery.buildGallery(app.getState());
}

/// Handle component selection
pub fn selectCategory(category: ComponentCategory) void {
    app.selectCategory(category);
}

/// Toggle theme
pub fn toggleTheme() void {
    app.toggleTheme();
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn gallery_init() void {
    init();
}

export fn gallery_deinit() void {
    deinit();
}

export fn gallery_select_category(category: u32) void {
    // Validate category is in valid range before enum conversion
    const max_category = @typeInfo(ComponentCategory).@"enum".fields.len;
    if (category >= max_category) {
        return; // Invalid category, ignore
    }
    selectCategory(@enumFromInt(category));
}

export fn gallery_toggle_theme() void {
    toggleTheme();
}

// ============================================================================
// Tests
// ============================================================================

test "gallery initialization" {
    init();
    defer deinit();

    const state = getState();
    try std.testing.expect(state.initialized);
    try std.testing.expectEqual(ComponentCategory.layout, state.selected_category);
}

test "category selection" {
    init();
    defer deinit();

    selectCategory(.inputs);
    try std.testing.expectEqual(ComponentCategory.inputs, app.getState().selected_category);

    selectCategory(.display);
    try std.testing.expectEqual(ComponentCategory.display, app.getState().selected_category);
}

test "theme toggle" {
    init();
    defer deinit();

    const initial_theme = app.getState().current_theme;
    toggleTheme();
    try std.testing.expect(app.getState().current_theme != initial_theme);
}
