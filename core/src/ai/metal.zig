//! Zylix AI - Metal/GPU Configuration
//!
//! Provides Metal GPU detection and configuration for Apple platforms.
//! Exposes GPU capabilities and allows fine-grained control over acceleration.
//!
//! ## Usage
//!
//! ```zig
//! const metal = @import("ai/metal.zig");
//!
//! // Check Metal availability
//! if (metal.isAvailable()) {
//!     const info = metal.getDeviceInfo();
//!     std.debug.print("GPU: {s}\n", .{info.getName()});
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

// === Constants ===

/// Maximum GPU device name length
pub const MAX_DEVICE_NAME_LEN: usize = 128;

/// Maximum number of GPU devices
pub const MAX_GPU_DEVICES: usize = 8;

// === Types ===

/// GPU/Metal device capabilities
pub const DeviceCapabilities = struct {
    /// Supports unified memory (Apple Silicon)
    unified_memory: bool = false,
    /// Supports Neural Engine acceleration
    neural_engine: bool = false,
    /// Supports float16 (half precision)
    float16: bool = false,
    /// Supports bfloat16
    bfloat16: bool = false,
    /// Maximum buffer size in bytes
    max_buffer_size: u64 = 0,
    /// Maximum threads per threadgroup
    max_threads_per_group: u32 = 0,
    /// Recommended working set size in bytes
    recommended_working_set: u64 = 0,
    /// GPU family (Apple GPU family number)
    gpu_family: u32 = 0,
};

/// GPU device information
pub const DeviceInfo = struct {
    /// Device name
    name: [MAX_DEVICE_NAME_LEN]u8 = [_]u8{0} ** MAX_DEVICE_NAME_LEN,
    name_len: usize = 0,

    /// Device index
    index: u32 = 0,

    /// Is this the default device
    is_default: bool = false,

    /// Is this a discrete GPU (vs integrated)
    is_discrete: bool = false,

    /// Is this a low-power device
    is_low_power: bool = false,

    /// Total VRAM in bytes (0 for unified memory)
    vram_size: u64 = 0,

    /// Device capabilities
    capabilities: DeviceCapabilities = .{},

    /// Get device name as slice
    pub fn getName(self: *const DeviceInfo) []const u8 {
        return self.name[0..self.name_len];
    }

    /// Set device name
    pub fn setName(self: *DeviceInfo, device_name: []const u8) void {
        const len = @min(device_name.len, MAX_DEVICE_NAME_LEN - 1);
        @memcpy(self.name[0..len], device_name[0..len]);
        self.name[len] = 0;
        self.name_len = len;
    }
};

/// Metal/GPU configuration
pub const MetalConfig = struct {
    /// Enable Metal acceleration
    enabled: bool = true,

    /// Preferred GPU device index (0 = default)
    device_index: u32 = 0,

    /// Number of GPU layers to offload (0 = auto, -1 = all)
    gpu_layers: i32 = 0,

    /// Use low-power GPU if available
    prefer_low_power: bool = false,

    /// Use Neural Engine when available
    use_neural_engine: bool = true,

    /// Maximum memory to use on GPU (0 = auto)
    max_gpu_memory_mb: u32 = 0,

    /// Enable async compute
    async_compute: bool = true,

    /// Command buffer count for pipelining
    command_buffer_count: u32 = 2,
};

/// Metal runtime status
pub const MetalStatus = enum(u8) {
    /// Not available on this platform
    unavailable = 0,
    /// Available but not initialized
    available = 1,
    /// Initialized and ready
    ready = 2,
    /// Error during initialization
    @"error" = 3,
};

// === Platform Detection ===

/// Check if Metal is available on this platform
pub fn isAvailable() bool {
    return switch (builtin.os.tag) {
        .macos, .ios, .tvos, .watchos => true,
        else => false,
    };
}

/// Check if this is an Apple Silicon device
pub fn isAppleSilicon() bool {
    if (!isAvailable()) return false;

    return switch (builtin.cpu.arch) {
        .aarch64 => switch (builtin.os.tag) {
            .macos, .ios, .tvos, .watchos => true,
            else => false,
        },
        else => false,
    };
}

/// Check if Neural Engine is likely available
pub fn hasNeuralEngine() bool {
    // Neural Engine is available on A11+ (iPhone 8+) and M1+
    return isAppleSilicon();
}

// === Device Information ===

/// Get default GPU device info
pub fn getDefaultDeviceInfo() DeviceInfo {
    var info = DeviceInfo{};
    info.is_default = true;

    if (isAppleSilicon()) {
        // Apple Silicon characteristics
        info.setName("Apple GPU");
        info.capabilities.unified_memory = true;
        info.capabilities.neural_engine = hasNeuralEngine();
        info.capabilities.float16 = true;
        info.capabilities.bfloat16 = true;
        info.capabilities.gpu_family = 8; // Apple8 family (M1+)

        // Estimate memory (unified, so typically large)
        info.capabilities.recommended_working_set = 8 * 1024 * 1024 * 1024; // 8GB default
        info.capabilities.max_threads_per_group = 1024;
    } else if (builtin.os.tag == .macos and builtin.cpu.arch == .x86_64) {
        // Intel Mac with possible discrete GPU
        info.setName("Intel/AMD GPU");
        info.capabilities.float16 = true;
        info.capabilities.max_threads_per_group = 1024;
    } else {
        info.setName("Unknown GPU");
    }

    return info;
}

/// Get number of available GPU devices
pub fn getDeviceCount() u32 {
    if (!isAvailable()) return 0;
    // For now, return 1 (default device)
    // Full implementation would query Metal for all devices
    return 1;
}

// === Recommended Settings ===

/// GPU layer offload recommendation
pub const LayerRecommendation = struct {
    /// Recommended number of layers to offload
    recommended_layers: i32,
    /// Maximum safe layers to offload
    max_layers: i32,
    /// Explanation for the recommendation
    reason: []const u8,
};

/// Get recommended GPU layers for a model size
pub fn getRecommendedLayers(model_size_mb: u64, available_vram_mb: u64) LayerRecommendation {
    if (!isAvailable()) {
        return .{
            .recommended_layers = 0,
            .max_layers = 0,
            .reason = "Metal not available",
        };
    }

    // Estimate layers based on model size and available memory
    // Typical: each layer needs ~100-500MB depending on model architecture

    const layer_estimate_mb: u64 = 200; // Conservative estimate
    const buffer_mb: u64 = 512; // Keep some buffer for other operations

    if (available_vram_mb < buffer_mb) {
        return .{
            .recommended_layers = 0,
            .max_layers = 0,
            .reason = "Insufficient GPU memory",
        };
    }

    const usable_vram = available_vram_mb - buffer_mb;
    const max_layers_from_vram = @as(i32, @intCast(usable_vram / layer_estimate_mb));

    // Estimate total layers from model size
    const estimated_total_layers = @as(i32, @intCast(model_size_mb / layer_estimate_mb));

    if (isAppleSilicon()) {
        // Apple Silicon: unified memory, can offload more aggressively
        return .{
            .recommended_layers = @min(estimated_total_layers, max_layers_from_vram),
            .max_layers = estimated_total_layers,
            .reason = "Apple Silicon unified memory",
        };
    } else {
        // Discrete GPU: be more conservative
        return .{
            .recommended_layers = @min(max_layers_from_vram, estimated_total_layers / 2),
            .max_layers = max_layers_from_vram,
            .reason = "Discrete GPU with dedicated VRAM",
        };
    }
}

/// Get default Metal configuration for this device
pub fn getDefaultConfig() MetalConfig {
    var config = MetalConfig{};

    if (!isAvailable()) {
        config.enabled = false;
        return config;
    }

    if (isAppleSilicon()) {
        // Apple Silicon: aggressive GPU usage
        config.gpu_layers = -1; // All layers
        config.use_neural_engine = true;
        config.async_compute = true;
    } else {
        // Intel Mac: conservative GPU usage
        config.gpu_layers = 0; // Auto
        config.prefer_low_power = false;
    }

    return config;
}

// === Memory Estimation ===

/// Estimate GPU memory requirements for inference
pub fn estimateGpuMemory(model_size_mb: u64, context_length: u32, batch_size: u32) u64 {
    // Model weights
    var total_mb: u64 = model_size_mb;

    // KV cache: roughly context_length * embedding_dim * 2 (K and V) * num_layers
    // Simplified estimate: ~0.5MB per 1K context for typical models
    const kv_cache_mb: u64 = (@as(u64, context_length) * batch_size) / 2048;
    total_mb += kv_cache_mb;

    // Intermediate buffers: ~10% of model size
    total_mb += model_size_mb / 10;

    // Metal command buffers and misc: ~100MB
    total_mb += 100;

    return total_mb;
}

// === Utility ===

/// Format GPU memory size for display
pub fn formatMemorySize(bytes: u64, buffer: []u8) []const u8 {
    if (bytes >= 1024 * 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} GB", .{
            @as(f64, @floatFromInt(bytes)) / (1024 * 1024 * 1024),
        }) catch "? GB";
    } else if (bytes >= 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} MB", .{
            @as(f64, @floatFromInt(bytes)) / (1024 * 1024),
        }) catch "? MB";
    } else {
        return std.fmt.bufPrint(buffer, "{d} KB", .{bytes / 1024}) catch "? KB";
    }
}

/// Get platform description string
pub fn getPlatformDescription() []const u8 {
    if (!isAvailable()) {
        return "No Metal support";
    }

    if (isAppleSilicon()) {
        return "Apple Silicon (Metal + Neural Engine)";
    } else if (builtin.os.tag == .macos) {
        return "macOS (Metal)";
    } else if (builtin.os.tag == .ios) {
        return "iOS (Metal + Neural Engine)";
    } else {
        return "Apple Platform (Metal)";
    }
}

// === Tests ===

test "isAvailable" {
    const available = isAvailable();
    // On macOS, should be available
    if (builtin.os.tag == .macos) {
        try std.testing.expect(available);
    }
}

test "isAppleSilicon" {
    const is_as = isAppleSilicon();
    // On Apple Silicon Mac, should be true
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        try std.testing.expect(is_as);
    }
}

test "getDefaultDeviceInfo" {
    const info = getDefaultDeviceInfo();
    try std.testing.expect(info.is_default);
    try std.testing.expect(info.getName().len > 0);
}

test "getDefaultConfig" {
    const config = getDefaultConfig();
    if (isAvailable()) {
        try std.testing.expect(config.enabled);
    } else {
        try std.testing.expect(!config.enabled);
    }
}

test "estimateGpuMemory" {
    const mem = estimateGpuMemory(4096, 2048, 1);
    try std.testing.expect(mem > 4096); // Should be more than just model size
}

test "formatMemorySize" {
    var buffer: [32]u8 = undefined;

    const gb = formatMemorySize(2 * 1024 * 1024 * 1024, &buffer);
    try std.testing.expectEqualStrings("2.0 GB", gb);

    const mb = formatMemorySize(512 * 1024 * 1024, &buffer);
    try std.testing.expectEqualStrings("512.0 MB", mb);
}
