const std = @import("std");

pub fn build(b: *std.Build) void {
    // Default target (native)
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // === Core Library ===
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zylix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    // === Tests ===
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // === Cross-compilation targets ===

    // iOS ARM64
    const ios_step = b.step("ios", "Build for iOS (arm64)");
    const ios_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    }, optimize);
    ios_step.dependOn(&b.addInstallArtifact(ios_lib, .{
        .dest_dir = .{ .override = .{ .custom = "ios" } },
    }).step);

    // iOS Simulator (arm64)
    const ios_sim_step = b.step("ios-sim", "Build for iOS Simulator (arm64)");
    const ios_sim_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
        .abi = .simulator,
    }, optimize);
    ios_sim_step.dependOn(&b.addInstallArtifact(ios_sim_lib, .{
        .dest_dir = .{ .override = .{ .custom = "ios-simulator" } },
    }).step);

    // Android ARM64
    const android_arm64_step = b.step("android-arm64", "Build for Android (arm64)");
    const android_arm64_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .android,
    }, optimize);
    android_arm64_step.dependOn(&b.addInstallArtifact(android_arm64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android-arm64" } },
    }).step);

    // Android x86_64 (for emulator)
    const android_x64_step = b.step("android-x64", "Build for Android (x86_64)");
    const android_x64_lib = buildForTarget(b, .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .android,
    }, optimize);
    android_x64_step.dependOn(&b.addInstallArtifact(android_x64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android-x64" } },
    }).step);

    // macOS ARM64
    const macos_arm64_step = b.step("macos-arm64", "Build for macOS (arm64)");
    const macos_arm64_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    }, optimize);
    macos_arm64_step.dependOn(&b.addInstallArtifact(macos_arm64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "macos-arm64" } },
    }).step);

    // macOS x86_64
    const macos_x64_step = b.step("macos-x64", "Build for macOS (x86_64)");
    const macos_x64_lib = buildForTarget(b, .{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    }, optimize);
    macos_x64_step.dependOn(&b.addInstallArtifact(macos_x64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "macos-x64" } },
    }).step);

    // === Windows ===

    // Windows x86_64
    const windows_x64_step = b.step("windows-x64", "Build for Windows (x86_64)");
    const windows_x64_lib = buildForTarget(b, .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .msvc,
    }, optimize);
    windows_x64_step.dependOn(&b.addInstallArtifact(windows_x64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "windows-x64" } },
    }).step);

    // Windows ARM64
    const windows_arm64_step = b.step("windows-arm64", "Build for Windows (arm64)");
    const windows_arm64_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .windows,
        .abi = .msvc,
    }, optimize);
    windows_arm64_step.dependOn(&b.addInstallArtifact(windows_arm64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "windows-arm64" } },
    }).step);

    // === Linux ===

    // Linux x86_64
    const linux_x64_step = b.step("linux-x64", "Build for Linux (x86_64)");
    const linux_x64_lib = buildForTarget(b, .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    }, optimize);
    linux_x64_step.dependOn(&b.addInstallArtifact(linux_x64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "linux-x64" } },
    }).step);

    // Linux ARM64
    const linux_arm64_step = b.step("linux-arm64", "Build for Linux (arm64)");
    const linux_arm64_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .gnu,
    }, optimize);
    linux_arm64_step.dependOn(&b.addInstallArtifact(linux_arm64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "linux-arm64" } },
    }).step);

    // === WebAssembly ===
    const wasm_step = b.step("wasm", "Build for WebAssembly");
    const wasm_lib = buildWasm(b, optimize);
    wasm_step.dependOn(&b.addInstallArtifact(wasm_lib, .{
        .dest_dir = .{ .override = .{ .custom = "wasm" } },
    }).step);

    // === Build All ===
    const all_step = b.step("all", "Build for all platforms");
    all_step.dependOn(ios_step);
    all_step.dependOn(ios_sim_step);
    all_step.dependOn(android_arm64_step);
    all_step.dependOn(android_x64_step);
    all_step.dependOn(macos_arm64_step);
    all_step.dependOn(macos_x64_step);
    all_step.dependOn(windows_x64_step);
    all_step.dependOn(windows_arm64_step);
    all_step.dependOn(linux_x64_step);
    all_step.dependOn(linux_arm64_step);
    all_step.dependOn(wasm_step);
}

fn buildForTarget(
    b: *std.Build,
    target_query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const resolved_target = b.resolveTargetQuery(target_query);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zylix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = resolved_target,
            .optimize = optimize,
        }),
    });

    return lib;
}

fn buildWasm(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const resolved_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Use addExecutable for WASM to get proper exports
    const wasm = b.addExecutable(.{
        .name = "zylix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = resolved_target,
            .optimize = optimize,
        }),
    });

    // Export all C ABI functions
    wasm.rdynamic = true;

    // No entry point for library usage
    wasm.entry = .disabled;

    return wasm;
}
