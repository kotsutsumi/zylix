//! Zylix LLM Integration Module
//!
//! Provider-agnostic LLM integration hooks.
//! Zig handles: message management, context, token estimation, state
//! Platform handles: HTTP requests, streaming, API authentication
//!
//! Supported patterns:
//! - Single request/response
//! - Streaming responses (via event queue)
//! - Conversation context management
//! - Tool/function calling
//!
//! Design Philosophy:
//! - No network I/O in Zig (platform handles HTTP)
//! - Zig prepares request payloads, parses responses
//! - Platform-agnostic data structures

const std = @import("std");

// === Constants ===

/// Maximum messages in a conversation
pub const MAX_MESSAGES: usize = 128;

/// Maximum content length per message (64KB)
pub const MAX_CONTENT_LEN: usize = 65536;

/// Maximum tool definitions
pub const MAX_TOOLS: usize = 32;

/// Maximum streaming chunks in queue
pub const MAX_STREAM_CHUNKS: usize = 256;

/// Token estimation: ~4 chars per token (rough approximation)
pub const CHARS_PER_TOKEN: usize = 4;

// === Enums ===

/// Message role
pub const Role = enum(u8) {
    system = 0,
    user = 1,
    assistant = 2,
    tool = 3,
};

/// Request status
pub const RequestStatus = enum(u8) {
    idle = 0,
    pending = 1,
    streaming = 2,
    completed = 3,
    failed = 4,
    cancelled = 5,
};

/// Finish reason
pub const FinishReason = enum(u8) {
    none = 0,
    stop = 1,
    length = 2,
    tool_calls = 3,
    content_filter = 4,
    failed = 5,
};

/// Provider hint (for token counting differences)
pub const Provider = enum(u8) {
    generic = 0,
    openai = 1,
    anthropic = 2,
    local = 3,
};

// === Data Structures ===

/// Message in a conversation
pub const Message = extern struct {
    /// Message role
    role: Role = .user,

    /// Content buffer (null-terminated)
    content: [MAX_CONTENT_LEN]u8 = [_]u8{0} ** MAX_CONTENT_LEN,

    /// Actual content length
    content_len: u32 = 0,

    /// Tool call ID (if role == tool)
    tool_call_id: [64]u8 = [_]u8{0} ** 64,

    /// Tool name (if role == tool)
    tool_name: [64]u8 = [_]u8{0} ** 64,

    /// Estimated token count
    token_count: u32 = 0,

    /// Timestamp (Unix ms)
    timestamp: u64 = 0,

    /// Is this message active?
    active: bool = false,

    _pad: [3]u8 = .{ 0, 0, 0 },

    pub fn setContent(self: *Message, content: []const u8) void {
        const len = @min(content.len, MAX_CONTENT_LEN - 1);
        @memcpy(self.content[0..len], content[0..len]);
        self.content[len] = 0;
        self.content_len = @intCast(len);
        self.token_count = estimateTokens(content);
    }

    pub fn getContent(self: *const Message) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn clear(self: *Message) void {
        self.* = Message{};
    }
};

/// Tool definition for function calling
pub const ToolDef = extern struct {
    /// Tool name
    name: [64]u8 = [_]u8{0} ** 64,

    /// Tool description
    description: [256]u8 = [_]u8{0} ** 256,

    /// JSON schema for parameters (simplified)
    parameters_schema: [1024]u8 = [_]u8{0} ** 1024,

    /// Is this tool active?
    active: bool = false,

    _pad: [7]u8 = .{ 0, 0, 0, 0, 0, 0, 0 },

    pub fn setName(self: *ToolDef, name: []const u8) void {
        const len = @min(name.len, 63);
        @memcpy(self.name[0..len], name[0..len]);
        self.name[len] = 0;
    }

    pub fn setDescription(self: *ToolDef, desc: []const u8) void {
        const len = @min(desc.len, 255);
        @memcpy(self.description[0..len], desc[0..len]);
        self.description[len] = 0;
    }
};

/// Tool call from assistant
pub const ToolCall = extern struct {
    /// Call ID
    id: [64]u8 = [_]u8{0} ** 64,

    /// Tool name
    name: [64]u8 = [_]u8{0} ** 64,

    /// Arguments (JSON string)
    arguments: [2048]u8 = [_]u8{0} ** 2048,

    /// Arguments length
    arguments_len: u32 = 0,

    _pad: [4]u8 = .{ 0, 0, 0, 0 },
};

/// Streaming chunk
pub const StreamChunk = extern struct {
    /// Chunk content
    content: [512]u8 = [_]u8{0} ** 512,

    /// Content length
    content_len: u32 = 0,

    /// Chunk index
    index: u32 = 0,

    /// Is this the final chunk?
    is_final: bool = false,

    /// Finish reason (if final)
    finish_reason: FinishReason = .none,

    _pad: [2]u8 = .{ 0, 0 },
};

/// Request configuration
pub const RequestConfig = extern struct {
    /// Model name
    model: [64]u8 = [_]u8{0} ** 64,

    /// Temperature (0.0 - 2.0)
    temperature: f32 = 1.0,

    /// Top P (0.0 - 1.0)
    top_p: f32 = 1.0,

    /// Max tokens to generate
    max_tokens: u32 = 4096,

    /// Enable streaming
    stream: bool = false,

    /// Provider hint
    provider: Provider = .generic,

    _pad: [2]u8 = .{ 0, 0 },

    pub fn setModel(self: *RequestConfig, model: []const u8) void {
        const len = @min(model.len, 63);
        @memcpy(self.model[0..len], model[0..len]);
        self.model[len] = 0;
    }
};

/// Response metadata
pub const ResponseMeta = extern struct {
    /// Request ID
    request_id: [64]u8 = [_]u8{0} ** 64,

    /// Model used
    model: [64]u8 = [_]u8{0} ** 64,

    /// Prompt tokens
    prompt_tokens: u32 = 0,

    /// Completion tokens
    completion_tokens: u32 = 0,

    /// Total tokens
    total_tokens: u32 = 0,

    /// Finish reason
    finish_reason: FinishReason = .none,

    /// Latency in milliseconds
    latency_ms: u32 = 0,

    _pad: [3]u8 = .{ 0, 0, 0 },
};

/// LLM session statistics
pub const LLMStats = extern struct {
    /// Total requests made
    total_requests: u32 = 0,

    /// Successful requests
    successful_requests: u32 = 0,

    /// Failed requests
    failed_requests: u32 = 0,

    /// Total prompt tokens
    total_prompt_tokens: u64 = 0,

    /// Total completion tokens
    total_completion_tokens: u64 = 0,

    /// Current conversation message count
    message_count: u32 = 0,

    /// Estimated context tokens
    context_tokens: u32 = 0,

    /// Current request status
    status: RequestStatus = .idle,

    _pad: [3]u8 = .{ 0, 0, 0 },
};

// === Global State ===

var messages: [MAX_MESSAGES]Message = undefined;
var tools: [MAX_TOOLS]ToolDef = undefined;
var stream_chunks: [MAX_STREAM_CHUNKS]StreamChunk = undefined;
var config: RequestConfig = .{};
var response_meta: ResponseMeta = .{};
var stats: LLMStats = .{};

var message_count: usize = 0;
var tool_count: usize = 0;
var stream_write_idx: usize = 0;
var stream_read_idx: usize = 0;

var system_prompt: [MAX_CONTENT_LEN]u8 = [_]u8{0} ** MAX_CONTENT_LEN;
var system_prompt_len: usize = 0;

var last_error: [256]u8 = [_]u8{0} ** 256;
var last_error_len: usize = 0;

var initialized: bool = false;

// === Initialization ===

/// Initialize LLM module
pub fn init() void {
    for (&messages) |*msg| {
        msg.clear();
    }
    for (&tools) |*tool| {
        tool.* = ToolDef{};
    }
    for (&stream_chunks) |*chunk| {
        chunk.* = StreamChunk{};
    }

    config = .{};
    response_meta = .{};
    stats = .{};
    message_count = 0;
    tool_count = 0;
    stream_write_idx = 0;
    stream_read_idx = 0;
    system_prompt_len = 0;
    last_error_len = 0;
    initialized = true;
}

/// Deinitialize LLM module
pub fn deinit() void {
    initialized = false;
}

/// Clear conversation (keep system prompt and config)
pub fn clearConversation() void {
    for (&messages) |*msg| {
        msg.clear();
    }
    message_count = 0;
    stats.message_count = 0;
    updateContextTokens();
}

/// Reset everything including config
pub fn reset() void {
    if (initialized) {
        init();
    }
}

// === System Prompt ===

/// Set system prompt
pub fn setSystemPrompt(prompt: []const u8) void {
    const len = @min(prompt.len, MAX_CONTENT_LEN - 1);
    @memcpy(system_prompt[0..len], prompt[0..len]);
    system_prompt[len] = 0;
    system_prompt_len = len;
    updateContextTokens();
}

/// Get system prompt
pub fn getSystemPrompt() []const u8 {
    return system_prompt[0..system_prompt_len];
}

// === Message Management ===

/// Add a message to conversation
pub fn addMessage(role: Role, content: []const u8) bool {
    if (message_count >= MAX_MESSAGES) return false;

    var msg = &messages[message_count];
    msg.role = role;
    msg.setContent(content);
    msg.timestamp = getTimestamp();
    msg.active = true;

    message_count += 1;
    stats.message_count = @intCast(message_count);
    updateContextTokens();

    return true;
}

/// Add user message (convenience)
pub fn addUserMessage(content: []const u8) bool {
    return addMessage(.user, content);
}

/// Add assistant message (convenience)
pub fn addAssistantMessage(content: []const u8) bool {
    return addMessage(.assistant, content);
}

/// Add tool result message
pub fn addToolResult(tool_call_id: []const u8, tool_name: []const u8, result: []const u8) bool {
    if (message_count >= MAX_MESSAGES) return false;

    var msg = &messages[message_count];
    msg.role = .tool;
    msg.setContent(result);

    const id_len = @min(tool_call_id.len, 63);
    @memcpy(msg.tool_call_id[0..id_len], tool_call_id[0..id_len]);

    const name_len = @min(tool_name.len, 63);
    @memcpy(msg.tool_name[0..name_len], tool_name[0..name_len]);

    msg.timestamp = getTimestamp();
    msg.active = true;

    message_count += 1;
    stats.message_count = @intCast(message_count);
    updateContextTokens();

    return true;
}

/// Get message by index
pub fn getMessage(index: usize) ?*const Message {
    if (index >= message_count) return null;
    return &messages[index];
}

/// Get message count
pub fn getMessageCount() u32 {
    return @intCast(message_count);
}

/// Get messages buffer pointer
pub fn getMessagesBuffer() *const [MAX_MESSAGES]Message {
    return &messages;
}

/// Get message buffer size
pub fn getMessageBufferSize() usize {
    return message_count * @sizeOf(Message);
}

// === Tool Management ===

/// Register a tool
pub fn registerTool(name: []const u8, description: []const u8, params_schema: []const u8) bool {
    if (tool_count >= MAX_TOOLS) return false;

    var tool = &tools[tool_count];
    tool.setName(name);
    tool.setDescription(description);

    const schema_len = @min(params_schema.len, 1023);
    @memcpy(tool.parameters_schema[0..schema_len], params_schema[0..schema_len]);

    tool.active = true;
    tool_count += 1;

    return true;
}

/// Get tool count
pub fn getToolCount() u32 {
    return @intCast(tool_count);
}

/// Get tools buffer
pub fn getToolsBuffer() *const [MAX_TOOLS]ToolDef {
    return &tools;
}

// === Configuration ===

/// Set model
pub fn setModel(model: []const u8) void {
    config.setModel(model);
}

/// Set temperature
pub fn setTemperature(temp: f32) void {
    config.temperature = std.math.clamp(temp, 0.0, 2.0);
}

/// Set max tokens
pub fn setMaxTokens(max: u32) void {
    config.max_tokens = max;
}

/// Enable/disable streaming
pub fn setStreaming(enabled: bool) void {
    config.stream = enabled;
}

/// Set provider hint
pub fn setProvider(provider: Provider) void {
    config.provider = provider;
}

/// Get config
pub fn getConfig() *const RequestConfig {
    return &config;
}

/// Get config size
pub fn getConfigSize() usize {
    return @sizeOf(RequestConfig);
}

// === Request/Response ===

/// Mark request as pending (called before platform sends request)
pub fn beginRequest() void {
    stats.status = .pending;
    stats.total_requests += 1;
    stream_write_idx = 0;
    stream_read_idx = 0;
}

/// Mark request as streaming
pub fn beginStreaming() void {
    stats.status = .streaming;
}

/// Push a streaming chunk
pub fn pushStreamChunk(content: []const u8, index: u32, is_final: bool, reason: FinishReason) void {
    if (stream_write_idx >= MAX_STREAM_CHUNKS) return;

    var chunk = &stream_chunks[stream_write_idx];
    const len = @min(content.len, 511);
    @memcpy(chunk.content[0..len], content[0..len]);
    chunk.content[len] = 0;
    chunk.content_len = @intCast(len);
    chunk.index = index;
    chunk.is_final = is_final;
    chunk.finish_reason = reason;

    stream_write_idx = (stream_write_idx + 1) % MAX_STREAM_CHUNKS;
}

/// Pop a streaming chunk
pub fn popStreamChunk() ?StreamChunk {
    if (stream_read_idx == stream_write_idx) return null;

    const chunk = stream_chunks[stream_read_idx];
    stream_read_idx = (stream_read_idx + 1) % MAX_STREAM_CHUNKS;
    return chunk;
}

/// Get stream chunk count
pub fn getStreamChunkCount() u32 {
    if (stream_write_idx >= stream_read_idx) {
        return @intCast(stream_write_idx - stream_read_idx);
    }
    return @intCast(MAX_STREAM_CHUNKS - stream_read_idx + stream_write_idx);
}

/// Complete request with response
pub fn completeRequest(content: []const u8, prompt_tokens: u32, completion_tokens: u32, reason: FinishReason) void {
    // Add assistant message
    _ = addAssistantMessage(content);

    // Update response metadata
    response_meta.prompt_tokens = prompt_tokens;
    response_meta.completion_tokens = completion_tokens;
    response_meta.total_tokens = prompt_tokens + completion_tokens;
    response_meta.finish_reason = reason;

    // Update stats
    stats.status = .completed;
    stats.successful_requests += 1;
    stats.total_prompt_tokens += prompt_tokens;
    stats.total_completion_tokens += completion_tokens;
}

/// Mark request as failed
pub fn failRequest(error_msg: []const u8) void {
    stats.status = .failed;
    stats.failed_requests += 1;
    setLastError(error_msg);
}

/// Cancel current request
pub fn cancelRequest() void {
    stats.status = .cancelled;
}

/// Get response metadata
pub fn getResponseMeta() *const ResponseMeta {
    return &response_meta;
}

/// Get stats
pub fn getStats() *const LLMStats {
    return &stats;
}

/// Get stats size
pub fn getStatsSize() usize {
    return @sizeOf(LLMStats);
}

// === Token Estimation ===

/// Estimate tokens for text
pub fn estimateTokens(text: []const u8) u32 {
    // Simple approximation: ~4 characters per token
    // This is a rough estimate; actual tokenization varies by model
    return @intCast((text.len + CHARS_PER_TOKEN - 1) / CHARS_PER_TOKEN);
}

/// Update context token count
fn updateContextTokens() void {
    var total: u32 = 0;

    // System prompt
    if (system_prompt_len > 0) {
        total += estimateTokens(system_prompt[0..system_prompt_len]);
    }

    // Messages
    for (0..message_count) |i| {
        total += messages[i].token_count;
        total += 4; // Role/formatting overhead
    }

    stats.context_tokens = total;
}

/// Get estimated context tokens
pub fn getContextTokens() u32 {
    return stats.context_tokens;
}

// === Error Handling ===

fn setLastError(msg: []const u8) void {
    const len = @min(msg.len, 255);
    @memcpy(last_error[0..len], msg[0..len]);
    last_error[len] = 0;
    last_error_len = len;
}

/// Get last error
pub fn getLastError() []const u8 {
    return last_error[0..last_error_len];
}

// === Utilities ===

fn getTimestamp() u64 {
    // In WASM, this would need to come from JS
    // For now, return 0 (platform should set this)
    return 0;
}

// === Tests ===

test "message management" {
    init();

    try std.testing.expect(addUserMessage("Hello!"));
    try std.testing.expectEqual(@as(u32, 1), getMessageCount());

    const msg = getMessage(0).?;
    try std.testing.expectEqual(Role.user, msg.role);
    try std.testing.expectEqualStrings("Hello!", msg.getContent());

    try std.testing.expect(addAssistantMessage("Hi there!"));
    try std.testing.expectEqual(@as(u32, 2), getMessageCount());

    clearConversation();
    try std.testing.expectEqual(@as(u32, 0), getMessageCount());

    deinit();
}

test "token estimation" {
    // ~4 chars per token
    try std.testing.expectEqual(@as(u32, 1), estimateTokens("Hi"));
    try std.testing.expectEqual(@as(u32, 3), estimateTokens("Hello world"));
    try std.testing.expectEqual(@as(u32, 25), estimateTokens("This is a longer message for testing"));
}

test "configuration" {
    init();

    setModel("gpt-4");
    setTemperature(0.7);
    setMaxTokens(2048);
    setStreaming(true);

    const cfg = getConfig();
    try std.testing.expectEqual(@as(f32, 0.7), cfg.temperature);
    try std.testing.expectEqual(@as(u32, 2048), cfg.max_tokens);
    try std.testing.expect(cfg.stream);

    deinit();
}

test "streaming chunks" {
    init();

    beginRequest();
    beginStreaming();

    pushStreamChunk("Hello", 0, false, .none);
    pushStreamChunk(" world", 1, false, .none);
    pushStreamChunk("!", 2, true, .stop);

    try std.testing.expectEqual(@as(u32, 3), getStreamChunkCount());

    const chunk1 = popStreamChunk().?;
    try std.testing.expectEqualStrings("Hello", chunk1.content[0..chunk1.content_len]);
    try std.testing.expect(!chunk1.is_final);

    const chunk2 = popStreamChunk().?;
    try std.testing.expectEqualStrings(" world", chunk2.content[0..chunk2.content_len]);

    const chunk3 = popStreamChunk().?;
    try std.testing.expect(chunk3.is_final);
    try std.testing.expectEqual(FinishReason.stop, chunk3.finish_reason);

    deinit();
}
