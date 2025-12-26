//! Developer Tooling Module
//!
//! Comprehensive developer tooling for Zylix applications:
//! - Project Scaffolding: Create project layouts for all 7 platforms
//! - Build Orchestration: Multi-target build execution
//! - Artifact Management: Query and export build artifacts
//! - Target Capabilities: Platform feature matrix
//! - Template Catalog: Project template management
//! - File Watcher: Real-time file system monitoring
//! - Component Tree: UI component inspection
//! - Live Preview: Hot reload and preview sessions
//!
//! CLI Commands:
//! - zylix new: Create new project from template
//! - zylix build: Build project for target platforms
//! - zylix dev: Start development server with hot reload
//! - zylix preview: Launch preview session
//! - zylix templates: Manage project templates

const std = @import("std");

// Re-export submodules
pub const project = @import("project.zig");
pub const project_io = @import("project_io.zig");
pub const build = @import("build.zig");
pub const build_executor = @import("build_executor.zig");
pub const artifacts = @import("artifacts.zig");
pub const targets = @import("targets.zig");
pub const templates = @import("templates.zig");
pub const watcher = @import("watcher.zig");
pub const ui = @import("ui.zig");
pub const preview = @import("preview.zig");
pub const lsp = @import("lsp.zig");
pub const dap = @import("dap.zig");
pub const hot_reload = @import("hot_reload.zig");

// P0 Tooling APIs (v0.20.0)
pub const registry = @import("registry.zig");
pub const serialization = @import("serialization.zig");
pub const instantiation = @import("instantiation.zig");

// C ABI exports for platform shell integration
pub const abi = @import("tooling_abi.zig");

// Re-export common types from Project
pub const Project = project.Project;
pub const ProjectId = project.ProjectId;
pub const ProjectConfig = project.ProjectConfig;
pub const ProjectInfo = project.ProjectInfo;
pub const ProjectType = project.ProjectType;
pub const Target = project.Target;
pub const ValidationResult = project.ValidationResult;
pub const ProjectError = project.ProjectError;

// Re-export common types from Build
pub const Build = build.Build;
pub const BuildId = build.BuildId;
pub const BuildConfig = build.BuildConfig;
pub const BuildMode = build.BuildMode;
pub const BuildState = build.BuildState;
pub const BuildStatus = build.BuildStatus;
pub const BuildProgress = build.BuildProgress;
pub const LogEntry = build.LogEntry;
pub const BuildError = build.BuildError;

// Re-export common types from Artifacts
pub const Artifacts = artifacts.Artifacts;
pub const Artifact = artifacts.Artifact;
pub const ArtifactType = artifacts.ArtifactType;
pub const ArtifactMetadata = artifacts.ArtifactMetadata;
pub const ArtifactError = artifacts.ArtifactError;

// Re-export common types from Targets
pub const Targets = targets.Targets;
pub const Feature = targets.Feature;
pub const SupportLevel = targets.SupportLevel;
pub const CapabilityMatrix = targets.CapabilityMatrix;
pub const InputSpec = targets.InputSpec;

// Re-export common types from Templates
pub const Templates = templates.Templates;
pub const Template = templates.Template;
pub const TemplateDetails = templates.TemplateDetails;
pub const TemplateCategory = templates.TemplateCategory;
pub const CustomTemplate = templates.CustomTemplate;
pub const TemplateError = templates.TemplateError;

// Re-export common types from Watcher
pub const FileWatcher = watcher.FileWatcher;
pub const WatchId = watcher.WatchId;
pub const WatchFilters = watcher.WatchFilters;
pub const FileChange = watcher.FileChange;
pub const ChangeType = watcher.ChangeType;
pub const WatcherError = watcher.WatcherError;

// Re-export common types from UI
pub const UI = ui.UI;
pub const ComponentId = ui.ComponentId;
pub const ComponentType = ui.ComponentType;
pub const ComponentInfo = ui.ComponentInfo;
pub const ComponentTree = ui.ComponentTree;
pub const UIError = ui.UIError;

// Re-export common types from Preview
pub const Preview = preview.Preview;
pub const PreviewId = preview.PreviewId;
pub const PreviewSession = preview.PreviewSession;
pub const PreviewState = preview.PreviewState;
pub const PreviewConfig = preview.PreviewConfig;
pub const DebugOverlay = preview.DebugOverlay;
pub const DeviceInfo = preview.DeviceInfo;
pub const PreviewError = preview.PreviewError;

// Re-export common types from LSP (Issue #79)
pub const Lsp = lsp.Lsp;
pub const LspConfig = lsp.LspConfig;
pub const LspSession = lsp.LspSession;
pub const LspServerId = lsp.ServerId;
pub const LspServerState = lsp.ServerState;
pub const LspServerCapabilities = lsp.ServerCapabilities;
pub const LspPosition = lsp.Position;
pub const LspRange = lsp.Range;
pub const LspLocation = lsp.Location;
pub const LspCompletionItem = lsp.CompletionItem;
pub const LspDiagnostic = lsp.Diagnostic;
pub const LspDocumentSymbol = lsp.DocumentSymbol;
pub const LspError = lsp.LspError;

// Re-export common types from DAP (Issue #79)
pub const Dap = dap.Dap;
pub const DapConfig = dap.DapConfig;
pub const DapSession = dap.DapSession;
pub const DapAdapterId = dap.AdapterId;
pub const DapAdapterState = dap.AdapterState;
pub const DapBreakpoint = dap.Breakpoint;
pub const DapThread = dap.Thread;
pub const DapStackFrame = dap.StackFrame;
pub const DapVariable = dap.Variable;
pub const DapScope = dap.Scope;
pub const DapError = dap.DapError;

// Re-export common types from HotReload (Issue #79)
pub const HotReload = hot_reload.HotReload;
pub const HotReloadConfig = hot_reload.HotReloadConfig;
pub const HotReloadSession = hot_reload.HotReloadSession;
pub const HotReloadError = hot_reload.HotReloadError;

// Re-export common types from Registry (Issue #58)
pub const ComponentRegistry = registry.Registry;
pub const ComponentMeta = registry.ComponentMeta;
pub const PropertyMeta = registry.PropertyMeta;
pub const PropertyType = registry.PropertyType;
pub const ComponentCategory = registry.ComponentCategory;

// Re-export common types from Serialization (Issue #59)
pub const SerializeOptions = serialization.SerializeOptions;
pub const JsonWriter = serialization.JsonWriter;
pub const serializeTree = serialization.serializeTree;
pub const serializeVTree = serialization.serializeVTree;

// Re-export common types from Instantiation (Issue #60)
pub const ComponentSpec = instantiation.ComponentSpec;
pub const VNodeSpec = instantiation.VNodeSpec;
pub const ComponentTemplate = instantiation.ComponentTemplate;
pub const createComponent = instantiation.createComponent;
pub const createVNode = instantiation.createVNode;
pub const instantiateInTree = instantiation.instantiateInTree;
pub const instantiateTemplate = instantiation.instantiateTemplate;

// Quick builders (Issue #60)
pub const button = instantiation.button;
pub const textElement = instantiation.textElement;
pub const input = instantiation.input;
pub const container = instantiation.container;
pub const vstack = instantiation.vstack;
pub const hstack = instantiation.hstack;
pub const image = instantiation.image;

/// Tooling Manager
/// Provides unified access to all developer tooling services.
pub const ToolingManager = struct {
    allocator: std.mem.Allocator,
    project_manager: ?*Project = null,
    build_orchestrator: ?*Build = null,
    artifact_manager: ?*Artifacts = null,
    target_manager: ?*Targets = null,
    template_manager: ?*Templates = null,
    file_watcher: ?*FileWatcher = null,
    ui_manager: ?*UI = null,
    preview_manager: ?*Preview = null,
    lsp_manager: ?*Lsp = null,
    dap_manager: ?*Dap = null,
    hot_reload_manager: ?*HotReload = null,

    pub fn init(allocator: std.mem.Allocator) ToolingManager {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ToolingManager) void {
        if (self.project_manager) |p| {
            p.deinit();
            self.allocator.destroy(p);
        }
        if (self.build_orchestrator) |b| {
            b.deinit();
            self.allocator.destroy(b);
        }
        if (self.artifact_manager) |a| {
            a.deinit();
            self.allocator.destroy(a);
        }
        if (self.target_manager) |t| {
            t.deinit();
            self.allocator.destroy(t);
        }
        if (self.template_manager) |t| {
            t.deinit();
            self.allocator.destroy(t);
        }
        if (self.file_watcher) |w| {
            w.deinit();
            self.allocator.destroy(w);
        }
        if (self.ui_manager) |u| {
            u.deinit();
            self.allocator.destroy(u);
        }
        if (self.preview_manager) |p| {
            p.deinit();
            self.allocator.destroy(p);
        }
        if (self.lsp_manager) |l| {
            l.deinit();
            self.allocator.destroy(l);
        }
        if (self.dap_manager) |d| {
            d.deinit();
            self.allocator.destroy(d);
        }
        if (self.hot_reload_manager) |h| {
            h.deinit();
            self.allocator.destroy(h);
        }
    }

    /// Get or create project manager
    pub fn getProjectManager(self: *ToolingManager) !*Project {
        if (self.project_manager) |p| return p;

        const p = try self.allocator.create(Project);
        p.* = project.createProjectManager(self.allocator);
        self.project_manager = p;
        return p;
    }

    /// Get or create build orchestrator
    pub fn getBuildOrchestrator(self: *ToolingManager) !*Build {
        if (self.build_orchestrator) |b| return b;

        const b = try self.allocator.create(Build);
        b.* = build.createBuildOrchestrator(self.allocator);
        self.build_orchestrator = b;
        return b;
    }

    /// Get or create artifact manager
    pub fn getArtifactManager(self: *ToolingManager) !*Artifacts {
        if (self.artifact_manager) |a| return a;

        const a = try self.allocator.create(Artifacts);
        a.* = artifacts.createArtifactManager(self.allocator);
        self.artifact_manager = a;
        return a;
    }

    /// Get or create target manager
    pub fn getTargetManager(self: *ToolingManager) !*Targets {
        if (self.target_manager) |t| return t;

        const t = try self.allocator.create(Targets);
        t.* = targets.createTargetManager(self.allocator);
        self.target_manager = t;
        return t;
    }

    /// Get or create template manager
    pub fn getTemplateManager(self: *ToolingManager) !*Templates {
        if (self.template_manager) |t| return t;

        const t = try self.allocator.create(Templates);
        t.* = templates.createTemplateManager(self.allocator);
        self.template_manager = t;
        return t;
    }

    /// Get or create file watcher
    pub fn getFileWatcher(self: *ToolingManager) !*FileWatcher {
        if (self.file_watcher) |w| return w;

        const w = try self.allocator.create(FileWatcher);
        w.* = watcher.createFileWatcher(self.allocator);
        self.file_watcher = w;
        return w;
    }

    /// Get or create UI manager
    pub fn getUIManager(self: *ToolingManager) !*UI {
        if (self.ui_manager) |u| return u;

        const u = try self.allocator.create(UI);
        u.* = ui.createUIManager(self.allocator);
        self.ui_manager = u;
        return u;
    }

    /// Get or create preview manager
    pub fn getPreviewManager(self: *ToolingManager) !*Preview {
        if (self.preview_manager) |p| return p;

        const p = try self.allocator.create(Preview);
        p.* = preview.createPreviewManager(self.allocator);
        self.preview_manager = p;
        return p;
    }

    /// Get or create LSP manager (Issue #79)
    pub fn getLspManager(self: *ToolingManager) !*Lsp {
        if (self.lsp_manager) |l| return l;

        const l = try self.allocator.create(Lsp);
        l.* = lsp.createLspManager(self.allocator);
        self.lsp_manager = l;
        return l;
    }

    /// Get or create DAP manager (Issue #79)
    pub fn getDapManager(self: *ToolingManager) !*Dap {
        if (self.dap_manager) |d| return d;

        const d = try self.allocator.create(Dap);
        d.* = dap.createDapManager(self.allocator);
        self.dap_manager = d;
        return d;
    }

    /// Get or create HotReload manager (Issue #79)
    pub fn getHotReloadManager(self: *ToolingManager) !*HotReload {
        if (self.hot_reload_manager) |h| return h;

        const h = try self.allocator.create(HotReload);
        h.* = hot_reload.createHotReloadManager(self.allocator);
        self.hot_reload_manager = h;
        return h;
    }
};

/// Create a tooling manager
pub fn createToolingManager(allocator: std.mem.Allocator) ToolingManager {
    return ToolingManager.init(allocator);
}

// Convenience functions

/// Create a project manager
pub fn createProjectManager(allocator: std.mem.Allocator) Project {
    return project.createProjectManager(allocator);
}

/// Create a build orchestrator
pub fn createBuildOrchestrator(allocator: std.mem.Allocator) Build {
    return build.createBuildOrchestrator(allocator);
}

/// Create an artifact manager
pub fn createArtifactManager(allocator: std.mem.Allocator) Artifacts {
    return artifacts.createArtifactManager(allocator);
}

/// Create a target manager
pub fn createTargetManager(allocator: std.mem.Allocator) Targets {
    return targets.createTargetManager(allocator);
}

/// Create a template manager
pub fn createTemplateManager(allocator: std.mem.Allocator) Templates {
    return templates.createTemplateManager(allocator);
}

/// Create a file watcher
pub fn createFileWatcher(allocator: std.mem.Allocator) FileWatcher {
    return watcher.createFileWatcher(allocator);
}

/// Create a UI manager
pub fn createUIManager(allocator: std.mem.Allocator) UI {
    return ui.createUIManager(allocator);
}

/// Create a preview manager
pub fn createPreviewManager(allocator: std.mem.Allocator) Preview {
    return preview.createPreviewManager(allocator);
}

/// Create an LSP manager (Issue #79)
pub fn createLspManager(allocator: std.mem.Allocator) Lsp {
    return lsp.createLspManager(allocator);
}

/// Create a DAP manager (Issue #79)
pub fn createDapManager(allocator: std.mem.Allocator) Dap {
    return dap.createDapManager(allocator);
}

/// Create a HotReload manager (Issue #79)
pub fn createHotReloadManager(allocator: std.mem.Allocator) HotReload {
    return hot_reload.createHotReloadManager(allocator);
}

// Tests
test "Tooling module imports" {
    // Verify all submodules can be imported
    _ = project;
    _ = build;
    _ = artifacts;
    _ = targets;
    _ = templates;
    _ = watcher;
    _ = ui;
    _ = preview;
    // P0 Tooling APIs (v0.20.0)
    _ = registry;
    _ = serialization;
    _ = instantiation;
    // Issue #79: LSP/DAP/HotReload
    _ = lsp;
    _ = dap;
    _ = hot_reload;
}

test "ToolingManager creation" {
    const allocator = std.testing.allocator;
    var manager = createToolingManager(allocator);
    defer manager.deinit();

    // Get each manager (lazy initialization)
    const proj = try manager.getProjectManager();
    try std.testing.expectEqual(@as(usize, 0), proj.count());

    const bld = try manager.getBuildOrchestrator();
    try std.testing.expectEqual(@as(usize, 0), bld.totalCount());

    const art = try manager.getArtifactManager();
    try std.testing.expectEqual(@as(usize, 0), art.count());

    const tgt = try manager.getTargetManager();
    try std.testing.expect(tgt.supportsFeature(.ios, .metal));

    const tmpl = try manager.getTemplateManager();
    try std.testing.expect(tmpl.exists("app"));

    const watch = try manager.getFileWatcher();
    try std.testing.expectEqual(@as(usize, 0), watch.totalCount());

    const uim = try manager.getUIManager();
    try std.testing.expectEqual(@as(usize, 0), uim.count());

    const prev = try manager.getPreviewManager();
    try std.testing.expectEqual(@as(usize, 0), prev.totalCount());

    // Issue #79: LSP/DAP/HotReload managers
    const lsp_mgr = try manager.getLspManager();
    try std.testing.expectEqual(@as(usize, 0), lsp_mgr.totalCount());

    const dap_mgr = try manager.getDapManager();
    try std.testing.expectEqual(@as(usize, 0), dap_mgr.totalCount());

    const hr_mgr = try manager.getHotReloadManager();
    try std.testing.expectEqual(@as(usize, 0), hr_mgr.totalCount());
}

test "ToolingManager caching" {
    const allocator = std.testing.allocator;
    var manager = createToolingManager(allocator);
    defer manager.deinit();

    const proj1 = try manager.getProjectManager();
    const proj2 = try manager.getProjectManager();
    try std.testing.expectEqual(proj1, proj2);
}

test "Convenience constructors" {
    const allocator = std.testing.allocator;

    var proj = createProjectManager(allocator);
    defer proj.deinit();

    var bld = createBuildOrchestrator(allocator);
    defer bld.deinit();

    var art = createArtifactManager(allocator);
    defer art.deinit();

    var tgt = createTargetManager(allocator);
    defer tgt.deinit();

    var tmpl = createTemplateManager(allocator);
    defer tmpl.deinit();

    var watch = createFileWatcher(allocator);
    defer watch.deinit();

    var uim = createUIManager(allocator);
    defer uim.deinit();

    var prev = createPreviewManager(allocator);
    defer prev.deinit();

    // Issue #79: LSP/DAP/HotReload
    var lsp_mgr = createLspManager(allocator);
    defer lsp_mgr.deinit();

    var dap_mgr = createDapManager(allocator);
    defer dap_mgr.deinit();

    var hr_mgr = createHotReloadManager(allocator);
    defer hr_mgr.deinit();
}

test "Type re-exports" {
    // Verify types are accessible
    const _target: Target = .ios;
    const _build_mode: BuildMode = .release;
    const _artifact_type: ArtifactType = .executable;
    const _feature: Feature = .metal;
    const _category: TemplateCategory = .app;
    const _change_type: ChangeType = .modified;
    const _component_type: ComponentType = .button;
    const _preview_state: PreviewState = .ready;
    // Issue #79: LSP/DAP types
    const _lsp_state: LspServerState = .ready;
    const _dap_state: DapAdapterState = .running;

    _ = _target;
    _ = _build_mode;
    _ = _artifact_type;
    _ = _feature;
    _ = _category;
    _ = _change_type;
    _ = _component_type;
    _ = _preview_state;
    _ = _lsp_state;
    _ = _dap_state;
}

test "End-to-end workflow" {
    const allocator = std.testing.allocator;
    var manager = createToolingManager(allocator);
    defer manager.deinit();

    // 1. Check available templates
    const tmpl = try manager.getTemplateManager();
    try std.testing.expect(tmpl.exists("app"));

    // 2. Create a project
    const proj = try manager.getProjectManager();
    const create_future = proj.create(
        "app",
        &.{ .ios, .android, .web },
        "/tmp/myapp",
        .{ .name = "myapp" },
    );
    defer allocator.destroy(create_future);
    const project_id = try create_future.get();
    try std.testing.expect(project_id.isValid());

    // 3. Check target capabilities
    const tgt = try manager.getTargetManager();
    try std.testing.expect(tgt.supportsFeature(.ios, .metal));
    try std.testing.expect(tgt.supportsFeature(.android, .vulkan));

    // 4. Register a build (using hermetic test method instead of actual execution)
    const bld = try manager.getBuildOrchestrator();
    const build_id = try bld.registerBuildForTest(project_id.name, .ios, .{ .mode = .release });
    try std.testing.expect(build_id.isValid());

    // 5. Start preview
    const prev = try manager.getPreviewManager();
    const preview_future = prev.open(project_id, .web, .{ .hot_reload = true });
    defer allocator.destroy(preview_future);
    const preview_id = try preview_future.get();
    try std.testing.expect(preview_id.isValid());
}
