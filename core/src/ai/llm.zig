//! Zylix AI - Large Language Model (LLM)
//!
//! Text generation functionality for chat, completion, and code generation.
//! Supports both synchronous and streaming generation.
//!
//! ## Usage
//!
//! ```zig
//! const llm = @import("ai/llm.zig");
//!
//! // Load model
//! var model = try llm.LLMModel.init(config, allocator);
//! defer model.deinit();
//!
//! // Generate text
//! const output = try model.generate("Hello, world!", .{});
//! defer allocator.free(output);
//!
//! // Chat format
//! const messages = [_]llm.ChatMessage{
//!     .{ .role = .system, .content = "You are a helpful assistant." },
//!     .{ .role = .user, .content = "Hello!" },
//! };
//! const response = try model.chat(&messages, .{});
//! ```

const std = @import("std");
const types = @import("types.zig");
const ModelConfig = types.ModelConfig;
const ModelFormat = types.ModelFormat;
const GenerateParams = types.GenerateParams;
const Result = types.Result;

// === Constants ===

/// Maximum prompt length
pub const MAX_PROMPT_LENGTH: usize = 32768;

/// Maximum output length
pub const MAX_OUTPUT_LENGTH: usize = 8192;

/// Maximum number of chat messages
pub const MAX_CHAT_MESSAGES: usize = 100;

/// Default context length
pub const DEFAULT_CONTEXT_LENGTH: u32 = 4096;

// === Chat Types ===

/// Chat message role
pub const ChatRole = enum(u8) {
    /// System message (instructions)
    system = 0,
    /// User message
    user = 1,
    /// Assistant response
    assistant = 2,
};

/// Chat message
pub const ChatMessage = struct {
    /// Message role
    role: ChatRole,
    /// Message content
    content: []const u8,
};

// === LLM Configuration ===

/// Configuration for LLM operations
pub const LLMConfig = struct {
    /// Model configuration
    model: ModelConfig,

    /// Context length (tokens)
    context_length: u32 = DEFAULT_CONTEXT_LENGTH,

    /// System prompt (optional)
    system_prompt: ?[]const u8 = null,

    /// Chat template format
    chat_template: ChatTemplate = .chatml,
};

/// Chat template format for different models
pub const ChatTemplate = enum(u8) {
    /// ChatML format (default)
    chatml = 0,
    /// Llama format
    llama = 1,
    /// Mistral format
    mistral = 2,
    /// Qwen format
    qwen = 3,
    /// Raw (no formatting)
    raw = 255,
};

// === Streaming Types ===

/// Callback for streaming token output
pub const StreamCallback = *const fn (token: []const u8, user_data: ?*anyopaque) void;

/// Streaming context for generation
pub const StreamContext = struct {
    callback: StreamCallback,
    user_data: ?*anyopaque,
};

// === Generation Output ===

/// Result of text generation
pub const GenerationOutput = struct {
    /// Generated text
    text: []u8,

    /// Number of tokens generated
    tokens_generated: u32,

    /// Number of prompt tokens
    prompt_tokens: u32,

    /// Generation time in milliseconds
    generation_time_ms: u64,

    /// Tokens per second
    tokens_per_second: f32,

    /// Finish reason
    finish_reason: FinishReason,
};

/// Reason for generation completion
pub const FinishReason = enum(u8) {
    /// Reached max tokens
    max_tokens = 0,
    /// Hit stop sequence
    stop = 1,
    /// End of sequence token
    eos = 2,
    /// User cancelled
    cancelled = 3,
    /// Error occurred
    @"error" = 255,
};

// === LLM Model ===

/// Large Language Model for text generation
pub const LLMModel = struct {
    config: LLMConfig,
    allocator: std.mem.Allocator,
    initialized: bool,
    context_used: u32,

    const Self = @This();

    /// Initialize LLM model
    pub fn init(config: LLMConfig, allocator: std.mem.Allocator) !Self {
        // Validate model path
        const path = config.model.getPath();
        if (path.len == 0) {
            return error.InvalidModelPath;
        }

        // Check model format
        const format = types.detectFormat(path);
        if (format == .unknown) {
            return error.UnsupportedFormat;
        }

        // Validate context length
        if (config.context_length == 0 or config.context_length > 128 * 1024) {
            return error.InvalidContextLength;
        }

        return Self{
            .config = config,
            .allocator = allocator,
            .initialized = true,
            .context_used = 0,
        };
    }

    /// Check if model is ready
    pub fn isReady(self: *const Self) bool {
        return self.initialized;
    }

    /// Get context length
    pub fn getContextLength(self: *const Self) u32 {
        return self.config.context_length;
    }

    /// Get remaining context
    pub fn getRemainingContext(self: *const Self) u32 {
        if (self.context_used >= self.config.context_length) {
            return 0;
        }
        return self.config.context_length - self.context_used;
    }

    /// Reset context (clear conversation history)
    pub fn resetContext(self: *Self) void {
        self.context_used = 0;
    }

    /// Generate text from prompt
    /// Caller owns the returned slice and must free it
    pub fn generate(self: *Self, prompt: []const u8, params: GenerateParams) ![]u8 {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (prompt.len == 0) {
            return error.EmptyPrompt;
        }

        if (prompt.len > MAX_PROMPT_LENGTH) {
            return error.PromptTooLong;
        }

        // Calculate output size
        const max_tokens = if (params.max_tokens > 0) params.max_tokens else 256;
        const output_size = @min(max_tokens * 4, MAX_OUTPUT_LENGTH); // ~4 chars per token average

        // Allocate temporary buffer for generation
        var temp_buffer: [MAX_OUTPUT_LENGTH]u8 = undefined;
        const buffer_slice = temp_buffer[0..@min(output_size, MAX_OUTPUT_LENGTH)];

        // TODO: Replace with actual LLM inference
        // For now, generate placeholder response
        const response_len = self.generatePlaceholderResponse(prompt, buffer_slice);

        // Allocate exact size for result
        const result = try self.allocator.alloc(u8, response_len);
        @memcpy(result, buffer_slice[0..response_len]);

        // Update context usage
        self.context_used += @intCast(prompt.len / 4); // Rough token estimate
        self.context_used += @intCast(response_len / 4);

        return result;
    }

    /// Generate text with streaming output
    pub fn generateStream(
        self: *Self,
        prompt: []const u8,
        params: GenerateParams,
        stream: StreamContext,
    ) !void {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (prompt.len == 0) {
            return error.EmptyPrompt;
        }

        _ = params;

        // TODO: Replace with actual streaming LLM inference
        // For now, simulate streaming with placeholder tokens
        const tokens = [_][]const u8{
            "This ",
            "is ",
            "a ",
            "streaming ",
            "response ",
            "from ",
            "the ",
            "LLM.",
        };

        for (tokens) |token| {
            stream.callback(token, stream.user_data);
        }
    }

    /// Generate response for chat messages
    /// Caller owns the returned slice and must free it
    pub fn chat(self: *Self, messages: []const ChatMessage, params: GenerateParams) ![]u8 {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (messages.len == 0) {
            return error.EmptyMessages;
        }

        if (messages.len > MAX_CHAT_MESSAGES) {
            return error.TooManyMessages;
        }

        // Format messages according to chat template
        var formatted_prompt: std.ArrayListUnmanaged(u8) = .{};
        defer formatted_prompt.deinit(self.allocator);

        try self.formatChatMessages(messages, &formatted_prompt);

        // Generate response
        return self.generate(formatted_prompt.items, params);
    }

    /// Generate response for chat messages with streaming
    pub fn chatStream(
        self: *Self,
        messages: []const ChatMessage,
        params: GenerateParams,
        stream: StreamContext,
    ) !void {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (messages.len == 0) {
            return error.EmptyMessages;
        }

        // Format messages according to chat template
        var formatted_prompt: std.ArrayListUnmanaged(u8) = .{};
        defer formatted_prompt.deinit(self.allocator);

        try self.formatChatMessages(messages, &formatted_prompt);

        // Generate streaming response
        return self.generateStream(formatted_prompt.items, params, stream);
    }

    /// Format chat messages according to template
    fn formatChatMessages(self: *const Self, messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8)) !void {
        switch (self.config.chat_template) {
            .chatml => try formatChatML(messages, output, self.allocator),
            .llama => try formatLlama(messages, output, self.allocator),
            .mistral => try formatMistral(messages, output, self.allocator),
            .qwen => try formatQwen(messages, output, self.allocator),
            .raw => try formatRaw(messages, output, self.allocator),
        }
    }

    /// Generate placeholder response (for testing before backend integration)
    /// Returns the length of the generated response
    fn generatePlaceholderResponse(self: *const Self, prompt: []const u8, output: []u8) usize {
        _ = self;

        // Generate a deterministic response based on prompt
        const base_response = "This is a placeholder response from the LLM. ";
        const prompt_snippet_len = @min(prompt.len, 20);

        var writer = std.io.fixedBufferStream(output);
        writer.writer().print("{s}Your prompt started with: \"{s}\"", .{
            base_response,
            prompt[0..prompt_snippet_len],
        }) catch {};

        return writer.pos;
    }

    /// Deinitialize model
    pub fn deinit(self: *Self) void {
        // TODO: Free backend resources when implemented
        self.initialized = false;
        self.context_used = 0;
    }
};

// === Chat Template Formatters ===

/// Format messages in ChatML format
fn formatChatML(messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    var writer = output.writer(allocator);
    for (messages) |msg| {
        const role_str = switch (msg.role) {
            .system => "system",
            .user => "user",
            .assistant => "assistant",
        };
        try writer.print("<|im_start|>{s}\n{s}<|im_end|>\n", .{ role_str, msg.content });
    }
    try output.appendSlice(allocator, "<|im_start|>assistant\n");
}

/// Format messages in Llama format
fn formatLlama(messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    var writer = output.writer(allocator);
    for (messages) |msg| {
        switch (msg.role) {
            .system => try writer.print("<<SYS>>\n{s}\n<</SYS>>\n\n", .{msg.content}),
            .user => try writer.print("[INST] {s} [/INST]", .{msg.content}),
            .assistant => try writer.print("{s}\n", .{msg.content}),
        }
    }
}

/// Format messages in Mistral format
fn formatMistral(messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    var writer = output.writer(allocator);
    for (messages) |msg| {
        switch (msg.role) {
            .system => try writer.print("[INST] {s} [/INST]", .{msg.content}),
            .user => try writer.print("[INST] {s} [/INST]", .{msg.content}),
            .assistant => try writer.print("{s}</s>", .{msg.content}),
        }
    }
}

/// Format messages in Qwen format
fn formatQwen(messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    var writer = output.writer(allocator);
    for (messages) |msg| {
        const role_str = switch (msg.role) {
            .system => "system",
            .user => "user",
            .assistant => "assistant",
        };
        try writer.print("<|{s}|>\n{s}\n", .{ role_str, msg.content });
    }
    try output.appendSlice(allocator, "<|assistant|>\n");
}

/// Format messages as raw text (no template)
fn formatRaw(messages: []const ChatMessage, output: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    for (messages) |msg| {
        try output.appendSlice(allocator, msg.content);
        try output.append(allocator, '\n');
    }
}

// === Utility Functions ===

/// Estimate token count from text (rough approximation)
pub fn estimateTokenCount(text: []const u8) u32 {
    // Rough estimate: ~4 characters per token on average
    return @intCast((text.len + 3) / 4);
}

/// Check if text likely fits in context
pub fn fitsInContext(text: []const u8, context_length: u32) bool {
    return estimateTokenCount(text) <= context_length;
}

// === Tests ===

test "LLMModel initialization" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    try std.testing.expect(model.isReady());
    try std.testing.expectEqual(@as(u32, DEFAULT_CONTEXT_LENGTH), model.getContextLength());
}

test "LLMModel generate" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    const output = try model.generate("Hello, how are you?", .{});
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}

test "LLMModel generate with params" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    const params = GenerateParams{
        .max_tokens = 100,
        .temperature = 0.8,
    };

    const output = try model.generate("Tell me a story", params);
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}

test "LLMModel chat" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    const messages = [_]ChatMessage{
        .{ .role = .system, .content = "You are a helpful assistant." },
        .{ .role = .user, .content = "Hello!" },
    };

    const output = try model.chat(&messages, .{});
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}

test "LLMModel context management" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
        .context_length = 1024,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    // Initial context should be empty
    try std.testing.expectEqual(@as(u32, 1024), model.getRemainingContext());

    // Generate some text
    const output = try model.generate("Hello", .{});
    allocator.free(output);

    // Context should be partially used
    try std.testing.expect(model.context_used > 0);
    try std.testing.expect(model.getRemainingContext() < 1024);

    // Reset context
    model.resetContext();
    try std.testing.expectEqual(@as(u32, 0), model.context_used);
    try std.testing.expectEqual(@as(u32, 1024), model.getRemainingContext());
}

test "LLMModel empty prompt error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    const result = model.generate("", .{});
    try std.testing.expectError(error.EmptyPrompt, result);
}

test "LLMModel empty messages error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    const empty: []const ChatMessage = &.{};
    const result = model.chat(empty, .{});
    try std.testing.expectError(error.EmptyMessages, result);
}

test "LLMModel invalid path error" {
    const allocator = std.testing.allocator;

    var model_config = ModelConfig{};
    model_config.model_type = .llm;

    const config = LLMConfig{
        .model = model_config,
    };

    const result = LLMModel.init(config, allocator);
    try std.testing.expectError(error.InvalidModelPath, result);
}

test "LLMModel unsupported format error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.unknown");

    const config = LLMConfig{
        .model = model_config,
    };

    const result = LLMModel.init(config, allocator);
    try std.testing.expectError(error.UnsupportedFormat, result);
}

test "LLMModel invalid context length error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
        .context_length = 0,
    };

    const result = LLMModel.init(config, allocator);
    try std.testing.expectError(error.InvalidContextLength, result);
}

test "formatChatML" {
    const allocator = std.testing.allocator;

    var output: std.ArrayListUnmanaged(u8) = .{};
    defer output.deinit(allocator);

    const messages = [_]ChatMessage{
        .{ .role = .system, .content = "You are helpful." },
        .{ .role = .user, .content = "Hi" },
    };

    try formatChatML(&messages, &output, allocator);

    try std.testing.expect(std.mem.indexOf(u8, output.items, "<|im_start|>system") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "<|im_start|>user") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "<|im_start|>assistant") != null);
}

test "estimateTokenCount" {
    try std.testing.expectEqual(@as(u32, 3), estimateTokenCount("Hello world!"));
    try std.testing.expectEqual(@as(u32, 0), estimateTokenCount(""));
    try std.testing.expectEqual(@as(u32, 1), estimateTokenCount("Hi"));
}

test "fitsInContext" {
    try std.testing.expect(fitsInContext("Hello", 100));
    try std.testing.expect(!fitsInContext("This is a very long text that should not fit in a tiny context", 5));
}

test "LLMModel generateStream" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forLLM("/path/to/model.gguf");

    const config = LLMConfig{
        .model = model_config,
    };

    var model = try LLMModel.init(config, allocator);
    defer model.deinit();

    var tokens_received: u32 = 0;
    const callback = struct {
        fn cb(_: []const u8, user_data: ?*anyopaque) void {
            const count: *u32 = @ptrCast(@alignCast(user_data.?));
            count.* += 1;
        }
    }.cb;

    try model.generateStream("Hello", .{}, .{
        .callback = callback,
        .user_data = &tokens_received,
    });

    try std.testing.expect(tokens_received > 0);
}
