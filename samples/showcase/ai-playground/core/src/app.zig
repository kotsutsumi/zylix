//! AI Playground - Application State

const std = @import("std");

pub const DemoMode = enum(u32) {
    voice = 0,
    vision = 1,
    text_mode = 2,
    chat = 3,

    pub fn title(self: DemoMode) []const u8 {
        return switch (self) {
            .voice => "Voice AI",
            .vision => "Vision AI",
            .text_mode => "Text AI",
            .chat => "Chat AI",
        };
    }

    pub fn description(self: DemoMode) []const u8 {
        return switch (self) {
            .voice => "Speech recognition and synthesis",
            .vision => "Image analysis and detection",
            .text_mode => "NLP and text processing",
            .chat => "Conversational AI demo",
        };
    }

    pub fn icon(self: DemoMode) []const u8 {
        return switch (self) {
            .voice => "waveform",
            .vision => "eye",
            .text_mode => "doc.text",
            .chat => "bubble.left.and.bubble.right",
        };
    }
};

pub const RecordingState = enum(u8) {
    idle,
    recording,
    processing,
    complete,
    error_state,
};

pub const Language = enum(u8) {
    english,
    japanese,
    spanish,
    french,
    german,
    chinese,

    pub fn code(self: Language) []const u8 {
        return switch (self) {
            .english => "en",
            .japanese => "ja",
            .spanish => "es",
            .french => "fr",
            .german => "de",
            .chinese => "zh",
        };
    }

    pub fn name(self: Language) []const u8 {
        return switch (self) {
            .english => "English",
            .japanese => "Japanese",
            .spanish => "Spanish",
            .french => "French",
            .german => "German",
            .chinese => "Chinese",
        };
    }
};

pub const VisionTask = enum(u8) {
    classification,
    detection,
    face,
    ocr,
};

pub const TextTask = enum(u8) {
    summarize,
    sentiment,
    translate,
    entities,
};

pub const ChatMessage = struct {
    is_user: bool,
    content: [256]u8,
    content_len: usize,
};

pub const AppState = struct {
    initialized: bool = false,
    current_mode: DemoMode = .voice,

    // Voice state
    recording_state: RecordingState = .idle,
    source_language: Language = .english,
    target_language: Language = .japanese,
    transcription: [512]u8 = [_]u8{0} ** 512,
    transcription_len: usize = 0,
    confidence: f32 = 0,
    audio_level: f32 = 0,

    // Vision state
    vision_task: VisionTask = .classification,
    has_image: bool = false,
    detection_count: u8 = 0,
    classification_result: [64]u8 = [_]u8{0} ** 64,
    classification_len: usize = 0,
    classification_confidence: f32 = 0,

    // Text state
    text_task: TextTask = .summarize,
    input_text: [1024]u8 = [_]u8{0} ** 1024,
    input_text_len: usize = 0,
    output_text: [1024]u8 = [_]u8{0} ** 1024,
    output_text_len: usize = 0,
    processing: bool = false,

    // Chat state
    messages: [20]ChatMessage = undefined,
    message_count: usize = 0,
    current_input: [256]u8 = [_]u8{0} ** 256,
    current_input_len: usize = 0,
    is_typing: bool = false,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
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

pub fn selectMode(mode: DemoMode) void {
    app_state.current_mode = mode;
}

// Voice functions
pub fn startRecording() void {
    if (app_state.recording_state == .idle) {
        app_state.recording_state = .recording;
        app_state.audio_level = 0;
    }
}

pub fn stopRecording() void {
    if (app_state.recording_state == .recording) {
        app_state.recording_state = .processing;
    }
}

pub fn setTranscription(text: []const u8, confidence: f32) void {
    const len = @min(text.len, app_state.transcription.len);
    @memcpy(app_state.transcription[0..len], text[0..len]);
    app_state.transcription_len = len;
    app_state.confidence = confidence;
    app_state.recording_state = .complete;
}

pub fn setSourceLanguage(lang: Language) void {
    app_state.source_language = lang;
}

pub fn setTargetLanguage(lang: Language) void {
    app_state.target_language = lang;
}

pub fn updateAudioLevel(level: f32) void {
    app_state.audio_level = @max(0, @min(level, 1.0));
}

// Vision functions
pub fn setVisionTask(task: VisionTask) void {
    app_state.vision_task = task;
}

pub fn loadImage() void {
    app_state.has_image = true;
    app_state.classification_len = 0;
    app_state.detection_count = 0;
}

pub fn setClassificationResult(label: []const u8, confidence: f32) void {
    const len = @min(label.len, app_state.classification_result.len);
    @memcpy(app_state.classification_result[0..len], label[0..len]);
    app_state.classification_len = len;
    app_state.classification_confidence = confidence;
}

pub fn setDetectionCount(count: u8) void {
    app_state.detection_count = count;
}

// Text functions
pub fn setTextTask(task: TextTask) void {
    app_state.text_task = task;
}

pub fn setInputText(text: []const u8) void {
    const len = @min(text.len, app_state.input_text.len);
    @memcpy(app_state.input_text[0..len], text[0..len]);
    app_state.input_text_len = len;
}

pub fn processText() void {
    app_state.processing = true;
}

pub fn setOutputText(text: []const u8) void {
    const len = @min(text.len, app_state.output_text.len);
    @memcpy(app_state.output_text[0..len], text[0..len]);
    app_state.output_text_len = len;
    app_state.processing = false;
}

// Chat functions
pub fn sendMessage(text: []const u8) void {
    if (app_state.message_count >= app_state.messages.len) return;

    var msg = &app_state.messages[app_state.message_count];
    msg.is_user = true;
    const len = @min(text.len, msg.content.len);
    @memcpy(msg.content[0..len], text[0..len]);
    msg.content_len = len;
    app_state.message_count += 1;
    app_state.is_typing = true;
}

pub fn receiveMessage(text: []const u8) void {
    if (app_state.message_count >= app_state.messages.len) return;

    var msg = &app_state.messages[app_state.message_count];
    msg.is_user = false;
    const len = @min(text.len, msg.content.len);
    @memcpy(msg.content[0..len], text[0..len]);
    msg.content_len = len;
    app_state.message_count += 1;
    app_state.is_typing = false;
}

pub fn clearChat() void {
    app_state.message_count = 0;
    app_state.is_typing = false;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(DemoMode.voice, app_state.current_mode);
}

test "mode selection" {
    init();
    defer deinit();
    selectMode(.vision);
    try std.testing.expectEqual(DemoMode.vision, app_state.current_mode);
}

test "recording state" {
    init();
    defer deinit();
    try std.testing.expectEqual(RecordingState.idle, app_state.recording_state);
    startRecording();
    try std.testing.expectEqual(RecordingState.recording, app_state.recording_state);
    stopRecording();
    try std.testing.expectEqual(RecordingState.processing, app_state.recording_state);
}

test "demo mode metadata" {
    try std.testing.expectEqualStrings("Voice AI", DemoMode.voice.title());
    try std.testing.expectEqualStrings("waveform", DemoMode.voice.icon());
}

test "language metadata" {
    try std.testing.expectEqualStrings("en", Language.english.code());
    try std.testing.expectEqualStrings("Japanese", Language.japanese.name());
}
