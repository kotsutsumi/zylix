//! Zylix AI - Vision Language Model (VLM)
//!
//! Image understanding and analysis functionality.
//! Combines vision and language models for tasks like OCR, image description,
//! and visual question answering.
//!
//! ## Usage
//!
//! ```zig
//! const vlm = @import("ai/vlm.zig");
//!
//! // Load model
//! var model = try vlm.VLMModel.init(config, allocator);
//! defer model.deinit();
//!
//! // Analyze image
//! const image = vlm.Image{ .data = image_bytes, .width = 640, .height = 480, .format = .rgb };
//! const description = try model.analyze(image, "Describe this image");
//! defer allocator.free(description);
//!
//! // OCR
//! const text = try model.extractText(image);
//! defer allocator.free(text);
//! ```

const std = @import("std");
const types = @import("types.zig");
const ModelConfig = types.ModelConfig;
const ModelFormat = types.ModelFormat;
const GenerateParams = types.GenerateParams;
const Result = types.Result;

// === Constants ===

/// Maximum image dimension (pixels)
pub const MAX_IMAGE_DIMENSION: u32 = 4096;

/// Maximum image size in bytes
pub const MAX_IMAGE_SIZE: usize = 16 * 1024 * 1024; // 16MB

/// Default max image size for processing
pub const DEFAULT_MAX_IMAGE_SIZE: u32 = 1024;

/// Maximum prompt length for VLM
pub const MAX_PROMPT_LENGTH: usize = 4096;

/// Maximum output length
pub const MAX_OUTPUT_LENGTH: usize = 4096;

// === Image Types ===

/// Image pixel format
pub const ImageFormat = enum(u8) {
    /// RGB (3 bytes per pixel)
    rgb = 0,
    /// RGBA (4 bytes per pixel)
    rgba = 1,
    /// Grayscale (1 byte per pixel)
    grayscale = 2,
    /// BGR (3 bytes per pixel, OpenCV format)
    bgr = 3,
    /// BGRA (4 bytes per pixel)
    bgra = 4,
};

/// Image data structure
pub const Image = struct {
    /// Raw pixel data
    data: []const u8,
    /// Image width in pixels
    width: u32,
    /// Image height in pixels
    height: u32,
    /// Pixel format
    format: ImageFormat,

    /// Get bytes per pixel for this format
    pub fn bytesPerPixel(self: *const Image) u8 {
        return switch (self.format) {
            .rgb, .bgr => 3,
            .rgba, .bgra => 4,
            .grayscale => 1,
        };
    }

    /// Get expected data size
    pub fn expectedDataSize(self: *const Image) usize {
        return @as(usize, self.width) * @as(usize, self.height) * @as(usize, self.bytesPerPixel());
    }

    /// Validate image data
    pub fn isValid(self: *const Image) bool {
        if (self.width == 0 or self.height == 0) return false;
        if (self.width > MAX_IMAGE_DIMENSION or self.height > MAX_IMAGE_DIMENSION) return false;
        if (self.data.len != self.expectedDataSize()) return false;
        return true;
    }
};

// === VLM Configuration ===

/// Configuration for VLM operations
pub const VLMConfig = struct {
    /// Model configuration
    model: ModelConfig,

    /// Maximum image size (will resize if larger)
    max_image_size: u32 = DEFAULT_MAX_IMAGE_SIZE,

    /// Enable automatic image preprocessing
    preprocess: bool = true,

    /// Context length for text generation
    context_length: u32 = 2048,
};

// === Analysis Result ===

/// Result of VLM analysis
pub const AnalysisResult = struct {
    /// Generated text response
    text: []u8,

    /// Confidence score (0.0 - 1.0)
    confidence: f32,

    /// Processing time in milliseconds
    processing_time_ms: u64,
};

// === VLM Model ===

/// Vision Language Model for image understanding
pub const VLMModel = struct {
    config: VLMConfig,
    allocator: std.mem.Allocator,
    initialized: bool,

    const Self = @This();

    /// Initialize VLM model
    pub fn init(config: VLMConfig, allocator: std.mem.Allocator) !Self {
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

        return Self{
            .config = config,
            .allocator = allocator,
            .initialized = true,
        };
    }

    /// Check if model is ready
    pub fn isReady(self: *const Self) bool {
        return self.initialized;
    }

    /// Analyze image with a prompt
    /// Caller owns the returned slice and must free it
    pub fn analyze(self: *Self, image: Image, prompt: []const u8) ![]u8 {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (!image.isValid()) {
            return error.InvalidImage;
        }

        if (prompt.len == 0) {
            return error.EmptyPrompt;
        }

        if (prompt.len > MAX_PROMPT_LENGTH) {
            return error.PromptTooLong;
        }

        // TODO: Replace with actual VLM inference
        // For now, generate placeholder response
        var temp_buffer: [MAX_OUTPUT_LENGTH]u8 = undefined;
        const response_len = self.generatePlaceholderResponse(image, prompt, &temp_buffer);

        // Allocate exact size for result
        const result = try self.allocator.alloc(u8, response_len);
        @memcpy(result, temp_buffer[0..response_len]);

        return result;
    }

    /// Extract text from image (OCR)
    /// Caller owns the returned slice and must free it
    pub fn extractText(self: *Self, image: Image) ![]u8 {
        return self.analyze(image, "Extract all text from this image exactly as it appears.");
    }

    /// Describe image contents
    /// Caller owns the returned slice and must free it
    pub fn describe(self: *Self, image: Image) ![]u8 {
        return self.analyze(image, "Describe this image in detail.");
    }

    /// Answer a question about the image
    /// Caller owns the returned slice and must free it
    pub fn ask(self: *Self, image: Image, question: []const u8) ![]u8 {
        return self.analyze(image, question);
    }

    /// Generate placeholder response (for testing before backend integration)
    fn generatePlaceholderResponse(self: *const Self, image: Image, prompt: []const u8, output: []u8) usize {
        _ = self;

        const prompt_snippet_len = @min(prompt.len, 30);

        var writer = std.io.fixedBufferStream(output);
        writer.writer().print(
            "VLM Analysis: Image {d}x{d} ({s} format). Prompt: \"{s}...\"",
            .{
                image.width,
                image.height,
                @tagName(image.format),
                prompt[0..prompt_snippet_len],
            },
        ) catch {};

        return writer.pos;
    }

    /// Deinitialize model
    pub fn deinit(self: *Self) void {
        self.initialized = false;
    }
};

// === Image Processing Utilities ===

/// Resize image to fit within max dimensions (maintains aspect ratio)
/// Caller owns the returned data and must free it
pub fn resizeImage(image: Image, max_size: u32, allocator: std.mem.Allocator) !Image {
    if (image.width <= max_size and image.height <= max_size) {
        // No resize needed, copy the data
        const data_copy = try allocator.alloc(u8, image.data.len);
        @memcpy(data_copy, image.data);
        return Image{
            .data = data_copy,
            .width = image.width,
            .height = image.height,
            .format = image.format,
        };
    }

    // Calculate new dimensions maintaining aspect ratio
    const scale = @min(
        @as(f32, @floatFromInt(max_size)) / @as(f32, @floatFromInt(image.width)),
        @as(f32, @floatFromInt(max_size)) / @as(f32, @floatFromInt(image.height)),
    );

    const new_width: u32 = @intFromFloat(@as(f32, @floatFromInt(image.width)) * scale);
    const new_height: u32 = @intFromFloat(@as(f32, @floatFromInt(image.height)) * scale);
    const bpp = image.bytesPerPixel();

    // Allocate new image buffer
    const new_size = @as(usize, new_width) * @as(usize, new_height) * @as(usize, bpp);
    const new_data = try allocator.alloc(u8, new_size);

    // TODO: Implement actual image resizing (nearest neighbor for now - placeholder)
    // For now, just fill with placeholder data
    @memset(new_data, 128);

    return Image{
        .data = new_data,
        .width = new_width,
        .height = new_height,
        .format = image.format,
    };
}

/// Convert image to RGB format
/// Caller owns the returned data and must free it
pub fn convertToRGB(image: Image, allocator: std.mem.Allocator) !Image {
    if (image.format == .rgb) {
        // Already RGB, copy the data
        const data_copy = try allocator.alloc(u8, image.data.len);
        @memcpy(data_copy, image.data);
        return Image{
            .data = data_copy,
            .width = image.width,
            .height = image.height,
            .format = .rgb,
        };
    }

    const new_size = @as(usize, image.width) * @as(usize, image.height) * 3;
    const new_data = try allocator.alloc(u8, new_size);

    // Convert based on source format
    switch (image.format) {
        .rgba => {
            // Remove alpha channel
            var src_idx: usize = 0;
            var dst_idx: usize = 0;
            while (src_idx < image.data.len) : ({
                src_idx += 4;
                dst_idx += 3;
            }) {
                new_data[dst_idx] = image.data[src_idx];
                new_data[dst_idx + 1] = image.data[src_idx + 1];
                new_data[dst_idx + 2] = image.data[src_idx + 2];
            }
        },
        .bgr => {
            // Swap B and R channels
            var i: usize = 0;
            while (i < image.data.len) : (i += 3) {
                new_data[i] = image.data[i + 2]; // R
                new_data[i + 1] = image.data[i + 1]; // G
                new_data[i + 2] = image.data[i]; // B
            }
        },
        .bgra => {
            // Swap B/R and remove alpha
            var src_idx: usize = 0;
            var dst_idx: usize = 0;
            while (src_idx < image.data.len) : ({
                src_idx += 4;
                dst_idx += 3;
            }) {
                new_data[dst_idx] = image.data[src_idx + 2]; // R
                new_data[dst_idx + 1] = image.data[src_idx + 1]; // G
                new_data[dst_idx + 2] = image.data[src_idx]; // B
            }
        },
        .grayscale => {
            // Expand to RGB
            for (image.data, 0..) |gray, i| {
                const dst_idx = i * 3;
                new_data[dst_idx] = gray;
                new_data[dst_idx + 1] = gray;
                new_data[dst_idx + 2] = gray;
            }
        },
        .rgb => unreachable, // Handled above
    }

    return Image{
        .data = new_data,
        .width = image.width,
        .height = image.height,
        .format = .rgb,
    };
}

// === Tests ===

test "Image validation" {
    // Valid image
    var data = [_]u8{0} ** (100 * 100 * 3);
    const valid_image = Image{
        .data = &data,
        .width = 100,
        .height = 100,
        .format = .rgb,
    };
    try std.testing.expect(valid_image.isValid());

    // Invalid: zero dimensions
    const zero_width = Image{
        .data = &data,
        .width = 0,
        .height = 100,
        .format = .rgb,
    };
    try std.testing.expect(!zero_width.isValid());

    // Invalid: dimension too large
    const too_large = Image{
        .data = &data,
        .width = MAX_IMAGE_DIMENSION + 1,
        .height = 100,
        .format = .rgb,
    };
    try std.testing.expect(!too_large.isValid());
}

test "Image bytesPerPixel" {
    const rgb_image = Image{ .data = &.{}, .width = 1, .height = 1, .format = .rgb };
    try std.testing.expectEqual(@as(u8, 3), rgb_image.bytesPerPixel());

    const rgba_image = Image{ .data = &.{}, .width = 1, .height = 1, .format = .rgba };
    try std.testing.expectEqual(@as(u8, 4), rgba_image.bytesPerPixel());

    const gray_image = Image{ .data = &.{}, .width = 1, .height = 1, .format = .grayscale };
    try std.testing.expectEqual(@as(u8, 1), gray_image.bytesPerPixel());
}

test "Image expectedDataSize" {
    const image = Image{ .data = &.{}, .width = 100, .height = 50, .format = .rgb };
    try std.testing.expectEqual(@as(usize, 100 * 50 * 3), image.expectedDataSize());
}

test "VLMModel initialization" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    try std.testing.expect(model.isReady());
}

test "VLMModel analyze" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    // Create test image
    var image_data = [_]u8{128} ** (64 * 64 * 3);
    const image = Image{
        .data = &image_data,
        .width = 64,
        .height = 64,
        .format = .rgb,
    };

    const result = try model.analyze(image, "What is in this image?");
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}

test "VLMModel extractText" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    var image_data = [_]u8{255} ** (32 * 32 * 3);
    const image = Image{
        .data = &image_data,
        .width = 32,
        .height = 32,
        .format = .rgb,
    };

    const result = try model.extractText(image);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}

test "VLMModel describe" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    var image_data = [_]u8{0} ** (16 * 16 * 3);
    const image = Image{
        .data = &image_data,
        .width = 16,
        .height = 16,
        .format = .rgb,
    };

    const result = try model.describe(image);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}

test "VLMModel invalid image error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    // Invalid image (wrong data size)
    var image_data = [_]u8{0} ** 10; // Too small for 64x64
    const invalid_image = Image{
        .data = &image_data,
        .width = 64,
        .height = 64,
        .format = .rgb,
    };

    const result = model.analyze(invalid_image, "Test");
    try std.testing.expectError(error.InvalidImage, result);
}

test "VLMModel empty prompt error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forVLM("/path/to/model.gguf");

    const config = VLMConfig{
        .model = model_config,
    };

    var model = try VLMModel.init(config, allocator);
    defer model.deinit();

    var image_data = [_]u8{0} ** (8 * 8 * 3);
    const image = Image{
        .data = &image_data,
        .width = 8,
        .height = 8,
        .format = .rgb,
    };

    const result = model.analyze(image, "");
    try std.testing.expectError(error.EmptyPrompt, result);
}

test "VLMModel invalid path error" {
    const allocator = std.testing.allocator;

    var model_config = ModelConfig{};
    model_config.model_type = .vlm;

    const config = VLMConfig{
        .model = model_config,
    };

    const result = VLMModel.init(config, allocator);
    try std.testing.expectError(error.InvalidModelPath, result);
}

test "convertToRGB from grayscale" {
    const allocator = std.testing.allocator;

    // Create grayscale image
    const gray_data = [_]u8{ 100, 150, 200, 50 }; // 2x2 grayscale
    const gray_image = Image{
        .data = &gray_data,
        .width = 2,
        .height = 2,
        .format = .grayscale,
    };

    const rgb_image = try convertToRGB(gray_image, allocator);
    defer allocator.free(@constCast(rgb_image.data));

    try std.testing.expectEqual(@as(u32, 2), rgb_image.width);
    try std.testing.expectEqual(@as(u32, 2), rgb_image.height);
    try std.testing.expectEqual(ImageFormat.rgb, rgb_image.format);
    try std.testing.expectEqual(@as(usize, 2 * 2 * 3), rgb_image.data.len);

    // Check that grayscale values are replicated to R, G, B
    try std.testing.expectEqual(@as(u8, 100), rgb_image.data[0]); // R
    try std.testing.expectEqual(@as(u8, 100), rgb_image.data[1]); // G
    try std.testing.expectEqual(@as(u8, 100), rgb_image.data[2]); // B
}

test "convertToRGB from BGR" {
    const allocator = std.testing.allocator;

    // Create BGR image (B=10, G=20, R=30)
    const bgr_data = [_]u8{ 10, 20, 30 }; // 1x1 BGR
    const bgr_image = Image{
        .data = &bgr_data,
        .width = 1,
        .height = 1,
        .format = .bgr,
    };

    const rgb_image = try convertToRGB(bgr_image, allocator);
    defer allocator.free(@constCast(rgb_image.data));

    // Check BGR -> RGB conversion (B and R swapped)
    try std.testing.expectEqual(@as(u8, 30), rgb_image.data[0]); // R (was B in BGR)
    try std.testing.expectEqual(@as(u8, 20), rgb_image.data[1]); // G
    try std.testing.expectEqual(@as(u8, 10), rgb_image.data[2]); // B (was R in BGR)
}

test "resizeImage no resize needed" {
    const allocator = std.testing.allocator;

    var data = [_]u8{128} ** (50 * 50 * 3);
    const image = Image{
        .data = &data,
        .width = 50,
        .height = 50,
        .format = .rgb,
    };

    const resized = try resizeImage(image, 100, allocator);
    defer allocator.free(@constCast(resized.data));

    // Should be same dimensions
    try std.testing.expectEqual(@as(u32, 50), resized.width);
    try std.testing.expectEqual(@as(u32, 50), resized.height);
}

test "resizeImage downscale" {
    const allocator = std.testing.allocator;

    var data = [_]u8{255} ** (200 * 100 * 3);
    const image = Image{
        .data = &data,
        .width = 200,
        .height = 100,
        .format = .rgb,
    };

    const resized = try resizeImage(image, 50, allocator);
    defer allocator.free(@constCast(resized.data));

    // Should be scaled down (200x100 -> 50x25, maintaining 2:1 aspect)
    try std.testing.expectEqual(@as(u32, 50), resized.width);
    try std.testing.expectEqual(@as(u32, 25), resized.height);
}
