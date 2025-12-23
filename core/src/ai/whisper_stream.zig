//! Zylix AI - Whisper Streaming Transcription
//!
//! Real-time streaming speech-to-text using chunk-based processing.
//! Supports sliding window with overlap for continuous transcription.
//!
//! ## Usage
//!
//! ```zig
//! const stream = @import("ai/whisper_stream.zig");
//!
//! // Create streaming context
//! var ctx = try stream.StreamingContext.init(allocator, model_path, .{});
//! defer ctx.deinit();
//!
//! // Process audio chunks
//! try ctx.feedAudio(samples);
//! while (ctx.hasSegments()) {
//!     const segment = ctx.popSegment();
//!     std.debug.print("{s}\n", .{segment.text});
//! }
//! ```

const std = @import("std");
const whisper = @import("whisper_cpp.zig");
const types = @import("types.zig");

// === Constants ===

/// Default sample rate (Whisper requires 16kHz)
pub const SAMPLE_RATE: u32 = 16000;

/// Default step size in milliseconds (how often to process)
pub const DEFAULT_STEP_MS: u32 = 3000;

/// Default audio window length in milliseconds
pub const DEFAULT_LENGTH_MS: u32 = 10000;

/// Default overlap to keep from previous chunk (for word boundaries)
pub const DEFAULT_KEEP_MS: u32 = 200;

/// Maximum audio buffer size (30 seconds at 16kHz)
pub const MAX_BUFFER_SAMPLES: usize = SAMPLE_RATE * 30;

/// Maximum number of pending segments
pub const MAX_PENDING_SEGMENTS: usize = 64;

// === Types ===

/// Streaming transcription segment
pub const StreamSegment = struct {
    /// Segment text (null-terminated)
    text: [512]u8,
    /// Text length
    text_len: usize,
    /// Start time in milliseconds (relative to stream start)
    start_ms: i64,
    /// End time in milliseconds
    end_ms: i64,
    /// Whether this is a partial (in-progress) segment
    is_partial: bool,

    /// Get text as slice
    pub fn getText(self: *const StreamSegment) []const u8 {
        return self.text[0..self.text_len];
    }
};

/// Streaming configuration
pub const StreamConfig = struct {
    /// Step size - how often to process audio (ms)
    step_ms: u32 = DEFAULT_STEP_MS,
    /// Audio window length for each chunk (ms)
    length_ms: u32 = DEFAULT_LENGTH_MS,
    /// Audio to keep from previous chunk (ms)
    keep_ms: u32 = DEFAULT_KEEP_MS,
    /// Language code (empty = auto-detect)
    language: []const u8 = "",
    /// Translate to English
    translate: bool = false,
    /// Number of processing threads
    n_threads: u8 = 4,
    /// Use GPU acceleration
    use_gpu: bool = true,
    /// Enable single segment mode (faster for streaming)
    single_segment: bool = true,
    /// Disable context (no carryover between chunks)
    no_context: bool = true,
    /// Print timestamps in output
    print_timestamps: bool = false,
};

/// Streaming context state
pub const StreamState = enum(u8) {
    uninitialized = 0,
    ready = 1,
    processing = 2,
    paused = 3,
    stopped = 4,
    @"error" = 5,
};

/// Streaming transcription context
pub const StreamingContext = struct {
    allocator: std.mem.Allocator,
    config: StreamConfig,
    state: StreamState,

    // Whisper context
    ctx: ?*whisper.whisper_context,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,

    // Audio buffer (ring buffer style)
    audio_buffer: []f32,
    buffer_write_pos: usize,
    buffer_read_pos: usize,
    samples_accumulated: usize,

    // Previous chunk samples to keep
    prev_samples: []f32,
    prev_samples_len: usize,

    // Segment output queue
    segments: [MAX_PENDING_SEGMENTS]StreamSegment,
    segment_write_idx: usize,
    segment_read_idx: usize,

    // Timing
    stream_start_ms: i64,
    total_samples_processed: u64,
    chunk_count: u64,

    const Self = @This();

    /// Initialize streaming context
    pub fn init(allocator: std.mem.Allocator, model_path: []const u8, config: StreamConfig) !*Self {
        if (model_path.len == 0 or model_path.len >= types.MAX_PATH_LEN) {
            return error.InvalidModelPath;
        }

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Allocate audio buffers
        const n_samples_keep = (config.keep_ms * SAMPLE_RATE) / 1000;

        const audio_buffer = try allocator.alloc(f32, MAX_BUFFER_SAMPLES);
        errdefer allocator.free(audio_buffer);

        const prev_samples = try allocator.alloc(f32, n_samples_keep);
        errdefer allocator.free(prev_samples);

        // Initialize whisper context
        var path_buf: [types.MAX_PATH_LEN]u8 = undefined;
        @memcpy(path_buf[0..model_path.len], model_path);
        path_buf[model_path.len] = 0;

        var ctx_params = whisper.contextDefaultParams();
        ctx_params.use_gpu = config.use_gpu;

        const ctx = whisper.initFromFile(
            @ptrCast(path_buf[0 .. model_path.len + 1]),
            ctx_params,
        );

        if (ctx == null) {
            allocator.free(audio_buffer);
            allocator.free(prev_samples);
            return error.ModelLoadFailed;
        }

        self.* = Self{
            .allocator = allocator,
            .config = config,
            .state = .ready,
            .ctx = ctx,
            .model_path = undefined,
            .model_path_len = model_path.len,
            .audio_buffer = audio_buffer,
            .buffer_write_pos = 0,
            .buffer_read_pos = 0,
            .samples_accumulated = 0,
            .prev_samples = prev_samples,
            .prev_samples_len = 0,
            .segments = undefined,
            .segment_write_idx = 0,
            .segment_read_idx = 0,
            .stream_start_ms = std.time.milliTimestamp(),
            .total_samples_processed = 0,
            .chunk_count = 0,
        };

        @memcpy(self.model_path[0..model_path.len], model_path);

        return self;
    }

    /// Deinitialize streaming context
    pub fn deinit(self: *Self) void {
        if (self.ctx) |ctx| {
            whisper.free(ctx);
            self.ctx = null;
        }

        self.allocator.free(self.audio_buffer);
        self.allocator.free(self.prev_samples);
        self.state = .stopped;
        self.allocator.destroy(self);
    }

    /// Feed audio samples to the stream
    pub fn feedAudio(self: *Self, samples: []const f32) !void {
        if (self.state == .stopped or self.state == .@"error") {
            return error.StreamNotActive;
        }

        // Copy samples to buffer
        for (samples) |sample| {
            self.audio_buffer[self.buffer_write_pos] = sample;
            self.buffer_write_pos = (self.buffer_write_pos + 1) % self.audio_buffer.len;
            self.samples_accumulated += 1;
        }

        // Check if we have enough samples to process
        const n_samples_step = (self.config.step_ms * SAMPLE_RATE) / 1000;

        if (self.samples_accumulated >= n_samples_step) {
            try self.processChunk();
        }
    }

    /// Process accumulated audio chunk
    fn processChunk(self: *Self) !void {
        if (self.ctx == null) {
            return error.ModelNotLoaded;
        }

        const ctx = self.ctx.?;
        self.state = .processing;

        const n_samples_step = (self.config.step_ms * SAMPLE_RATE) / 1000;
        const n_samples_len = (self.config.length_ms * SAMPLE_RATE) / 1000;
        const n_samples_keep = (self.config.keep_ms * SAMPLE_RATE) / 1000;

        // Build chunk: prev_samples + new samples
        var chunk: [MAX_BUFFER_SAMPLES]f32 = undefined;
        var chunk_len: usize = 0;

        // Add kept samples from previous chunk
        if (self.prev_samples_len > 0) {
            @memcpy(chunk[0..self.prev_samples_len], self.prev_samples[0..self.prev_samples_len]);
            chunk_len = self.prev_samples_len;
        }

        // Add new samples
        const new_samples_to_take = @min(self.samples_accumulated, n_samples_len - chunk_len);
        const read_start = if (self.buffer_read_pos + new_samples_to_take <= self.audio_buffer.len)
            self.buffer_read_pos
        else
            0;

        for (0..new_samples_to_take) |i| {
            const idx = (read_start + i) % self.audio_buffer.len;
            chunk[chunk_len + i] = self.audio_buffer[idx];
        }
        chunk_len += new_samples_to_take;

        // Update buffer position
        self.buffer_read_pos = (self.buffer_read_pos + new_samples_to_take) % self.audio_buffer.len;
        self.samples_accumulated -= new_samples_to_take;

        // Save samples to keep for next iteration
        if (chunk_len > n_samples_keep) {
            const keep_start = chunk_len - n_samples_keep;
            @memcpy(self.prev_samples[0..n_samples_keep], chunk[keep_start..chunk_len]);
            self.prev_samples_len = n_samples_keep;
        }

        // Set up transcription parameters
        var params = whisper.fullDefaultParams(.greedy);
        params.n_threads = self.config.n_threads;
        params.translate = self.config.translate;
        params.print_progress = false;
        params.print_realtime = false;
        params.print_timestamps = self.config.print_timestamps;

        whisper.setSingleSegment(&params, self.config.single_segment);
        whisper.setNoContext(&params, self.config.no_context);

        // Set language if specified
        if (self.config.language.len > 0 and self.config.language.len < 8) {
            var lang_buf: [8]u8 = .{0} ** 8;
            @memcpy(lang_buf[0..self.config.language.len], self.config.language);
            params.language = @ptrCast(&lang_buf);
        }

        // Run transcription
        const ret = whisper.full(ctx, params, &chunk, @intCast(chunk_len));

        if (ret != 0) {
            self.state = .@"error";
            return error.TranscriptionFailed;
        }

        // Get results
        const n_segments: usize = @intCast(@max(0, whisper.fullNSegments(ctx)));

        // Calculate time offset based on processed samples
        const time_offset_ms: i64 = @intCast((self.total_samples_processed * 1000) / SAMPLE_RATE);

        for (0..n_segments) |i| {
            const segment_text = whisper.fullGetSegmentText(ctx, @intCast(i));
            const text_span = std.mem.span(segment_text);

            // Skip empty segments
            if (text_span.len == 0) continue;

            // Skip leading space on first segment
            var actual_span = text_span;
            if (text_span.len > 0 and text_span[0] == ' ') {
                actual_span = text_span[1..];
            }

            // Skip if still empty
            if (actual_span.len == 0) continue;

            // Add segment to queue
            const seg_idx = self.segment_write_idx % MAX_PENDING_SEGMENTS;
            var segment = &self.segments[seg_idx];

            const copy_len = @min(actual_span.len, segment.text.len - 1);
            @memcpy(segment.text[0..copy_len], actual_span[0..copy_len]);
            segment.text[copy_len] = 0;
            segment.text_len = copy_len;

            const t0 = whisper.fullGetSegmentT0(ctx, @intCast(i));
            const t1 = whisper.fullGetSegmentT1(ctx, @intCast(i));
            segment.start_ms = time_offset_ms + (t0 * 10); // centiseconds to ms
            segment.end_ms = time_offset_ms + (t1 * 10);
            segment.is_partial = false;

            self.segment_write_idx += 1;
        }

        self.total_samples_processed += @intCast(n_samples_step);
        self.chunk_count += 1;
        self.state = .ready;
    }

    /// Check if there are pending segments
    pub fn hasSegments(self: *const Self) bool {
        return self.segment_read_idx < self.segment_write_idx;
    }

    /// Get number of pending segments
    pub fn pendingSegmentCount(self: *const Self) usize {
        return self.segment_write_idx - self.segment_read_idx;
    }

    /// Pop next segment from queue
    pub fn popSegment(self: *Self) ?StreamSegment {
        if (!self.hasSegments()) {
            return null;
        }

        const seg_idx = self.segment_read_idx % MAX_PENDING_SEGMENTS;
        const segment = self.segments[seg_idx];
        self.segment_read_idx += 1;
        return segment;
    }

    /// Get current streaming state
    pub fn getState(self: *const Self) StreamState {
        return self.state;
    }

    /// Get streaming statistics
    pub fn getStats(self: *const Self) StreamStats {
        const elapsed_ms = std.time.milliTimestamp() - self.stream_start_ms;
        const audio_duration_ms: i64 = @intCast((self.total_samples_processed * 1000) / SAMPLE_RATE);

        return StreamStats{
            .chunks_processed = self.chunk_count,
            .samples_processed = self.total_samples_processed,
            .segments_produced = self.segment_write_idx,
            .elapsed_ms = elapsed_ms,
            .audio_duration_ms = audio_duration_ms,
            .realtime_factor = if (elapsed_ms > 0)
                @as(f32, @floatFromInt(audio_duration_ms)) / @as(f32, @floatFromInt(elapsed_ms))
            else
                0.0,
        };
    }

    /// Reset stream state (keep model loaded)
    pub fn reset(self: *Self) void {
        self.buffer_write_pos = 0;
        self.buffer_read_pos = 0;
        self.samples_accumulated = 0;
        self.prev_samples_len = 0;
        self.segment_write_idx = 0;
        self.segment_read_idx = 0;
        self.stream_start_ms = std.time.milliTimestamp();
        self.total_samples_processed = 0;
        self.chunk_count = 0;
        self.state = .ready;

        if (self.ctx) |ctx| {
            whisper.resetTimings(ctx);
        }
    }

    /// Pause streaming
    pub fn pause(self: *Self) void {
        if (self.state == .ready or self.state == .processing) {
            self.state = .paused;
        }
    }

    /// Resume streaming
    pub fn resumeStream(self: *Self) void {
        if (self.state == .paused) {
            self.state = .ready;
        }
    }

    /// Force process any remaining audio
    pub fn flush(self: *Self) !void {
        if (self.samples_accumulated > 0) {
            try self.processChunk();
        }
    }

    /// Check if model is loaded
    pub fn isLoaded(self: *const Self) bool {
        return self.ctx != null;
    }
};

/// Streaming statistics
pub const StreamStats = struct {
    chunks_processed: u64,
    samples_processed: u64,
    segments_produced: usize,
    elapsed_ms: i64,
    audio_duration_ms: i64,
    realtime_factor: f32,
};

/// Create streaming context from audio file for testing
pub fn createFromFile(
    allocator: std.mem.Allocator,
    audio_path: []const u8,
    model_path: []const u8,
    config: StreamConfig,
) !struct { ctx: *StreamingContext, samples: []f32 } {
    const audio_decoder = @import("audio_decoder.zig");

    // Decode audio file
    var decode_result = try audio_decoder.decodeFileForWhisper(allocator, audio_path);
    errdefer decode_result.deinit();

    // Create streaming context
    const ctx = try StreamingContext.init(allocator, model_path, config);
    errdefer ctx.deinit();

    return .{
        .ctx = ctx,
        .samples = decode_result.samples,
    };
}

// === Tests ===

test "StreamConfig defaults" {
    const config = StreamConfig{};
    try std.testing.expectEqual(@as(u32, 3000), config.step_ms);
    try std.testing.expectEqual(@as(u32, 10000), config.length_ms);
    try std.testing.expectEqual(@as(u32, 200), config.keep_ms);
}

test "StreamSegment getText" {
    var segment = StreamSegment{
        .text = undefined,
        .text_len = 5,
        .start_ms = 0,
        .end_ms = 1000,
        .is_partial = false,
    };
    segment.text[0] = 'H';
    segment.text[1] = 'e';
    segment.text[2] = 'l';
    segment.text[3] = 'l';
    segment.text[4] = 'o';

    try std.testing.expectEqualStrings("Hello", segment.getText());
}
