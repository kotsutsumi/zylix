//! Metal Stub Module
//!
//! Provides stub types for platforms without Metal support.

pub const MAX_DEVICE_NAME_LEN: usize = 128;
pub const MAX_GPU_DEVICES: usize = 8;

pub const DeviceCapabilities = struct {
    unified_memory: bool = false,
    neural_engine: bool = false,
    float16: bool = false,
    bfloat16: bool = false,
    max_buffer_size: u64 = 0,
    max_threads_per_group: u32 = 0,
    recommended_working_set: u64 = 0,
    gpu_family: u32 = 0,
};

pub const MetalStatus = enum(u8) {
    unavailable = 0,
    available = 1,
    active = 2,
    @"error" = 3,
};

pub const MetalConfig = struct {
    enable_profiling: bool = false,
    prefer_neural_engine: bool = true,
    max_memory_mb: u32 = 0,
};

pub const DeviceInfo = struct {
    name: [MAX_DEVICE_NAME_LEN]u8 = [_]u8{0} ** MAX_DEVICE_NAME_LEN,
    name_len: usize = 0,
    capabilities: DeviceCapabilities = .{},
    is_available: bool = false,
    is_integrated: bool = false,

    pub fn getName(self: *const DeviceInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

/// Metal not available on stub platform
pub fn isAvailable() bool {
    return false;
}

/// Get stub device info
pub fn getDefaultDeviceInfo() DeviceInfo {
    return .{};
}

/// Get stub config
pub fn getDefaultConfig() MetalConfig {
    return .{};
}
