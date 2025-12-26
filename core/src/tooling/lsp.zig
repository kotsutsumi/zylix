//! Language Server Protocol (LSP) Integration
//!
//! Provides IDE integration through the Language Server Protocol:
//! - Code completion
//! - Go to definition
//! - Find references
//! - Hover information
//! - Diagnostics
//! - Document symbols
//! - Workspace symbols
//!
//! This module enables IDE support for Zylix component files.

const std = @import("std");
const project = @import("project.zig");

/// LSP error types
pub const LspError = error{
    NotInitialized,
    InvalidProject,
    InvalidPosition,
    InvalidUri,
    ServerStartFailed,
    ConnectionLost,
    RequestFailed,
    OutOfMemory,
};

/// LSP server identifier
pub const ServerId = struct {
    id: u64,
    port: u16,
    started_at: i64,

    pub fn isValid(self: *const ServerId) bool {
        return self.id > 0;
    }
};

/// LSP server state
pub const ServerState = enum(u8) {
    stopped = 0,
    starting = 1,
    initializing = 2,
    ready = 3,
    shutdown = 4,
    error_state = 5,

    pub fn isRunning(self: ServerState) bool {
        return switch (self) {
            .initializing, .ready => true,
            else => false,
        };
    }

    pub fn toString(self: ServerState) []const u8 {
        return switch (self) {
            .stopped => "Stopped",
            .starting => "Starting",
            .initializing => "Initializing",
            .ready => "Ready",
            .shutdown => "Shutdown",
            .error_state => "Error",
        };
    }
};

/// LSP configuration
pub const LspConfig = struct {
    /// Server port (0 for auto-assign)
    port: u16 = 0,
    /// Enable completion
    completion: bool = true,
    /// Enable hover
    hover: bool = true,
    /// Enable definition
    definition: bool = true,
    /// Enable references
    references: bool = true,
    /// Enable document symbols
    document_symbols: bool = true,
    /// Enable workspace symbols
    workspace_symbols: bool = true,
    /// Enable diagnostics
    diagnostics: bool = true,
    /// Enable formatting
    formatting: bool = true,
    /// Enable rename
    rename: bool = true,
    /// Enable code actions
    code_actions: bool = true,
};

/// Document position
pub const Position = struct {
    line: u32,
    character: u32,
};

/// Document range
pub const Range = struct {
    start: Position,
    end: Position,
};

/// Location in a document
pub const Location = struct {
    uri: []const u8,
    range: Range,
};

/// Completion item kind
pub const CompletionItemKind = enum(u8) {
    text = 1,
    method = 2,
    function = 3,
    constructor = 4,
    field = 5,
    variable = 6,
    class = 7,
    interface = 8,
    module = 9,
    property = 10,
    unit = 11,
    value = 12,
    enumeration = 13,
    keyword = 14,
    snippet = 15,
    color = 16,
    file = 17,
    reference = 18,
    folder = 19,
    enum_member = 20,
    constant = 21,
    structure = 22,
    event = 23,
    operator = 24,
    type_parameter = 25,
};

/// Completion item
pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: ?[]const u8 = null,
    documentation: ?[]const u8 = null,
    insert_text: ?[]const u8 = null,
    sort_text: ?[]const u8 = null,
};

/// Diagnostic severity
pub const DiagnosticSeverity = enum(u8) {
    err = 1,
    warning = 2,
    information = 3,
    hint = 4,
};

/// Diagnostic
pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    code: ?[]const u8 = null,
    source: ?[]const u8 = null,
    message: []const u8,
};

/// Hover result
pub const HoverResult = struct {
    contents: []const u8,
    range: ?Range = null,
};

/// Symbol kind
pub const SymbolKind = enum(u8) {
    file = 1,
    module = 2,
    namespace = 3,
    package = 4,
    class = 5,
    method = 6,
    property = 7,
    field = 8,
    constructor = 9,
    enumeration = 10,
    interface = 11,
    function = 12,
    variable = 13,
    constant = 14,
    string = 15,
    number = 16,
    boolean = 17,
    array = 18,
    object = 19,
    key = 20,
    null_value = 21,
    enum_member = 22,
    structure = 23,
    event = 24,
    operator = 25,
    type_parameter = 26,
};

/// Document symbol
pub const DocumentSymbol = struct {
    name: []const u8,
    kind: SymbolKind,
    range: Range,
    selection_range: Range,
    detail: ?[]const u8 = null,
    children: []const DocumentSymbol = &.{},
};

/// LSP server session
pub const LspSession = struct {
    id: ServerId,
    state: ServerState,
    config: LspConfig,
    project_path: []const u8,
    open_documents: u32 = 0,
    request_count: u64 = 0,
    error_count: u32 = 0,
    last_request_at: ?i64 = null,
};

/// Server capabilities
pub const ServerCapabilities = struct {
    completion: bool = false,
    hover: bool = false,
    definition: bool = false,
    references: bool = false,
    document_symbols: bool = false,
    workspace_symbols: bool = false,
    diagnostics: bool = false,
    formatting: bool = false,
    rename: bool = false,
    code_actions: bool = false,
};

/// LSP event
pub const LspEvent = union(enum) {
    server_started: ServerId,
    server_stopped: ServerId,
    document_opened: []const u8,
    document_closed: []const u8,
    document_changed: []const u8,
    diagnostics_published: struct {
        uri: []const u8,
        count: u32,
    },
    error_occurred: []const u8,
};

/// Event callback type
pub const EventCallback = *const fn (LspEvent) void;

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?LspError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: LspError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) LspError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return LspError.NotInitialized;
        }
    };
}

/// Server entry
const ServerEntry = struct {
    session: LspSession,
    event_callback: ?EventCallback = null,
    capabilities: ServerCapabilities = .{},
};

/// LSP Server Manager
pub const Lsp = struct {
    allocator: std.mem.Allocator,
    servers: std.AutoHashMapUnmanaged(u64, ServerEntry) = .{},
    next_id: u64 = 1,
    next_port: u16 = 5000,

    pub fn init(allocator: std.mem.Allocator) Lsp {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lsp) void {
        self.servers.deinit(self.allocator);
    }

    /// Start LSP server
    pub fn start(
        self: *Lsp,
        project_id: project.ProjectId,
        config: LspConfig,
    ) *Future(ServerId) {
        const future = self.allocator.create(Future(ServerId)) catch {
            const err_future = self.allocator.create(Future(ServerId)) catch unreachable;
            err_future.* = Future(ServerId).init();
            err_future.fail(LspError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ServerId).init();

        if (!project_id.isValid()) {
            future.fail(LspError.InvalidProject);
            return future;
        }

        const port = if (config.port == 0) blk: {
            const p = self.next_port;
            self.next_port += 1;
            break :blk p;
        } else config.port;

        const server_id = ServerId{
            .id = self.next_id,
            .port = port,
            .started_at = std.time.timestamp(),
        };
        self.next_id += 1;

        const session = LspSession{
            .id = server_id,
            .state = .starting,
            .config = config,
            .project_path = project_id.path,
        };

        const capabilities = ServerCapabilities{
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

        self.servers.put(self.allocator, server_id.id, .{
            .session = session,
            .capabilities = capabilities,
        }) catch {
            future.fail(LspError.OutOfMemory);
            return future;
        };

        // Transition to ready state
        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.state = .ready;
        }

        future.complete(server_id);
        return future;
    }

    /// Stop LSP server
    pub fn stop(self: *Lsp, server_id: ServerId) void {
        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.state = .shutdown;
            if (entry.event_callback) |cb| {
                cb(.{ .server_stopped = server_id });
            }
        }
        _ = self.servers.remove(server_id.id);
    }

    /// Get session information
    pub fn getSession(self: *const Lsp, server_id: ServerId) ?LspSession {
        if (self.servers.get(server_id.id)) |entry| {
            return entry.session;
        }
        return null;
    }

    /// Get server capabilities
    pub fn getCapabilities(self: *const Lsp, server_id: ServerId) ?ServerCapabilities {
        if (self.servers.get(server_id.id)) |entry| {
            return entry.capabilities;
        }
        return null;
    }

    /// Get completion items (stub implementation)
    pub fn getCompletion(
        self: *Lsp,
        server_id: ServerId,
        uri: []const u8,
        position: Position,
    ) ![]CompletionItem {
        _ = uri;
        _ = position;

        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.request_count += 1;
            entry.session.last_request_at = std.time.timestamp();
        } else {
            return LspError.InvalidProject;
        }

        // Stub: return empty completion list
        return &.{};
    }

    /// Get hover information (stub implementation)
    pub fn getHover(
        self: *Lsp,
        server_id: ServerId,
        uri: []const u8,
        position: Position,
    ) !?HoverResult {
        _ = uri;
        _ = position;

        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.request_count += 1;
            entry.session.last_request_at = std.time.timestamp();
        } else {
            return LspError.InvalidProject;
        }

        // Stub: return no hover
        return null;
    }

    /// Get definition location (stub implementation)
    pub fn getDefinition(
        self: *Lsp,
        server_id: ServerId,
        uri: []const u8,
        position: Position,
    ) !?Location {
        _ = uri;
        _ = position;

        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.request_count += 1;
            entry.session.last_request_at = std.time.timestamp();
        } else {
            return LspError.InvalidProject;
        }

        // Stub: return no definition
        return null;
    }

    /// Get references (stub implementation)
    pub fn getReferences(
        self: *Lsp,
        server_id: ServerId,
        uri: []const u8,
        position: Position,
    ) ![]Location {
        _ = uri;
        _ = position;

        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.request_count += 1;
            entry.session.last_request_at = std.time.timestamp();
        } else {
            return LspError.InvalidProject;
        }

        // Stub: return empty references
        return &.{};
    }

    /// Get document symbols (stub implementation)
    pub fn getDocumentSymbols(
        self: *Lsp,
        server_id: ServerId,
        uri: []const u8,
    ) ![]DocumentSymbol {
        _ = uri;

        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.session.request_count += 1;
            entry.session.last_request_at = std.time.timestamp();
        } else {
            return LspError.InvalidProject;
        }

        // Stub: return empty symbols
        return &.{};
    }

    /// Register event callback
    pub fn onEvent(self: *Lsp, server_id: ServerId, callback: EventCallback) void {
        if (self.servers.getPtr(server_id.id)) |entry| {
            entry.event_callback = callback;
        }
    }

    /// Get active server count
    pub fn activeCount(self: *const Lsp) usize {
        var count: usize = 0;
        var iter = self.servers.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.session.state.isRunning()) {
                count += 1;
            }
        }
        return count;
    }

    /// Get total server count
    pub fn totalCount(self: *const Lsp) usize {
        return self.servers.count();
    }
};

/// Create an LSP server manager
pub fn createLspManager(allocator: std.mem.Allocator) Lsp {
    return Lsp.init(allocator);
}

// Tests
test "Lsp initialization" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    try std.testing.expectEqual(@as(usize, 0), lsp.totalCount());
}

test "ServerState methods" {
    try std.testing.expect(!ServerState.stopped.isRunning());
    try std.testing.expect(ServerState.ready.isRunning());
    try std.testing.expect(ServerState.initializing.isRunning());
    try std.testing.expect(!ServerState.shutdown.isRunning());

    try std.testing.expect(std.mem.eql(u8, "Ready", ServerState.ready.toString()));
}

test "Start LSP server" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = lsp.start(project_id, .{});
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());

    const server_id = try future.get();
    try std.testing.expect(server_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), lsp.totalCount());
}

test "Stop LSP server" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = lsp.start(project_id, .{});
    defer allocator.destroy(future);
    const server_id = try future.get();

    lsp.stop(server_id);
    try std.testing.expectEqual(@as(usize, 0), lsp.totalCount());
}

test "Get session" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = lsp.start(project_id, .{ .port = 8080 });
    defer allocator.destroy(future);
    const server_id = try future.get();

    const session = lsp.getSession(server_id);
    try std.testing.expect(session != null);
    try std.testing.expectEqual(ServerState.ready, session.?.state);
    try std.testing.expectEqual(@as(u16, 8080), session.?.id.port);
}

test "Get capabilities" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = lsp.start(project_id, .{ .completion = true, .hover = false });
    defer allocator.destroy(future);
    const server_id = try future.get();

    const caps = lsp.getCapabilities(server_id);
    try std.testing.expect(caps != null);
    try std.testing.expect(caps.?.completion);
    try std.testing.expect(!caps.?.hover);
}

test "Active count" {
    const allocator = std.testing.allocator;
    var lsp = createLspManager(allocator);
    defer lsp.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = lsp.start(project_id, .{});
    defer allocator.destroy(future);
    _ = try future.get();

    try std.testing.expectEqual(@as(usize, 1), lsp.activeCount());
}
