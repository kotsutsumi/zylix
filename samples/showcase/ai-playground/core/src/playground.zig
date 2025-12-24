//! AI Playground - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, progress, spacer };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
    value: f32 = 0,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    gap: ?u32 = null,
};

pub const Size = union(enum) { px: u32, percent: f32, fill, wrap };
pub const Spacing = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
    pub fn all(v: u32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
    pub fn horizontal(v: u32) Spacing {
        return .{ .left = v, .right = v };
    }
};
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 124, .g = 58, .b = 237 };
    pub const secondary = Color{ .r = 16, .g = 185, .b = 129 };
    pub const accent = Color{ .r = 245, .g = 158, .b = 11 };
    pub const dark = Color{ .r = 30, .g = 30, .b = 40 };
    pub const darker = Color{ .r = 20, .g = 20, .b = 28 };
    pub const gray = Color{ .r = 128, .g = 128, .b = 128 };
    pub const light = Color{ .r = 200, .g = 200, .b = 200 };
    pub const user_bubble = Color{ .r = 59, .g = 130, .b = 246 };
    pub const ai_bubble = Color{ .r = 55, .g = 65, .b = 81 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .height = .fill, .background = Color.darker } }, &.{
        buildHeader(state),
        row(.{ .style = .{ .height = .fill } }, &.{
            buildModeSelector(state),
            buildMainContent(state),
        }),
    });
}

fn buildHeader(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 56 },
            .padding = Spacing.horizontal(20),
            .background = Color.dark,
            .alignment = .center,
            .justify = .space_between,
        },
    }, &.{
        row(.{ .style = .{ .gap = 12, .alignment = .center } }, &.{
            icon("brain", .{ .style = .{ .color = Color.primary } }),
            text("AI Playground", .{ .style = .{ .font_size = 20, .font_weight = .bold, .color = Color.white } }),
        }),
        row(.{ .style = .{ .gap = 8, .alignment = .center } }, &.{
            icon(state.current_mode.icon(), .{ .style = .{ .color = Color.accent } }),
            text(state.current_mode.title(), .{ .style = .{ .font_size = 14, .color = Color.light } }),
        }),
    });
}

fn buildModeSelector(state: *const app.AppState) VNode {
    const modes = [_]app.DemoMode{ .voice, .vision, .text_mode, .chat };
    const S = struct {
        var items: [4]VNode = undefined;
    };
    for (modes, 0..) |mode, i| {
        S.items[i] = buildModeItem(mode, state.current_mode == mode);
    }
    return column(.{
        .style = .{
            .width = .{ .px = 180 },
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .gap = 8,
        },
    }, &.{
        text("AI Modes", .{ .style = .{ .font_size = 11, .font_weight = .bold, .color = Color.gray } }),
        column(.{ .style = .{ .gap = 6 } }, &S.items),
    });
}

fn buildModeItem(mode: app.DemoMode, active: bool) VNode {
    return row(.{
        .id = @tagName(mode),
        .active = active,
        .style = .{
            .padding = Spacing.all(12),
            .background = if (active) Color.primary else Color.dark,
            .border_radius = 8,
            .gap = 10,
            .alignment = .center,
        },
    }, &.{
        icon(mode.icon(), .{ .style = .{ .color = if (active) Color.white else Color.gray } }),
        column(.{ .style = .{ .gap = 2 } }, &.{
            text(mode.title(), .{ .style = .{ .font_size = 13, .font_weight = .bold, .color = if (active) Color.white else Color.light } }),
            text(mode.description(), .{ .style = .{ .font_size = 10, .color = if (active) Color.light else Color.gray } }),
        }),
    });
}

fn buildMainContent(state: *const app.AppState) VNode {
    return switch (state.current_mode) {
        .voice => buildVoicePanel(state),
        .vision => buildVisionPanel(state),
        .text_mode => buildTextPanel(state),
        .chat => buildChatPanel(state),
    };
}

fn buildVoicePanel(state: *const app.AppState) VNode {
    const record_icon = switch (state.recording_state) {
        .idle => "mic",
        .recording => "stop.fill",
        .processing => "waveform",
        .complete => "checkmark.circle",
        .error_state => "exclamationmark.circle",
    };
    const record_color = switch (state.recording_state) {
        .idle => Color.primary,
        .recording => Color.accent,
        .processing => Color.secondary,
        .complete => Color.secondary,
        .error_state => Color.accent,
    };

    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(24),
            .gap = 24,
            .alignment = .center,
        },
    }, &.{
        text("Speech Recognition", .{ .style = .{ .font_size = 18, .font_weight = .bold, .color = Color.white } }),
        buildLanguageSelector(state),
        button(record_icon, .{
            .id = "record",
            .style = .{
                .width = .{ .px = 80 },
                .height = .{ .px = 80 },
                .background = record_color,
                .border_radius = 40,
            },
        }),
        buildAudioLevel(state),
        buildTranscriptionBox(state),
    });
}

fn buildLanguageSelector(state: *const app.AppState) VNode {
    return row(.{ .style = .{ .gap = 16, .alignment = .center } }, &.{
        column(.{ .style = .{ .gap = 4 } }, &.{
            text("From", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
            text(state.source_language.name(), .{ .style = .{ .font_size = 14, .color = Color.white } }),
        }),
        icon("arrow.right", .{ .style = .{ .color = Color.gray } }),
        column(.{ .style = .{ .gap = 4 } }, &.{
            text("To", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
            text(state.target_language.name(), .{ .style = .{ .font_size = 14, .color = Color.white } }),
        }),
    });
}

fn buildAudioLevel(state: *const app.AppState) VNode {
    if (state.recording_state != .recording) {
        return spacer(0);
    }
    return progress(.{ .value = state.audio_level, .style = .{ .width = .{ .px = 200 }, .height = .{ .px = 8 }, .background = Color.dark, .border_radius = 4 } });
}

fn buildTranscriptionBox(state: *const app.AppState) VNode {
    if (state.transcription_len == 0) {
        return text("Transcription will appear here...", .{ .style = .{ .font_size = 14, .color = Color.gray } });
    }
    const S = struct {
        var conf_text: [16]u8 = undefined;
    };
    const conf_str = std.fmt.bufPrint(&S.conf_text, "{d:.0}%", .{state.confidence * 100}) catch "0%";
    return column(.{
        .style = .{
            .width = .{ .px = 400 },
            .padding = Spacing.all(16),
            .background = Color.dark,
            .border_radius = 8,
            .gap = 8,
        },
    }, &.{
        text(state.transcription[0..state.transcription_len], .{ .style = .{ .font_size = 16, .color = Color.white } }),
        row(.{ .style = .{ .justify = .space_between } }, &.{
            text("Confidence", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
            text(conf_str, .{ .style = .{ .font_size = 11, .color = Color.secondary } }),
        }),
    });
}

fn buildVisionPanel(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(24),
            .gap = 20,
        },
    }, &.{
        text("Vision AI", .{ .style = .{ .font_size = 18, .font_weight = .bold, .color = Color.white } }),
        buildVisionTasks(state),
        buildImageArea(state),
        buildVisionResults(state),
    });
}

fn buildVisionTasks(state: *const app.AppState) VNode {
    const tasks = [_]app.VisionTask{ .classification, .detection, .face, .ocr };
    const labels = [_][]const u8{ "Classify", "Detect", "Face", "OCR" };
    const S = struct {
        var buttons: [4]VNode = undefined;
    };
    for (tasks, 0..) |task, i| {
        S.buttons[i] = button(labels[i], .{
            .id = @tagName(task),
            .active = state.vision_task == task,
            .style = .{ .padding = Spacing.all(10), .background = if (state.vision_task == task) Color.primary else Color.dark, .border_radius = 6 },
        });
    }
    return row(.{ .style = .{ .gap = 8 } }, &S.buttons);
}

fn buildImageArea(state: *const app.AppState) VNode {
    if (!state.has_image) {
        return column(.{
            .style = .{
                .width = .{ .px = 320 },
                .height = .{ .px = 240 },
                .background = Color.dark,
                .border_radius = 8,
                .alignment = .center,
                .justify = .center,
                .gap = 12,
            },
        }, &.{
            icon("photo", .{ .style = .{ .color = Color.gray } }),
            text("Drop image or click to upload", .{ .style = .{ .font_size = 12, .color = Color.gray } }),
        });
    }
    return div(.{
        .style = .{
            .width = .{ .px = 320 },
            .height = .{ .px = 240 },
            .background = Color.dark,
            .border_radius = 8,
        },
    }, &.{
        text("Image loaded", .{ .style = .{ .color = Color.secondary } }),
    });
}

fn buildVisionResults(state: *const app.AppState) VNode {
    if (state.classification_len == 0 and state.detection_count == 0) {
        return spacer(0);
    }
    if (state.classification_len > 0) {
        const S = struct {
            var conf_text: [16]u8 = undefined;
        };
        const conf_str = std.fmt.bufPrint(&S.conf_text, "{d:.0}%", .{state.classification_confidence * 100}) catch "0%";
        return row(.{ .style = .{ .gap = 16 } }, &.{
            text(state.classification_result[0..state.classification_len], .{ .style = .{ .font_size = 16, .font_weight = .bold, .color = Color.white } }),
            text(conf_str, .{ .style = .{ .font_size = 14, .color = Color.secondary } }),
        });
    }
    const S2 = struct {
        var count_text: [16]u8 = undefined;
    };
    const count_str = std.fmt.bufPrint(&S2.count_text, "{d} objects", .{state.detection_count}) catch "0 objects";
    return text(count_str, .{ .style = .{ .font_size = 16, .color = Color.white } });
}

fn buildTextPanel(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(24),
            .gap = 20,
        },
    }, &.{
        text("Text AI", .{ .style = .{ .font_size = 18, .font_weight = .bold, .color = Color.white } }),
        buildTextTasks(state),
        row(.{ .style = .{ .gap = 16, .height = .fill } }, &.{
            buildTextInput(state),
            buildTextOutput(state),
        }),
    });
}

fn buildTextTasks(state: *const app.AppState) VNode {
    const tasks = [_]app.TextTask{ .summarize, .sentiment, .translate, .entities };
    const labels = [_][]const u8{ "Summarize", "Sentiment", "Translate", "Entities" };
    const S = struct {
        var buttons: [4]VNode = undefined;
    };
    for (tasks, 0..) |task, i| {
        S.buttons[i] = button(labels[i], .{
            .id = @tagName(task),
            .active = state.text_task == task,
            .style = .{ .padding = Spacing.all(10), .background = if (state.text_task == task) Color.primary else Color.dark, .border_radius = 6 },
        });
    }
    return row(.{ .style = .{ .gap = 8 } }, &S.buttons);
}

fn buildTextInput(state: *const app.AppState) VNode {
    _ = state;
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .border_radius = 8,
            .gap = 8,
        },
    }, &.{
        text("Input", .{ .style = .{ .font_size = 11, .font_weight = .bold, .color = Color.gray } }),
        text("Enter text to process...", .{ .style = .{ .font_size = 14, .color = Color.light } }),
    });
}

fn buildTextOutput(state: *const app.AppState) VNode {
    const output = if (state.output_text_len > 0) state.output_text[0..state.output_text_len] else "Output will appear here...";
    const output_color = if (state.output_text_len > 0) Color.white else Color.gray;
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .border_radius = 8,
            .gap = 8,
        },
    }, &.{
        text("Output", .{ .style = .{ .font_size = 11, .font_weight = .bold, .color = Color.gray } }),
        text(output, .{ .style = .{ .font_size = 14, .color = output_color } }),
    });
}

fn buildChatPanel(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(24),
            .gap = 16,
        },
    }, &.{
        text("Chat AI", .{ .style = .{ .font_size = 18, .font_weight = .bold, .color = Color.white } }),
        buildChatMessages(state),
        buildChatInput(state),
    });
}

fn buildChatMessages(state: *const app.AppState) VNode {
    if (state.message_count == 0) {
        return column(.{
            .style = .{
                .width = .fill,
                .height = .fill,
                .background = Color.dark,
                .border_radius = 8,
                .alignment = .center,
                .justify = .center,
            },
        }, &.{
            icon("bubble.left.and.bubble.right", .{ .style = .{ .color = Color.gray } }),
            text("Start a conversation...", .{ .style = .{ .font_size = 14, .color = Color.gray } }),
        });
    }

    const S = struct {
        var msgs: [20]VNode = undefined;
    };
    for (0..state.message_count) |i| {
        S.msgs[i] = buildChatMessage(&state.messages[i]);
    }
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .border_radius = 8,
            .gap = 8,
        },
    }, S.msgs[0..state.message_count]);
}

fn buildChatMessage(msg: *const app.ChatMessage) VNode {
    const bg = if (msg.is_user) Color.user_bubble else Color.ai_bubble;
    const msg_align: Alignment = if (msg.is_user) .end else .start;
    return row(.{ .style = .{ .justify = if (msg.is_user) .end else .start } }, &.{
        div(.{
            .style = .{
                .padding = Spacing.all(10),
                .background = bg,
                .border_radius = 12,
                .alignment = msg_align,
            },
        }, &.{
            text(msg.content[0..msg.content_len], .{ .style = .{ .font_size = 14, .color = Color.white } }),
        }),
    });
}

fn buildChatInput(state: *const app.AppState) VNode {
    _ = state;
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = Color.dark,
            .border_radius = 8,
            .gap = 12,
            .alignment = .center,
        },
    }, &.{
        text("Type a message...", .{ .style = .{ .font_size = 14, .color = Color.gray } }),
        button("send", .{ .id = "send", .style = .{ .padding = Spacing.all(10), .background = Color.primary, .border_radius = 20 } }),
    });
}

// Element constructors
pub fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

pub fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

pub fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

pub fn text(content: []const u8, props: Props) VNode {
    return .{ .tag = .text, .props = props, .text = content };
}

pub fn button(label: []const u8, props: Props) VNode {
    return .{ .tag = .button, .props = props, .text = label };
}

pub fn icon(name: []const u8, props: Props) VNode {
    return .{ .tag = .icon, .props = props, .text = name };
}

pub fn progress(props: Props) VNode {
    return .{ .tag = .progress, .props = props };
}

pub fn spacer(size: u32) VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .width = .{ .px = size } } } };
}

// Tests
test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "mode panel builds" {
    var state = app.AppState{ .initialized = true };
    state.current_mode = .chat;
    const content = buildMainContent(&state);
    try std.testing.expectEqual(Tag.column, content.tag);
}
