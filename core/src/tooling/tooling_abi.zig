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
//! - Component Tree Export API (#56)
//! - Live Preview Bridge API (#57)
//! - Hot Reload API (#61)
//! - LSP Integration API (#62)
//! - DAP Integration API (#63)

const std = @import("std");
const project = @import("project.zig");
const build = @import("build.zig");
const artifacts = @import("artifacts.zig");
const targets = @import("targets.zig");
const templates = @import("templates.zig");
const watcher = @import("watcher.zig");
const ui = @import("ui.zig");
const preview = @import("preview.zig");
const hot_reload = @import("hot_reload.zig");
const lsp = @import("lsp.zig");
const dap = @import("dap.zig");

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
var ui_manager: ?ui.UI = null;
var preview_manager: ?preview.Preview = null;
var hot_reload_manager: ?hot_reload.HotReload = null;
var lsp_manager: ?lsp.Lsp = null;
var dap_manager: ?dap.Dap = null;

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
    ui_manager = ui.createUIManager(allocator);
    preview_manager = preview.createPreviewManager(allocator);
    hot_reload_manager = hot_reload.createHotReloadManager(allocator);
    lsp_manager = lsp.createLspManager(allocator);
    dap_manager = dap.createDapManager(allocator);

    initialized = true;
    return @intFromEnum(ToolingResult.ok);
}

/// Shutdown Zylix Tooling
pub fn zylix_tooling_deinit() callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.ok);

    if (dap_manager) |*d| d.deinit();
    if (lsp_manager) |*l| l.deinit();
    if (hot_reload_manager) |*h| h.deinit();
    if (preview_manager) |*p| p.deinit();
    if (ui_manager) |*u| u.deinit();
    if (file_watcher) |*w| w.deinit();
    if (template_manager) |*t| t.deinit();
    if (target_manager) |*t| t.deinit();
    if (artifact_manager) |*a| a.deinit();
    if (build_orchestrator) |*b| b.deinit();
    if (project_manager) |*p| p.deinit();

    dap_manager = null;
    lsp_manager = null;
    hot_reload_manager = null;
    preview_manager = null;
    ui_manager = null;
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
// COMPONENT TREE EXPORT API (#56)
// =============================================================================

/// C-compatible component identifier
pub const CComponentId = extern struct {
    id: u64,
    name: [128]u8,
    parent_id: u64, // 0 if root
};

/// C-compatible component information
pub const CComponentInfo = extern struct {
    id: CComponentId,
    component_type: u8,
    display_name: [128]u8,
    custom_type: [64]u8,
    source_file: [512]u8,
    source_line: u32,
    children_count: u32,
    visible: bool,
    enabled: bool,
};

// Static caches for C ABI returns
var c_component_info_cache: CComponentInfo = undefined;
var c_component_list_cache: [64]CComponentInfo = undefined;

/// Export component tree for a project
pub fn zylix_ui_export_tree(project_id: u64, format: u8) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var um = ui_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const future = um.exportTree(pid);
    defer allocator.destroy(future);

    if (future.err != null) {
        return @intFromEnum(ToolingResult.err_io_error);
    }

    // Format: 0=JSON, 1=YAML, 2=XML
    _ = format;

    return @intFromEnum(ToolingResult.ok);
}

/// Get component information by ID
pub fn zylix_ui_get_component(component_id: u64) callconv(.c) ?*const CComponentInfo {
    if (!initialized) return null;

    const um = ui_manager orelse return null;

    const cid = ui.ComponentId{
        .id = component_id,
        .name = "",
    };

    if (um.getComponentInfo(cid)) |info| {
        // Clear and populate cache
        @memset(&c_component_info_cache.id.name, 0);
        @memset(&c_component_info_cache.display_name, 0);
        @memset(&c_component_info_cache.custom_type, 0);
        @memset(&c_component_info_cache.source_file, 0);

        c_component_info_cache.id.id = info.id.id;
        c_component_info_cache.id.parent_id = info.id.parent_id orelse 0;
        c_component_info_cache.component_type = @intFromEnum(info.component_type);
        c_component_info_cache.source_line = info.source_line orelse 0;
        c_component_info_cache.children_count = info.children_count;
        c_component_info_cache.visible = info.visible;
        c_component_info_cache.enabled = info.enabled;

        // Copy name
        const name_len = @min(info.id.name.len, c_component_info_cache.id.name.len - 1);
        @memcpy(c_component_info_cache.id.name[0..name_len], info.id.name[0..name_len]);

        // Copy display name
        if (info.display_name) |dn| {
            const dn_len = @min(dn.len, c_component_info_cache.display_name.len - 1);
            @memcpy(c_component_info_cache.display_name[0..dn_len], dn[0..dn_len]);
        }

        // Copy custom type
        if (info.custom_type) |ct| {
            const ct_len = @min(ct.len, c_component_info_cache.custom_type.len - 1);
            @memcpy(c_component_info_cache.custom_type[0..ct_len], ct[0..ct_len]);
        }

        // Copy source file
        if (info.source_file) |sf| {
            const sf_len = @min(sf.len, c_component_info_cache.source_file.len - 1);
            @memcpy(c_component_info_cache.source_file[0..sf_len], sf[0..sf_len]);
        }

        return &c_component_info_cache;
    }

    return null;
}

/// Get component count for a project
pub fn zylix_ui_component_count(project_id: u64) callconv(.c) u32 {
    if (!initialized) return 0;

    const um = ui_manager orelse return 0;
    _ = project_id; // Would filter by project in real implementation

    return @intCast(um.count());
}

/// Find components by type
pub fn zylix_ui_find_by_type(project_id: u64, component_type: u8, count: *u32) callconv(.c) ?*const CComponentInfo {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var um = ui_manager orelse {
        count.* = 0;
        return null;
    };

    _ = project_id; // Would filter by project in real implementation

    const comp_type: ui.ComponentType = @enumFromInt(component_type);
    const components = um.findByType(comp_type) catch {
        count.* = 0;
        return null;
    };
    defer allocator.free(components);

    if (components.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(components.len, c_component_list_cache.len);

    for (components[0..max_count], 0..) |info, i| {
        @memset(&c_component_list_cache[i].id.name, 0);
        @memset(&c_component_list_cache[i].display_name, 0);
        @memset(&c_component_list_cache[i].custom_type, 0);
        @memset(&c_component_list_cache[i].source_file, 0);

        c_component_list_cache[i].id.id = info.id.id;
        c_component_list_cache[i].id.parent_id = info.id.parent_id orelse 0;
        c_component_list_cache[i].component_type = @intFromEnum(info.component_type);
        c_component_list_cache[i].source_line = info.source_line orelse 0;
        c_component_list_cache[i].children_count = info.children_count;
        c_component_list_cache[i].visible = info.visible;
        c_component_list_cache[i].enabled = info.enabled;

        const name_len = @min(info.id.name.len, c_component_list_cache[i].id.name.len - 1);
        @memcpy(c_component_list_cache[i].id.name[0..name_len], info.id.name[0..name_len]);

        if (info.display_name) |dn| {
            const dn_len = @min(dn.len, c_component_list_cache[i].display_name.len - 1);
            @memcpy(c_component_list_cache[i].display_name[0..dn_len], dn[0..dn_len]);
        }
    }

    count.* = @intCast(max_count);
    return &c_component_list_cache[0];
}

// =============================================================================
// LIVE PREVIEW BRIDGE API (#57)
// =============================================================================

/// C-compatible preview identifier
pub const CPreviewId = extern struct {
    id: u64,
    project_name: [128]u8,
    target: u8,
    started_at: i64,
};

/// C-compatible preview configuration
pub const CPreviewConfig = extern struct {
    device_id: [64]u8,
    port: u16,
    hot_reload: bool,
    auto_open: bool,
    remote_debug: bool,
};

/// C-compatible preview session
pub const CPreviewSession = extern struct {
    id: CPreviewId,
    state: u8,
    url: [256]u8,
    reload_count: u32,
    last_reload: i64,
};

/// Preview event callback type
pub const CPreviewEventCallback = ?*const fn (u8, ?*const anyopaque) callconv(.c) void;

// Static caches for preview API
var c_preview_session_cache: CPreviewSession = undefined;
var c_preview_callback: CPreviewEventCallback = null;

/// Open a preview session
pub fn zylix_preview_open(project_id: u64, target: u8, config: *const CPreviewConfig) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var pm = preview_manager orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const zig_config = preview.PreviewConfig{
        .device_id = null, // Would parse from config.device_id
        .port = config.port,
        .hot_reload = config.hot_reload,
        .auto_open = config.auto_open,
        .remote_debug = config.remote_debug,
    };

    const future = pm.open(pid, @enumFromInt(target), zig_config);
    defer allocator.destroy(future);

    if (future.result) |preview_id| {
        return @intCast(preview_id.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_io_error));
}

/// Close a preview session
pub fn zylix_preview_close(preview_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var pm = preview_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const pid = preview.PreviewId{
        .id = preview_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    pm.close(pid);
    return @intFromEnum(ToolingResult.ok);
}

/// Refresh a preview session
pub fn zylix_preview_refresh(preview_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var pm = preview_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const pid = preview.PreviewId{
        .id = preview_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    pm.refresh(pid);
    return @intFromEnum(ToolingResult.ok);
}

/// Set debug overlay for a preview session
pub fn zylix_preview_set_debug_overlay(preview_id: u64, enabled: bool) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var pm = preview_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const pid = preview.PreviewId{
        .id = preview_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    pm.setDebugOverlay(pid, enabled);
    return @intFromEnum(ToolingResult.ok);
}

/// Get preview session information
pub fn zylix_preview_get_session(preview_id: u64) callconv(.c) ?*const CPreviewSession {
    if (!initialized) return null;

    const pm = preview_manager orelse return null;

    const pid = preview.PreviewId{
        .id = preview_id,
        .project_name = "",
        .target = .ios,
        .started_at = 0,
    };

    if (pm.getSession(pid)) |session| {
        // Clear and populate cache
        @memset(&c_preview_session_cache.id.project_name, 0);
        @memset(&c_preview_session_cache.url, 0);

        c_preview_session_cache.id.id = session.id.id;
        c_preview_session_cache.id.target = @intFromEnum(session.id.target);
        c_preview_session_cache.id.started_at = session.id.started_at;
        c_preview_session_cache.state = @intFromEnum(session.state);
        c_preview_session_cache.reload_count = session.reload_count;
        c_preview_session_cache.last_reload = session.last_reload orelse 0;

        // Copy project name
        const pn_len = @min(session.id.project_name.len, c_preview_session_cache.id.project_name.len - 1);
        @memcpy(c_preview_session_cache.id.project_name[0..pn_len], session.id.project_name[0..pn_len]);

        // Copy URL
        const url = session.url orelse "";
        const url_len = @min(url.len, c_preview_session_cache.url.len - 1);
        @memcpy(c_preview_session_cache.url[0..url_len], url[0..url_len]);

        return &c_preview_session_cache;
    }

    return null;
}

/// Set preview event callback
pub fn zylix_preview_set_callback(preview_id: u64, callback: CPreviewEventCallback) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    _ = preview_id; // Would register per-session in real implementation
    c_preview_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Get active preview count
pub fn zylix_preview_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const pm = preview_manager orelse return 0;
    return @intCast(pm.activeCount());
}

// =============================================================================
// HOT RELOAD API (#61)
// =============================================================================

/// C-compatible hot reload session identifier
pub const CHotReloadSessionId = extern struct {
    id: u64,
    project_name: [128]u8,
    started_at: i64,
};

/// C-compatible hot reload configuration
pub const CHotReloadConfig = extern struct {
    debounce_ms: u32,
    preserve_state: bool,
    incremental: bool,
    auto_reload: bool,
    notify_success: bool,
    notify_error: bool,
};

/// C-compatible hot reload statistics
pub const CHotReloadStats = extern struct {
    total_reloads: u32,
    successful_reloads: u32,
    failed_reloads: u32,
    average_duration_ms: u64,
    last_reload_at: i64,
    total_files_changed: u32,
};

/// C-compatible hot reload session
pub const CHotReloadSession = extern struct {
    id: CHotReloadSessionId,
    state: u8,
    target: u8,
    stats: CHotReloadStats,
    error_message: [256]u8,
};

/// C-compatible reload result
pub const CReloadResult = extern struct {
    success: bool,
    duration_ms: u64,
    changed_files: u32,
    compiled_modules: u32,
    preserved_state: bool,
    error_message: [256]u8,
};

/// Hot reload event callback type
pub const CHotReloadEventCallback = ?*const fn (u8, ?*const anyopaque) callconv(.c) void;

// Static caches for hot reload API
var c_hot_reload_session_cache: CHotReloadSession = undefined;
var c_hot_reload_stats_cache: CHotReloadStats = undefined;
var c_reload_result_cache: CReloadResult = undefined;
var c_hot_reload_callback: CHotReloadEventCallback = null;

/// Start a hot reload session
pub fn zylix_hot_reload_start(project_id: u64, target: u8, config: *const CHotReloadConfig) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var hrm = hot_reload_manager orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const zig_config = hot_reload.HotReloadConfig{
        .debounce_ms = config.debounce_ms,
        .preserve_state = config.preserve_state,
        .incremental = config.incremental,
        .auto_reload = config.auto_reload,
        .notify_success = config.notify_success,
        .notify_error = config.notify_error,
    };

    const future = hrm.start(pid, @enumFromInt(target), zig_config);
    defer allocator.destroy(future);

    if (future.result) |session_id| {
        return @intCast(session_id.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_io_error));
}

/// Stop a hot reload session
pub fn zylix_hot_reload_stop(session_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var hrm = hot_reload_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    hrm.stop(sid);
    return @intFromEnum(ToolingResult.ok);
}

/// Trigger a reload
pub fn zylix_hot_reload_trigger(session_id: u64) callconv(.c) ?*const CReloadResult {
    if (!initialized) return null;

    var hrm = hot_reload_manager orelse return null;

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    const future = hrm.reload(sid);
    defer allocator.destroy(future);

    if (future.result) |result| {
        @memset(&c_reload_result_cache.error_message, 0);

        c_reload_result_cache = .{
            .success = result.success,
            .duration_ms = result.duration_ms,
            .changed_files = result.changed_files,
            .compiled_modules = result.compiled_modules,
            .preserved_state = result.preserved_state,
            .error_message = undefined,
        };
        @memset(&c_reload_result_cache.error_message, 0);

        if (result.error_message) |msg| {
            const len = @min(msg.len, c_reload_result_cache.error_message.len - 1);
            @memcpy(c_reload_result_cache.error_message[0..len], msg[0..len]);
        }

        return &c_reload_result_cache;
    }

    return null;
}

/// Pause hot reload watching
pub fn zylix_hot_reload_pause(session_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var hrm = hot_reload_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    hrm.pause(sid);
    return @intFromEnum(ToolingResult.ok);
}

/// Resume hot reload watching
pub fn zylix_hot_reload_resume(session_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var hrm = hot_reload_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    hrm.resumeWatch(sid);
    return @intFromEnum(ToolingResult.ok);
}

/// Get hot reload session information
pub fn zylix_hot_reload_get_session(session_id: u64) callconv(.c) ?*const CHotReloadSession {
    if (!initialized) return null;

    const hrm = hot_reload_manager orelse return null;

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    if (hrm.getSession(sid)) |session| {
        @memset(&c_hot_reload_session_cache.id.project_name, 0);
        @memset(&c_hot_reload_session_cache.error_message, 0);

        c_hot_reload_session_cache.id.id = session.id.id;
        c_hot_reload_session_cache.id.started_at = session.id.started_at;
        c_hot_reload_session_cache.state = @intFromEnum(session.state);
        c_hot_reload_session_cache.target = @intFromEnum(session.target);

        c_hot_reload_session_cache.stats = .{
            .total_reloads = session.stats.total_reloads,
            .successful_reloads = session.stats.successful_reloads,
            .failed_reloads = session.stats.failed_reloads,
            .average_duration_ms = session.stats.average_duration_ms,
            .last_reload_at = session.stats.last_reload_at orelse 0,
            .total_files_changed = session.stats.total_files_changed,
        };

        const pn_len = @min(session.id.project_name.len, c_hot_reload_session_cache.id.project_name.len - 1);
        @memcpy(c_hot_reload_session_cache.id.project_name[0..pn_len], session.id.project_name[0..pn_len]);

        if (session.error_message) |msg| {
            const len = @min(msg.len, c_hot_reload_session_cache.error_message.len - 1);
            @memcpy(c_hot_reload_session_cache.error_message[0..len], msg[0..len]);
        }

        return &c_hot_reload_session_cache;
    }

    return null;
}

/// Get hot reload statistics
pub fn zylix_hot_reload_get_stats(session_id: u64) callconv(.c) ?*const CHotReloadStats {
    if (!initialized) return null;

    const hrm = hot_reload_manager orelse return null;

    const sid = hot_reload.SessionId{
        .id = session_id,
        .project_name = "",
        .started_at = 0,
    };

    if (hrm.getStats(sid)) |stats| {
        c_hot_reload_stats_cache = .{
            .total_reloads = stats.total_reloads,
            .successful_reloads = stats.successful_reloads,
            .failed_reloads = stats.failed_reloads,
            .average_duration_ms = stats.average_duration_ms,
            .last_reload_at = stats.last_reload_at orelse 0,
            .total_files_changed = stats.total_files_changed,
        };
        return &c_hot_reload_stats_cache;
    }

    return null;
}

/// Set hot reload event callback
pub fn zylix_hot_reload_set_callback(session_id: u64, callback: CHotReloadEventCallback) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    _ = session_id; // Would register per-session in real implementation
    c_hot_reload_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Get active hot reload session count
pub fn zylix_hot_reload_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const hrm = hot_reload_manager orelse return 0;
    return @intCast(hrm.activeCount());
}

/// Get total hot reload session count
pub fn zylix_hot_reload_total_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const hrm = hot_reload_manager orelse return 0;
    return @intCast(hrm.totalCount());
}

// =============================================================================
// LSP INTEGRATION API (#62)
// =============================================================================

/// C-compatible LSP server identifier
pub const CLspServerId = extern struct {
    id: u64,
    port: u16,
    started_at: i64,
};

/// C-compatible LSP configuration
pub const CLspConfig = extern struct {
    port: u16,
    completion: bool,
    hover: bool,
    definition: bool,
    references: bool,
    document_symbols: bool,
    workspace_symbols: bool,
    diagnostics: bool,
    formatting: bool,
    rename: bool,
    code_actions: bool,
};

/// C-compatible LSP session
pub const CLspSession = extern struct {
    id: CLspServerId,
    state: u8,
    project_path: [512]u8,
    open_documents: u32,
    request_count: u64,
    error_count: u32,
    last_request_at: i64,
};

/// C-compatible server capabilities
pub const CLspCapabilities = extern struct {
    completion: bool,
    hover: bool,
    definition: bool,
    references: bool,
    document_symbols: bool,
    workspace_symbols: bool,
    diagnostics: bool,
    formatting: bool,
    rename: bool,
    code_actions: bool,
};

/// C-compatible position
pub const CLspPosition = extern struct {
    line: u32,
    character: u32,
};

/// C-compatible range
pub const CLspRange = extern struct {
    start_line: u32,
    start_character: u32,
    end_line: u32,
    end_character: u32,
};

/// C-compatible location
pub const CLspLocation = extern struct {
    uri: [512]u8,
    start_line: u32,
    start_character: u32,
    end_line: u32,
    end_character: u32,
};

/// C-compatible completion item
pub const CLspCompletionItem = extern struct {
    label: [128]u8,
    kind: u8,
    detail: [256]u8,
    documentation: [512]u8,
    insert_text: [256]u8,
};

/// C-compatible hover result
pub const CLspHoverResult = extern struct {
    contents: [1024]u8,
    has_range: bool,
    range: CLspRange,
};

/// C-compatible document symbol
pub const CLspDocumentSymbol = extern struct {
    name: [128]u8,
    kind: u8,
    range: CLspRange,
    selection_range: CLspRange,
    detail: [256]u8,
};

/// LSP event callback type
pub const CLspEventCallback = ?*const fn (u8, ?*const anyopaque) callconv(.c) void;

// Static caches for LSP API
var c_lsp_session_cache: CLspSession = undefined;
var c_lsp_capabilities_cache: CLspCapabilities = undefined;
var c_lsp_hover_cache: CLspHoverResult = undefined;
var c_lsp_location_cache: CLspLocation = undefined;
var c_lsp_completions_cache: [32]CLspCompletionItem = undefined;
var c_lsp_symbols_cache: [64]CLspDocumentSymbol = undefined;
var c_lsp_locations_cache: [64]CLspLocation = undefined;
var c_lsp_callback: CLspEventCallback = null;

/// Start LSP server
pub fn zylix_lsp_start(project_id: u64, config: *const CLspConfig) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var lm = lsp_manager orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const zig_config = lsp.LspConfig{
        .port = config.port,
        .completion = config.completion,
        .hover = config.hover,
        .definition = config.definition,
        .references = config.references,
        .document_symbols = config.document_symbols,
        .workspace_symbols = config.workspace_symbols,
        .diagnostics = config.diagnostics,
        .formatting = config.formatting,
        .rename = config.rename,
        .code_actions = config.code_actions,
    };

    const future = lm.start(pid, zig_config);
    defer allocator.destroy(future);

    if (future.result) |server_id| {
        return @intCast(server_id.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_io_error));
}

/// Stop LSP server
pub fn zylix_lsp_stop(server_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var lm = lsp_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    lm.stop(sid);
    return @intFromEnum(ToolingResult.ok);
}

/// Get LSP session information
pub fn zylix_lsp_get_session(server_id: u64) callconv(.c) ?*const CLspSession {
    if (!initialized) return null;

    const lm = lsp_manager orelse return null;

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    if (lm.getSession(sid)) |session| {
        @memset(&c_lsp_session_cache.project_path, 0);

        c_lsp_session_cache.id.id = session.id.id;
        c_lsp_session_cache.id.port = session.id.port;
        c_lsp_session_cache.id.started_at = session.id.started_at;
        c_lsp_session_cache.state = @intFromEnum(session.state);
        c_lsp_session_cache.open_documents = session.open_documents;
        c_lsp_session_cache.request_count = session.request_count;
        c_lsp_session_cache.error_count = session.error_count;
        c_lsp_session_cache.last_request_at = session.last_request_at orelse 0;

        const path_len = @min(session.project_path.len, c_lsp_session_cache.project_path.len - 1);
        @memcpy(c_lsp_session_cache.project_path[0..path_len], session.project_path[0..path_len]);

        return &c_lsp_session_cache;
    }

    return null;
}

/// Get LSP server capabilities
pub fn zylix_lsp_get_capabilities(server_id: u64) callconv(.c) ?*const CLspCapabilities {
    if (!initialized) return null;

    const lm = lsp_manager orelse return null;

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    if (lm.getCapabilities(sid)) |caps| {
        c_lsp_capabilities_cache = .{
            .completion = caps.completion,
            .hover = caps.hover,
            .definition = caps.definition,
            .references = caps.references,
            .document_symbols = caps.document_symbols,
            .workspace_symbols = caps.workspace_symbols,
            .diagnostics = caps.diagnostics,
            .formatting = caps.formatting,
            .rename = caps.rename,
            .code_actions = caps.code_actions,
        };
        return &c_lsp_capabilities_cache;
    }

    return null;
}

/// Get completion items
pub fn zylix_lsp_get_completion(
    server_id: u64,
    uri: [*:0]const u8,
    line: u32,
    character: u32,
    count: *u32,
) callconv(.c) ?*const CLspCompletionItem {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var lm = lsp_manager orelse {
        count.* = 0;
        return null;
    };

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    const uri_str = std.mem.span(uri);
    const position = lsp.Position{ .line = line, .character = character };

    const items = lm.getCompletion(sid, uri_str, position) catch {
        count.* = 0;
        return null;
    };

    if (items.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(items.len, c_lsp_completions_cache.len);

    for (items[0..max_count], 0..) |item, i| {
        @memset(&c_lsp_completions_cache[i].label, 0);
        @memset(&c_lsp_completions_cache[i].detail, 0);
        @memset(&c_lsp_completions_cache[i].documentation, 0);
        @memset(&c_lsp_completions_cache[i].insert_text, 0);

        const label_len = @min(item.label.len, c_lsp_completions_cache[i].label.len - 1);
        @memcpy(c_lsp_completions_cache[i].label[0..label_len], item.label[0..label_len]);

        c_lsp_completions_cache[i].kind = @intFromEnum(item.kind);

        if (item.detail) |d| {
            const d_len = @min(d.len, c_lsp_completions_cache[i].detail.len - 1);
            @memcpy(c_lsp_completions_cache[i].detail[0..d_len], d[0..d_len]);
        }
    }

    count.* = @intCast(max_count);
    return &c_lsp_completions_cache[0];
}

/// Get hover information
pub fn zylix_lsp_get_hover(
    server_id: u64,
    uri: [*:0]const u8,
    line: u32,
    character: u32,
) callconv(.c) ?*const CLspHoverResult {
    if (!initialized) return null;

    var lm = lsp_manager orelse return null;

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    const uri_str = std.mem.span(uri);
    const position = lsp.Position{ .line = line, .character = character };

    if (lm.getHover(sid, uri_str, position) catch null) |hover| {
        @memset(&c_lsp_hover_cache.contents, 0);

        const content_len = @min(hover.contents.len, c_lsp_hover_cache.contents.len - 1);
        @memcpy(c_lsp_hover_cache.contents[0..content_len], hover.contents[0..content_len]);

        c_lsp_hover_cache.has_range = hover.range != null;
        if (hover.range) |r| {
            c_lsp_hover_cache.range = .{
                .start_line = r.start.line,
                .start_character = r.start.character,
                .end_line = r.end.line,
                .end_character = r.end.character,
            };
        }

        return &c_lsp_hover_cache;
    }

    return null;
}

/// Get definition location
pub fn zylix_lsp_get_definition(
    server_id: u64,
    uri: [*:0]const u8,
    line: u32,
    character: u32,
) callconv(.c) ?*const CLspLocation {
    if (!initialized) return null;

    var lm = lsp_manager orelse return null;

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    const uri_str = std.mem.span(uri);
    const position = lsp.Position{ .line = line, .character = character };

    if (lm.getDefinition(sid, uri_str, position) catch null) |loc| {
        @memset(&c_lsp_location_cache.uri, 0);

        const uri_len = @min(loc.uri.len, c_lsp_location_cache.uri.len - 1);
        @memcpy(c_lsp_location_cache.uri[0..uri_len], loc.uri[0..uri_len]);

        c_lsp_location_cache.start_line = loc.range.start.line;
        c_lsp_location_cache.start_character = loc.range.start.character;
        c_lsp_location_cache.end_line = loc.range.end.line;
        c_lsp_location_cache.end_character = loc.range.end.character;

        return &c_lsp_location_cache;
    }

    return null;
}

/// Get references
pub fn zylix_lsp_get_references(
    server_id: u64,
    uri: [*:0]const u8,
    line: u32,
    character: u32,
    count: *u32,
) callconv(.c) ?*const CLspLocation {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var lm = lsp_manager orelse {
        count.* = 0;
        return null;
    };

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    const uri_str = std.mem.span(uri);
    const position = lsp.Position{ .line = line, .character = character };

    const refs = lm.getReferences(sid, uri_str, position) catch {
        count.* = 0;
        return null;
    };

    if (refs.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(refs.len, c_lsp_locations_cache.len);

    for (refs[0..max_count], 0..) |loc, i| {
        @memset(&c_lsp_locations_cache[i].uri, 0);

        const u_len = @min(loc.uri.len, c_lsp_locations_cache[i].uri.len - 1);
        @memcpy(c_lsp_locations_cache[i].uri[0..u_len], loc.uri[0..u_len]);

        c_lsp_locations_cache[i].start_line = loc.range.start.line;
        c_lsp_locations_cache[i].start_character = loc.range.start.character;
        c_lsp_locations_cache[i].end_line = loc.range.end.line;
        c_lsp_locations_cache[i].end_character = loc.range.end.character;
    }

    count.* = @intCast(max_count);
    return &c_lsp_locations_cache[0];
}

/// Get document symbols
pub fn zylix_lsp_get_document_symbols(
    server_id: u64,
    uri: [*:0]const u8,
    count: *u32,
) callconv(.c) ?*const CLspDocumentSymbol {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var lm = lsp_manager orelse {
        count.* = 0;
        return null;
    };

    const sid = lsp.ServerId{
        .id = server_id,
        .port = 0,
        .started_at = 0,
    };

    const uri_str = std.mem.span(uri);

    const symbols = lm.getDocumentSymbols(sid, uri_str) catch {
        count.* = 0;
        return null;
    };

    if (symbols.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(symbols.len, c_lsp_symbols_cache.len);

    for (symbols[0..max_count], 0..) |sym, i| {
        @memset(&c_lsp_symbols_cache[i].name, 0);
        @memset(&c_lsp_symbols_cache[i].detail, 0);

        const name_len = @min(sym.name.len, c_lsp_symbols_cache[i].name.len - 1);
        @memcpy(c_lsp_symbols_cache[i].name[0..name_len], sym.name[0..name_len]);

        c_lsp_symbols_cache[i].kind = @intFromEnum(sym.kind);
        c_lsp_symbols_cache[i].range = .{
            .start_line = sym.range.start.line,
            .start_character = sym.range.start.character,
            .end_line = sym.range.end.line,
            .end_character = sym.range.end.character,
        };
        c_lsp_symbols_cache[i].selection_range = .{
            .start_line = sym.selection_range.start.line,
            .start_character = sym.selection_range.start.character,
            .end_line = sym.selection_range.end.line,
            .end_character = sym.selection_range.end.character,
        };

        if (sym.detail) |d| {
            const d_len = @min(d.len, c_lsp_symbols_cache[i].detail.len - 1);
            @memcpy(c_lsp_symbols_cache[i].detail[0..d_len], d[0..d_len]);
        }
    }

    count.* = @intCast(max_count);
    return &c_lsp_symbols_cache[0];
}

/// Set LSP event callback
pub fn zylix_lsp_set_callback(server_id: u64, callback: CLspEventCallback) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    _ = server_id; // Would register per-server in real implementation
    c_lsp_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Get active LSP server count
pub fn zylix_lsp_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const lm = lsp_manager orelse return 0;
    return @intCast(lm.activeCount());
}

/// Get total LSP server count
pub fn zylix_lsp_total_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const lm = lsp_manager orelse return 0;
    return @intCast(lm.totalCount());
}

// =============================================================================
// DAP INTEGRATION API (#63)
// =============================================================================

/// C-compatible DAP adapter identifier
pub const CDapAdapterId = extern struct {
    id: u64,
    port: u16,
    started_at: i64,
};

/// C-compatible DAP configuration
pub const CDapConfig = extern struct {
    port: u16,
    stop_at_entry: bool,
    source_maps: bool,
    logging: bool,
    exception_breakpoints: bool,
};

/// C-compatible DAP session
pub const CDapSession = extern struct {
    id: CDapAdapterId,
    state: u8,
    project_path: [512]u8,
    breakpoint_count: u32,
    thread_count: u32,
    current_thread_id: u64,
    current_frame_id: u64,
    stop_reason: u8,
};

/// C-compatible debug capabilities
pub const CDapCapabilities = extern struct {
    supports_configuration_done: bool,
    supports_function_breakpoints: bool,
    supports_conditional_breakpoints: bool,
    supports_hit_conditional_breakpoints: bool,
    supports_evaluate_for_hovers: bool,
    supports_step_back: bool,
    supports_set_variable: bool,
    supports_restart_frame: bool,
    supports_stepping_granularity: bool,
    supports_exception_breakpoints: bool,
    supports_value_formatting: bool,
    supports_terminate_debuggee: bool,
    supports_log_points: bool,
};

/// C-compatible breakpoint
pub const CDapBreakpoint = extern struct {
    id: u64,
    breakpoint_type: u8,
    verified: bool,
    source_path: [512]u8,
    line: u32,
    column: u32,
    condition: [256]u8,
    hit_count: u32,
};

/// C-compatible thread
pub const CDapThread = extern struct {
    id: u64,
    name: [128]u8,
};

/// C-compatible stack frame
pub const CDapStackFrame = extern struct {
    id: u64,
    name: [128]u8,
    source_path: [512]u8,
    line: u32,
    column: u32,
    end_line: u32,
    end_column: u32,
};

/// C-compatible variable
pub const CDapVariable = extern struct {
    name: [128]u8,
    value: [512]u8,
    variable_type: [64]u8,
    variables_reference: u64,
};

/// DAP event callback type
pub const CDapEventCallback = ?*const fn (u8, ?*const anyopaque) callconv(.c) void;

// Static caches for DAP API
var c_dap_session_cache: CDapSession = undefined;
var c_dap_capabilities_cache: CDapCapabilities = undefined;
var c_dap_breakpoint_cache: CDapBreakpoint = undefined;
var c_dap_threads_cache: [32]CDapThread = undefined;
var c_dap_frames_cache: [64]CDapStackFrame = undefined;
var c_dap_variables_cache: [64]CDapVariable = undefined;
var c_dap_callback: CDapEventCallback = null;

/// Start DAP adapter
pub fn zylix_dap_start(project_id: u64, config: *const CDapConfig) callconv(.c) i64 {
    if (!initialized) return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    var dm = dap_manager orelse return -@as(i64, @intFromEnum(ToolingResult.err_not_initialized));

    const pid = project.ProjectId{
        .id = project_id,
        .name = "",
        .path = "",
    };

    const zig_config = dap.DapConfig{
        .port = config.port,
        .stop_at_entry = config.stop_at_entry,
        .source_maps = config.source_maps,
        .logging = config.logging,
        .exception_breakpoints = config.exception_breakpoints,
    };

    const future = dm.start(pid, zig_config);
    defer allocator.destroy(future);

    if (future.result) |adapter_id| {
        return @intCast(adapter_id.id);
    }

    return -@as(i64, @intFromEnum(ToolingResult.err_io_error));
}

/// Stop DAP adapter
pub fn zylix_dap_stop(adapter_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.stop(aid);
    return @intFromEnum(ToolingResult.ok);
}

/// Launch debuggee
pub fn zylix_dap_launch(adapter_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const future = dm.launch(aid);
    defer allocator.destroy(future);

    if (future.err != null) {
        return @intFromEnum(ToolingResult.err_io_error);
    }

    return @intFromEnum(ToolingResult.ok);
}

/// Attach to running process
pub fn zylix_dap_attach(adapter_id: u64, process_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const future = dm.attach(aid, process_id);
    defer allocator.destroy(future);

    if (future.err != null) {
        return @intFromEnum(ToolingResult.err_io_error);
    }

    return @intFromEnum(ToolingResult.ok);
}

/// Get DAP session information
pub fn zylix_dap_get_session(adapter_id: u64) callconv(.c) ?*const CDapSession {
    if (!initialized) return null;

    const dm = dap_manager orelse return null;

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    if (dm.getSession(aid)) |session| {
        @memset(&c_dap_session_cache.project_path, 0);

        c_dap_session_cache.id.id = session.id.id;
        c_dap_session_cache.id.port = session.id.port;
        c_dap_session_cache.id.started_at = session.id.started_at;
        c_dap_session_cache.state = @intFromEnum(session.state);
        c_dap_session_cache.breakpoint_count = session.breakpoint_count;
        c_dap_session_cache.thread_count = session.thread_count;
        c_dap_session_cache.current_thread_id = session.current_thread_id orelse 0;
        c_dap_session_cache.current_frame_id = session.current_frame_id orelse 0;
        c_dap_session_cache.stop_reason = if (session.stop_reason) |r| @intFromEnum(r) else 0;

        const path_len = @min(session.project_path.len, c_dap_session_cache.project_path.len - 1);
        @memcpy(c_dap_session_cache.project_path[0..path_len], session.project_path[0..path_len]);

        return &c_dap_session_cache;
    }

    return null;
}

/// Get DAP capabilities
pub fn zylix_dap_get_capabilities(adapter_id: u64) callconv(.c) ?*const CDapCapabilities {
    if (!initialized) return null;

    const dm = dap_manager orelse return null;

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    if (dm.getCapabilities(aid)) |caps| {
        c_dap_capabilities_cache = .{
            .supports_configuration_done = caps.supports_configuration_done,
            .supports_function_breakpoints = caps.supports_function_breakpoints,
            .supports_conditional_breakpoints = caps.supports_conditional_breakpoints,
            .supports_hit_conditional_breakpoints = caps.supports_hit_conditional_breakpoints,
            .supports_evaluate_for_hovers = caps.supports_evaluate_for_hovers,
            .supports_step_back = caps.supports_step_back,
            .supports_set_variable = caps.supports_set_variable,
            .supports_restart_frame = caps.supports_restart_frame,
            .supports_stepping_granularity = caps.supports_stepping_granularity,
            .supports_exception_breakpoints = caps.supports_exception_breakpoints,
            .supports_value_formatting = caps.supports_value_formatting,
            .supports_terminate_debuggee = caps.supports_terminate_debuggee,
            .supports_log_points = caps.supports_log_points,
        };
        return &c_dap_capabilities_cache;
    }

    return null;
}

/// Set breakpoint
pub fn zylix_dap_set_breakpoint(
    adapter_id: u64,
    source_path: [*:0]const u8,
    line: u32,
    condition: [*:0]const u8,
) callconv(.c) ?*const CDapBreakpoint {
    if (!initialized) return null;

    var dm = dap_manager orelse return null;

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const source_str = std.mem.span(source_path);
    const cond_str = std.mem.span(condition);
    const cond_opt: ?[]const u8 = if (cond_str.len > 0) cond_str else null;

    const future = dm.setBreakpoint(aid, source_str, line, cond_opt);
    defer allocator.destroy(future);

    if (future.result) |bp| {
        @memset(&c_dap_breakpoint_cache.source_path, 0);
        @memset(&c_dap_breakpoint_cache.condition, 0);

        c_dap_breakpoint_cache.id = bp.id;
        c_dap_breakpoint_cache.breakpoint_type = @intFromEnum(bp.breakpoint_type);
        c_dap_breakpoint_cache.verified = bp.verified;
        c_dap_breakpoint_cache.line = bp.line orelse 0;
        c_dap_breakpoint_cache.column = bp.column orelse 0;
        c_dap_breakpoint_cache.hit_count = bp.hit_count;

        if (bp.source_path) |sp| {
            const sp_len = @min(sp.len, c_dap_breakpoint_cache.source_path.len - 1);
            @memcpy(c_dap_breakpoint_cache.source_path[0..sp_len], sp[0..sp_len]);
        }

        if (bp.condition) |c| {
            const c_len = @min(c.len, c_dap_breakpoint_cache.condition.len - 1);
            @memcpy(c_dap_breakpoint_cache.condition[0..c_len], c[0..c_len]);
        }

        return &c_dap_breakpoint_cache;
    }

    return null;
}

/// Remove breakpoint
pub fn zylix_dap_remove_breakpoint(adapter_id: u64, breakpoint_id: u64) callconv(.c) bool {
    if (!initialized) return false;

    var dm = dap_manager orelse return false;

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    return dm.removeBreakpoint(aid, breakpoint_id);
}

/// Continue execution
pub fn zylix_dap_continue(adapter_id: u64, thread_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.continueExecution(aid, thread_id);
    return @intFromEnum(ToolingResult.ok);
}

/// Pause execution
pub fn zylix_dap_pause(adapter_id: u64, thread_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.pause(aid, thread_id);
    return @intFromEnum(ToolingResult.ok);
}

/// Step into
pub fn zylix_dap_step_into(adapter_id: u64, thread_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.stepInto(aid, thread_id);
    return @intFromEnum(ToolingResult.ok);
}

/// Step over
pub fn zylix_dap_step_over(adapter_id: u64, thread_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.stepOver(aid, thread_id);
    return @intFromEnum(ToolingResult.ok);
}

/// Step out
pub fn zylix_dap_step_out(adapter_id: u64, thread_id: u64) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    var dm = dap_manager orelse return @intFromEnum(ToolingResult.err_not_initialized);

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    dm.stepOut(aid, thread_id);
    return @intFromEnum(ToolingResult.ok);
}

/// Get threads
pub fn zylix_dap_get_threads(adapter_id: u64, count: *u32) callconv(.c) ?*const CDapThread {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var dm = dap_manager orelse {
        count.* = 0;
        return null;
    };

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const threads = dm.getThreads(aid) catch {
        count.* = 0;
        return null;
    };

    if (threads.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(threads.len, c_dap_threads_cache.len);

    for (threads[0..max_count], 0..) |t, i| {
        @memset(&c_dap_threads_cache[i].name, 0);
        c_dap_threads_cache[i].id = t.id;

        const name_len = @min(t.name.len, c_dap_threads_cache[i].name.len - 1);
        @memcpy(c_dap_threads_cache[i].name[0..name_len], t.name[0..name_len]);
    }

    count.* = @intCast(max_count);
    return &c_dap_threads_cache[0];
}

/// Get stack trace
pub fn zylix_dap_get_stack_trace(adapter_id: u64, thread_id: u64, count: *u32) callconv(.c) ?*const CDapStackFrame {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var dm = dap_manager orelse {
        count.* = 0;
        return null;
    };

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const frames = dm.getStackTrace(aid, thread_id) catch {
        count.* = 0;
        return null;
    };

    if (frames.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(frames.len, c_dap_frames_cache.len);

    for (frames[0..max_count], 0..) |f, i| {
        @memset(&c_dap_frames_cache[i].name, 0);
        @memset(&c_dap_frames_cache[i].source_path, 0);

        c_dap_frames_cache[i].id = f.id;
        c_dap_frames_cache[i].line = f.line;
        c_dap_frames_cache[i].column = f.column;
        c_dap_frames_cache[i].end_line = f.end_line orelse 0;
        c_dap_frames_cache[i].end_column = f.end_column orelse 0;

        const name_len = @min(f.name.len, c_dap_frames_cache[i].name.len - 1);
        @memcpy(c_dap_frames_cache[i].name[0..name_len], f.name[0..name_len]);

        if (f.source_path) |sp| {
            const sp_len = @min(sp.len, c_dap_frames_cache[i].source_path.len - 1);
            @memcpy(c_dap_frames_cache[i].source_path[0..sp_len], sp[0..sp_len]);
        }
    }

    count.* = @intCast(max_count);
    return &c_dap_frames_cache[0];
}

/// Get variables
pub fn zylix_dap_get_variables(adapter_id: u64, variables_reference: u64, count: *u32) callconv(.c) ?*const CDapVariable {
    if (!initialized) {
        count.* = 0;
        return null;
    }

    var dm = dap_manager orelse {
        count.* = 0;
        return null;
    };

    const aid = dap.AdapterId{
        .id = adapter_id,
        .port = 0,
        .started_at = 0,
    };

    const vars = dm.getVariables(aid, variables_reference) catch {
        count.* = 0;
        return null;
    };

    if (vars.len == 0) {
        count.* = 0;
        return null;
    }

    const max_count = @min(vars.len, c_dap_variables_cache.len);

    for (vars[0..max_count], 0..) |v, i| {
        @memset(&c_dap_variables_cache[i].name, 0);
        @memset(&c_dap_variables_cache[i].value, 0);
        @memset(&c_dap_variables_cache[i].variable_type, 0);

        c_dap_variables_cache[i].variables_reference = v.variables_reference;

        const name_len = @min(v.name.len, c_dap_variables_cache[i].name.len - 1);
        @memcpy(c_dap_variables_cache[i].name[0..name_len], v.name[0..name_len]);

        const val_len = @min(v.value.len, c_dap_variables_cache[i].value.len - 1);
        @memcpy(c_dap_variables_cache[i].value[0..val_len], v.value[0..val_len]);

        if (v.variable_type) |vt| {
            const vt_len = @min(vt.len, c_dap_variables_cache[i].variable_type.len - 1);
            @memcpy(c_dap_variables_cache[i].variable_type[0..vt_len], vt[0..vt_len]);
        }
    }

    count.* = @intCast(max_count);
    return &c_dap_variables_cache[0];
}

/// Set DAP event callback
pub fn zylix_dap_set_callback(adapter_id: u64, callback: CDapEventCallback) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(ToolingResult.err_not_initialized);

    _ = adapter_id; // Would register per-adapter in real implementation
    c_dap_callback = callback;
    return @intFromEnum(ToolingResult.ok);
}

/// Get active DAP adapter count
pub fn zylix_dap_active_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const dm = dap_manager orelse return 0;
    return @intCast(dm.activeCount());
}

/// Get total DAP adapter count
pub fn zylix_dap_total_count() callconv(.c) u32 {
    if (!initialized) return 0;
    const dm = dap_manager orelse return 0;
    return @intCast(dm.totalCount());
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

    // Component Tree Export (#56)
    @export(&zylix_ui_export_tree, .{ .name = "zylix_ui_export_tree" });
    @export(&zylix_ui_get_component, .{ .name = "zylix_ui_get_component" });
    @export(&zylix_ui_component_count, .{ .name = "zylix_ui_component_count" });
    @export(&zylix_ui_find_by_type, .{ .name = "zylix_ui_find_by_type" });

    // Live Preview Bridge (#57)
    @export(&zylix_preview_open, .{ .name = "zylix_preview_open" });
    @export(&zylix_preview_close, .{ .name = "zylix_preview_close" });
    @export(&zylix_preview_refresh, .{ .name = "zylix_preview_refresh" });
    @export(&zylix_preview_set_debug_overlay, .{ .name = "zylix_preview_set_debug_overlay" });
    @export(&zylix_preview_get_session, .{ .name = "zylix_preview_get_session" });
    @export(&zylix_preview_set_callback, .{ .name = "zylix_preview_set_callback" });
    @export(&zylix_preview_active_count, .{ .name = "zylix_preview_active_count" });

    // Hot Reload (#61)
    @export(&zylix_hot_reload_start, .{ .name = "zylix_hot_reload_start" });
    @export(&zylix_hot_reload_stop, .{ .name = "zylix_hot_reload_stop" });
    @export(&zylix_hot_reload_trigger, .{ .name = "zylix_hot_reload_trigger" });
    @export(&zylix_hot_reload_pause, .{ .name = "zylix_hot_reload_pause" });
    @export(&zylix_hot_reload_resume, .{ .name = "zylix_hot_reload_resume" });
    @export(&zylix_hot_reload_get_session, .{ .name = "zylix_hot_reload_get_session" });
    @export(&zylix_hot_reload_get_stats, .{ .name = "zylix_hot_reload_get_stats" });
    @export(&zylix_hot_reload_set_callback, .{ .name = "zylix_hot_reload_set_callback" });
    @export(&zylix_hot_reload_active_count, .{ .name = "zylix_hot_reload_active_count" });
    @export(&zylix_hot_reload_total_count, .{ .name = "zylix_hot_reload_total_count" });

    // LSP Integration (#62)
    @export(&zylix_lsp_start, .{ .name = "zylix_lsp_start" });
    @export(&zylix_lsp_stop, .{ .name = "zylix_lsp_stop" });
    @export(&zylix_lsp_get_session, .{ .name = "zylix_lsp_get_session" });
    @export(&zylix_lsp_get_capabilities, .{ .name = "zylix_lsp_get_capabilities" });
    @export(&zylix_lsp_get_completion, .{ .name = "zylix_lsp_get_completion" });
    @export(&zylix_lsp_get_hover, .{ .name = "zylix_lsp_get_hover" });
    @export(&zylix_lsp_get_definition, .{ .name = "zylix_lsp_get_definition" });
    @export(&zylix_lsp_get_references, .{ .name = "zylix_lsp_get_references" });
    @export(&zylix_lsp_get_document_symbols, .{ .name = "zylix_lsp_get_document_symbols" });
    @export(&zylix_lsp_set_callback, .{ .name = "zylix_lsp_set_callback" });
    @export(&zylix_lsp_active_count, .{ .name = "zylix_lsp_active_count" });
    @export(&zylix_lsp_total_count, .{ .name = "zylix_lsp_total_count" });

    // DAP Integration (#63)
    @export(&zylix_dap_start, .{ .name = "zylix_dap_start" });
    @export(&zylix_dap_stop, .{ .name = "zylix_dap_stop" });
    @export(&zylix_dap_launch, .{ .name = "zylix_dap_launch" });
    @export(&zylix_dap_attach, .{ .name = "zylix_dap_attach" });
    @export(&zylix_dap_get_session, .{ .name = "zylix_dap_get_session" });
    @export(&zylix_dap_get_capabilities, .{ .name = "zylix_dap_get_capabilities" });
    @export(&zylix_dap_set_breakpoint, .{ .name = "zylix_dap_set_breakpoint" });
    @export(&zylix_dap_remove_breakpoint, .{ .name = "zylix_dap_remove_breakpoint" });
    @export(&zylix_dap_continue, .{ .name = "zylix_dap_continue" });
    @export(&zylix_dap_pause, .{ .name = "zylix_dap_pause" });
    @export(&zylix_dap_step_into, .{ .name = "zylix_dap_step_into" });
    @export(&zylix_dap_step_over, .{ .name = "zylix_dap_step_over" });
    @export(&zylix_dap_step_out, .{ .name = "zylix_dap_step_out" });
    @export(&zylix_dap_get_threads, .{ .name = "zylix_dap_get_threads" });
    @export(&zylix_dap_get_stack_trace, .{ .name = "zylix_dap_get_stack_trace" });
    @export(&zylix_dap_get_variables, .{ .name = "zylix_dap_get_variables" });
    @export(&zylix_dap_set_callback, .{ .name = "zylix_dap_set_callback" });
    @export(&zylix_dap_active_count, .{ .name = "zylix_dap_active_count" });
    @export(&zylix_dap_total_count, .{ .name = "zylix_dap_total_count" });
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

// Component Tree Export API (#56) Tests
test "ui component count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no components are registered
    try std.testing.expectEqual(@as(u32, 0), zylix_ui_component_count(1));
}

test "ui export tree" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should succeed even with no components (exports empty tree)
    try std.testing.expectEqual(@as(i32, 0), zylix_ui_export_tree(1, 0)); // JSON format
}

test "ui get component returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_ui_get_component(999) == null);
}

test "ui find by type returns null when none found" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_ui_find_by_type(1, 0, &count); // Button type
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

// Live Preview Bridge API (#57) Tests
test "preview active count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no previews are active
    try std.testing.expectEqual(@as(u32, 0), zylix_preview_active_count());
}

test "preview get session returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_preview_get_session(999) == null);
}

test "preview set callback" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should succeed
    try std.testing.expectEqual(@as(i32, 0), zylix_preview_set_callback(1, null));
}

test "preview close invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_preview_close(999));
}

test "preview refresh invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_preview_refresh(999));
}

test "preview set debug overlay" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_preview_set_debug_overlay(999, true));
}

// Hot Reload API (#61) Tests
test "hot reload active count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no sessions are active
    try std.testing.expectEqual(@as(u32, 0), zylix_hot_reload_active_count());
}

test "hot reload total count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no sessions exist
    try std.testing.expectEqual(@as(u32, 0), zylix_hot_reload_total_count());
}

test "hot reload get session returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_hot_reload_get_session(999) == null);
}

test "hot reload get stats returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_hot_reload_get_stats(999) == null);
}

test "hot reload set callback" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should succeed
    try std.testing.expectEqual(@as(i32, 0), zylix_hot_reload_set_callback(1, null));
}

test "hot reload stop invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_hot_reload_stop(999));
}

test "hot reload pause invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_hot_reload_pause(999));
}

test "hot reload resume invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_hot_reload_resume(999));
}

test "hot reload trigger returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_hot_reload_trigger(999) == null);
}

// LSP Integration API (#62) Tests
test "lsp active count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no servers are active
    try std.testing.expectEqual(@as(u32, 0), zylix_lsp_active_count());
}

test "lsp total count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no servers exist
    try std.testing.expectEqual(@as(u32, 0), zylix_lsp_total_count());
}

test "lsp get session returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_lsp_get_session(999) == null);
}

test "lsp get capabilities returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_lsp_get_capabilities(999) == null);
}

test "lsp set callback" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should succeed
    try std.testing.expectEqual(@as(i32, 0), zylix_lsp_set_callback(1, null));
}

test "lsp stop invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_lsp_stop(999));
}

test "lsp get hover returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_lsp_get_hover(999, "file:///test.zy", 0, 0) == null);
}

test "lsp get definition returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_lsp_get_definition(999, "file:///test.zy", 0, 0) == null);
}

test "lsp get completion returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_lsp_get_completion(999, "file:///test.zy", 0, 0, &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "lsp get references returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_lsp_get_references(999, "file:///test.zy", 0, 0, &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "lsp get document symbols returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_lsp_get_document_symbols(999, "file:///test.zy", &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

// DAP Integration API (#63) Tests
test "dap active count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no adapters are active
    try std.testing.expectEqual(@as(u32, 0), zylix_dap_active_count());
}

test "dap total count" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return 0 when no adapters exist
    try std.testing.expectEqual(@as(u32, 0), zylix_dap_total_count());
}

test "dap get session returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_dap_get_session(999) == null);
}

test "dap get capabilities returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_dap_get_capabilities(999) == null);
}

test "dap set callback" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should succeed
    try std.testing.expectEqual(@as(i32, 0), zylix_dap_set_callback(1, null));
}

test "dap stop invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should still return OK (idempotent)
    try std.testing.expectEqual(@as(i32, 0), zylix_dap_stop(999));
}

test "dap continue invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_continue(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap pause invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_pause(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap step into invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_step_into(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap step over invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_step_over(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap step out invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_step_out(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap get threads returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_dap_get_threads(999, &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "dap get stack trace returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_dap_get_stack_trace(999, 1, &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "dap get variables returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    var count: u32 = 0;
    const result = zylix_dap_get_variables(999, 1, &count);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "dap set breakpoint returns null for invalid id" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    try std.testing.expect(zylix_dap_set_breakpoint(999, "test.zy", 10, null) == null);
}

test "dap remove breakpoint invalid adapter" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_remove_breakpoint(999, 1);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap launch invalid adapter" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_launch(999, "/path/to/app", null, null);
    try std.testing.expect(result != @as(i32, 0));
}

test "dap attach invalid adapter" {
    _ = zylix_tooling_init();
    defer _ = zylix_tooling_deinit();

    // Should return error for invalid adapter
    const result = zylix_dap_attach(999, 12345);
    try std.testing.expect(result != @as(i32, 0));
}
