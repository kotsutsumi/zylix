//! LLM Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");
const types = @import("types.zig");

pub const MAX_PROMPT_LENGTH: usize = 32768;
pub const MAX_OUTPUT_LENGTH: usize = 8192;
pub const MAX_CHAT_MESSAGES: usize = 100;
pub const DEFAULT_CONTEXT_LENGTH: u32 = 4096;

pub const ChatRole = enum(u8) {
    system = 0,
    user = 1,
    assistant = 2,
};

pub const ChatMessage = struct {
    role: ChatRole,
    content: []const u8,
};

pub const ChatTemplate = enum(u8) {
    chatml = 0,
    llama = 1,
    mistral = 2,
    qwen = 3,
    raw = 255,
};

pub const LLMConfig = struct {
    model: types.ModelConfig = .{},
    context_length: u32 = DEFAULT_CONTEXT_LENGTH,
    system_prompt: ?[]const u8 = null,
    chat_template: ChatTemplate = .chatml,
};

/// Stub LLM model - always fails on unsupported platforms
pub const LLMModel = struct {
    allocator: std.mem.Allocator,

    pub fn init(_: LLMConfig, _: std.mem.Allocator) !*LLMModel {
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *LLMModel) void {}
};
