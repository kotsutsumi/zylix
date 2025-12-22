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

    // === CLI Executable ===
    const cli_exe = b.addExecutable(.{
        .name = "zylix-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(cli_exe);

    // Run CLI
    const run_cli = b.addRunArtifact(cli_exe);
    run_cli.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cli.addArgs(args);
    }
    const run_step = b.step("run", "Run the Zylix Test CLI");
    run_step.dependOn(&run_cli.step);

    // === Tests ===
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const cli_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_cli_tests = b.addRunArtifact(cli_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_unit_tests.step);

    // === Integration Tests ===
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test/integration/integration_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_integration_tests.step);

    // === E2E Tests ===
    const e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test/e2e/e2e_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    const e2e_step = b.step("test-e2e", "Run E2E tests (requires running bridge servers)");
    e2e_step.dependOn(&run_e2e_tests.step);

    // Test all (unit + integration)
    const test_all_step = b.step("test-all", "Run all tests (unit + integration)");
    test_all_step.dependOn(&run_unit_tests.step);
    test_all_step.dependOn(&run_cli_tests.step);
    test_all_step.dependOn(&run_integration_tests.step);

    // Test everything (unit + integration + e2e)
    const test_everything_step = b.step("test-everything", "Run all tests including E2E");
    test_everything_step.dependOn(&run_unit_tests.step);
    test_everything_step.dependOn(&run_cli_tests.step);
    test_everything_step.dependOn(&run_integration_tests.step);
    test_everything_step.dependOn(&run_e2e_tests.step);

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

    // Android ARM64 (arm64-v8a)
    const android_arm64_step = b.step("android-arm64", "Build for Android (arm64-v8a)");
    const android_arm64_lib = buildAndroidShared(b, .aarch64, optimize);
    android_arm64_step.dependOn(&b.addInstallArtifact(android_arm64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android/arm64-v8a" } },
    }).step);

    // Android ARMv7 (armeabi-v7a)
    const android_arm32_step = b.step("android-arm32", "Build for Android (armeabi-v7a)");
    const android_arm32_lib = buildAndroidShared(b, .arm, optimize);
    android_arm32_step.dependOn(&b.addInstallArtifact(android_arm32_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android/armeabi-v7a" } },
    }).step);

    // Android x86_64 (for emulator)
    const android_x64_step = b.step("android-x64", "Build for Android (x86_64)");
    const android_x64_lib = buildAndroidShared(b, .x86_64, optimize);
    android_x64_step.dependOn(&b.addInstallArtifact(android_x64_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android/x86_64" } },
    }).step);

    // Android x86 (for older emulators)
    const android_x86_step = b.step("android-x86", "Build for Android (x86)");
    const android_x86_lib = buildAndroidShared(b, .x86, optimize);
    android_x86_step.dependOn(&b.addInstallArtifact(android_x86_lib, .{
        .dest_dir = .{ .override = .{ .custom = "android/x86" } },
    }).step);

    // Android All ABIs
    const android_all_step = b.step("android", "Build for all Android ABIs");
    android_all_step.dependOn(android_arm64_step);
    android_all_step.dependOn(android_arm32_step);
    android_all_step.dependOn(android_x64_step);
    android_all_step.dependOn(android_x86_step);

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
    all_step.dependOn(android_all_step);
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

fn buildAndroidShared(
    b: *std.Build,
    cpu_arch: std.Target.Cpu.Arch,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const resolved_target = b.resolveTargetQuery(.{
        .cpu_arch = cpu_arch,
        .os_tag = .linux,
        .abi = .android,
    });

    // Build as shared library for JNI
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zylix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = resolved_target,
            .optimize = optimize,
        }),
    });

    return lib;
}
