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
    // Target configuration
    // Note: ESP32-S3 (Xtensa) requires zig-xtensa fork
    // For testing, use native target: zig build test
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // M5Stack Shell Library
    const m5stack_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zylix-m5stack",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(m5stack_lib);

    // Unit tests (for host target only)
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

    // Documentation
    const docs = b.addLibrary(.{
        .linkage = .static,
        .name = "zylix-m5stack-docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .Debug,
        }),
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);
}
