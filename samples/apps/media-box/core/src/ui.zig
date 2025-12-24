//! Media Box - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, slider, artwork };

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
    pub const background: u32 = 0xFF000000;
    pub const surface: u32 = 0xFF1C1C1E;
    pub const card: u32 = 0xFF2C2C2E;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFFFF2D55;
    pub const accent: u32 = 0xFFFF375F;
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
    S.content[2] = buildMiniPlayer(state);

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
    S.items[2] = iconView("magnifyingglass", .{ .style = .{ .color = Color.primary, .font_size = 22 } });

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .library => buildLibraryScreen(state),
        .now_playing => buildNowPlayingScreen(state),
        .playlists => buildPlaylistsScreen(state),
        .search => buildSearchScreen(state),
    };
}

fn buildLibraryScreen(state: *const app.AppState) VNode {
    const max_display = 6;
    const display_count = @min(state.track_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Songs", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text, .padding = Spacing.symmetric(16, 8) },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildTrackItem(&state.tracks[i]);
    }

    return column(.{ .style = .{ .flex = 1 } }, S.items[0 .. display_count + 1]);
}

fn buildTrackItem(track: *const app.Track) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var dur_buf: [8]u8 = undefined;
    };

    const dur = app.formatDuration(track.duration);
    const dur_str = std.fmt.bufPrint(&S.dur_buf, "{d}:{d:0>2}", .{ dur.min, dur.sec }) catch "0:00";

    S.items[0] = div(.{
        .style = .{ .background = Color.card, .width = 48, .height = 48, .border_radius = 8 },
    }, &.{
        iconView("music.note", .{ .style = .{ .color = Color.text_secondary, .font_size = 20, .padding = Spacing.all(14) } }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(track.title[0..track.title_len], .{ .style = .{ .font_size = 16, .color = Color.text } }),
        text(track.artist[0..track.artist_len], .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = text(dur_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildNowPlayingScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    const current = app.getCurrentTrack();
    const title = if (current) |t| t.title[0..t.title_len] else "Not Playing";
    const artist = if (current) |t| t.artist[0..t.artist_len] else "";

    // Album art
    S.items[0] = div(.{
        .style = .{ .background = Color.card, .width = 280, .height = 280, .border_radius = 16 },
    }, &.{
        iconView("music.note", .{ .style = .{ .color = Color.text_secondary, .font_size = 80, .padding = Spacing.all(100) } }),
    });

    // Track info
    S.items[1] = column(.{ .style = .{ .gap = 8 } }, &.{
        text(title, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } }),
        text(artist, .{ .style = .{ .font_size = 18, .color = Color.text_secondary } }),
    });

    // Progress bar
    S.items[2] = div(.{
        .style = .{ .background = Color.card, .height = 4, .border_radius = 2, .width = 280 },
    }, &.{
        div(.{
            .style = .{
                .background = Color.primary,
                .height = 4,
                .border_radius = 2,
                .width = 280 * state.position,
            },
        }, &.{}),
    });

    // Controls
    S.items[3] = buildPlaybackControls(state);

    return column(.{
        .style = .{ .padding = Spacing.all(32), .gap = 32, .flex = 1 },
    }, &S.items);
}

fn buildPlaybackControls(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    const play_icon: []const u8 = if (state.play_state == .playing) "pause.fill" else "play.fill";

    S.items[0] = iconView("shuffle", .{
        .style = .{ .color = if (state.shuffle) Color.primary else Color.text_secondary, .font_size = 20 },
    });
    S.items[1] = iconView("backward.fill", .{ .style = .{ .color = Color.text, .font_size = 28 } });
    S.items[2] = div(.{
        .style = .{ .background = Color.primary, .width = 64, .height = 64, .border_radius = 32 },
    }, &.{
        iconView(play_icon, .{ .style = .{ .color = Color.text, .font_size = 28, .padding = Spacing.all(18) } }),
    });
    S.items[3] = iconView("forward.fill", .{ .style = .{ .color = Color.text, .font_size = 28 } });
    S.items[4] = iconView("repeat", .{
        .style = .{ .color = if (state.repeat != .off) Color.primary else Color.text_secondary, .font_size = 20 },
    });

    return row(.{ .style = .{ .gap = 32 } }, &S.items);
}

fn buildPlaylistsScreen(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.playlist_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Playlists", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text, .padding = Spacing.symmetric(16, 8) },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildPlaylistItem(&state.playlists[i]);
    }

    return column(.{ .style = .{ .flex = 1 } }, S.items[0 .. display_count + 1]);
}

fn buildPlaylistItem(playlist: *const app.Playlist) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "{d} songs", .{playlist.track_count}) catch "0 songs";

    S.items[0] = div(.{
        .style = .{ .background = Color.primary, .width = 56, .height = 56, .border_radius = 8 },
    }, &.{
        iconView("music.note.list", .{ .style = .{ .color = Color.text, .font_size = 24, .padding = Spacing.all(16) } }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(playlist.name[0..playlist.name_len], .{ .style = .{ .font_size = 16, .color = Color.text } }),
        text(count_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = iconView("chevron.right", .{ .style = .{ .color = Color.text_secondary, .font_size = 14 } });

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
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
                text("Search songs, artists...", .{ .style = .{ .color = Color.text_secondary } }),
            }),
        }),
        text("Recent Searches", .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } }),
    });
}

fn buildMiniPlayer(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    const current = app.getCurrentTrack();
    const title = if (current) |t| t.title[0..t.title_len] else "Not Playing";
    const artist = if (current) |t| t.artist[0..t.artist_len] else "";

    const play_icon: []const u8 = if (state.play_state == .playing) "pause.fill" else "play.fill";

    S.items[0] = div(.{
        .style = .{ .background = Color.card, .width = 48, .height = 48, .border_radius = 8 },
    }, &.{
        iconView("music.note", .{ .style = .{ .color = Color.text_secondary, .font_size = 20, .padding = Spacing.all(14) } }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(title, .{ .style = .{ .font_size = 14, .color = Color.text } }),
        text(artist, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });
    S.items[2] = row(.{ .style = .{ .gap = 16 } }, &.{
        iconView(play_icon, .{ .style = .{ .color = Color.text, .font_size = 24 } }),
        iconView("forward.fill", .{ .style = .{ .color = Color.text, .font_size = 20 } }),
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(12),
            .gap = 12,
        },
    }, &S.items);
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
