//! Zylix AI - Embedding Model
//!
//! Text embedding functionality for semantic search and RAG applications.
//! Converts text into dense vector representations.
//!
//! ## Usage
//!
//! ```zig
//! const embedding = @import("ai/embedding.zig");
//!
//! // Load model
//! var model = try embedding.EmbeddingModel.init(config, allocator);
//! defer model.deinit();
//!
//! // Embed text
//! const vec = try model.embed("Hello, world!");
//! defer allocator.free(vec);
//!
//! // Calculate similarity
//! const sim = embedding.cosineSimilarity(vec1, vec2);
//! ```

const std = @import("std");
const types = @import("types.zig");
const ModelConfig = types.ModelConfig;
const ModelFormat = types.ModelFormat;
const Result = types.Result;

// === Configuration ===

/// Default embedding dimension (can vary by model)
pub const DEFAULT_EMBEDDING_DIM: u32 = 384;

/// Maximum text length for single embedding
pub const MAX_TEXT_LENGTH: usize = 8192;

/// Maximum batch size
pub const MAX_BATCH_SIZE: usize = 32;

// === Embedding Config ===

/// Configuration for embedding operations
pub const EmbeddingConfig = struct {
    /// Model configuration
    model: ModelConfig,

    /// Normalize output vectors (L2 normalization)
    normalize: bool = true,

    /// Truncate text if exceeds max length
    truncate: bool = true,

    /// Max sequence length for tokenization
    max_sequence_length: u32 = 512,
};

// === Embedding Output ===

/// Result of embedding operation
pub const EmbeddingOutput = struct {
    /// The embedding vector
    vector: []f32,

    /// Dimension of the vector
    dimension: u32,

    /// Number of tokens processed
    tokens_used: u32,

    /// Whether the input was truncated
    was_truncated: bool,
};

// === Embedding Model ===

/// Embedding model for text-to-vector conversion
pub const EmbeddingModel = struct {
    config: EmbeddingConfig,
    allocator: std.mem.Allocator,
    initialized: bool,
    embedding_dim: u32,

    const Self = @This();

    /// Initialize embedding model
    pub fn init(config: EmbeddingConfig, allocator: std.mem.Allocator) !Self {
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

        // For now, we don't actually load the model (placeholder for backend integration)
        // This will be replaced with actual GGML/ONNX loading

        return Self{
            .config = config,
            .allocator = allocator,
            .initialized = true,
            .embedding_dim = DEFAULT_EMBEDDING_DIM,
        };
    }

    /// Check if model is ready
    pub fn isReady(self: *const Self) bool {
        return self.initialized;
    }

    /// Get embedding dimension
    pub fn getDimension(self: *const Self) u32 {
        return self.embedding_dim;
    }

    /// Embed single text
    /// Caller owns the returned slice and must free it
    pub fn embed(self: *Self, text: []const u8) ![]f32 {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (text.len == 0) {
            return error.EmptyInput;
        }

        // Check text length
        if (text.len > MAX_TEXT_LENGTH and !self.config.truncate) {
            return error.TextTooLong;
        }

        // Allocate output vector
        const vector = try self.allocator.alloc(f32, self.embedding_dim);
        errdefer self.allocator.free(vector);

        // TODO: Replace with actual embedding inference
        // For now, generate deterministic placeholder based on text hash
        self.generatePlaceholderEmbedding(text, vector);

        // Normalize if configured
        if (self.config.normalize) {
            normalizeVector(vector);
        }

        return vector;
    }

    /// Embed multiple texts in batch
    /// Caller owns the returned slices and must free them
    pub fn embedBatch(self: *Self, texts: []const []const u8) ![][]f32 {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (texts.len == 0) {
            return error.EmptyInput;
        }

        if (texts.len > MAX_BATCH_SIZE) {
            return error.BatchTooLarge;
        }

        // Allocate result array
        const results = try self.allocator.alloc([]f32, texts.len);
        errdefer {
            for (results) |vec| {
                self.allocator.free(vec);
            }
            self.allocator.free(results);
        }

        // Process each text
        var processed: usize = 0;
        for (texts) |text| {
            results[processed] = try self.embed(text);
            processed += 1;
        }

        return results;
    }

    /// Free batch results
    pub fn freeBatch(self: *Self, batch: [][]f32) void {
        for (batch) |vec| {
            self.allocator.free(vec);
        }
        self.allocator.free(batch);
    }

    /// Generate placeholder embedding (for testing before backend integration)
    fn generatePlaceholderEmbedding(self: *const Self, text: []const u8, output: []f32) void {
        // Use hash-based deterministic values for consistent testing
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(text);
        var seed = hasher.final();

        for (output, 0..) |*val, i| {
            // Generate pseudo-random but deterministic values
            seed = seed *% 0x5851F42D4C957F2D +% @as(u64, @intCast(i));
            const float_val = @as(f32, @floatFromInt(seed >> 40)) / 16777216.0 - 0.5;
            val.* = float_val;
        }
        _ = self;
    }

    /// Deinitialize model
    pub fn deinit(self: *Self) void {
        // TODO: Free backend resources when implemented
        self.initialized = false;
    }
};

// === Vector Operations ===

/// Calculate cosine similarity between two vectors
/// Returns a value between -1 and 1
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len or a.len == 0) {
        return 0;
    }

    var dot: f32 = 0;
    var norm_a: f32 = 0;
    var norm_b: f32 = 0;

    for (a, b) |va, vb| {
        dot += va * vb;
        norm_a += va * va;
        norm_b += vb * vb;
    }

    const denominator = @sqrt(norm_a) * @sqrt(norm_b);
    if (denominator == 0) {
        return 0;
    }

    return dot / denominator;
}

/// Calculate dot product of two vectors
pub fn dotProduct(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len) {
        return 0;
    }

    var sum: f32 = 0;
    for (a, b) |va, vb| {
        sum += va * vb;
    }
    return sum;
}

/// Calculate Euclidean distance between two vectors
pub fn euclideanDistance(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len) {
        return std.math.inf(f32);
    }

    var sum: f32 = 0;
    for (a, b) |va, vb| {
        const diff = va - vb;
        sum += diff * diff;
    }
    return @sqrt(sum);
}

/// Normalize vector to unit length (L2 normalization)
pub fn normalizeVector(vec: []f32) void {
    var norm: f32 = 0;
    for (vec) |v| {
        norm += v * v;
    }
    norm = @sqrt(norm);

    if (norm > 0) {
        for (vec) |*v| {
            v.* /= norm;
        }
    }
}

/// Calculate L2 norm of a vector
pub fn vectorNorm(vec: []const f32) f32 {
    var sum: f32 = 0;
    for (vec) |v| {
        sum += v * v;
    }
    return @sqrt(sum);
}

// === Tests ===

test "cosineSimilarity - identical vectors" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0, 0.0 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sim, 0.0001);
}

test "cosineSimilarity - orthogonal vectors" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0, 0.0 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sim, 0.0001);
}

test "cosineSimilarity - opposite vectors" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ -1.0, 0.0, 0.0 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), sim, 0.0001);
}

test "cosineSimilarity - similar vectors" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sim, 0.0001);
}

test "cosineSimilarity - different length vectors" {
    const a = [_]f32{ 1.0, 2.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectEqual(@as(f32, 0.0), sim);
}

test "cosineSimilarity - empty vectors" {
    const a = [_]f32{};
    const b = [_]f32{};

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectEqual(@as(f32, 0.0), sim);
}

test "dotProduct" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };

    const dot = dotProduct(&a, &b);
    // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), dot, 0.0001);
}

test "euclideanDistance - same point" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };

    const dist = euclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dist, 0.0001);
}

test "euclideanDistance - unit distance" {
    const a = [_]f32{ 0.0, 0.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0, 0.0 };

    const dist = euclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dist, 0.0001);
}

test "normalizeVector" {
    var vec = [_]f32{ 3.0, 4.0 };
    normalizeVector(&vec);

    // Magnitude should be 1
    const norm = vectorNorm(&vec);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, 0.0001);

    // Values should be 3/5 and 4/5
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), vec[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), vec[1], 0.0001);
}

test "vectorNorm" {
    const vec = [_]f32{ 3.0, 4.0 };
    const norm = vectorNorm(&vec);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), norm, 0.0001);
}

test "EmbeddingModel initialization" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    try std.testing.expect(model.isReady());
    try std.testing.expectEqual(@as(u32, DEFAULT_EMBEDDING_DIM), model.getDimension());
}

test "EmbeddingModel embed produces deterministic output" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
        .normalize = false, // Disable normalization for determinism check
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    const vec1 = try model.embed("Hello, world!");
    defer allocator.free(vec1);

    const vec2 = try model.embed("Hello, world!");
    defer allocator.free(vec2);

    // Same input should produce same output
    try std.testing.expectEqual(vec1.len, vec2.len);
    for (vec1, vec2) |v1, v2| {
        try std.testing.expectEqual(v1, v2);
    }
}

test "EmbeddingModel embed with normalization" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
        .normalize = true,
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    const vec = try model.embed("Test text");
    defer allocator.free(vec);

    // Normalized vector should have unit length
    const norm = vectorNorm(vec);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, 0.0001);
}

test "EmbeddingModel different texts produce different embeddings" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    const vec1 = try model.embed("Hello");
    defer allocator.free(vec1);

    const vec2 = try model.embed("Goodbye");
    defer allocator.free(vec2);

    // Different texts should produce different embeddings
    const sim = cosineSimilarity(vec1, vec2);
    try std.testing.expect(sim < 1.0);
}

test "EmbeddingModel embedBatch" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    const texts = [_][]const u8{ "First text", "Second text", "Third text" };

    const batch_results = try model.embedBatch(&texts);
    defer model.freeBatch(batch_results);

    try std.testing.expectEqual(@as(usize, 3), batch_results.len);

    // Each result should have correct dimension
    for (batch_results) |vec| {
        try std.testing.expectEqual(@as(usize, DEFAULT_EMBEDDING_DIM), vec.len);
    }
}

test "EmbeddingModel empty input error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forEmbedding("/path/to/model.gguf");

    const config = EmbeddingConfig{
        .model = model_config,
    };

    var model = try EmbeddingModel.init(config, allocator);
    defer model.deinit();

    const result = model.embed("");
    try std.testing.expectError(error.EmptyInput, result);
}

test "EmbeddingModel invalid path error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig{};
    // Empty path

    const config = EmbeddingConfig{
        .model = model_config,
    };

    const result = EmbeddingModel.init(config, allocator);
    try std.testing.expectError(error.InvalidModelPath, result);
}

test "EmbeddingModel unsupported format error" {
    const allocator = std.testing.allocator;

    // Use forEmbedding with a path that has an unknown extension
    const model_config = ModelConfig.forEmbedding("/path/to/model.unknown");

    const config = EmbeddingConfig{
        .model = model_config,
    };

    const result = EmbeddingModel.init(config, allocator);
    try std.testing.expectError(error.UnsupportedFormat, result);
}
