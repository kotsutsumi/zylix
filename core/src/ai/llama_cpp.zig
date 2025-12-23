//! Zylix AI - llama.cpp C Bindings
//!
//! Low-level bindings to llama.cpp C API for model inference.
//! This module provides direct access to llama.cpp functions.

const std = @import("std");

// C imports for llama.cpp
pub const c = @cImport({
    @cInclude("llama.h");
});

// Re-export commonly used types
pub const llama_model = c.llama_model;
pub const llama_context = c.llama_context;
pub const llama_token = c.llama_token;
pub const llama_pos = c.llama_pos;
pub const llama_seq_id = c.llama_seq_id;
pub const llama_batch = c.llama_batch;
pub const llama_model_params = c.llama_model_params;
pub const llama_context_params = c.llama_context_params;
pub const llama_sampler = c.llama_sampler;

// Pooling types for embeddings
pub const LLAMA_POOLING_TYPE_NONE = c.LLAMA_POOLING_TYPE_NONE;
pub const LLAMA_POOLING_TYPE_MEAN = c.LLAMA_POOLING_TYPE_MEAN;
pub const LLAMA_POOLING_TYPE_CLS = c.LLAMA_POOLING_TYPE_CLS;
pub const LLAMA_POOLING_TYPE_LAST = c.LLAMA_POOLING_TYPE_LAST;

// === Initialization ===

/// Initialize llama backend
pub fn backendInit() void {
    c.llama_backend_init();
}

/// Free llama backend
pub fn backendFree() void {
    c.llama_backend_free();
}

// === Model Loading ===

/// Get default model parameters
pub fn modelDefaultParams() llama_model_params {
    return c.llama_model_default_params();
}

/// Get default context parameters
pub fn contextDefaultParams() llama_context_params {
    return c.llama_context_default_params();
}

/// Load model from file
pub fn modelLoadFromFile(path: [*:0]const u8, params: llama_model_params) ?*llama_model {
    return c.llama_model_load_from_file(path, params);
}

/// Free model
pub fn modelFree(model: *llama_model) void {
    c.llama_model_free(model);
}

/// Create context from model
pub fn initFromModel(model: *llama_model, params: llama_context_params) ?*llama_context {
    return c.llama_init_from_model(model, params);
}

/// Free context
pub fn free(ctx: *llama_context) void {
    c.llama_free(ctx);
}

// === Model Info ===

/// Get embedding dimension
pub fn modelNEmbd(model: *const llama_model) i32 {
    return c.llama_model_n_embd(model);
}

/// Get context training length
pub fn modelNCtxTrain(model: *const llama_model) i32 {
    return c.llama_model_n_ctx_train(model);
}

/// Get vocabulary from model
pub fn modelGetVocab(model: *const llama_model) ?*const c.llama_vocab {
    return c.llama_model_get_vocab(model);
}

/// Get number of tokens in vocabulary
pub fn vocabNTokens(vocab: *const c.llama_vocab) i32 {
    return c.llama_vocab_n_tokens(vocab);
}

// === Context Info ===

/// Get context size
pub fn nCtx(ctx: *const llama_context) u32 {
    return c.llama_n_ctx(ctx);
}

/// Get batch size
pub fn nBatch(ctx: *const llama_context) u32 {
    return c.llama_n_batch(ctx);
}

/// Get model from context
pub fn getModel(ctx: *const llama_context) *const llama_model {
    return c.llama_get_model(ctx);
}

/// Get pooling type
pub fn poolingType(ctx: *const llama_context) c_int {
    return @intFromEnum(c.llama_pooling_type(ctx));
}

// === Tokenization ===

/// Tokenize text
/// Returns number of tokens, or negative value on error
pub fn tokenize(
    vocab: *const c.llama_vocab,
    text: [*]const u8,
    text_len: i32,
    tokens: [*]llama_token,
    n_tokens_max: i32,
    add_special: bool,
    parse_special: bool,
) i32 {
    return c.llama_tokenize(vocab, text, text_len, tokens, n_tokens_max, add_special, parse_special);
}

/// Detokenize (convert tokens back to text)
pub fn tokenToPiece(
    vocab: *const c.llama_vocab,
    token: llama_token,
    buf: [*]u8,
    length: i32,
    lstrip: i32,
    special: bool,
) i32 {
    return c.llama_token_to_piece(vocab, token, buf, length, lstrip, special);
}

// === Batch Operations ===

/// Initialize batch with n_tokens capacity
pub fn batchInit(n_tokens: i32, embd: i32, n_seq_max: i32) llama_batch {
    return c.llama_batch_init(n_tokens, embd, n_seq_max);
}

/// Free batch
pub fn batchFree(batch: llama_batch) void {
    c.llama_batch_free(batch);
}

// === Inference ===

/// Decode batch
/// Returns 0 on success
pub fn decode(ctx: *llama_context, batch: llama_batch) i32 {
    return c.llama_decode(ctx, batch);
}

/// Encode (for encoder models)
pub fn encode(ctx: *llama_context, batch: llama_batch) i32 {
    return c.llama_encode(ctx, batch);
}

// === Embeddings ===

/// Enable/disable embeddings mode
pub fn setEmbeddings(ctx: *llama_context, embeddings: bool) void {
    c.llama_set_embeddings(ctx, embeddings);
}

/// Get embeddings for the ith token
pub fn getEmbeddingsIth(ctx: *llama_context, i: i32) ?[*]f32 {
    return c.llama_get_embeddings_ith(ctx, i);
}

/// Get embeddings for a sequence
pub fn getEmbeddingsSeq(ctx: *llama_context, seq_id: llama_seq_id) ?[*]f32 {
    return c.llama_get_embeddings_seq(ctx, seq_id);
}

// === Logits ===

/// Get logits for the ith token
pub fn getLogitsIth(ctx: *llama_context, i: i32) ?[*]f32 {
    return c.llama_get_logits_ith(ctx, i);
}

// === Sampling ===

/// Create sampler chain with default params
pub fn samplerChainInit(params: c.llama_sampler_chain_params) ?*llama_sampler {
    return c.llama_sampler_chain_init(params);
}

/// Get default sampler chain params
pub fn samplerChainDefaultParams() c.llama_sampler_chain_params {
    return c.llama_sampler_chain_default_params();
}

/// Add sampler to chain
pub fn samplerChainAdd(chain: *llama_sampler, smpl: *llama_sampler) void {
    c.llama_sampler_chain_add(chain, smpl);
}

/// Free sampler
pub fn samplerFree(smpl: *llama_sampler) void {
    c.llama_sampler_free(smpl);
}

/// Sample token
pub fn samplerSample(smpl: *llama_sampler, ctx: *llama_context, idx: i32) llama_token {
    return c.llama_sampler_sample(smpl, ctx, idx);
}

/// Create greedy sampler
pub fn samplerInitGreedy() ?*llama_sampler {
    return c.llama_sampler_init_greedy();
}

/// Create temperature sampler
pub fn samplerInitTemp(temp: f32) ?*llama_sampler {
    return c.llama_sampler_init_temp(temp);
}

/// Create top-p sampler
pub fn samplerInitTopP(p: f32, min_keep: usize) ?*llama_sampler {
    return c.llama_sampler_init_top_p(p, min_keep);
}

/// Create top-k sampler
pub fn samplerInitTopK(k: i32) ?*llama_sampler {
    return c.llama_sampler_init_top_k(k);
}

// === Special Tokens ===

/// Get BOS token
pub fn vocabBos(vocab: *const c.llama_vocab) llama_token {
    return c.llama_vocab_bos(vocab);
}

/// Get EOS token
pub fn vocabEos(vocab: *const c.llama_vocab) llama_token {
    return c.llama_vocab_eos(vocab);
}

/// Get EOT token
pub fn vocabEot(vocab: *const c.llama_vocab) llama_token {
    return c.llama_vocab_eot(vocab);
}

// === Memory Management ===

/// llama_memory_t type
pub const llama_memory_t = c.llama_memory_t;

/// Get memory from context
pub fn getMemory(ctx: *const llama_context) llama_memory_t {
    return c.llama_get_memory(ctx);
}

/// Clear memory (replaces old kv_cache_clear)
pub fn memoryClear(mem: llama_memory_t, data: bool) void {
    c.llama_memory_clear(mem, data);
}

// === Utility ===

/// Check if model supports GPU offload
pub fn supportsGpuOffload() bool {
    return c.llama_supports_gpu_offload();
}

/// Check if model supports mmap
pub fn supportsMmap() bool {
    return c.llama_supports_mmap();
}

// === Helper Functions ===

/// Helper to create a simple batch for single sequence
/// Note: pos and seq_id are now handled internally by llama.cpp
pub fn batchGetOne(tokens: [*]llama_token, n_tokens: i32) llama_batch {
    return c.llama_batch_get_one(tokens, n_tokens);
}
