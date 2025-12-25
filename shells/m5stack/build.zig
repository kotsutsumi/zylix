//! M5Stack CoreS3 Build Configuration
//!
//! Build configuration for ESP32-S3 (Xtensa) target with M5Stack CoreS3 hardware.
//!
//! This build file is designed to work with the zig-xtensa toolchain fork.
//! Standard upstream Zig does not support Xtensa architecture.
//!
//! Requirements:
//! - zig-xtensa toolchain (https://github.com/INetBowser/zig-xtensa)
//! - ESP-IDF v5.x (for runtime libraries)
//!
//! Usage:
//!   zig build                    # Build for ESP32-S3
//!   zig build -Dtarget=native    # Build for host (testing only)

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target configuration for ESP32-S3
    // Note: Requires zig-xtensa fork, not standard Zig
    const target = b.standardTargetOptions(.{
        .default_target = .{
            // ESP32-S3 uses Xtensa LX7 architecture
            // This requires the zig-xtensa toolchain
            .cpu_arch = .xtensa,
            .os_tag = .freestanding,
            .abi = .none,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    // M5Stack Shell Library
    const m5stack_lib = b.addStaticLibrary(.{
        .name = "zylix-m5stack",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add core module dependency
    if (b.lazyDependency("zylix-core", .{
        .target = target,
        .optimize = optimize,
    })) |core_dep| {
        m5stack_lib.root_module.addImport("zylix", core_dep.module("zylix"));
    }

    b.installArtifact(m5stack_lib);

    // Unit tests (for host target only)
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Documentation
    const docs = b.addStaticLibrary(.{
        .name = "zylix-m5stack",
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = .Debug,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);
}
