//! Zylix AI - whisper.cpp Zig Bindings
//!
//! Low-level bindings to whisper.cpp C API for speech recognition.

const std = @import("std");

// C API bindings
pub const c = @cImport({
    @cInclude("whisper.h");
});

// Type aliases for cleaner code
pub const whisper_context = c.struct_whisper_context;
pub const whisper_state = c.struct_whisper_state;
pub const whisper_full_params = c.struct_whisper_full_params;
pub const whisper_context_params = c.struct_whisper_context_params;
pub const whisper_token = c.whisper_token;

// Constants
pub const SAMPLE_RATE: u32 = c.WHISPER_SAMPLE_RATE;
pub const N_FFT: u32 = c.WHISPER_N_FFT;
pub const HOP_LENGTH: u32 = c.WHISPER_HOP_LENGTH;
pub const CHUNK_SIZE: u32 = c.WHISPER_CHUNK_SIZE;

// Sampling strategy enum
pub const SamplingStrategy = enum(c_uint) {
    greedy = 0,
    beam_search = 1,
};

// === Initialization ===

/// Get whisper.cpp version string
pub fn version() [*:0]const u8 {
    return c.whisper_version();
}

/// Get default context parameters
pub fn contextDefaultParams() whisper_context_params {
    return c.whisper_context_default_params();
}

/// Get default full params for transcription
pub fn fullDefaultParams(strategy: SamplingStrategy) whisper_full_params {
    return c.whisper_full_default_params(@intFromEnum(strategy));
}

/// Initialize whisper context from file
pub fn initFromFile(path: [*:0]const u8, params: whisper_context_params) ?*whisper_context {
    return c.whisper_init_from_file_with_params(path, params);
}

/// Initialize whisper state
pub fn initState(ctx: *whisper_context) ?*whisper_state {
    return c.whisper_init_state(ctx);
}

// === Cleanup ===

/// Free whisper context
pub fn free(ctx: *whisper_context) void {
    c.whisper_free(ctx);
}

/// Free whisper state
pub fn freeState(state: *whisper_state) void {
    c.whisper_free_state(state);
}

// === Model Info ===

/// Check if model is multilingual
pub fn isMultilingual(ctx: *whisper_context) bool {
    return c.whisper_is_multilingual(ctx) != 0;
}

/// Get number of vocabulary tokens
pub fn nVocab(ctx: *whisper_context) c_int {
    return c.whisper_n_vocab(ctx);
}

/// Get max language id
pub fn langMaxId() c_int {
    return c.whisper_lang_max_id();
}

/// Get language id from string
pub fn langId(lang: [*:0]const u8) c_int {
    return c.whisper_lang_id(lang);
}

/// Get language string from id
pub fn langStr(id: c_int) [*:0]const u8 {
    return c.whisper_lang_str(id);
}

/// Get full language name from id
pub fn langStrFull(id: c_int) [*:0]const u8 {
    return c.whisper_lang_str_full(id);
}

// === Transcription ===

/// Run full transcription
pub fn full(
    ctx: *whisper_context,
    params: whisper_full_params,
    samples: [*]const f32,
    n_samples: c_int,
) c_int {
    return c.whisper_full(ctx, params, samples, n_samples);
}

/// Run full transcription with state
pub fn fullWithState(
    ctx: *whisper_context,
    state: *whisper_state,
    params: whisper_full_params,
    samples: [*]const f32,
    n_samples: c_int,
) c_int {
    return c.whisper_full_with_state(ctx, state, params, samples, n_samples);
}

/// Run parallel transcription (for long audio)
pub fn fullParallel(
    ctx: *whisper_context,
    params: whisper_full_params,
    samples: [*]const f32,
    n_samples: c_int,
    n_processors: c_int,
) c_int {
    return c.whisper_full_parallel(ctx, params, samples, n_samples, n_processors);
}

// === Results ===

/// Get number of segments in result
pub fn fullNSegments(ctx: *whisper_context) c_int {
    return c.whisper_full_n_segments(ctx);
}

/// Get number of segments from state
pub fn fullNSegmentsFromState(state: *whisper_state) c_int {
    return c.whisper_full_n_segments_from_state(state);
}

/// Get detected language id
pub fn fullLangId(ctx: *whisper_context) c_int {
    return c.whisper_full_lang_id(ctx);
}

/// Get segment start time (in centiseconds)
pub fn fullGetSegmentT0(ctx: *whisper_context, i_segment: c_int) i64 {
    return c.whisper_full_get_segment_t0(ctx, i_segment);
}

/// Get segment end time (in centiseconds)
pub fn fullGetSegmentT1(ctx: *whisper_context, i_segment: c_int) i64 {
    return c.whisper_full_get_segment_t1(ctx, i_segment);
}

/// Get segment text
pub fn fullGetSegmentText(ctx: *whisper_context, i_segment: c_int) [*:0]const u8 {
    return c.whisper_full_get_segment_text(ctx, i_segment);
}

/// Get segment text from state
pub fn fullGetSegmentTextFromState(state: *whisper_state, i_segment: c_int) [*:0]const u8 {
    return c.whisper_full_get_segment_text_from_state(state, i_segment);
}

/// Get number of tokens in segment
pub fn fullNTokens(ctx: *whisper_context, i_segment: c_int) c_int {
    return c.whisper_full_n_tokens(ctx, i_segment);
}

// === Audio Processing ===

/// Convert PCM to mel spectrogram
pub fn pcmToMel(
    ctx: *whisper_context,
    samples: [*]const f32,
    n_samples: c_int,
    n_threads: c_int,
) c_int {
    return c.whisper_pcm_to_mel(ctx, samples, n_samples, n_threads);
}

// === Token Operations ===

/// Convert token to string
pub fn tokenToStr(ctx: *whisper_context, token: whisper_token) [*:0]const u8 {
    return c.whisper_token_to_str(ctx, token);
}

/// Get EOT (end of text) token
pub fn tokenEot(ctx: *whisper_context) whisper_token {
    return c.whisper_token_eot(ctx);
}

/// Get SOT (start of text) token
pub fn tokenSot(ctx: *whisper_context) whisper_token {
    return c.whisper_token_sot(ctx);
}

/// Get translate token
pub fn tokenTranslate(ctx: *whisper_context) whisper_token {
    return c.whisper_token_translate(ctx);
}

/// Get transcribe token
pub fn tokenTranscribe(ctx: *whisper_context) whisper_token {
    return c.whisper_token_transcribe(ctx);
}

// === Helper Functions ===

/// Set language in params
pub fn setLanguage(params: *whisper_full_params, lang: [*:0]const u8) void {
    params.language = lang;
}

/// Set translate mode in params
pub fn setTranslate(params: *whisper_full_params, translate: bool) void {
    params.translate = translate;
}

/// Set number of threads
pub fn setNThreads(params: *whisper_full_params, n_threads: c_int) void {
    params.n_threads = n_threads;
}

/// Enable/disable token timestamps
pub fn setTokenTimestamps(params: *whisper_full_params, enable: bool) void {
    params.token_timestamps = enable;
}

/// Set max tokens per segment
pub fn setMaxTokensPerSegment(params: *whisper_full_params, max_tokens: c_int) void {
    params.max_tokens = max_tokens;
}

/// Set single segment mode (for streaming)
pub fn setSingleSegment(params: *whisper_full_params, enable: bool) void {
    params.single_segment = enable;
}

/// Set no context mode (for streaming without context carryover)
pub fn setNoContext(params: *whisper_full_params, enable: bool) void {
    params.no_context = enable;
}

/// Set audio context size (0 = all)
pub fn setAudioCtx(params: *whisper_full_params, audio_ctx: c_int) void {
    params.audio_ctx = audio_ctx;
}

/// Reset timings (for streaming)
pub fn resetTimings(ctx: *whisper_context) void {
    c.whisper_reset_timings(ctx);
}

/// Print performance timings
pub fn printTimings(ctx: *whisper_context) void {
    c.whisper_print_timings(ctx);
}

// === Callback Types ===

/// New segment callback type
pub const NewSegmentCallback = *const fn (ctx: *whisper_context, state: *whisper_state, n_new: c_int, user_data: ?*anyopaque) callconv(.C) void;

/// Progress callback type
pub const ProgressCallback = *const fn (ctx: *whisper_context, state: *whisper_state, progress: c_int, user_data: ?*anyopaque) callconv(.C) void;

/// Set new segment callback
pub fn setNewSegmentCallback(params: *whisper_full_params, callback: ?NewSegmentCallback, user_data: ?*anyopaque) void {
    params.new_segment_callback = @ptrCast(callback);
    params.new_segment_callback_user_data = user_data;
}

/// Set progress callback
pub fn setProgressCallback(params: *whisper_full_params, callback: ?ProgressCallback, user_data: ?*anyopaque) void {
    params.progress_callback = @ptrCast(callback);
    params.progress_callback_user_data = user_data;
}

// === State-based result functions ===

/// Get detected language id from state
pub fn fullLangIdFromState(state: *whisper_state) c_int {
    return c.whisper_full_lang_id_from_state(state);
}

/// Get segment start time from state (in centiseconds)
pub fn fullGetSegmentT0FromState(state: *whisper_state, i_segment: c_int) i64 {
    return c.whisper_full_get_segment_t0_from_state(state, i_segment);
}

/// Get segment end time from state (in centiseconds)
pub fn fullGetSegmentT1FromState(state: *whisper_state, i_segment: c_int) i64 {
    return c.whisper_full_get_segment_t1_from_state(state, i_segment);
}

// === Tests ===

test "whisper version" {
    const ver = version();
    try std.testing.expect(ver[0] != 0);
}

test "context default params" {
    const params = contextDefaultParams();
    // Check default GPU setting
    _ = params.use_gpu;
}

test "full default params" {
    const params = fullDefaultParams(.greedy);
    // Check params initialized
    try std.testing.expect(params.n_threads >= 0);
}

test "language functions" {
    const max_id = langMaxId();
    try std.testing.expect(max_id > 0);

    const en_id = langId("en");
    try std.testing.expect(en_id >= 0);

    const lang_str = langStr(en_id);
    try std.testing.expectEqualStrings("en", std.mem.span(lang_str));
}
