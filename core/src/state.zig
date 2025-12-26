//! State Management Module
//!
//! Manages all application state in Zylix Core.
//! State is owned entirely by Zig and exposed read-only to platform shells.
//!
//! Phase 2: Now uses generic Store with diff tracking.

const std = @import("std");
const events = @import("events.zig");
const store_mod = @import("store.zig");
const diff_mod = @import("diff.zig");
const arena_mod = @import("arena.zig");

pub const Store = store_mod.Store;
pub const Diff = diff_mod.Diff;
pub const Arena = arena_mod.Arena;

/// Global store instance (Phase 2: using generic Store)
var global_store: Store(AppState) = Store(AppState).init(.{});
var initialized: bool = false;

/// Last calculated diff
var last_diff: Diff(AppState) = Diff(AppState).init();

/// Scratch arena for temporary allocations
var scratch_arena: Arena(4096) = Arena(4096).init();

/// Legacy global state (for backward compatibility)
var global_state: State = .{};

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
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = true;
}

/// Deinitialize state
pub fn deinit() void {
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = false;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get current state (read-only) - Legacy
pub fn getState() *const State {
    // Sync legacy state with store
    global_state.app = global_store.getState().*;
    global_state.version = global_store.getVersion();
    return &global_state;
}

/// Get mutable state (internal use) - Legacy
pub fn getStateMut() *State {
    return &global_state;
}

/// Get state version
pub fn getVersion() u64 {
    return global_store.getVersion();
}

/// Set last error
pub fn setError(err: ?[]const u8) void {
    global_state.last_error = err;
}

// === Phase 2: Store Access ===

/// Get the global store
pub fn getStore() *Store(AppState) {
    return &global_store;
}

/// Get app state directly from store
pub fn getAppState() *const AppState {
    return global_store.getState();
}

/// Get last calculated diff
pub fn getDiff() *const Diff(AppState) {
    return &last_diff;
}

/// Calculate and return diff since last commit
pub fn calculateDiff() *const Diff(AppState) {
    last_diff = Diff(AppState).calculate(
        global_store.getPrevState(),
        global_store.getState(),
        global_store.getVersion(),
    );
    return &last_diff;
}

/// Get scratch arena for temporary allocations
pub fn getScratchArena() *Arena(4096) {
    return &scratch_arena;
}

/// Reset scratch arena (call after each event dispatch cycle)
pub fn resetScratchArena() void {
    scratch_arena.reset();
}

// === State Reducers (Phase 2: using Store) ===

/// Handle increment event
pub fn handleIncrement() void {
    const increment = struct {
        fn f(app: *AppState) void {
            app.counter += 1;
        }
    }.f;
    global_store.update(&increment);
    _ = calculateDiff();
    global_store.commit();
}

/// Handle decrement event
pub fn handleDecrement() void {
    const decrement = struct {
        fn f(app: *AppState) void {
            app.counter -= 1;
        }
    }.f;
    global_store.update(&decrement);
    _ = calculateDiff();
    global_store.commit();
}

/// Handle reset event
pub fn handleReset() void {
    const reset_counter = struct {
        fn f(app: *AppState) void {
            app.counter = 0;
        }
    }.f;
    global_store.update(&reset_counter);
    _ = calculateDiff();
    global_store.commit();
}

/// Handle text input event
pub fn handleTextInput(text: []const u8) void {
    // For text input, we use direct mutation since we need the text slice
    const app = global_store.getStateMut();
    const copy_len = @min(text.len, app.input_text.len - 1);
    @memcpy(app.input_text[0..copy_len], text[0..copy_len]);
    app.input_text[copy_len] = 0;
    app.input_len = copy_len;
    global_store.dirty = true;
    _ = calculateDiff();
    global_store.commit();
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

test "text input handling" {
    init();
    defer deinit();

    handleTextInput("Hello");
    const state = getState();
    try std.testing.expectEqual(@as(usize, 5), state.app.input_len);
    try std.testing.expectEqualStrings("Hello", state.app.input_text[0..5]);
}

test "text input truncation" {
    init();
    defer deinit();

    // Test that long text is truncated
    var long_text: [300]u8 = undefined;
    @memset(&long_text, 'A');

    handleTextInput(&long_text);
    const state = getState();
    // Should be truncated to 255 (buffer size - 1)
    try std.testing.expectEqual(@as(usize, 255), state.app.input_len);
}

test "navigation handling" {
    init();
    defer deinit();

    try std.testing.expectEqual(UIState.Screen.home, getState().ui.screen);

    handleNavigate(.detail);
    try std.testing.expectEqual(UIState.Screen.detail, getState().ui.screen);

    handleNavigate(.settings);
    try std.testing.expectEqual(UIState.Screen.settings, getState().ui.screen);
}

test "diff calculation" {
    init();
    defer deinit();

    handleIncrement();
    const diff = getDiff(); // Get the already-calculated diff from handleIncrement

    try std.testing.expect(diff.hasChanges());
    try std.testing.expect(diff.hasFieldChangedByName("counter"));
}

test "scratch arena reset" {
    init();
    defer deinit();

    const arena = getScratchArena();
    _ = arena.alloc(u8, 100);

    resetScratchArena();
    // After reset, the arena should be empty again
    // We can verify by allocating again
    _ = arena.alloc(u8, 4000);
}

test "error handling" {
    init();
    defer deinit();

    try std.testing.expect(getState().last_error == null);

    setError("Test error message");
    try std.testing.expect(getState().last_error != null);
    try std.testing.expectEqualStrings("Test error message", getState().last_error.?);

    setError(null);
    try std.testing.expect(getState().last_error == null);
}

test "ABI state conversion" {
    init();
    defer deinit();

    handleIncrement();
    handleNavigate(.detail);

    const state = getState();
    const abi = state.toABI();

    try std.testing.expectEqual(@as(u32, 1), abi.screen);
    try std.testing.expect(!abi.loading);
    try std.testing.expect(abi.view_data != null);
    try std.testing.expectEqual(@sizeOf(AppState), abi.view_data_size);
}

test "store access" {
    init();
    defer deinit();

    const store = getStore();
    // Verify store is accessible (not null)
    try std.testing.expect(@intFromPtr(store) != 0);

    const app_state = getAppState();
    try std.testing.expectEqual(@as(i64, 0), app_state.counter);
}

test "version bumping" {
    var state = State{};

    try std.testing.expectEqual(@as(u64, 0), state.version);

    state.bumpVersion();
    try std.testing.expectEqual(@as(u64, 1), state.version);

    state.bumpVersion();
    try std.testing.expectEqual(@as(u64, 2), state.version);
}
