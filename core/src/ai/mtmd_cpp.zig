//! Zylix AI - mtmd (Multi-Modal) Zig Bindings
//!
//! Low-level bindings to llama.cpp mtmd C API for vision and audio processing.

const std = @import("std");

// C API bindings
pub const c = @cImport({
    @cInclude("mtmd.h");
});

// Re-export llama types needed for mtmd
pub const llama = @cImport({
    @cInclude("llama.h");
});

// Type aliases
pub const mtmd_context = c.struct_mtmd_context;
pub const mtmd_bitmap = c.struct_mtmd_bitmap;
pub const mtmd_image_tokens = c.struct_mtmd_image_tokens;
pub const mtmd_input_chunk = c.struct_mtmd_input_chunk;
pub const mtmd_input_chunks = c.struct_mtmd_input_chunks;
pub const mtmd_context_params = c.struct_mtmd_context_params;
pub const mtmd_input_text = c.struct_mtmd_input_text;

// Chunk type enum
pub const InputChunkType = enum(c_uint) {
    text = c.MTMD_INPUT_CHUNK_TYPE_TEXT,
    image = c.MTMD_INPUT_CHUNK_TYPE_IMAGE,
    audio = c.MTMD_INPUT_CHUNK_TYPE_AUDIO,
};

// === Context Functions ===

/// Get default marker for image/audio placement
pub fn defaultMarker() [*:0]const u8 {
    return c.mtmd_default_marker();
}

/// Get default context parameters
pub fn contextParamsDefault() mtmd_context_params {
    return c.mtmd_context_params_default();
}

/// Initialize mtmd context from file
pub fn initFromFile(
    mmproj_fname: [*:0]const u8,
    text_model: *llama.struct_llama_model,
    ctx_params: mtmd_context_params,
) ?*mtmd_context {
    return c.mtmd_init_from_file(mmproj_fname, text_model, ctx_params);
}

/// Free mtmd context
pub fn free(ctx: *mtmd_context) void {
    c.mtmd_free(ctx);
}

// === Context Query Functions ===

/// Check if model needs non-causal mask for decode
pub fn decodeUseNonCausal(ctx: *mtmd_context) bool {
    return c.mtmd_decode_use_non_causal(ctx);
}

/// Check if model uses M-RoPE
pub fn decodeUseMrope(ctx: *mtmd_context) bool {
    return c.mtmd_decode_use_mrope(ctx);
}

/// Check if model supports vision input
pub fn supportVision(ctx: *mtmd_context) bool {
    return c.mtmd_support_vision(ctx);
}

/// Check if model supports audio input
pub fn supportAudio(ctx: *mtmd_context) bool {
    return c.mtmd_support_audio(ctx);
}

/// Get audio bitrate in Hz (returns -1 if not supported)
pub fn getAudioBitrate(ctx: *mtmd_context) c_int {
    return c.mtmd_get_audio_bitrate(ctx);
}

// === Bitmap Functions ===

/// Create bitmap from RGB image data
/// data length must be nx * ny * 3 (RGBRGBRGB format)
pub fn bitmapInit(nx: u32, ny: u32, data: [*]const u8) ?*mtmd_bitmap {
    return c.mtmd_bitmap_init(nx, ny, data);
}

/// Create bitmap from audio samples
/// data is PCM F32 format
pub fn bitmapInitFromAudio(n_samples: usize, data: [*]const f32) ?*mtmd_bitmap {
    return c.mtmd_bitmap_init_from_audio(n_samples, data);
}

/// Get bitmap width
pub fn bitmapGetNx(bitmap: *const mtmd_bitmap) u32 {
    return c.mtmd_bitmap_get_nx(bitmap);
}

/// Get bitmap height
pub fn bitmapGetNy(bitmap: *const mtmd_bitmap) u32 {
    return c.mtmd_bitmap_get_ny(bitmap);
}

/// Get bitmap data
pub fn bitmapGetData(bitmap: *const mtmd_bitmap) [*]const u8 {
    return c.mtmd_bitmap_get_data(bitmap);
}

/// Get bitmap data size in bytes
pub fn bitmapGetNBytes(bitmap: *const mtmd_bitmap) usize {
    return c.mtmd_bitmap_get_n_bytes(bitmap);
}

/// Check if bitmap is audio
pub fn bitmapIsAudio(bitmap: *const mtmd_bitmap) bool {
    return c.mtmd_bitmap_is_audio(bitmap);
}

/// Free bitmap
pub fn bitmapFree(bitmap: *mtmd_bitmap) void {
    c.mtmd_bitmap_free(bitmap);
}

/// Get bitmap ID
pub fn bitmapGetId(bitmap: *const mtmd_bitmap) [*:0]const u8 {
    return c.mtmd_bitmap_get_id(bitmap);
}

/// Set bitmap ID
pub fn bitmapSetId(bitmap: *mtmd_bitmap, id: [*:0]const u8) void {
    c.mtmd_bitmap_set_id(bitmap, id);
}

// === Input Chunks Functions ===

/// Initialize input chunks container
pub fn inputChunksInit() ?*mtmd_input_chunks {
    return c.mtmd_input_chunks_init();
}

/// Get number of chunks
pub fn inputChunksSize(chunks: *const mtmd_input_chunks) usize {
    return c.mtmd_input_chunks_size(chunks);
}

/// Get chunk at index
pub fn inputChunksGet(chunks: *const mtmd_input_chunks, idx: usize) ?*const mtmd_input_chunk {
    return c.mtmd_input_chunks_get(chunks, idx);
}

/// Free input chunks
pub fn inputChunksFree(chunks: *mtmd_input_chunks) void {
    c.mtmd_input_chunks_free(chunks);
}

// === Input Chunk Functions ===

/// Get chunk type
pub fn inputChunkGetType(chunk: *const mtmd_input_chunk) InputChunkType {
    return @enumFromInt(c.mtmd_input_chunk_get_type(chunk));
}

/// Get text tokens from chunk
pub fn inputChunkGetTokensText(chunk: *const mtmd_input_chunk, n_tokens: *usize) ?[*]const llama.llama_token {
    return c.mtmd_input_chunk_get_tokens_text(chunk, n_tokens);
}

/// Get image tokens from chunk
pub fn inputChunkGetTokensImage(chunk: *const mtmd_input_chunk) ?*const mtmd_image_tokens {
    return c.mtmd_input_chunk_get_tokens_image(chunk);
}

/// Get number of tokens in chunk
pub fn inputChunkGetNTokens(chunk: *const mtmd_input_chunk) usize {
    return c.mtmd_input_chunk_get_n_tokens(chunk);
}

/// Get chunk ID (null for text chunks)
pub fn inputChunkGetId(chunk: *const mtmd_input_chunk) ?[*:0]const u8 {
    return c.mtmd_input_chunk_get_id(chunk);
}

/// Get number of positions
pub fn inputChunkGetNPos(chunk: *const mtmd_input_chunk) llama.llama_pos {
    return c.mtmd_input_chunk_get_n_pos(chunk);
}

// === Tokenization and Encoding ===

/// Tokenize text with image/audio markers
/// Returns: 0 on success, 1 if bitmap count mismatch, 2 on preprocessing error
pub fn tokenize(
    ctx: *mtmd_context,
    output: *mtmd_input_chunks,
    text: *const mtmd_input_text,
    bitmaps: [*]const ?*const mtmd_bitmap,
    n_bitmaps: usize,
) i32 {
    return c.mtmd_tokenize(ctx, output, text, bitmaps, n_bitmaps);
}

/// Encode a chunk
/// Returns 0 on success
pub fn encodeChunk(ctx: *mtmd_context, chunk: *const mtmd_input_chunk) i32 {
    return c.mtmd_encode_chunk(ctx, chunk);
}

/// Get output embeddings from last encode pass
pub fn getOutputEmbd(ctx: *mtmd_context) ?[*]f32 {
    return c.mtmd_get_output_embd(ctx);
}

// === Image Tokens Functions ===

/// Get number of tokens for image
pub fn imageTokensGetNTokens(image_tokens: *const mtmd_image_tokens) usize {
    return c.mtmd_image_tokens_get_n_tokens(image_tokens);
}

/// Get image tokens width
pub fn imageTokensGetNx(image_tokens: *const mtmd_image_tokens) usize {
    return c.mtmd_image_tokens_get_nx(image_tokens);
}

/// Get image tokens height
pub fn imageTokensGetNy(image_tokens: *const mtmd_image_tokens) usize {
    return c.mtmd_image_tokens_get_ny(image_tokens);
}

// === Tests ===

test "default marker" {
    const marker = defaultMarker();
    try std.testing.expect(marker[0] != 0);
}

test "context params default" {
    const params = contextParamsDefault();
    // Check that params initialized
    _ = params.use_gpu;
}
