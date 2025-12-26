---
title: "AI Module"
weight: 6
---

# AI Module

The AI module provides integration with local AI/ML backends including Whisper (speech-to-text) and Vision Language Models (VLM).

## Overview

```
┌─────────────────────────────────────────────┐
│                 AI Module                    │
│  ┌───────────────────────────────────────┐  │
│  │           Model Manager               │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────┐  ┌───────────────────┐   │
│  │    Whisper    │  │       VLM         │   │
│  │  (Speech-to-  │  │  (Vision Language │   │
│  │     Text)     │  │      Model)       │   │
│  └───────────────┘  └───────────────────┘   │
│              │                │              │
│              ▼                ▼              │
│  ┌───────────────────────────────────────┐  │
│  │     llama.cpp / whisper.cpp           │  │
│  │         (Native Backend)              │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## Model Types

```zig
pub const ModelType = enum {
    /// Text generation (LLaMA, Mistral, etc.)
    text,

    /// Speech-to-text (Whisper)
    whisper,

    /// Vision-language (LLaVA, etc.)
    vision,

    /// Text-to-speech
    tts,

    /// Embedding models
    embedding,
};

pub const ModelFormat = enum {
    gguf,      // GGUF format (recommended)
    ggml,      // Legacy GGML format
    safetensors,
    pytorch,
};
```

## Whisper Backend

Speech-to-text transcription using Whisper models.

### Configuration

```zig
pub const WhisperConfig = struct {
    /// Path to Whisper model file (.bin)
    model_path: []const u8 = "",

    /// Target language (empty = auto-detect)
    language: []const u8 = "",

    /// Translate to English
    translate: bool = false,

    /// Number of CPU threads
    n_threads: u8 = 4,

    /// Use GPU acceleration
    use_gpu: bool = true,

    /// Print progress during transcription
    print_progress: bool = false,

    /// Maximum tokens per segment
    max_tokens_per_segment: u32 = 0,
};
```

### Usage

```zig
const ai = @import("ai/ai.zig");

// Check if Whisper is available
if (!ai.whisper.isWhisperAvailable()) {
    std.debug.print("Whisper not available on this platform\n", .{});
    return;
}

// Initialize backend
var config = ai.whisper.WhisperConfig{
    .model_path = "models/whisper-base.bin",
    .language = "en",
    .n_threads = 4,
};

var backend = try ai.whisper.WhisperBackend.init(allocator, config);
defer backend.deinit();

// Check status
if (backend.getStatus() != .ready) {
    return error.BackendNotReady;
}

// Transcribe audio
const audio_samples: []const f32 = ...;  // 16kHz mono audio
const result = try backend.transcribe(audio_samples);
defer allocator.free(result.text);

std.debug.print("Transcription: {s}\n", .{result.text});
std.debug.print("Language: {s}\n", .{result.language});
```

### Status

```zig
pub const WhisperStatus = enum(u8) {
    uninitialized = 0,
    loading = 1,
    ready = 2,
    transcribing = 3,
    @"error" = 4,
    shutdown = 5,
};
```

### Transcription Result

```zig
pub const TranscriptResult = struct {
    /// Transcribed text
    text: []u8,
    text_len: usize,

    /// Detected language code
    language: [8]u8,

    /// Number of segments
    n_segments: usize,
};
```

### Audio Requirements

- **Sample Rate**: 16,000 Hz (use `ai.whisper.getSampleRate()`)
- **Channels**: Mono
- **Format**: 32-bit float PCM

## VLM Backend

Vision Language Model for image understanding.

### Configuration

```zig
pub const VLMConfig = struct {
    /// Path to language model
    model_path: []const u8 = "",

    /// Path to multimodal projector
    mmproj_path: []const u8 = "",

    /// Number of CPU threads
    n_threads: u32 = 4,

    /// Use GPU acceleration
    use_gpu: bool = true,

    /// Context size
    n_ctx: u32 = 2048,

    /// Maximum output tokens
    max_tokens: u32 = 512,

    /// Sampling temperature
    temperature: f32 = 0.1,

    /// Top-p sampling
    top_p: f32 = 0.9,
};
```

### Usage

```zig
const ai = @import("ai/ai.zig");

// Check if VLM is available
if (!ai.vlm.isVLMAvailable()) {
    std.debug.print("VLM not available on this platform\n", .{});
    return;
}

// Initialize backend
var config = ai.vlm.VLMConfig{
    .model_path = "models/llava-1.5-7b.gguf",
    .mmproj_path = "models/llava-1.5-mmproj.gguf",
    .n_threads = 4,
    .max_tokens = 256,
};

var backend = try ai.vlm.VLMBackend.init(allocator, config);
defer backend.deinit();

// Analyze image
const image_data: []const u8 = ...;  // Image bytes (JPEG, PNG)
const prompt = "Describe this image in detail.";
const result = try backend.analyze(image_data, prompt);

std.debug.print("Analysis: {s}\n", .{result.text[0..result.text_len]});
std.debug.print("Tokens: {d} in, {d} out\n", .{
    result.n_input_tokens,
    result.n_output_tokens,
});
```

### Status

```zig
pub const VLMStatus = enum {
    uninitialized,
    ready,
    processing,
    error_state,
};
```

### Analysis Result

```zig
pub const AnalysisResult = struct {
    /// Generated text
    text_len: usize,

    /// Token counts
    n_input_tokens: usize,
    n_output_tokens: usize,

    /// Processing time in milliseconds
    processing_time_ms: u64,

    /// Detected language
    language: [8]u8,
};
```

### Capabilities

```zig
// Check model capabilities
if (backend.supportsVision()) {
    // Can process images
}

if (backend.supportsAudio()) {
    // Can process audio (future)
}
```

## Platform Availability

The AI backends have different availability depending on the platform:

| Platform | Whisper | VLM | Notes |
|----------|---------|-----|-------|
| macOS (Apple Silicon) | Yes | Yes | Full GPU acceleration via Metal |
| macOS (Intel) | Yes | Yes | CPU only |
| iOS | Yes | Limited | On-device, memory constraints |
| Android | Yes | Limited | NNAPI acceleration |
| Linux (CUDA) | Yes | Yes | Full GPU acceleration |
| Linux (CPU) | Yes | Yes | AVX/AVX2 optimized |
| Windows | Yes | Yes | CUDA or CPU |
| Web (WASM) | No | No | Stub only (use server-side) |

## Stub Modules

For platforms without native C support (e.g., WASM), stub modules are provided:

```zig
// whisper_backend_stub.zig
pub fn isWhisperAvailable() bool {
    return false;  // Always false on unsupported platforms
}

// vlm_backend_stub.zig
pub fn isVLMAvailable() bool {
    return false;  // Always false on unsupported platforms
}
```

Platform shells should check availability before using AI features:

```swift
// iOS Example
if zylix_ai_whisper_available() {
    // Show transcription UI
} else {
    // Hide or disable feature
}
```

## Model Management

### Downloading Models

```zig
const ai = @import("ai/ai.zig");

// Download from Hugging Face
try ai.models.download(.{
    .repo = "ggerganov/whisper.cpp",
    .file = "ggml-base.bin",
    .destination = "models/whisper-base.bin",
    .progress_callback = progressHandler,
});

// Verify checksum
const valid = try ai.models.verify(
    "models/whisper-base.bin",
    "sha256:abc123...",
);
```

### Model Info

```zig
const info = try ai.models.getInfo("models/llava.gguf");
std.debug.print("Model: {s}\n", .{info.name});
std.debug.print("Parameters: {d}B\n", .{info.n_params / 1_000_000_000});
std.debug.print("Quantization: {s}\n", .{@tagName(info.quantization)});
std.debug.print("Context Size: {d}\n", .{info.n_ctx});
```

## Performance Tips

1. **Model Selection**: Use quantized models (Q4_K_M, Q5_K_M) for mobile
2. **Batch Processing**: Process multiple requests together when possible
3. **Caching**: Cache model instances across requests
4. **Memory Management**: Unload unused models to free memory
5. **Threading**: Adjust `n_threads` based on device capabilities
