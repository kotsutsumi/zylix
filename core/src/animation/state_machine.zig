//! Animation State Machine - State-based animation controller
//!
//! Provides a finite state machine for managing complex animation
//! transitions, commonly used in games and interactive applications.
//!
//! ## Features
//!
//! - Named states with entry/exit callbacks
//! - Conditional transitions
//! - Transition blending
//! - Parameter-driven transitions
//! - Sub-state machines
//!
//! ## Usage
//!
//! ```zig
//! const sm = @import("state_machine.zig");
//!
//! var machine = sm.StateMachine.init(allocator);
//! machine.addState("idle", idle_animation);
//! machine.addState("walk", walk_animation);
//! machine.addTransition("idle", "walk", .{ .parameter = "speed", .threshold = 0.1 });
//! machine.setState("idle");
//! ```

const std = @import("std");
const types = @import("types.zig");

const TimeMs = types.TimeMs;
const DurationMs = types.DurationMs;

// === Condition Types ===

/// Parameter type for state machine conditions
pub const ParameterType = enum(u8) {
    bool_type = 0,
    int_type = 1,
    float_type = 2,
    trigger = 3, // Auto-resets after consumed
};

/// Parameter value union
pub const ParameterValue = union(ParameterType) {
    bool_type: bool,
    int_type: i32,
    float_type: f32,
    trigger: bool,
};

/// Comparison operator for conditions
pub const CompareOp = enum(u8) {
    equals = 0,
    not_equals = 1,
    greater = 2,
    greater_or_equal = 3,
    less = 4,
    less_or_equal = 5,
};

/// Transition condition
pub const Condition = struct {
    parameter_name: []const u8,
    compare_op: CompareOp = .equals,
    threshold: ParameterValue,

    /// Evaluate condition against parameter value
    pub fn evaluate(self: Condition, value: ParameterValue) bool {
        return switch (self.threshold) {
            .bool_type => |threshold| switch (value) {
                .bool_type => |v| switch (self.compare_op) {
                    .equals => v == threshold,
                    .not_equals => v != threshold,
                    else => false,
                },
                else => false,
            },
            .int_type => |threshold| switch (value) {
                .int_type => |v| switch (self.compare_op) {
                    .equals => v == threshold,
                    .not_equals => v != threshold,
                    .greater => v > threshold,
                    .greater_or_equal => v >= threshold,
                    .less => v < threshold,
                    .less_or_equal => v <= threshold,
                },
                else => false,
            },
            .float_type => |threshold| switch (value) {
                .float_type => |v| blk: {
                    const EPSILON: f32 = 1e-6;
                    break :blk switch (self.compare_op) {
                        .equals => @abs(v - threshold) < EPSILON,
                        .not_equals => @abs(v - threshold) >= EPSILON,
                        .greater => v > threshold,
                        .greater_or_equal => v >= threshold,
                        .less => v < threshold,
                        .less_or_equal => v <= threshold,
                    };
                },
                else => false,
            },
            .trigger => |threshold| switch (value) {
                .trigger => |v| v == threshold,
                else => false,
            },
        };
    }
};

// === Transition Types ===

/// Transition blend mode
pub const TransitionBlendMode = enum(u8) {
    instant = 0, // Immediate switch
    crossfade = 1, // Linear crossfade
    ease_in = 2, // Fade in new state
    ease_out = 3, // Fade out old state
    ease_in_out = 4, // Both fade
};

/// Transition configuration
pub const TransitionConfig = struct {
    duration: DurationMs = 200, // Transition duration in ms
    blend_mode: TransitionBlendMode = .crossfade,
    exit_time: ?f32 = null, // Normalized time (0-1) when transition can occur
    has_exit_time: bool = false, // Must wait for exit_time
    can_interrupt: bool = true, // Can be interrupted by other transitions
    priority: u8 = 0, // Higher priority transitions take precedence
};

/// State transition definition
pub const Transition = struct {
    from_state: []const u8,
    to_state: []const u8,
    conditions: std.ArrayList(Condition),
    config: TransitionConfig,

    pub fn init(allocator: std.mem.Allocator, from: []const u8, to: []const u8) Transition {
        return Transition{
            .from_state = from,
            .to_state = to,
            .conditions = std.ArrayList(Condition).init(allocator),
            .config = TransitionConfig{},
        };
    }

    pub fn deinit(self: *Transition) void {
        self.conditions.deinit();
    }

    /// Add a condition to this transition
    pub fn addCondition(self: *Transition, condition: Condition) *Transition {
        self.conditions.append(condition) catch {};
        return self;
    }

    /// Set transition configuration
    pub fn setConfig(self: *Transition, config: TransitionConfig) *Transition {
        self.config = config;
        return self;
    }
};

// === State Types ===

/// Animation state callback signatures
pub const StateCallback = *const fn (state_name: []const u8) void;
pub const UpdateCallback = *const fn (state_name: []const u8, delta_ms: TimeMs) void;

/// Animation state definition
pub const State = struct {
    name: []const u8,
    animation_id: ?u32 = null, // Optional linked animation
    speed: f32 = 1.0,
    loop: bool = true,

    // Callbacks
    on_enter: ?StateCallback = null,
    on_exit: ?StateCallback = null,
    on_update: ?UpdateCallback = null,

    // State timing
    normalized_time: f32 = 0,
    total_time: TimeMs = 0,
};

// === State Machine ===

/// Animation state machine controller
pub const StateMachine = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    states: std.StringHashMap(State),
    transitions: std.ArrayList(Transition),
    parameters: std.StringHashMap(ParameterValue),

    // Current state
    current_state: ?[]const u8,
    previous_state: ?[]const u8,

    // Transition state
    is_transitioning: bool,
    transition_progress: f32,
    active_transition: ?*const Transition,
    transition_start_time: TimeMs,

    // Any state transitions (from any state)
    any_state_transitions: std.ArrayList(Transition),

    // Callbacks
    on_state_changed: ?*const fn (from: ?[]const u8, to: []const u8) void,
    on_transition_started: ?*const fn (transition: *const Transition) void,
    on_transition_completed: ?*const fn (transition: *const Transition) void,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .states = std.StringHashMap(State).init(allocator),
            .transitions = std.ArrayList(Transition).init(allocator),
            .parameters = std.StringHashMap(ParameterValue).init(allocator),
            .current_state = null,
            .previous_state = null,
            .is_transitioning = false,
            .transition_progress = 0,
            .active_transition = null,
            .transition_start_time = 0,
            .any_state_transitions = std.ArrayList(Transition).init(allocator),
            .on_state_changed = null,
            .on_transition_started = null,
            .on_transition_completed = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.states.deinit();
        for (self.transitions.items) |*t| {
            t.deinit();
        }
        self.transitions.deinit();
        for (self.any_state_transitions.items) |*t| {
            t.deinit();
        }
        self.any_state_transitions.deinit();
        self.parameters.deinit();
    }

    // === State Management ===

    /// Add a state to the machine
    pub fn addState(self: *Self, name: []const u8, state: State) *Self {
        var new_state = state;
        new_state.name = name;
        self.states.put(name, new_state) catch {};
        return self;
    }

    /// Add a simple state with just a name
    pub fn addSimpleState(self: *Self, name: []const u8) *Self {
        self.states.put(name, State{ .name = name }) catch {};
        return self;
    }

    /// Remove a state
    pub fn removeState(self: *Self, name: []const u8) bool {
        return self.states.remove(name);
    }

    /// Get a state by name
    pub fn getState(self: *Self, name: []const u8) ?*State {
        return self.states.getPtr(name);
    }

    /// Check if state exists
    pub fn hasState(self: *const Self, name: []const u8) bool {
        return self.states.contains(name);
    }

    // === Transition Management ===

    /// Add a transition between states
    pub fn addTransition(self: *Self, from: []const u8, to: []const u8) *Transition {
        var transition = Transition.init(self.allocator, from, to);
        self.transitions.append(transition) catch {};
        return &self.transitions.items[self.transitions.items.len - 1];
    }

    /// Add a transition from any state
    pub fn addAnyStateTransition(self: *Self, to: []const u8) *Transition {
        var transition = Transition.init(self.allocator, "*", to);
        self.any_state_transitions.append(transition) catch {};
        return &self.any_state_transitions.items[self.any_state_transitions.items.len - 1];
    }

    // === Parameter Management ===

    /// Set a boolean parameter
    pub fn setBool(self: *Self, name: []const u8, value: bool) void {
        self.parameters.put(name, ParameterValue{ .bool_type = value }) catch {};
    }

    /// Set an integer parameter
    pub fn setInt(self: *Self, name: []const u8, value: i32) void {
        self.parameters.put(name, ParameterValue{ .int_type = value }) catch {};
    }

    /// Set a float parameter
    pub fn setFloat(self: *Self, name: []const u8, value: f32) void {
        self.parameters.put(name, ParameterValue{ .float_type = value }) catch {};
    }

    /// Set a trigger (auto-resets after consumed)
    pub fn setTrigger(self: *Self, name: []const u8) void {
        self.parameters.put(name, ParameterValue{ .trigger = true }) catch {};
    }

    /// Reset a trigger
    pub fn resetTrigger(self: *Self, name: []const u8) void {
        if (self.parameters.getPtr(name)) |param| {
            if (param.* == .trigger) {
                param.* = ParameterValue{ .trigger = false };
            }
        }
    }

    /// Get a parameter value
    pub fn getParameter(self: *const Self, name: []const u8) ?ParameterValue {
        return self.parameters.get(name);
    }

    // === State Control ===

    /// Set the current state immediately (no transition)
    pub fn setState(self: *Self, state_name: []const u8) bool {
        if (!self.states.contains(state_name)) return false;

        // Exit current state
        if (self.current_state) |current| {
            if (self.states.getPtr(current)) |state| {
                if (state.on_exit) |callback| {
                    callback(current);
                }
            }
        }

        self.previous_state = self.current_state;
        self.current_state = state_name;

        // Enter new state
        if (self.states.getPtr(state_name)) |state| {
            state.normalized_time = 0;
            state.total_time = 0;
            if (state.on_enter) |callback| {
                callback(state_name);
            }
        }

        // Notify callback
        if (self.on_state_changed) |callback| {
            callback(self.previous_state, state_name);
        }

        return true;
    }

    /// Request transition to a state (checks conditions)
    pub fn requestTransition(self: *Self, to_state: []const u8) bool {
        if (self.is_transitioning and self.active_transition != null) {
            if (!self.active_transition.?.config.can_interrupt) {
                return false;
            }
        }

        // Find valid transition
        const transition = self.findValidTransition(to_state);
        if (transition) |t| {
            self.startTransition(t);
            return true;
        }
        return false;
    }

    /// Force immediate transition (bypass conditions)
    pub fn forceTransition(self: *Self, to_state: []const u8) bool {
        if (!self.states.contains(to_state)) return false;

        // Instant transition - directly set state without transition animation
        return self.setState(to_state);
    }

    // === Update ===

    /// Update the state machine (call each frame)
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        // Update transition
        if (self.is_transitioning) {
            self.updateTransition(delta_ms);
        }

        // Update current state
        if (self.current_state) |state_name| {
            if (self.states.getPtr(state_name)) |state| {
                state.total_time += delta_ms;
                // Note: normalized_time would need animation duration info
                if (state.on_update) |callback| {
                    callback(state_name, delta_ms);
                }
            }
        }

        // Check for automatic transitions
        if (!self.is_transitioning) {
            self.checkAutomaticTransitions();
        }
    }

    /// Get current state info
    pub fn getCurrentStateName(self: *const Self) ?[]const u8 {
        return self.current_state;
    }

    /// Get transition progress (0-1)
    pub fn getTransitionProgress(self: *const Self) f32 {
        return self.transition_progress;
    }

    /// Check if currently transitioning
    pub fn isInTransition(self: *const Self) bool {
        return self.is_transitioning;
    }

    /// Get blend weight for current state (for animation blending)
    pub fn getCurrentStateWeight(self: *const Self) f32 {
        if (self.is_transitioning) {
            return 1.0 - self.transition_progress;
        }
        return 1.0;
    }

    /// Get blend weight for target state during transition
    pub fn getTargetStateWeight(self: *const Self) f32 {
        if (self.is_transitioning) {
            return self.transition_progress;
        }
        return 0.0;
    }

    // === Private Methods ===

    fn findValidTransition(self: *Self, to_state: []const u8) ?*const Transition {
        const current = self.current_state orelse return null;

        // Check any-state transitions first (higher priority)
        for (self.any_state_transitions.items) |*t| {
            if (std.mem.eql(u8, t.to_state, to_state)) {
                if (self.evaluateConditions(t)) {
                    return t;
                }
            }
        }

        // Check regular transitions
        for (self.transitions.items) |*t| {
            if (std.mem.eql(u8, t.from_state, current) and std.mem.eql(u8, t.to_state, to_state)) {
                if (self.evaluateConditions(t)) {
                    return t;
                }
            }
        }

        return null;
    }

    fn evaluateConditions(self: *Self, transition: *const Transition) bool {
        // Check exit time if required
        if (transition.config.has_exit_time) {
            if (self.current_state) |state_name| {
                if (self.states.getPtr(state_name)) |state| {
                    if (transition.config.exit_time) |exit_time| {
                        if (state.normalized_time < exit_time) {
                            return false;
                        }
                    }
                }
            }
        }

        // Check all conditions (AND logic)
        for (transition.conditions.items) |condition| {
            if (self.parameters.get(condition.parameter_name)) |value| {
                if (!condition.evaluate(value)) {
                    return false;
                }
            } else {
                return false; // Parameter not found
            }
        }

        return true;
    }

    fn startTransition(self: *Self, transition: *const Transition) void {
        self.is_transitioning = true;
        self.transition_progress = 0;
        self.active_transition = transition;
        self.transition_start_time = 0;

        if (self.on_transition_started) |callback| {
            callback(transition);
        }

        // Consume triggers
        for (transition.conditions.items) |condition| {
            if (self.parameters.getPtr(condition.parameter_name)) |param| {
                if (param.* == .trigger) {
                    param.* = ParameterValue{ .trigger = false };
                }
            }
        }
    }

    fn updateTransition(self: *Self, delta_ms: TimeMs) void {
        if (self.active_transition) |transition| {
            self.transition_start_time += delta_ms;

            if (transition.config.duration == 0) {
                // Instant transition
                self.completeTransition();
            } else {
                self.transition_progress = @as(f32, @floatFromInt(self.transition_start_time)) /
                    @as(f32, @floatFromInt(transition.config.duration));

                if (self.transition_progress >= 1.0) {
                    self.completeTransition();
                }
            }
        }
    }

    fn completeTransition(self: *Self) void {
        if (self.active_transition) |transition| {
            _ = self.setState(transition.to_state);

            if (self.on_transition_completed) |callback| {
                callback(transition);
            }
        }

        self.is_transitioning = false;
        self.transition_progress = 0;
        self.active_transition = null;
        self.transition_start_time = 0;
    }

    fn checkAutomaticTransitions(self: *Self) void {
        const current = self.current_state orelse return;

        // Check any-state transitions
        for (self.any_state_transitions.items) |*t| {
            if (!std.mem.eql(u8, t.to_state, current)) {
                if (self.evaluateConditions(t)) {
                    self.startTransition(t);
                    return;
                }
            }
        }

        // Check regular transitions from current state
        for (self.transitions.items) |*t| {
            if (std.mem.eql(u8, t.from_state, current)) {
                if (self.evaluateConditions(t)) {
                    self.startTransition(t);
                    return;
                }
            }
        }
    }
};

// === Layer Support ===

/// Animation layer for blending multiple state machines
pub const AnimationLayer = struct {
    name: []const u8,
    state_machine: StateMachine,
    weight: f32 = 1.0,
    blend_mode: LayerBlendMode = .override,
    mask: ?[]const u8 = null, // Optional bone/property mask
};

/// Layer blend mode
pub const LayerBlendMode = enum(u8) {
    override = 0, // Replace lower layers
    additive = 1, // Add to lower layers
};

/// Multi-layer animation controller
pub const AnimationController = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    layers: std.ArrayList(AnimationLayer),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .layers = std.ArrayList(AnimationLayer).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.layers.items) |*layer| {
            layer.state_machine.deinit();
        }
        self.layers.deinit();
    }

    /// Add a layer
    pub fn addLayer(self: *Self, name: []const u8) *AnimationLayer {
        const layer = AnimationLayer{
            .name = name,
            .state_machine = StateMachine.init(self.allocator),
        };
        self.layers.append(layer) catch {};
        return &self.layers.items[self.layers.items.len - 1];
    }

    /// Get layer by name
    pub fn getLayer(self: *Self, name: []const u8) ?*AnimationLayer {
        for (self.layers.items) |*layer| {
            if (std.mem.eql(u8, layer.name, name)) {
                return layer;
            }
        }
        return null;
    }

    /// Update all layers
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        for (self.layers.items) |*layer| {
            layer.state_machine.update(delta_ms);
        }
    }

    /// Set parameter on all layers
    pub fn setFloat(self: *Self, name: []const u8, value: f32) void {
        for (self.layers.items) |*layer| {
            layer.state_machine.setFloat(name, value);
        }
    }

    /// Set trigger on all layers
    pub fn setTrigger(self: *Self, name: []const u8) void {
        for (self.layers.items) |*layer| {
            layer.state_machine.setTrigger(name);
        }
    }
};
