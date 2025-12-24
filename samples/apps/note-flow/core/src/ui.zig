//! Note Flow - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, input, editor };

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    pub fn all(v: f32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
    pub fn symmetric(h: f32, v: f32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
    }
};

pub const Style = struct {
    padding: Spacing = .{},
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFFF2F2F7;
    pub const surface: u32 = 0xFFFFFFFF;
    pub const card: u32 = 0xFFFFFFFF;
    pub const text: u32 = 0xFF1C1C1E;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFFFFCC00;
    pub const accent: u32 = 0xFFFF9500;
    pub const favorite: u32 = 0xFFFF3B30;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
    icon: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}
fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}
fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}
fn text(content: []const u8, props: Props) VNode {
    var p = props;
    p.text = content;
    return .{ .tag = .text, .props = p, .children = &.{} };
}
fn button(label: []const u8, props: Props) VNode {
    var p = props;
    p.text = label;
    return .{ .tag = .button, .props = p, .children = &.{} };
}
fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}
fn spacer() VNode {
    return .{ .tag = .div, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [3]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildContent(state);
    S.content[2] = buildTabBar(state);

    return column(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 28, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = iconView("plus.circle.fill", .{ .style = .{ .color = Color.primary, .font_size = 28 } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(16, 12),
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .notes => buildNotesScreen(state),
        .editor => buildEditorScreen(state),
        .folders => buildFoldersScreen(state),
        .search => buildSearchScreen(state),
    };
}

fn buildNotesScreen(state: *const app.AppState) VNode {
    const max_display = 6;
    var display_count: usize = 0;

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = Color.surface, .border_radius = 12, .padding = Spacing.all(12) },
    }, &.{
        row(.{ .style = .{ .gap = 8 } }, &.{
            iconView("magnifyingglass", .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } }),
            text("Search notes...", .{ .style = .{ .color = Color.text_secondary } }),
        }),
    });

    for (state.notes[0..state.note_count]) |*note| {
        if (display_count >= max_display) break;
        if (state.show_favorites_only and !note.is_favorite) continue;
        if (!state.show_archived and note.is_archived) continue;

        S.items[display_count + 1] = buildNoteCard(note);
        display_count += 1;
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0 .. display_count + 1]);
}

fn buildNoteCard(note: *const app.Note) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    // Truncate content for preview
    const preview_len = @min(note.content_len, 50);

    S.items[0] = row(.{}, &.{
        text(note.title[0..note.title_len], .{
            .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text, .flex = 1 },
        }),
        iconView(if (note.is_favorite) "star.fill" else "star", .{
            .style = .{ .color = if (note.is_favorite) Color.primary else Color.text_secondary, .font_size = 18 },
        }),
    });
    S.items[1] = text(note.content[0..preview_len], .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });
    S.items[2] = text("Just now", .{
        .style = .{ .font_size = 12, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildEditorScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    const note = if (state.selected_note) |id| app.getNote(id) else null;
    const title = if (note) |n| n.title[0..n.title_len] else "Untitled";
    const content = if (note) |n| n.content[0..n.content_len] else "";

    S.items[0] = row(.{ .style = .{ .padding = Spacing.symmetric(16, 8), .gap = 12 } }, &.{
        iconView("chevron.left", .{ .style = .{ .color = Color.primary, .font_size = 20 } }),
        text("Notes", .{ .style = .{ .color = Color.primary } }),
        spacer(),
        iconView("ellipsis", .{ .style = .{ .color = Color.primary, .font_size = 20 } }),
    });
    S.items[1] = div(.{
        .style = .{ .padding = Spacing.all(16), .flex = 1 },
    }, &.{
        text(title, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } }),
        text(content, .{ .style = .{ .font_size = 16, .color = Color.text, .padding = Spacing.symmetric(0, 16) } }),
    });
    S.items[2] = row(.{
        .style = .{ .background = Color.surface, .padding = Spacing.all(12), .gap = 16 },
    }, &.{
        iconView("textformat", .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } }),
        iconView("checklist", .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } }),
        iconView("photo", .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } }),
        spacer(),
        iconView("keyboard", .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } }),
    });

    return column(.{ .style = .{ .flex = 1 } }, &S.items);
}

fn buildFoldersScreen(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.folder_count, max_display);

    const S = struct {
        var items: [max_display + 2]VNode = undefined;
    };

    S.items[0] = text("Folders", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildFolderItem(&state.folders[i]);
    }

    S.items[display_count + 1] = row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &.{
        iconView("plus", .{ .style = .{ .color = Color.primary, .font_size = 20 } }),
        text("New Folder", .{ .style = .{ .color = Color.primary } }),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0 .. display_count + 2]);
}

fn buildFolderItem(folder: *const app.Folder) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "{d}", .{folder.note_count}) catch "0";

    S.items[0] = iconView("folder.fill", .{ .style = .{ .color = folder.color, .font_size = 24 } });
    S.items[1] = text(folder.name[0..folder.name_len], .{
        .style = .{ .font_size = 16, .color = Color.text, .flex = 1 },
    });
    S.items[2] = text(count_str, .{ .style = .{ .color = Color.text_secondary } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildSearchScreen(state: *const app.AppState) VNode {
    _ = state;
    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 } }, &.{
        div(.{
            .style = .{ .background = Color.surface, .border_radius = 12, .padding = Spacing.all(12) },
        }, &.{
            row(.{ .style = .{ .gap = 8 } }, &.{
                iconView("magnifyingglass", .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } }),
                text("Search notes...", .{ .style = .{ .color = Color.text_secondary } }),
            }),
        }),
        text("Recent", .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } }),
    });
}

fn buildTabBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildTabItem("note.text", "Notes", state.current_screen == .notes);
    S.items[1] = buildTabItem("folder", "Folders", state.current_screen == .folders);
    S.items[2] = buildTabItem("magnifyingglass", "Search", state.current_screen == .search);
    S.items[3] = buildTabItem("gear", "Settings", false);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(icon_name: []const u8, label: []const u8, selected: bool) VNode {
    const color = if (selected) Color.primary else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 20 } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 10, .color = color } });

    return column(.{ .style = .{ .flex = 1, .gap = 4, .padding = Spacing.symmetric(0, 8) } }, &S.items);
}

// ============================================================================
// C ABI Export
// ============================================================================

pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildApp(app.getState());
    return &S.root;
}

// ============================================================================
// Tests
// ============================================================================

test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
