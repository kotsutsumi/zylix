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

    // Add llama.cpp support for native builds
    addLlamaCppSupport(lib, b);

    b.installArtifact(lib);

    // === AI Module (shared between CLI and tests) ===
    const ai_mod = b.createModule(.{
        .root_source_file = b.path("src/ai/ai.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add llama.cpp include paths to AI module
    ai_mod.addIncludePath(b.path("deps/llama.cpp/include"));
    ai_mod.addIncludePath(b.path("deps/llama.cpp/ggml/include"));
    // Add mtmd (multi-modal) include path for VLM support
    ai_mod.addIncludePath(b.path("deps/llama.cpp/tools/mtmd"));

    // Add whisper.cpp include paths to AI module
    ai_mod.addIncludePath(b.path("deps/whisper.cpp/include"));
    ai_mod.addIncludePath(b.path("deps/whisper.cpp/ggml/include"));
    // Add miniaudio include path for audio decoding (MP3, FLAC support)
    ai_mod.addIncludePath(b.path("deps/whisper.cpp/examples"));
    // Add src/ai include path for miniaudio wrapper header
    ai_mod.addIncludePath(b.path("src/ai"));

    // === CLI Executable ===
    const cli_exe = b.addExecutable(.{
        .name = "zylix-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ai", .module = ai_mod },
            },
        }),
    });

    // Add llama.cpp, whisper.cpp, and Core ML support for CLI
    addLlamaCppSupport(cli_exe, b);
    addWhisperCppSupport(cli_exe, b);
    addCoreMLSupport(cli_exe, b);

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

    // Add llama.cpp, whisper.cpp, and Core ML support for tests
    addLlamaCppSupport(unit_tests, b);
    addWhisperCppSupport(unit_tests, b);
    addCoreMLSupport(unit_tests, b);

    // Create CLI test module (reuses ai_mod defined above)
    const cli_root_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ai", .module = ai_mod },
        },
    });

    const cli_tests = b.addTest(.{
        .root_module = cli_root_mod,
    });

    // Add llama.cpp, whisper.cpp, and Core ML support for CLI tests
    addLlamaCppSupport(cli_tests, b);
    addWhisperCppSupport(cli_tests, b);
    addCoreMLSupport(cli_tests, b);

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

    // === Benchmarks ===
    const benchmark_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/benchmark/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    const run_benchmarks = b.addRunArtifact(benchmark_tests);
    const benchmark_step = b.step("bench", "Run performance benchmarks");
    benchmark_step.dependOn(&run_benchmarks.step);

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

    // watchOS ARM64
    const watchos_step = b.step("watchos", "Build for watchOS (arm64)");
    const watchos_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .watchos,
    }, optimize);
    watchos_step.dependOn(&b.addInstallArtifact(watchos_lib, .{
        .dest_dir = .{ .override = .{ .custom = "watchos" } },
    }).step);

    // watchOS Simulator (arm64)
    const watchos_sim_step = b.step("watchos-sim", "Build for watchOS Simulator (arm64)");
    const watchos_sim_lib = buildForTarget(b, .{
        .cpu_arch = .aarch64,
        .os_tag = .watchos,
        .abi = .simulator,
    }, optimize);
    watchos_sim_step.dependOn(&b.addInstallArtifact(watchos_sim_lib, .{
        .dest_dir = .{ .override = .{ .custom = "watchos-simulator" } },
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

    // === WebAssembly (Debug) ===
    const wasm_debug_step = b.step("wasm-debug", "Build for WebAssembly (debug, larger size)");
    const wasm_debug_lib = buildWasm(b, .Debug);
    wasm_debug_step.dependOn(&b.addInstallArtifact(wasm_debug_lib, .{
        .dest_dir = .{ .override = .{ .custom = "wasm-debug" } },
    }).step);

    // === Build All ===
    const all_step = b.step("all", "Build for all platforms");
    all_step.dependOn(ios_step);
    all_step.dependOn(ios_sim_step);
    all_step.dependOn(watchos_step);
    all_step.dependOn(watchos_sim_step);
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

    // For WASM, prefer ReleaseSmall for smallest bundle size
    // unless explicitly specified otherwise
    const wasm_optimize = if (optimize == .Debug) optimize else .ReleaseSmall;

    // Use addExecutable for WASM to get proper exports
    const wasm = b.addExecutable(.{
        .name = "zylix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = resolved_target,
            .optimize = wasm_optimize,
            // Performance: single-threaded for WASM (no threading overhead)
            .single_threaded = true,
            // Strip debug symbols in release for smaller size
            .strip = wasm_optimize != .Debug,
        }),
    });

    // Export all C ABI functions
    wasm.rdynamic = true;

    // No entry point for library usage
    wasm.entry = .disabled;

    // Link-time optimization for smaller bundle
    if (wasm_optimize != .Debug) {
        wasm.want_lto = true;
    }

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

fn addLlamaCppSupport(compile: *std.Build.Step.Compile, b: *std.Build) void {
    const target = compile.root_module.resolved_target.?.result;

    // Only add llama.cpp support for native builds (not cross-compilation)
    // llama.cpp requires platform-specific builds
    const is_native = target.os.tag == @import("builtin").os.tag and
        target.cpu.arch == @import("builtin").cpu.arch;

    if (!is_native) {
        return;
    }

    // Check if llama.cpp libraries exist (skip if not built)
    const llama_lib_path = b.path("deps/llama.cpp/build/src/libllama.a");
    std.fs.cwd().access(llama_lib_path.getPath(b), .{}) catch {
        // llama.cpp not built, skip linking
        return;
    };

    // Add include paths for llama.cpp headers
    compile.root_module.addIncludePath(b.path("deps/llama.cpp/include"));
    compile.root_module.addIncludePath(b.path("deps/llama.cpp/ggml/include"));
    // Add mtmd (multi-modal) include path for VLM support
    compile.root_module.addIncludePath(b.path("deps/llama.cpp/tools/mtmd"));

    // Link against llama.cpp static libraries
    compile.addObjectFile(b.path("deps/llama.cpp/build/src/libllama.a"));
    compile.addObjectFile(b.path("deps/llama.cpp/build/ggml/src/libggml.a"));
    compile.addObjectFile(b.path("deps/llama.cpp/build/ggml/src/libggml-base.a"));
    compile.addObjectFile(b.path("deps/llama.cpp/build/ggml/src/libggml-cpu.a"));
    // Add mtmd (multi-modal) library for VLM support
    compile.addObjectFile(b.path("deps/llama.cpp/build/tools/mtmd/libmtmd.a"));
    compile.addObjectFile(b.path("deps/llama.cpp/build/common/libcommon.a"));

    // Platform-specific libraries
    if (target.os.tag == .macos) {
        // macOS: Metal and Accelerate support
        compile.addObjectFile(b.path("deps/llama.cpp/build/ggml/src/ggml-metal/libggml-metal.a"));
        compile.addObjectFile(b.path("deps/llama.cpp/build/ggml/src/ggml-blas/libggml-blas.a"));

        // Link macOS frameworks
        compile.root_module.linkFramework("Metal", .{});
        compile.root_module.linkFramework("MetalKit", .{});
        compile.root_module.linkFramework("Accelerate", .{});
        compile.root_module.linkFramework("Foundation", .{});

        // Link C++ standard library
        compile.root_module.linkSystemLibrary("c++", .{});
    } else if (target.os.tag == .linux) {
        // Linux: CPU-only for now
        compile.root_module.linkSystemLibrary("stdc++", .{});
        compile.root_module.linkSystemLibrary("m", .{});
        compile.root_module.linkSystemLibrary("pthread", .{});
    }
}

fn addWhisperCppSupport(compile: *std.Build.Step.Compile, b: *std.Build) void {
    const target = compile.root_module.resolved_target.?.result;

    // Only add whisper.cpp support for native builds (not cross-compilation)
    const is_native = target.os.tag == @import("builtin").os.tag and
        target.cpu.arch == @import("builtin").cpu.arch;

    if (!is_native) {
        return;
    }

    // Check if whisper.cpp libraries exist (skip if not built)
    const whisper_lib_path = b.path("deps/whisper.cpp/build/src/libwhisper.a");
    std.fs.cwd().access(whisper_lib_path.getPath(b), .{}) catch {
        // whisper.cpp not built, skip linking
        return;
    };

    // Add include paths for whisper.cpp headers
    compile.root_module.addIncludePath(b.path("deps/whisper.cpp/include"));
    compile.root_module.addIncludePath(b.path("deps/whisper.cpp/ggml/include"));
    // Add miniaudio include path for audio decoding (MP3, FLAC support)
    compile.root_module.addIncludePath(b.path("deps/whisper.cpp/examples"));
    // Add src/ai include path for miniaudio wrapper header
    compile.root_module.addIncludePath(b.path("src/ai"));

    // Compile miniaudio wrapper for audio decoding
    compile.addCSourceFile(.{
        .file = b.path("src/ai/miniaudio_wrapper.c"),
        .flags = &.{
            "-std=c11",
            "-O2",
            "-DNDEBUG",
            "-fno-sanitize=undefined", // Disable UBSan for miniaudio
        },
    });

    // Link against whisper.cpp static libraries
    compile.addObjectFile(b.path("deps/whisper.cpp/build/src/libwhisper.a"));
    compile.addObjectFile(b.path("deps/whisper.cpp/build/ggml/src/libggml.a"));
    compile.addObjectFile(b.path("deps/whisper.cpp/build/ggml/src/libggml-base.a"));
    compile.addObjectFile(b.path("deps/whisper.cpp/build/ggml/src/libggml-cpu.a"));

    // Platform-specific libraries
    if (target.os.tag == .macos) {
        // macOS: Metal and Accelerate support
        compile.addObjectFile(b.path("deps/whisper.cpp/build/ggml/src/ggml-metal/libggml-metal.a"));
        compile.addObjectFile(b.path("deps/whisper.cpp/build/ggml/src/ggml-blas/libggml-blas.a"));

        // Link macOS frameworks (if not already linked by llama.cpp)
        compile.root_module.linkFramework("Metal", .{});
        compile.root_module.linkFramework("MetalKit", .{});
        compile.root_module.linkFramework("Accelerate", .{});
        compile.root_module.linkFramework("Foundation", .{});

        // Link C++ standard library
        compile.root_module.linkSystemLibrary("c++", .{});
    } else if (target.os.tag == .linux) {
        // Linux: CPU-only for now
        compile.root_module.linkSystemLibrary("stdc++", .{});
        compile.root_module.linkSystemLibrary("m", .{});
        compile.root_module.linkSystemLibrary("pthread", .{});
    }
}

fn addCoreMLSupport(compile: *std.Build.Step.Compile, b: *std.Build) void {
    const target = compile.root_module.resolved_target.?.result;

    // Only add Core ML support for Apple platforms
    const is_apple = target.os.tag == .macos or target.os.tag == .ios or
        target.os.tag == .tvos or target.os.tag == .watchos;

    if (!is_apple) {
        return;
    }

    // Add include path for Core ML wrapper
    compile.root_module.addIncludePath(b.path("src/ai"));

    // Compile Core ML Objective-C wrapper
    compile.addCSourceFile(.{
        .file = b.path("src/ai/coreml_wrapper.m"),
        .flags = &.{
            "-fobjc-arc", // Enable Automatic Reference Counting
            "-fno-modules", // Disable Clang modules (compatibility)
            "-O2",
            "-DNDEBUG",
            "-Wno-deprecated-declarations",
        },
    });

    // Link Core ML framework
    compile.root_module.linkFramework("CoreML", .{});

    // Additional frameworks needed for Core ML
    compile.root_module.linkFramework("Foundation", .{});

    // Link Objective-C runtime
    compile.root_module.linkSystemLibrary("objc", .{});
}
