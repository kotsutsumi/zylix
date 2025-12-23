//! Target Capability Matrix API
//!
//! Query and manage target platform capabilities:
//! - Supported features per target
//! - Runtime capability detection
//! - Feature compatibility validation
//! - Dynamic UI field configuration
//!
//! This module provides platform capability information.

const std = @import("std");
const project = @import("project.zig");

/// Feature categories
pub const Feature = enum(u8) {
    // Core features
    gpu = 0,
    webgl = 1,
    metal = 2,
    vulkan = 3,
    directx = 4,

    // Platform features
    push_notifications = 10,
    in_app_purchase = 11,
    game_center = 12,
    google_play_services = 13,

    // Hardware features
    camera = 20,
    microphone = 21,
    accelerometer = 22,
    gyroscope = 23,
    haptics = 24,
    face_id = 25,
    touch_id = 26,
    nfc = 27,
    bluetooth = 28,

    // Storage features
    file_system = 30,
    keychain = 31,
    local_storage = 32,
    sqlite = 33,
    core_data = 34,

    // Network features
    websocket = 40,
    http2 = 41,
    http3 = 42,
    webrtc = 43,

    // UI features
    native_ui = 50,
    web_view = 51,
    split_view = 52,
    widgets = 53,
    live_activities = 54,

    // Debug features
    hot_reload = 60,
    remote_debug = 61,
    profiler = 62,
    inspector = 63,

    pub fn toString(self: Feature) []const u8 {
        return switch (self) {
            .gpu => "GPU Rendering",
            .webgl => "WebGL",
            .metal => "Metal",
            .vulkan => "Vulkan",
            .directx => "DirectX",
            .push_notifications => "Push Notifications",
            .in_app_purchase => "In-App Purchase",
            .game_center => "Game Center",
            .google_play_services => "Google Play Services",
            .camera => "Camera",
            .microphone => "Microphone",
            .accelerometer => "Accelerometer",
            .gyroscope => "Gyroscope",
            .haptics => "Haptics",
            .face_id => "Face ID",
            .touch_id => "Touch ID",
            .nfc => "NFC",
            .bluetooth => "Bluetooth",
            .file_system => "File System",
            .keychain => "Keychain",
            .local_storage => "Local Storage",
            .sqlite => "SQLite",
            .core_data => "Core Data",
            .websocket => "WebSocket",
            .http2 => "HTTP/2",
            .http3 => "HTTP/3",
            .webrtc => "WebRTC",
            .native_ui => "Native UI",
            .web_view => "Web View",
            .split_view => "Split View",
            .widgets => "Widgets",
            .live_activities => "Live Activities",
            .hot_reload => "Hot Reload",
            .remote_debug => "Remote Debugging",
            .profiler => "Profiler",
            .inspector => "Inspector",
        };
    }
};

/// Feature support level
pub const SupportLevel = enum(u8) {
    not_supported = 0,
    partial = 1,
    full = 2,
    native = 3, // Native platform feature

    pub fn isSupported(self: SupportLevel) bool {
        return self != .not_supported;
    }

    pub fn toString(self: SupportLevel) []const u8 {
        return switch (self) {
            .not_supported => "Not Supported",
            .partial => "Partial",
            .full => "Full",
            .native => "Native",
        };
    }
};

/// Input specification for target configuration
pub const InputSpec = struct {
    name: []const u8,
    label: []const u8,
    input_type: InputType,
    required: bool = false,
    default_value: ?[]const u8 = null,
    placeholder: ?[]const u8 = null,
    validation: ?[]const u8 = null,
    options: []const []const u8 = &.{},
};

/// Input types for UI generation
pub const InputType = enum(u8) {
    text = 0,
    number = 1,
    boolean = 2,
    select = 3,
    file = 4,
    directory = 5,
    password = 6,
    textarea = 7,
};

/// Capability matrix entry
pub const CapabilityEntry = struct {
    target: project.Target,
    feature: Feature,
    support: SupportLevel,
    notes: ?[]const u8 = null,
};

/// Capability matrix
pub const CapabilityMatrix = struct {
    entries: []const CapabilityEntry,

    pub fn getSupport(self: *const CapabilityMatrix, target: project.Target, feature: Feature) SupportLevel {
        for (self.entries) |entry| {
            if (entry.target == target and entry.feature == feature) {
                return entry.support;
            }
        }
        return .not_supported;
    }

    pub fn getSupportedFeatures(self: *const CapabilityMatrix, target: project.Target, allocator: std.mem.Allocator) ![]Feature {
        var features = std.ArrayList(Feature).init(allocator);
        for (self.entries) |entry| {
            if (entry.target == target and entry.support.isSupported()) {
                try features.append(entry.feature);
            }
        }
        return features.toOwnedSlice();
    }
};

/// Target Manager
pub const Targets = struct {
    allocator: std.mem.Allocator,
    capabilities: CapabilityMatrix,
    inputs: std.AutoHashMapUnmanaged(project.Target, []const InputSpec) = .{},

    pub fn init(allocator: std.mem.Allocator) Targets {
        return .{
            .allocator = allocator,
            .capabilities = getDefaultCapabilities(),
        };
    }

    pub fn deinit(self: *Targets) void {
        self.inputs.deinit(self.allocator);
    }

    /// Get full capability matrix
    pub fn getCapabilities(self: *const Targets) CapabilityMatrix {
        return self.capabilities;
    }

    /// Check if target supports a feature
    pub fn supportsFeature(self: *const Targets, target: project.Target, feature: Feature) bool {
        return self.capabilities.getSupport(target, feature).isSupported();
    }

    /// Get support level for a feature
    pub fn getFeatureSupport(self: *const Targets, target: project.Target, feature: Feature) SupportLevel {
        return self.capabilities.getSupport(target, feature);
    }

    /// Get required inputs for target configuration
    pub fn getRequiredInputs(_: *const Targets, target: project.Target) []const InputSpec {
        return switch (target) {
            .ios => &ios_inputs,
            .android => &android_inputs,
            .web => &web_inputs,
            .macos => &macos_inputs,
            .windows => &windows_inputs,
            .linux => &linux_inputs,
            .embedded => &embedded_inputs,
        };
    }

    /// Get all available targets
    pub fn getAllTargets() []const project.Target {
        return &all_targets;
    }

    /// Check if targets are compatible (can share code)
    pub fn areCompatible(target1: project.Target, target2: project.Target) bool {
        // Mobile targets are compatible
        if (target1.isMobile() and target2.isMobile()) return true;
        // Desktop targets are compatible
        if (target1.isDesktop() and target2.isDesktop()) return true;
        // Same target is compatible
        return target1 == target2;
    }
};

// Static data
const all_targets = [_]project.Target{
    .ios,
    .android,
    .web,
    .macos,
    .windows,
    .linux,
    .embedded,
};

const ios_inputs = [_]InputSpec{
    .{ .name = "bundle_id", .label = "Bundle ID", .input_type = .text, .required = true, .placeholder = "com.example.app" },
    .{ .name = "team_id", .label = "Team ID", .input_type = .text, .required = true },
    .{ .name = "deployment_target", .label = "Deployment Target", .input_type = .select, .options = &.{ "15.0", "16.0", "17.0", "18.0" }, .default_value = "16.0" },
    .{ .name = "provisioning_profile", .label = "Provisioning Profile", .input_type = .file },
};

const android_inputs = [_]InputSpec{
    .{ .name = "package_name", .label = "Package Name", .input_type = .text, .required = true, .placeholder = "com.example.app" },
    .{ .name = "min_sdk", .label = "Min SDK Version", .input_type = .number, .default_value = "24" },
    .{ .name = "target_sdk", .label = "Target SDK Version", .input_type = .number, .default_value = "34" },
    .{ .name = "keystore", .label = "Keystore File", .input_type = .file },
};

const web_inputs = [_]InputSpec{
    .{ .name = "output_dir", .label = "Output Directory", .input_type = .directory, .default_value = "dist" },
    .{ .name = "base_url", .label = "Base URL", .input_type = .text, .default_value = "/" },
    .{ .name = "pwa", .label = "Enable PWA", .input_type = .boolean, .default_value = "false" },
};

const macos_inputs = [_]InputSpec{
    .{ .name = "bundle_id", .label = "Bundle ID", .input_type = .text, .required = true, .placeholder = "com.example.app" },
    .{ .name = "team_id", .label = "Team ID", .input_type = .text },
    .{ .name = "deployment_target", .label = "Deployment Target", .input_type = .select, .options = &.{ "12.0", "13.0", "14.0", "15.0" }, .default_value = "13.0" },
    .{ .name = "sandbox", .label = "App Sandbox", .input_type = .boolean, .default_value = "true" },
};

const windows_inputs = [_]InputSpec{
    .{ .name = "app_id", .label = "Application ID", .input_type = .text, .required = true },
    .{ .name = "publisher", .label = "Publisher", .input_type = .text },
    .{ .name = "certificate", .label = "Code Signing Certificate", .input_type = .file },
};

const linux_inputs = [_]InputSpec{
    .{ .name = "app_id", .label = "Application ID", .input_type = .text, .required = true },
    .{ .name = "category", .label = "Category", .input_type = .select, .options = &.{ "Utility", "Development", "Game", "Graphics", "Office" } },
    .{ .name = "flatpak", .label = "Build Flatpak", .input_type = .boolean, .default_value = "false" },
};

const embedded_inputs = [_]InputSpec{
    .{ .name = "board", .label = "Target Board", .input_type = .select, .required = true, .options = &.{ "rpi4", "rpi5", "beaglebone", "custom" } },
    .{ .name = "memory_limit", .label = "Memory Limit (MB)", .input_type = .number, .default_value = "256" },
};

// Default capability matrix
fn getDefaultCapabilities() CapabilityMatrix {
    return .{
        .entries = &default_capabilities,
    };
}

const default_capabilities = [_]CapabilityEntry{
    // iOS capabilities
    .{ .target = .ios, .feature = .metal, .support = .native },
    .{ .target = .ios, .feature = .push_notifications, .support = .native },
    .{ .target = .ios, .feature = .in_app_purchase, .support = .native },
    .{ .target = .ios, .feature = .game_center, .support = .native },
    .{ .target = .ios, .feature = .camera, .support = .native },
    .{ .target = .ios, .feature = .haptics, .support = .native },
    .{ .target = .ios, .feature = .face_id, .support = .native },
    .{ .target = .ios, .feature = .keychain, .support = .native },
    .{ .target = .ios, .feature = .sqlite, .support = .full },
    .{ .target = .ios, .feature = .core_data, .support = .native },
    .{ .target = .ios, .feature = .native_ui, .support = .native },
    .{ .target = .ios, .feature = .widgets, .support = .native },
    .{ .target = .ios, .feature = .live_activities, .support = .native },
    .{ .target = .ios, .feature = .hot_reload, .support = .full },

    // Android capabilities
    .{ .target = .android, .feature = .vulkan, .support = .full },
    .{ .target = .android, .feature = .push_notifications, .support = .native },
    .{ .target = .android, .feature = .in_app_purchase, .support = .native },
    .{ .target = .android, .feature = .google_play_services, .support = .native },
    .{ .target = .android, .feature = .camera, .support = .native },
    .{ .target = .android, .feature = .haptics, .support = .full },
    .{ .target = .android, .feature = .nfc, .support = .native },
    .{ .target = .android, .feature = .sqlite, .support = .full },
    .{ .target = .android, .feature = .native_ui, .support = .native },
    .{ .target = .android, .feature = .widgets, .support = .native },
    .{ .target = .android, .feature = .hot_reload, .support = .full },

    // Web capabilities
    .{ .target = .web, .feature = .webgl, .support = .native },
    .{ .target = .web, .feature = .local_storage, .support = .native },
    .{ .target = .web, .feature = .websocket, .support = .native },
    .{ .target = .web, .feature = .webrtc, .support = .native },
    .{ .target = .web, .feature = .camera, .support = .full },
    .{ .target = .web, .feature = .microphone, .support = .full },
    .{ .target = .web, .feature = .hot_reload, .support = .native },
    .{ .target = .web, .feature = .inspector, .support = .native },

    // macOS capabilities
    .{ .target = .macos, .feature = .metal, .support = .native },
    .{ .target = .macos, .feature = .in_app_purchase, .support = .native },
    .{ .target = .macos, .feature = .keychain, .support = .native },
    .{ .target = .macos, .feature = .sqlite, .support = .full },
    .{ .target = .macos, .feature = .core_data, .support = .native },
    .{ .target = .macos, .feature = .native_ui, .support = .native },
    .{ .target = .macos, .feature = .touch_id, .support = .native },
    .{ .target = .macos, .feature = .hot_reload, .support = .full },

    // Windows capabilities
    .{ .target = .windows, .feature = .directx, .support = .native },
    .{ .target = .windows, .feature = .vulkan, .support = .full },
    .{ .target = .windows, .feature = .file_system, .support = .native },
    .{ .target = .windows, .feature = .sqlite, .support = .full },
    .{ .target = .windows, .feature = .native_ui, .support = .native },
    .{ .target = .windows, .feature = .hot_reload, .support = .full },

    // Linux capabilities
    .{ .target = .linux, .feature = .vulkan, .support = .full },
    .{ .target = .linux, .feature = .file_system, .support = .native },
    .{ .target = .linux, .feature = .sqlite, .support = .full },
    .{ .target = .linux, .feature = .native_ui, .support = .full },
    .{ .target = .linux, .feature = .hot_reload, .support = .full },

    // Embedded capabilities
    .{ .target = .embedded, .feature = .file_system, .support = .partial },
};

/// Create a target manager
pub fn createTargetManager(allocator: std.mem.Allocator) Targets {
    return Targets.init(allocator);
}

// Tests
test "Targets initialization" {
    const allocator = std.testing.allocator;
    var targets = createTargetManager(allocator);
    defer targets.deinit();

    const caps = targets.getCapabilities();
    try std.testing.expect(caps.entries.len > 0);
}

test "Feature support check" {
    const allocator = std.testing.allocator;
    var targets = createTargetManager(allocator);
    defer targets.deinit();

    try std.testing.expect(targets.supportsFeature(.ios, .metal));
    try std.testing.expect(targets.supportsFeature(.android, .vulkan));
    try std.testing.expect(targets.supportsFeature(.web, .webgl));
    try std.testing.expect(!targets.supportsFeature(.web, .metal));
}

test "Feature support level" {
    const allocator = std.testing.allocator;
    var targets = createTargetManager(allocator);
    defer targets.deinit();

    try std.testing.expectEqual(SupportLevel.native, targets.getFeatureSupport(.ios, .metal));
    try std.testing.expectEqual(SupportLevel.not_supported, targets.getFeatureSupport(.web, .metal));
}

test "Required inputs" {
    const allocator = std.testing.allocator;
    var targets = createTargetManager(allocator);
    defer targets.deinit();

    const ios_input = targets.getRequiredInputs(.ios);
    try std.testing.expect(ios_input.len > 0);

    var has_bundle_id = false;
    for (ios_input) |input| {
        if (std.mem.eql(u8, input.name, "bundle_id")) {
            has_bundle_id = true;
            try std.testing.expect(input.required);
        }
    }
    try std.testing.expect(has_bundle_id);
}

test "Target compatibility" {
    try std.testing.expect(Targets.areCompatible(.ios, .android));
    try std.testing.expect(Targets.areCompatible(.macos, .windows));
    try std.testing.expect(Targets.areCompatible(.linux, .macos));
    try std.testing.expect(!Targets.areCompatible(.ios, .web));
    try std.testing.expect(Targets.areCompatible(.web, .web));
}

test "SupportLevel methods" {
    try std.testing.expect(!SupportLevel.not_supported.isSupported());
    try std.testing.expect(SupportLevel.partial.isSupported());
    try std.testing.expect(SupportLevel.full.isSupported());
    try std.testing.expect(SupportLevel.native.isSupported());
}

test "Feature toString" {
    try std.testing.expect(std.mem.eql(u8, "Metal", Feature.metal.toString()));
    try std.testing.expect(std.mem.eql(u8, "WebGL", Feature.webgl.toString()));
    try std.testing.expect(std.mem.eql(u8, "Push Notifications", Feature.push_notifications.toString()));
}

test "Get all targets" {
    const targets = Targets.getAllTargets();
    try std.testing.expectEqual(@as(usize, 7), targets.len);
}
