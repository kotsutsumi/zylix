//! AI Playground Showcase
//!
//! Demonstration of Zylix AI/ML integration capabilities.

const std = @import("std");
const app = @import("app.zig");
const playground = @import("playground.zig");

pub const AppState = app.AppState;
pub const DemoMode = app.DemoMode;
pub const RecordingState = app.RecordingState;
pub const Language = app.Language;
pub const VisionTask = app.VisionTask;
pub const TextTask = app.TextTask;
pub const VNode = playground.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn render() VNode {
    return playground.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_select_mode(mode: u32) void {
    const max_mode = @typeInfo(DemoMode).@"enum".fields.len;
    if (mode >= max_mode) return;
    app.selectMode(@enumFromInt(mode));
}

// Voice exports
export fn app_start_recording() void {
    app.startRecording();
}

export fn app_stop_recording() void {
    app.stopRecording();
}

export fn app_set_source_language(lang: u8) void {
    const max_lang = @typeInfo(Language).@"enum".fields.len;
    if (lang >= max_lang) return;
    app.setSourceLanguage(@enumFromInt(lang));
}

export fn app_set_target_language(lang: u8) void {
    const max_lang = @typeInfo(Language).@"enum".fields.len;
    if (lang >= max_lang) return;
    app.setTargetLanguage(@enumFromInt(lang));
}

export fn app_update_audio_level(level: f32) void {
    app.updateAudioLevel(level);
}

export fn app_get_recording_state() u8 {
    return @intFromEnum(getState().recording_state);
}

// Vision exports
export fn app_set_vision_task(task: u8) void {
    const max_task = @typeInfo(VisionTask).@"enum".fields.len;
    if (task >= max_task) return;
    app.setVisionTask(@enumFromInt(task));
}

export fn app_load_image() void {
    app.loadImage();
}

export fn app_has_image() i32 {
    return if (getState().has_image) 1 else 0;
}

// Text exports
export fn app_set_text_task(task: u8) void {
    const max_task = @typeInfo(TextTask).@"enum".fields.len;
    if (task >= max_task) return;
    app.setTextTask(@enumFromInt(task));
}

export fn app_process_text() void {
    app.processText();
}

export fn app_is_processing() i32 {
    return if (getState().processing) 1 else 0;
}

// Chat exports
export fn app_clear_chat() void {
    app.clearChat();
}

export fn app_get_message_count() u32 {
    return @intCast(getState().message_count);
}

export fn app_is_typing() i32 {
    return if (getState().is_typing) 1 else 0;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(DemoMode.voice, getState().current_mode);
}

test "mode selection" {
    init();
    defer deinit();
    app.selectMode(.vision);
    try std.testing.expectEqual(DemoMode.vision, getState().current_mode);
}

test "recording workflow" {
    init();
    defer deinit();
    try std.testing.expectEqual(RecordingState.idle, getState().recording_state);
    app.startRecording();
    try std.testing.expectEqual(RecordingState.recording, getState().recording_state);
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(playground.Tag.column, view.tag);
}
