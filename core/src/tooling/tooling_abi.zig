//! Tooling C ABI Exports Module
//!
//! Provides the public C ABI interface for developer tooling.
//! All functions here use C calling convention and C-compatible types.
//!
//! Includes exports for:
//! - Project Scaffolding API (#46)
//! - Build Orchestration API (#47)
//! - Build Artifact Query API (#48)
//! - Target Capability Matrix API (#51)
//! - Template Catalog API (#52)
//! - File Watcher API (#53)

const std = @import("std");
const project = @import("project.zig");
const build = @import("build.zig");
const artifacts = @import("artifacts.zig");
const targets = @import("targets.zig");
const templates = @import("templates.zig");
const watcher = @import("watcher.zig");

/// Tooling ABI version
pub const TOOLING_ABI_VERSION: u32 = 1;

/// Result codes for tooling operations
pub const ToolingResult = enum(i32) {
    ok = 0,
    err_invalid_arg = 1,
    err_out_of_memory = 2,
    err_not_found = 3,
    err_already_exists = 4,
    err_permission_denied = 5,
    err_validation_failed = 6,
    err_build_failed = 7,
    err_cancelled = 8,
    err_not_initialized = 9,
    err_io_error = 10,
};

// === Global State ===

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator: std.mem.Allocator = undefined;
var initialized: bool = false;

// Manager instances
var project_manager: ?project.Project = null;
var build_orchestrator: ?build.Build = null;
var artifact_manager: ?artifacts.Artifacts = null;
var target_manager: ?targets.Targets = null;
var template_manager: ?templates.Templates = null;
var file_watcher: ?watcher.FileWatcher = null;

// === Lifecycle Functions ===

/// Initialize Zylix Tooling
pub fn zylix_tooling_init() callconv(.c) i32 {
    if (initialized) return @intFromEnum(ToolingResult.ok);

    allocator = gpa.allocator();
    project_manager = project.createProjectManager(allocator);
    build_orchestrator = build.createBuildOrchestrator(allocator);
    artifact_manager = artifacts.createArtifactManager(allocator);
    target_manager = targets.createTargetManager(allocator);
    template_manager = templates.createTemplateManager(allocator);
    file_watcher = watcher.createFileWatcher(allocator);

    initialized = true;
    return @intFromEnum(ToolingResult.ok);
}

/// Shutdown Zylix Tooling
pub fn zylix_tooling_deinit() callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.ok);

    if (file_watcher) |*w| w.deinit();
    if (template_manager) |*t| t.deinit();
    if (target_manager) |*t| t.deinit();
    if (artifact_manager) |*a| a.deinit();
    if (build_orchestrator) |*b| b.deinit();
    if (project_manager) |*p| p.deinit();

    file_watcher = null;
    template_manager = null;
    target_manager = null;
    artifact_manager = null;
    build_orchestrator = null;
    project_manager = null;

    initialized = false;
    return @intFromEnum(ToolingResult.ok);
}

/// Get Tooling ABI version
pub fn zylix_tooling_get_version() callconv(.c) u32 {
    return TOOLING_ABI_VERSION;
}

/// Check if tooling is initialized
pub fn zylix_tooling_is_initialized() callconv(.c) bool {
    return initialized;
}

// =============================================================================
// PROJECT SCAFFOLDING API (#46)
// =============================================================================

/// C-compatible project configuration
pub const CProjectConfig = extern struct {
    name: [*:0]const u8,
    description: [*:0]const u8,
    version: [*:0]const u8,
    project_type: u8,
    template_id: [*:0]const u8,
    author: [*:0]const u8,
    license: [*:0]const u8,
    org_id: [*:0]const u8,
    init_git: bool,
    install_deps: bool,
};

/// C-compatible project info
pub const CProjectInfo = extern struct {
    id: u64,
    name: [128]u8,
    path: [512]u8,
    created_at: i64,
    modified_at: i64,
};

// Static buffers for C ABI returns
var c_project_info_cache: CProjectInfo = undefined;

/// Create a new project
pub fn zylix_project_create(
    template_id: [*:0]const u8,
    targets_mask: u8,
    output_dir: [*:0]const u8,
    config: *const CProjectConfig,
) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var pm = project_manager orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    // Parse targets from mask
    var target_list: [7]project.Target = undefined;
    var target_count: usize = 0;

    inline for (0..7) |i| {
        if ((targets_mask >> @intCast(i)) & 1 == 1) {
            target_list[target_count] = @enumFromInt(i);
            target_count += 1;
        }
    }

    if (target_count == 0) return -@as(i64, @intFromEnum(ToolingResult.err_invalid_arg));

    const template_str = std.mem.span(template_id);
    const output_str = std.mem.span(output_dir);
    const name_str = std.mem.span(config.name);

    const zig_config = project.ProjectConfig{
        .name = name_str,
        .description = std.mem.span(config.description),
        .version = std.mem.span(config.version),
        .project_type = @enumFromInt(config.project_type),
        .template_id = if (config.template_id[0] != 0) std.mem.span(config.template_id) else null,
        .author = if (config.author[0] != 0) std.mem.span(config.author) else null,
        .license = if (config.license[0] != 0) std.mem.span(config.license) else null,
        .org_id = if (config.org_id[0] != 0) std.mem.span(config.org_id) else null,
        .init_git = config.init_git,
        .install_deps = config.install_deps,
    };

    const future = pm.create(template_str, target_list[0..target_count], output_str, zig_config);
    defer allocator.destroy(future);

    if (future.err != null) {
        return -@as(i64, @intFromEnum(ToolingResult.err_validation_failed));
    }

    if (future.result) |pid| {
        return @intCast(pid.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_validation_failed));
}

/// Validate an existing project
pub fn zylix_project_validate(project_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var pm = project_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const future = pm.validate(pid);
    defer allocator.destroy(future);

    if (future.result) |result| {
        if (result.valid) {
            return @intFromEnum(ToolingResult.ok);
        }
        return @intFromEnum(ToolingResult.err_validation_failed);
    }

    return @intFromEnum(ToolingResult.err_not_found);
}

/// Get project info
pub fn zylix_project_get_info(name: [*:0]const u8) callconv(.c) ?*const CProjectInfo {
    if (!initialized) return null;

    const pm = project_manager orelse return null;
    const name_str = std.mem.span(name);

    if (pm.getInfo(name_str)) |info| {
        // Clear and populate cache
        @memset(&c_project_info_cache.name, 0);
        @memset(&c_project_info_cache.path, 0);

        c_project_info_cache.id = info.id.id;
        c_project_info_cache.created_at = info.created_at;
        c_project_info_cache.modified_at = info.modified_at;

        const name_len = @min(info.id.name.len, c_project_info_cache.name.len - 1);
        @memcpy(c_project_info_cache.name[0..name_len], info.id.name[0..name_len]);

        const path_len = @min(info.id.path.len, c_project_info_cache.path.len - 1);
        @memcpy(c_project_info_cache.path[0..path_len], info.id.path[0..path_len]);

        return &c_project_info_cache;
    }

    return null;
}

/// Get project count
pub fn zylix_project_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const pm = project_manager orelse return 0;
    return @intCast(pm.count());
}

/// Delete a project
pub fn zylix_project_delete(name: [*:0]const u8) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var pm = project_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);
    const name_str = std.mem.span(name);

    if (pm.delete(name_str)) {
        return @intFromEnum(ToolingResult.ok);
    }
    return @intFromEnum(ToolingResult.err_not_found);
}

// =============================================================================
// BUILD ORCHESTRATION API (#47)
// =============================================================================

/// C-compatible build configuration
pub const CBuildConfig = extern struct {
    mode: u8,
    optimization: u8,
    sign: bool,
    parallel: bool,
    max_jobs: u8,
    incremental: bool,
    cache: bool,
};

/// C-compatible build status
pub const CBuildStatus = extern struct {
    state: u8,
    progress: f32,
    files_compiled: u32,
    files_total: u32,
    errors: u32,
    warnings: u32,
    elapsed_ms: u64,
};

/// C-compatible build progress for callback
pub const CBuildProgress = extern struct {
    build_id: u64,
    state: u8,
    progress: f32,
    timestamp: i64,
};

/// C-compatible log entry for callback
pub const CLogEntry = extern struct {
    build_id: u64,
    level: u8,
    message: [512]u8,
    timestamp: i64,
};

// Build callback function pointers
pub const CBuildProgressCallback = ?*const fn (*const CBuildProgress) callconv(.c) void;
pub const CBuildLogCallback = ?*const fn (*const CLogEntry) callconv(.c) void;

var c_build_status_cache: CBuildStatus = undefined;
var c_progress_callback: CBuildProgressCallback = null;
var c_log_callback: CBuildLogCallback = null;

/// Start a new build
pub fn zylix_build_start(
    project_name: [*:0]const u8,
    target: u8,
    config: *const CBuildConfig,
) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var bo = build_orchestrator orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    const name_str = std.mem.span(project_name);

    const project_id = project.ProjectId{
        .id = 1, // Placeholder, would look up from project manager
        .name = name_str,
        .path = "",
    };

    const zig_config = build.BuildConfig{
        .mode = @enumFromInt(config.mode),
        .optimization = @enumFromInt(config.optimization),
        .sign = config.sign,
        .parallel = config.parallel,
        .max_jobs = config.max_jobs,
        .incremental = config.incremental,
        .cache = config.cache,
    };

    const future = bo.start(project_id, @enumFromInt(target), zig_config);
    defer allocator.destroy(future);

    if (future.result) |bid| {
        return @intCast(bid.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_build_failed));
}

/// Cancel a running build
pub fn zylix_build_cancel(build_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var bo = build_orchestrator orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const bid = build.BuildId{
        .id = build_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    bo.cancel(bid);
    return @intFromEnum(ToolingResult.ok);
}

/// Get build status
pub fn zylix_build_get_status(build_id: u64) callconv(.c) ?*const CBuildStatus {
    if (!initialized) return null;

    const bo = build_orchestrator orelse return null;

    const bid = build.BuildId{
        .id = build_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    if (bo.getStatus(bid)) |status| {
        c_build_status_cache = .{
            .state = @intFromEnum(status.state),
            .progress = status.progress,
            .files_compiled = status.files_compiled,
            .files_total = status.files_total,
            .errors = status.errors,
            .warnings = status.warnings,
            .elapsed_ms = status.elapsed_ms,
        };
        return &c_build_status_cache;
    }

    return null;
}

/// Set progress callback
pub fn zylix_build_set_progress_callback(callback: CBuildProgressCallback) callconv(.c) i32 {
    c_progress_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Set log callback
pub fn zylix_build_set_log_callback(callback: CBuildLogCallback) callconv(.c) i32 {
    c_log_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Get active build count
pub fn zylix_build_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const bo = build_orchestrator orelse return 0;
    return @intCast(bo.activeCount());
}

/// Get total build count
pub fn zylix_build_total_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const bo = build_orchestrator orelse return 0;
    return @intCast(bo.totalCount());
}

// =============================================================================
// BUILD ARTIFACT QUERY API (#48)
// =============================================================================

/// C-compatible artifact metadata
pub const CArtifactMetadata = extern struct {
    size: u64,
    hash: [64]u8,
    created_at: i64,
    modified_at: i64,
    artifact_type: u8,
    target: u8,
    build_mode: u8,
    signed: bool,
};

/// C-compatible artifact
pub const CArtifact = extern struct {
    path: [512]u8,
    name: [128]u8,
    build_id: u64,
    metadata: CArtifactMetadata,
};

var c_artifact_cache: CArtifact = undefined;
var c_metadata_cache: CArtifactMetadata = undefined;

/// Get artifact count for a build
pub fn zylix_artifacts_count(build_id: u64) callconv(.c) u32 {
    if (!initialized) return 0;
    var am = artifact_manager orelse return 0;

    const bid = build.BuildId{
        .id = build_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    const future = am.getArtifacts(bid);
    defer allocator.destroy(future);

    if (future.result) |arts| {
        return @intCast(arts.len);
    }
    return 0;
}

/// Get artifact metadata
pub fn zylix_artifacts_get_metadata(path: [*:0]const u8) callconv(.c) ?*const CArtifactMetadata {
    if (!initialized) return null;

    const am = artifact_manager orelse return null;
    const path_str = std.mem.span(path);

    if (am.getMetadata(path_str)) |metadata| {
        @memset(&c_metadata_cache.hash, 0);

        c_metadata_cache = .{
            .size = metadata.size,
            .hash = undefined,
            .created_at = metadata.created_at,
            .modified_at = metadata.modified_at,
            .artifact_type = @intFromEnum(metadata.artifact_type),
            .target = @intFromEnum(metadata.target),
            .build_mode = @intFromEnum(metadata.build_mode),
            .signed = metadata.signed,
        };

        const hash_len = @min(metadata.hash.len, c_metadata_cache.hash.len);
        @memcpy(c_metadata_cache.hash[0..hash_len], metadata.hash[0..hash_len]);

        return &c_metadata_cache;
    }

    return null;
}

/// Export artifact to destination
pub fn zylix_artifacts_export(
    path: [*:0]const u8,
    dest: [*:0]const u8,
    compress: bool,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var am = artifact_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const path_str = std.mem.span(path);
    const dest_str = std.mem.span(dest);

    const future = am.exportArtifact(path_str, dest_str, .{ .compress = compress });
    defer allocator.destroy(future);

    if (future.err != null) {
        return @intFromEnum(ToolingResult.err_io_error);
    }

    return @intFromEnum(ToolingResult.ok);
}

/// Verify artifact integrity
pub fn zylix_artifacts_verify(path: [*:0]const u8, hash: [*:0]const u8) callconv(.c) bool {
    if (!initialized) return false;

    const am = artifact_manager orelse return false;
    const path_str = std.mem.span(path);
    const hash_str = std.mem.span(hash);

    return am.verify(path_str, hash_str);
}

// =============================================================================
// TARGET CAPABILITY MATRIX API (#51)
// =============================================================================

/// C-compatible input specification
pub const CInputSpec = extern struct {
    name: [64]u8,
    label: [64]u8,
    input_type: u8,
    required: bool,
    has_default: bool,
    default_value: [128]u8,
};

var c_input_specs_cache: [16]CInputSpec = undefined;

/// Check if target supports a feature
pub fn zylix_targets_supports_feature(target: u8, feature: u8) callconv(.c) bool {
    if (!initialized) return false;

    const tm = target_manager orelse return false;
    return tm.supportsFeature(@enumFromInt(target), @enumFromInt(feature));
}

/// Get feature support level
pub fn zylix_targets_get_support_level(target: u8, feature: u8) callconv(.c) u8 {
    if (!initialized) return 0;

    const tm = target_manager orelse return 0;
    const level = tm.getFeatureSupport(@enumFromInt(target), @enumFromInt(feature));
    return @intFromEnum(level);
}

/// Get required input specs for target
pub fn zylix_targets_get_input_specs(target: u8, count: *u32) callconv(.c) ?*const CInputSpec {
    if (!initialized) return null;

    const tm = target_manager orelse return null;
    const specs = tm.getRequiredInputs(@enumFromInt(target));

    if (specs.len == 0) {
        count.* = 0;
        return null;
    }

    const max_specs = @min(specs.len, c_input_specs_cache.len);

    for (specs[0..max_specs], 0..) |spec, i| {
        @memset(&c_input_specs_cache[i].name, 0);
        @memset(&c_input_specs_cache[i].label, 0);
        @memset(&c_input_specs_cache[i].default_value, 0);

        const name_len = @min(spec.name.len, c_input_specs_cache[i].name.len - 1);
        @memcpy(c_input_specs_cache[i].name[0..name_len], spec.name[0..name_len]);

        const label_len = @min(spec.label.len, c_input_specs_cache[i].label.len - 1);
        @memcpy(c_input_specs_cache[i].label[0..label_len], spec.label[0..label_len]);

        c_input_specs_cache[i].input_type = @intFromEnum(spec.input_type);
        c_input_specs_cache[i].required = spec.required;
        c_input_specs_cache[i].has_default = spec.default_value != null;

        if (spec.default_value) |dv| {
            const dv_len = @min(dv.len, c_input_specs_cache[i].default_value.len - 1);
            @memcpy(c_input_specs_cache[i].default_value[0..dv_len], dv[0..dv_len]);
        }
    }

    count.* = @intCast(max_specs);
    return &c_input_specs_cache[0];
}

/// Get number of targets
pub fn zylix_targets_count() callconv(.c) u32 {
    return 7; // iOS, Android, Web, macOS, Windows, Linux, Embedded
}

/// Check if targets are compatible
pub fn zylix_targets_are_compatible(target1: u8, target2: u8) callconv(.c) bool {
    return targets.Targets.areCompatible(@enumFromInt(target1), @enumFromInt(target2));
}

// =============================================================================
// TEMPLATE CATALOG API (#52)
// =============================================================================

/// C-compatible template info
pub const CTemplate = extern struct {
    id: [64]u8,
    name: [128]u8,
    description: [256]u8,
    category: u8,
    source: u8,
    version: [16]u8,
};

var c_templates_cache: [16]CTemplate = undefined;
var c_template_cache: CTemplate = undefined;

/// Get template count
pub fn zylix_templates_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const tm = template_manager orelse return 0;
    return @intCast(tm.list().len);
}

/// Get template by index
pub fn zylix_templates_get(index: u32) callconv(.c) ?*const CTemplate {
    if (!initialized) return null;

    const tm = template_manager orelse return null;
    const list = tm.list();

    if (index >= list.len) return null;

    const t = list[index];
    @memset(&c_template_cache.id, 0);
    @memset(&c_template_cache.name, 0);
    @memset(&c_template_cache.description, 0);
    @memset(&c_template_cache.version, 0);

    const id_len = @min(t.id.len, c_template_cache.id.len - 1);
    @memcpy(c_template_cache.id[0..id_len], t.id[0..id_len]);

    const name_len = @min(t.name.len, c_template_cache.name.len - 1);
    @memcpy(c_template_cache.name[0..name_len], t.name[0..name_len]);

    const desc_len = @min(t.description.len, c_template_cache.description.len - 1);
    @memcpy(c_template_cache.description[0..desc_len], t.description[0..desc_len]);

    const ver_len = @min(t.version.len, c_template_cache.version.len - 1);
    @memcpy(c_template_cache.version[0..ver_len], t.version[0..ver_len]);

    c_template_cache.category = @intFromEnum(t.category);
    c_template_cache.source = @intFromEnum(t.source);

    return &c_template_cache;
}

/// Get template by ID
pub fn zylix_templates_get_by_id(id: [*:0]const u8) callconv(.c) ?*const CTemplate {
    if (!initialized) return null;

    const tm = template_manager orelse return null;
    const id_str = std.mem.span(id);

    if (tm.getDetails(id_str)) |details| {
        const t = details.template;
        @memset(&c_template_cache.id, 0);
        @memset(&c_template_cache.name, 0);
        @memset(&c_template_cache.description, 0);
        @memset(&c_template_cache.version, 0);

        const tid_len = @min(t.id.len, c_template_cache.id.len - 1);
        @memcpy(c_template_cache.id[0..tid_len], t.id[0..tid_len]);

        const name_len = @min(t.name.len, c_template_cache.name.len - 1);
        @memcpy(c_template_cache.name[0..name_len], t.name[0..name_len]);

        const desc_len = @min(t.description.len, c_template_cache.description.len - 1);
        @memcpy(c_template_cache.description[0..desc_len], t.description[0..desc_len]);

        const ver_len = @min(t.version.len, c_template_cache.version.len - 1);
        @memcpy(c_template_cache.version[0..ver_len], t.version[0..ver_len]);

        c_template_cache.category = @intFromEnum(t.category);
        c_template_cache.source = @intFromEnum(t.source);

        return &c_template_cache;
    }

    return null;
}

/// Check if template exists
pub fn zylix_templates_exists(id: [*:0]const u8) callconv(.c) bool {
    if (!initialized) return false;

    const tm = template_manager orelse return false;
    const id_str = std.mem.span(id);

    return tm.exists(id_str);
}

// =============================================================================
// FILE WATCHER API (#53)
// =============================================================================

/// C-compatible file change event
pub const CFileChange = extern struct {
    watch_id: u64,
    change_type: u8,
    path: [512]u8,
    is_directory: bool,
    timestamp: i64,
};

/// File change callback
pub const CFileChangeCallback = ?*const fn (*const CFileChange) callconv(.c) void;

var c_file_change_cache: CFileChange = undefined;
var c_file_change_callback: CFileChangeCallback = null;

/// Start watching a path
pub fn zylix_fs_watch(path: [*:0]const u8, recursive: bool) callconv(.c) u64 {
    if (!initialized) return 0;

    var fw = file_watcher orelse return 0;
    const path_str = std.mem.span(path);

    const watch_id = fw.watch(path_str, .{ .recursive = recursive }) catch return 0;
    return watch_id.id;
}

/// Stop watching a path
pub fn zylix_fs_unwatch(watch_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var fw = file_watcher orelse return @intFromEnum(ToolingResult.err_not_initialized);

    fw.unwatch(.{ .id = watch_id, .path = "" });
    return @intFromEnum(ToolingResult.ok);
}

/// Set file change callback
pub fn zylix_fs_set_callback(callback: CFileChangeCallback) callconv(.c) i32 {
    c_file_change_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Pause watching
pub fn zylix_fs_pause(watch_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var fw = file_watcher orelse return @intFromEnum(ToolingResult.err_not_initialized);

    fw.pause(.{ .id = watch_id, .path = "" });
    return @intFromEnum(ToolingResult.ok);
}

/// Resume watching
pub fn zylix_fs_resume(watch_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var fw = file_watcher orelse return @intFromEnum(ToolingResult.err_not_initialized);

    fw.resumeWatch(.{ .id = watch_id, .path = "" });
    return @intFromEnum(ToolingResult.ok);
}

/// Get active watch count
pub fn zylix_fs_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const fw = file_watcher orelse return 0;
    return @intCast(fw.activeCount());
}

/// Get total watch count
pub fn zylix_fs_total_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const fw = file_watcher orelse return 0;
    return @intCast(fw.totalCount());
}

/// Check if path is being watched
pub fn zylix_fs_is_watching(path: [*:0]const u8) callconv(.c) bool {
    if (!initialized) return false;
    const fw = file_watcher orelse return false;
    return fw.isWatching(std.mem.span(path));
}

/// Stop all watches
pub fn zylix_fs_stop_all() callconv(.c) void {
    if (!initialized) return;
    var fw = file_watcher orelse return;
    fw.stopAll();
}

// =============================================================================
// SYMBOL EXPORTS
// =============================================================================

comptime {
    // Lifecycle
    @export(&zylix_tooling_init, .{ .name = "zylix_tooling_init" });
    @export(&zylix_tooling_deinit, .{ .name = "zylix_tooling_deinit" });
    @export(&zylix_tooling_get_version, .{ .name = "zylix_tooling_get_version" });
    @export(&zylix_tooling_is_initialized, .{ .name = "zylix_tooling_is_initialized" });

    // Project Scaffolding (#46)
    @export(&zylix_project_create, .{ .name = "zylix_project_create" });
    @export(&zylix_project_validate, .{ .name = "zylix_project_validate" });
    @export(&zylix_project_get_info, .{ .name = "zylix_project_get_info" });
    @export(&zylix_project_count, .{ .name = "zylix_project_count" });
    @export(&zylix_project_delete, .{ .name = "zylix_project_delete" });

    // Build Orchestration (#47)
    @export(&zylix_build_start, .{ .name = "zylix_build_start" });
    @export(&zylix_build_cancel, .{ .name = "zylix_build_cancel" });
    @export(&zylix_build_get_status, .{ .name = "zylix_build_get_status" });
    @export(&zylix_build_set_progress_callback, .{ .name = "zylix_build_set_progress_callback" });
    @export(&zylix_build_set_log_callback, .{ .name = "zylix_build_set_log_callback" });
    @export(&zylix_build_active_count, .{ .name = "zylix_build_active_count" });
    @export(&zylix_build_total_count, .{ .name = "zylix_build_total_count" });

    // Artifact Query (#48)
    @export(&zylix_artifacts_count, .{ .name = "zylix_artifacts_count" });
    @export(&zylix_artifacts_get_metadata, .{ .name = "zylix_artifacts_get_metadata" });
    @export(&zylix_artifacts_export, .{ .name = "zylix_artifacts_export" });
    @export(&zylix_artifacts_verify, .{ .name = "zylix_artifacts_verify" });

    // Target Capability Matrix (#51)
    @export(&zylix_targets_supports_feature, .{ .name = "zylix_targets_supports_feature" });
    @export(&zylix_targets_get_support_level, .{ .name = "zylix_targets_get_support_level" });
    @export(&zylix_targets_get_input_specs, .{ .name = "zylix_targets_get_input_specs" });
    @export(&zylix_targets_count, .{ .name = "zylix_targets_count" });
    @export(&zylix_targets_are_compatible, .{ .name = "zylix_targets_are_compatible" });

    // Template Catalog (#52)
    @export(&zylix_templates_count, .{ .name = "zylix_templates_count" });
    @export(&zylix_templates_get, .{ .name = "zylix_templates_get" });
    @export(&zylix_templates_get_by_id, .{ .name = "zylix_templates_get_by_id" });
    @export(&zylix_templates_exists, .{ .name = "zylix_templates_exists" });

    // File Watcher (#53)
    @export(&zylix_fs_watch, .{ .name = "zylix_fs_watch" });
    @export(&zylix_fs_unwatch, .{ .name = "zylix_fs_unwatch" });
    @export(&zylix_fs_set_callback, .{ .name = "zylix_fs_set_callback" });
    @export(&zylix_fs_pause, .{ .name = "zylix_fs_pause" });
    @export(&zylix_fs_resume, .{ .name = "zylix_fs_resume" });
    @export(&zylix_fs_active_count, .{ .name = "zylix_fs_active_count" });
    @export(&zylix_fs_total_count, .{ .name = "zylix_fs_total_count" });
    @export(&zylix_fs_is_watching, .{ .name = "zylix_fs_is_watching" });
    @export(&zylix_fs_stop_all, .{ .name = "zylix_fs_stop_all" });
}

// =============================================================================
// TESTS
// =============================================================================

test "tooling abi init/deinit" {
    try std.testing.expectEqual(@as(i32, 0), zylix_tooling_init());
    try std.testing.expect(zylix_tooling_is_initialized());
    try std.testing.expectEqual(@as(i32, 0), zylix_tooling_deinit());
    try std.testing.expect(!zylix_tooling_is_initialized());
}

test "tooling abi version" {
    try std.testing.expectEqual(TOOLING_ABI_VERSION, zylix_tooling_get_version());
}

test "template exists" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_templates_exists("app"));
    try std.testing.expect(!zylix_templates_exists("nonexistent"));
}

test "target support" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // iOS supports Metal
    try std.testing.expect(zylix_targets_supports_feature(0, 2)); // ios, metal
    // Web doesn't support Metal
    try std.testing.expect(!zylix_targets_supports_feature(2, 2)); // web, metal
}

test "target count" {
    try std.testing.expectEqual(@as(u32, 7), zylix_targets_count());
}

test "target compatibility" {
    // iOS and Android are compatible (both mobile)
    try std.testing.expect(zylix_targets_are_compatible(0, 1));
    // macOS and Windows are compatible (both desktop)
    try std.testing.expect(zylix_targets_are_compatible(3, 4));
}
