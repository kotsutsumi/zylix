//! Note Flow - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    notes = 0,
    editor = 1,
    folders = 2,
    search = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .notes => "Notes",
            .editor => "Edit",
            .folders => "Folders",
            .search => "Search",
        };
    }
};

pub const Note = struct {
    id: u32 = 0,
    title: [64]u8 = [_]u8{0} ** 64,
    title_len: usize = 0,
    content: [512]u8 = [_]u8{0} ** 512,
    content_len: usize = 0,
    folder_id: u32 = 0,
    is_favorite: bool = false,
    is_archived: bool = false,
    updated_at: i64 = 0,
};

pub const Folder = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    note_count: u32 = 0,
    color: u32 = 0xFF007AFF,
};

pub const max_notes = 50;
pub const max_folders = 10;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .notes,

    // Notes
    notes: [max_notes]Note = undefined,
    note_count: usize = 0,
    selected_note: ?u32 = null,
    next_note_id: u32 = 1,

    // Folders
    folders: [max_folders]Folder = undefined,
    folder_count: usize = 0,
    selected_folder: ?u32 = null,

    // View
    show_favorites_only: bool = false,
    show_archived: bool = false,

    // Search
    search_query: [64]u8 = [_]u8{0} ** 64,
    search_query_len: usize = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Add folders
    _ = addFolder("Personal", 0xFF007AFF);
    _ = addFolder("Work", 0xFFFF9500);
    _ = addFolder("Ideas", 0xFF34C759);

    // Add notes
    _ = addNote("Meeting Notes", "Discussed project timeline and deliverables...", 2, false);
    _ = addNote("Shopping List", "- Milk\n- Bread\n- Eggs\n- Coffee", 1, false);
    _ = addNote("App Ideas", "1. Fitness tracker\n2. Recipe app\n3. Budget planner", 3, true);
    _ = addNote("Quick Note", "Remember to call mom", 1, false);
}

fn addFolder(name: []const u8, color: u32) ?u32 {
    if (app_state.folder_count >= max_folders) return null;

    var f = &app_state.folders[app_state.folder_count];
    f.id = @intCast(app_state.folder_count + 1);

    const name_len = @min(name.len, f.name.len);
    @memcpy(f.name[0..name_len], name[0..name_len]);
    f.name_len = name_len;

    f.color = color;

    app_state.folder_count += 1;
    return f.id;
}

fn addNote(title: []const u8, content: []const u8, folder_id: u32, favorite: bool) ?u32 {
    if (app_state.note_count >= max_notes) return null;

    var n = &app_state.notes[app_state.note_count];
    n.id = app_state.next_note_id;
    app_state.next_note_id += 1;

    const title_len = @min(title.len, n.title.len);
    @memcpy(n.title[0..title_len], title[0..title_len]);
    n.title_len = title_len;

    const content_len = @min(content.len, n.content.len);
    @memcpy(n.content[0..content_len], content[0..content_len]);
    n.content_len = content_len;

    n.folder_id = folder_id;
    n.is_favorite = favorite;
    n.updated_at = 1700000000 + @as(i64, @intCast(app_state.note_count)) * 3600;

    // Update folder count
    for (app_state.folders[0..app_state.folder_count]) |*f| {
        if (f.id == folder_id) {
            f.note_count += 1;
            break;
        }
    }

    app_state.note_count += 1;
    return n.id;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

pub fn selectNote(id: ?u32) void {
    app_state.selected_note = id;
    if (id != null) {
        app_state.current_screen = .editor;
    }
}

pub fn selectFolder(id: ?u32) void {
    app_state.selected_folder = id;
    app_state.current_screen = .notes;
}

// Note operations
pub fn createNote() u32 {
    const id = addNote("Untitled", "", app_state.selected_folder orelse 1, false);
    if (id) |note_id| {
        app_state.selected_note = note_id;
        app_state.current_screen = .editor;
        return note_id;
    }
    return 0;
}

pub fn deleteNote(id: u32) bool {
    for (app_state.notes[0..app_state.note_count], 0..) |*note, i| {
        if (note.id == id) {
            // Update folder count
            for (app_state.folders[0..app_state.folder_count]) |*f| {
                if (f.id == note.folder_id and f.note_count > 0) {
                    f.note_count -= 1;
                    break;
                }
            }

            // Remove note
            if (i < app_state.note_count - 1) {
                var j = i;
                while (j < app_state.note_count - 1) : (j += 1) {
                    app_state.notes[j] = app_state.notes[j + 1];
                }
            }
            app_state.note_count -= 1;

            if (app_state.selected_note == id) {
                app_state.selected_note = null;
                app_state.current_screen = .notes;
            }
            return true;
        }
    }
    return false;
}

pub fn toggleFavorite(id: u32) void {
    for (app_state.notes[0..app_state.note_count]) |*note| {
        if (note.id == id) {
            note.is_favorite = !note.is_favorite;
            break;
        }
    }
}

pub fn archiveNote(id: u32) void {
    for (app_state.notes[0..app_state.note_count]) |*note| {
        if (note.id == id) {
            note.is_archived = true;
            break;
        }
    }
}

// View toggles
pub fn toggleFavoritesOnly() void {
    app_state.show_favorites_only = !app_state.show_favorites_only;
}

pub fn toggleShowArchived() void {
    app_state.show_archived = !app_state.show_archived;
}

// Search
pub fn setSearchQuery(query: []const u8) void {
    const len = @min(query.len, app_state.search_query.len);
    @memcpy(app_state.search_query[0..len], query[0..len]);
    app_state.search_query_len = len;
}

// Queries
pub fn getNote(id: u32) ?*const Note {
    for (app_state.notes[0..app_state.note_count]) |*note| {
        if (note.id == id) return note;
    }
    return null;
}

pub fn getFolder(id: u32) ?*const Folder {
    for (app_state.folders[0..app_state.folder_count]) |*folder| {
        if (folder.id == id) return folder;
    }
    return null;
}

pub fn getFavoriteCount() u32 {
    var count: u32 = 0;
    for (app_state.notes[0..app_state.note_count]) |note| {
        if (note.is_favorite) count += 1;
    }
    return count;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.note_count > 0);
    try std.testing.expect(app_state.folder_count > 0);
}

test "create note" {
    init();
    defer deinit();
    const initial = app_state.note_count;
    const id = createNote();
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(initial + 1, app_state.note_count);
}

test "delete note" {
    init();
    defer deinit();
    const initial = app_state.note_count;
    try std.testing.expect(deleteNote(1));
    try std.testing.expectEqual(initial - 1, app_state.note_count);
}

test "toggle favorite" {
    init();
    defer deinit();
    const note = getNote(1);
    try std.testing.expect(note != null);
    const was_favorite = note.?.is_favorite;
    toggleFavorite(1);
    const updated_note = getNote(1);
    try std.testing.expectEqual(!was_favorite, updated_note.?.is_favorite);
}

test "navigation" {
    init();
    defer deinit();
    selectNote(1);
    try std.testing.expectEqual(@as(?u32, 1), app_state.selected_note);
    try std.testing.expectEqual(Screen.editor, app_state.current_screen);
}
