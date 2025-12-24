//! Note Flow - Entry Point and C ABI Exports

const std = @import("std");
pub const app = @import("app.zig");
pub const ui = @import("ui.zig");

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

// Navigation
export fn app_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn app_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

export fn app_select_note(id: u32) void {
    if (id == 0) {
        app.selectNote(null);
    } else {
        app.selectNote(id);
    }
}

export fn app_select_folder(id: u32) void {
    if (id == 0) {
        app.selectFolder(null);
    } else {
        app.selectFolder(id);
    }
}

// Note operations
export fn app_create_note() u32 {
    return app.createNote();
}

export fn app_delete_note(id: u32) i32 {
    return if (app.deleteNote(id)) 1 else 0;
}

export fn app_toggle_favorite(id: u32) void {
    app.toggleFavorite(id);
}

export fn app_archive_note(id: u32) void {
    app.archiveNote(id);
}

// View toggles
export fn app_toggle_favorites_only() void {
    app.toggleFavoritesOnly();
}

export fn app_toggle_show_archived() void {
    app.toggleShowArchived();
}

// Search
export fn app_set_search_query(ptr: [*]const u8, len: usize) void {
    if (len > 0) {
        app.setSearchQuery(ptr[0..len]);
    } else {
        app.setSearchQuery("");
    }
}

// Queries
export fn app_get_note_count() u32 {
    return @intCast(app.getState().note_count);
}

export fn app_get_folder_count() u32 {
    return @intCast(app.getState().folder_count);
}

export fn app_get_favorite_count() u32 {
    return app.getFavoriteCount();
}

export fn app_get_selected_note() u32 {
    return app.getState().selected_note orelse 0;
}

export fn app_get_selected_folder() u32 {
    return app.getState().selected_folder orelse 0;
}

export fn app_is_favorites_only() i32 {
    return if (app.getState().show_favorites_only) 1 else 0;
}

// UI rendering
export fn app_render() [*]const ui.VNode {
    return ui.render();
}

// ============================================================================
// Tests
// ============================================================================

test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(app.getState().initialized);
}

test "note operations" {
    init();
    defer deinit();

    const initial = app_get_note_count();

    // Create note
    const id = app_create_note();
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(initial + 1, app_get_note_count());

    // Delete note
    try std.testing.expectEqual(@as(i32, 1), app_delete_note(id));
    try std.testing.expectEqual(initial, app_get_note_count());
}

test "favorites" {
    init();
    defer deinit();

    const initial_favorites = app_get_favorite_count();
    app_toggle_favorite(1);
    // Count should change
    const new_favorites = app_get_favorite_count();
    try std.testing.expect(new_favorites != initial_favorites);
}

test "navigation" {
    init();
    defer deinit();

    app_select_note(1);
    try std.testing.expectEqual(@as(u32, 1), app_get_selected_note());
    try std.testing.expectEqual(@as(u8, 1), app_get_screen()); // editor
}

test "folders" {
    init();
    defer deinit();

    try std.testing.expect(app_get_folder_count() > 0);

    app_select_folder(1);
    try std.testing.expectEqual(@as(u32, 1), app_get_selected_folder());
}

test "view toggles" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i32, 0), app_is_favorites_only());
    app_toggle_favorites_only();
    try std.testing.expectEqual(@as(i32, 1), app_is_favorites_only());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
