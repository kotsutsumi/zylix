const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "space-shooter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const wasm_step = b.step("wasm", "Build for WebAssembly");
    const wasm = b.addExecutable(.{
        .name = "space-shooter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = .ReleaseSmall,
        }),
    });
    wasm.rdynamic = true;
    wasm.entry = .disabled;
    wasm_step.dependOn(&b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "wasm" } },
    }).step);
}
