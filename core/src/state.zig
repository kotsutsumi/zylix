//! State Management Module
//!
//! Manages all application state in Zylix Core.
//! State is owned entirely by Zig and exposed read-only to platform shells.

const std = @import("std");
const events = @import("events.zig");

/// Global state instance
var global_state: State = .{};
var initialized: bool = false;

/// ABI-compatible state structure for C interop
pub const ABIState = extern struct {
    version: u64,
    screen: u32,
    loading: bool,
    error_message: ?[*:0]const u8,
    view_data: ?*const anyopaque,
    view_data_size: usize,
};

/// Main state container
pub const State = struct {
    /// State version (monotonically increasing)
    version: u64 = 0,

    /// Application-specific state
    app: AppState = .{},

    /// UI state hints
    ui: UIState = .{},

    /// Last error message
    last_error: ?[]const u8 = null,

    /// Convert to ABI-compatible structure
    pub fn toABI(self: *const State) ABIState {
        return .{
            .version = self.version,
            .screen = @intFromEnum(self.ui.screen),
            .loading = self.ui.loading,
            .error_message = if (self.last_error) |err| @ptrCast(err.ptr) else null,
            .view_data = self.app.getViewData(),
            .view_data_size = self.app.getViewDataSize(),
        };
    }

    /// Increment version after state change
    pub fn bumpVersion(self: *State) void {
        self.version +%= 1;
    }
};

/// Application-specific state (customize per app)
pub const AppState = struct {
    /// Counter value (PoC example)
    counter: i64 = 0,

    /// Form text (PoC example)
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,

    /// Get view data pointer for ABI
    pub fn getViewData(self: *const AppState) ?*const anyopaque {
        return @ptrCast(self);
    }

    /// Get view data size for ABI
    pub fn getViewDataSize(self: *const AppState) usize {
        _ = self;
        return @sizeOf(AppState);
    }
};

/// UI state hints
pub const UIState = struct {
    /// Current screen
    screen: Screen = .home,

    /// Loading indicator
    loading: bool = false,

    /// Screen enum
    pub const Screen = enum(u32) {
        home = 0,
        detail = 1,
        settings = 2,
    };
};

// === State Access Functions ===

/// Initialize state
pub fn init() void {
    global_state = .{};
    initialized = true;
}

/// Deinitialize state
pub fn deinit() void {
    global_state = .{};
    initialized = false;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get current state (read-only)
pub fn getState() *const State {
    return &global_state;
}

/// Get mutable state (internal use)
pub fn getStateMut() *State {
    return &global_state;
}

/// Get state version
pub fn getVersion() u64 {
    return global_state.version;
}

/// Set last error
pub fn setError(err: ?[]const u8) void {
    global_state.last_error = err;
}

// === State Reducers ===

/// Handle increment event
pub fn handleIncrement() void {
    global_state.app.counter += 1;
    global_state.bumpVersion();
}

/// Handle decrement event
pub fn handleDecrement() void {
    global_state.app.counter -= 1;
    global_state.bumpVersion();
}

/// Handle reset event
pub fn handleReset() void {
    global_state.app.counter = 0;
    global_state.bumpVersion();
}

/// Handle text input event
pub fn handleTextInput(text: []const u8) void {
    const copy_len = @min(text.len, global_state.app.input_text.len - 1);
    @memcpy(global_state.app.input_text[0..copy_len], text[0..copy_len]);
    global_state.app.input_text[copy_len] = 0;
    global_state.app.input_len = copy_len;
    global_state.bumpVersion();
}

/// Handle navigation event
pub fn handleNavigate(screen: UIState.Screen) void {
    global_state.ui.screen = screen;
    global_state.bumpVersion();
}

// === Tests ===

test "state initialization" {
    init();
    try std.testing.expect(isInitialized());
    try std.testing.expectEqual(@as(u64, 0), getVersion());

    deinit();
    try std.testing.expect(!isInitialized());
}

test "counter increment" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i64, 0), getState().app.counter);

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 1), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 1), getVersion());

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 2), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 2), getVersion());
}

test "counter decrement" {
    init();
    defer deinit();

    handleDecrement();
    try std.testing.expectEqual(@as(i64, -1), getState().app.counter);
}

test "counter reset" {
    init();
    defer deinit();

    handleIncrement();
    handleIncrement();
    handleReset();
    try std.testing.expectEqual(@as(i64, 0), getState().app.counter);
}
