//! Behavior Tree System
//!
//! Provides a flexible behavior tree implementation for game AI decision-making.
//! Supports composite nodes, decorators, action/condition leaf nodes, and runtime
//! modification with blackboard data sharing.
//!
//! ## Features
//! - Composite nodes: Sequence, Selector, Parallel, RandomSelector
//! - Decorator nodes: Inverter, Repeater, Limiter, Cooldown, AlwaysSucceed/Fail
//! - Leaf nodes: Actions and Conditions with user-defined callbacks
//! - Blackboard for shared data between nodes
//! - Tree builder for easy construction
//! - Subtree support for modular behavior design
//!
//! ## Example
//! ```zig
//! const bt = @import("behavior_tree.zig");
//!
//! // Build a simple patrol/chase behavior
//! var builder = bt.TreeBuilder.init(allocator);
//! defer builder.deinit();
//!
//! const tree = try builder
//!     .selector()
//!         .sequence()
//!             .condition("see_enemy", seeEnemy)
//!             .action("chase", chaseEnemy)
//!         .end()
//!         .action("patrol", patrol)
//!     .end()
//!     .build();
//! defer tree.deinit();
//!
//! // Run the tree
//! var blackboard = bt.Blackboard.init(allocator);
//! const result = tree.tick(&blackboard, delta_time);
//! ```

const std = @import("std");

// ============================================================================
// Node Status
// ============================================================================

/// Result status of a behavior tree node tick
pub const Status = enum(u8) {
    /// Node is still running (will be ticked again)
    running,
    /// Node completed successfully
    success,
    /// Node failed
    failure,

    pub fn isComplete(self: Status) bool {
        return self != .running;
    }
};

// ============================================================================
// Node Types
// ============================================================================

/// Types of behavior tree nodes
pub const NodeType = enum(u8) {
    // Composites
    sequence,
    selector,
    parallel,
    random_selector,

    // Decorators
    inverter,
    repeater,
    limiter,
    cooldown,
    always_succeed,
    always_fail,
    until_success,
    until_failure,

    // Leaves
    action,
    condition,
    wait,
    subtree,
};

// ============================================================================
// Blackboard
// ============================================================================

/// Shared data storage for behavior tree nodes
pub const Blackboard = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMap(Value),

    /// Value types that can be stored in the blackboard
    pub const Value = union(enum) {
        boolean: bool,
        integer: i64,
        float: f64,
        string: []const u8,
        vector3: [3]f32,
        entity_id: u32,
        pointer: *anyopaque,
    };

    pub fn init(allocator: std.mem.Allocator) Blackboard {
        return .{
            .allocator = allocator,
            .data = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Blackboard) void {
        self.data.deinit();
    }

    pub fn set(self: *Blackboard, key: []const u8, value: Value) !void {
        try self.data.put(key, value);
    }

    pub fn get(self: *const Blackboard, key: []const u8) ?Value {
        return self.data.get(key);
    }

    pub fn getBool(self: *const Blackboard, key: []const u8) ?bool {
        if (self.data.get(key)) |val| {
            if (val == .boolean) return val.boolean;
        }
        return null;
    }

    pub fn getInt(self: *const Blackboard, key: []const u8) ?i64 {
        if (self.data.get(key)) |val| {
            if (val == .integer) return val.integer;
        }
        return null;
    }

    pub fn getFloat(self: *const Blackboard, key: []const u8) ?f64 {
        if (self.data.get(key)) |val| {
            if (val == .float) return val.float;
        }
        return null;
    }

    pub fn getEntityId(self: *const Blackboard, key: []const u8) ?u32 {
        if (self.data.get(key)) |val| {
            if (val == .entity_id) return val.entity_id;
        }
        return null;
    }

    pub fn remove(self: *Blackboard, key: []const u8) void {
        _ = self.data.remove(key);
    }

    pub fn clear(self: *Blackboard) void {
        self.data.clearRetainingCapacity();
    }
};

// ============================================================================
// Node Context
// ============================================================================

/// Context passed to nodes during tick
pub const NodeContext = struct {
    blackboard: *Blackboard,
    delta_time: f32,
    /// User data pointer (e.g., entity or game state)
    user_data: ?*anyopaque = null,
};

// ============================================================================
// Behavior Node
// ============================================================================

/// A single node in the behavior tree
pub const BehaviorNode = struct {
    node_type: NodeType,
    name: []const u8,
    children: std.ArrayList(*BehaviorNode),
    allocator: std.mem.Allocator,

    // Node-specific data
    data: NodeData = .{ .none = {} },

    // Runtime state
    state: NodeState = .{},

    pub const NodeData = union(enum) {
        none: void,
        action: ActionData,
        condition: ConditionData,
        repeater: RepeaterData,
        limiter: LimiterData,
        cooldown: CooldownData,
        parallel: ParallelData,
        wait: WaitData,
        subtree: SubtreeData,
    };

    pub const ActionData = struct {
        callback: *const fn (*NodeContext) Status,
        on_enter: ?*const fn (*NodeContext) void = null,
        on_exit: ?*const fn (*NodeContext, Status) void = null,
    };

    pub const ConditionData = struct {
        callback: *const fn (*NodeContext) bool,
    };

    pub const RepeaterData = struct {
        count: u32, // 0 = infinite
        current: u32 = 0,
    };

    pub const LimiterData = struct {
        max_runs: u32,
        runs: u32 = 0,
    };

    pub const CooldownData = struct {
        duration: f32,
        elapsed: f32 = 0,
    };

    pub const ParallelData = struct {
        policy: ParallelPolicy = .require_all,
        success_count: u32 = 0,
        failure_count: u32 = 0,
    };

    pub const WaitData = struct {
        duration: f32,
        elapsed: f32 = 0,
    };

    pub const SubtreeData = struct {
        tree: *BehaviorTree,
    };

    pub const ParallelPolicy = enum(u8) {
        require_all, // Success if all succeed
        require_one, // Success if any succeeds
        require_n, // Success if N succeed
    };

    pub const NodeState = struct {
        running_child: u32 = 0,
        is_running: bool = false,
    };

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType, name: []const u8) BehaviorNode {
        return .{
            .node_type = node_type,
            .name = name,
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BehaviorNode) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *BehaviorNode, child: *BehaviorNode) !void {
        try self.children.append(self.allocator, child);
    }

    /// Tick the node and return its status
    pub fn tick(self: *BehaviorNode, ctx: *NodeContext) Status {
        return switch (self.node_type) {
            // Composites
            .sequence => self.tickSequence(ctx),
            .selector => self.tickSelector(ctx),
            .parallel => self.tickParallel(ctx),
            .random_selector => self.tickRandomSelector(ctx),

            // Decorators
            .inverter => self.tickInverter(ctx),
            .repeater => self.tickRepeater(ctx),
            .limiter => self.tickLimiter(ctx),
            .cooldown => self.tickCooldown(ctx),
            .always_succeed => self.tickAlwaysSucceed(ctx),
            .always_fail => self.tickAlwaysFail(ctx),
            .until_success => self.tickUntilSuccess(ctx),
            .until_failure => self.tickUntilFailure(ctx),

            // Leaves
            .action => self.tickAction(ctx),
            .condition => self.tickCondition(ctx),
            .wait => self.tickWait(ctx),
            .subtree => self.tickSubtree(ctx),
        };
    }

    /// Reset node state for a new run
    pub fn reset(self: *BehaviorNode) void {
        self.state = .{};

        // Reset node-specific data
        switch (self.data) {
            .repeater => |*d| d.current = 0,
            .limiter => |*d| d.runs = 0,
            .cooldown => |*d| d.elapsed = 0,
            .parallel => |*d| {
                d.success_count = 0;
                d.failure_count = 0;
            },
            .wait => |*d| d.elapsed = 0,
            else => {},
        }

        // Reset children
        for (self.children.items) |child| {
            child.reset();
        }
    }

    // =======================================================================
    // Composite Node Implementations
    // =======================================================================

    fn tickSequence(self: *BehaviorNode, ctx: *NodeContext) Status {
        var start: u32 = 0;
        if (self.state.is_running) {
            start = self.state.running_child;
        }

        var i: u32 = start;
        while (i < self.children.items.len) : (i += 1) {
            const result = self.children.items[i].tick(ctx);

            switch (result) {
                .running => {
                    self.state.running_child = i;
                    self.state.is_running = true;
                    return .running;
                },
                .failure => {
                    self.state.is_running = false;
                    return .failure;
                },
                .success => {},
            }
        }

        self.state.is_running = false;
        return .success;
    }

    fn tickSelector(self: *BehaviorNode, ctx: *NodeContext) Status {
        var start: u32 = 0;
        if (self.state.is_running) {
            start = self.state.running_child;
        }

        var i: u32 = start;
        while (i < self.children.items.len) : (i += 1) {
            const result = self.children.items[i].tick(ctx);

            switch (result) {
                .running => {
                    self.state.running_child = i;
                    self.state.is_running = true;
                    return .running;
                },
                .success => {
                    self.state.is_running = false;
                    return .success;
                },
                .failure => {},
            }
        }

        self.state.is_running = false;
        return .failure;
    }

    fn tickParallel(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.data != .parallel) return .failure;

        var success_count: u32 = 0;
        var failure_count: u32 = 0;
        var has_running = false;

        for (self.children.items) |child| {
            const result = child.tick(ctx);
            switch (result) {
                .success => success_count += 1,
                .failure => failure_count += 1,
                .running => has_running = true,
            }
        }

        const policy = self.data.parallel.policy;
        const total: u32 = @intCast(self.children.items.len);

        return switch (policy) {
            .require_all => {
                if (failure_count > 0) return .failure;
                if (success_count == total) return .success;
                return .running;
            },
            .require_one => {
                if (success_count > 0) return .success;
                if (failure_count == total) return .failure;
                return .running;
            },
            .require_n => {
                // Use success_count from data as threshold
                const threshold = self.data.parallel.success_count;
                if (success_count >= threshold) return .success;
                if (failure_count > total - threshold) return .failure;
                if (has_running) return .running;
                return .failure;
            },
        };
    }

    fn tickRandomSelector(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;

        // If not running, pick a random child
        if (!self.state.is_running) {
            var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
            self.state.running_child = prng.random().intRangeLessThan(u32, 0, @intCast(self.children.items.len));
        }

        const result = self.children.items[self.state.running_child].tick(ctx);

        if (result == .running) {
            self.state.is_running = true;
            return .running;
        }

        self.state.is_running = false;
        return result;
    }

    // =======================================================================
    // Decorator Node Implementations
    // =======================================================================

    fn tickInverter(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;

        const result = self.children.items[0].tick(ctx);
        return switch (result) {
            .success => .failure,
            .failure => .success,
            .running => .running,
        };
    }

    fn tickRepeater(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;
        if (self.data != .repeater) return .failure;

        const data = &self.data.repeater;

        // Check if we've reached the limit (0 = infinite)
        if (data.count > 0 and data.current >= data.count) {
            return .success;
        }

        const result = self.children.items[0].tick(ctx);

        if (result == .running) {
            return .running;
        }

        data.current += 1;

        // Check if we've hit the limit after this iteration
        if (data.count > 0 and data.current >= data.count) {
            return result;
        }

        // Continue repeating
        return .running;
    }

    fn tickLimiter(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;
        if (self.data != .limiter) return .failure;

        var data = &self.data.limiter;

        // Check if limit reached
        if (data.runs >= data.max_runs) {
            return .failure;
        }

        if (!self.state.is_running) {
            data.runs += 1;
        }

        const result = self.children.items[0].tick(ctx);
        self.state.is_running = result == .running;

        return result;
    }

    fn tickCooldown(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;
        if (self.data != .cooldown) return .failure;

        var data = &self.data.cooldown;

        // Still in cooldown
        if (data.elapsed < data.duration) {
            data.elapsed += ctx.delta_time;
            return .failure;
        }

        const result = self.children.items[0].tick(ctx);

        // Reset cooldown on completion
        if (result != .running) {
            data.elapsed = 0;
        }

        return result;
    }

    fn tickAlwaysSucceed(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .success;

        const result = self.children.items[0].tick(ctx);
        if (result == .running) return .running;
        return .success;
    }

    fn tickAlwaysFail(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;

        const result = self.children.items[0].tick(ctx);
        if (result == .running) return .running;
        return .failure;
    }

    fn tickUntilSuccess(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;

        const result = self.children.items[0].tick(ctx);
        if (result == .success) return .success;
        return .running;
    }

    fn tickUntilFailure(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.children.items.len == 0) return .failure;

        const result = self.children.items[0].tick(ctx);
        if (result == .failure) return .failure;
        return .running;
    }

    // =======================================================================
    // Leaf Node Implementations
    // =======================================================================

    fn tickAction(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.data != .action) return .failure;

        const action = self.data.action;

        // Call on_enter if starting
        if (!self.state.is_running) {
            if (action.on_enter) |on_enter| {
                on_enter(ctx);
            }
        }

        const result = action.callback(ctx);

        self.state.is_running = result == .running;

        // Call on_exit if complete
        if (result != .running) {
            if (action.on_exit) |on_exit| {
                on_exit(ctx, result);
            }
        }

        return result;
    }

    fn tickCondition(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.data != .condition) return .failure;

        const result = self.data.condition.callback(ctx);
        return if (result) .success else .failure;
    }

    fn tickWait(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.data != .wait) return .failure;

        var data = &self.data.wait;
        data.elapsed += ctx.delta_time;

        if (data.elapsed >= data.duration) {
            data.elapsed = 0;
            return .success;
        }

        return .running;
    }

    fn tickSubtree(self: *BehaviorNode, ctx: *NodeContext) Status {
        if (self.data != .subtree) return .failure;

        return self.data.subtree.tree.tick(ctx);
    }
};

// ============================================================================
// Behavior Tree
// ============================================================================

/// A complete behavior tree with root node
pub const BehaviorTree = struct {
    root: *BehaviorNode,
    allocator: std.mem.Allocator,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, root: *BehaviorNode, name: []const u8) BehaviorTree {
        return .{
            .root = root,
            .allocator = allocator,
            .name = name,
        };
    }

    pub fn deinit(self: *BehaviorTree) void {
        self.root.deinit();
        self.allocator.destroy(self.root);
    }

    /// Tick the entire tree
    pub fn tick(self: *BehaviorTree, ctx: *NodeContext) Status {
        return self.root.tick(ctx);
    }

    /// Reset the tree for a fresh run
    pub fn reset(self: *BehaviorTree) void {
        self.root.reset();
    }

    /// Tick with convenience wrapper
    pub fn update(self: *BehaviorTree, blackboard: *Blackboard, delta_time: f32, user_data: ?*anyopaque) Status {
        var ctx = NodeContext{
            .blackboard = blackboard,
            .delta_time = delta_time,
            .user_data = user_data,
        };
        return self.tick(&ctx);
    }
};

// ============================================================================
// Tree Builder
// ============================================================================

/// Fluent builder for constructing behavior trees
pub const TreeBuilder = struct {
    allocator: std.mem.Allocator,
    stack: std.ArrayList(*BehaviorNode),
    root: ?*BehaviorNode = null,

    pub fn init(allocator: std.mem.Allocator) TreeBuilder {
        return .{
            .allocator = allocator,
            .stack = .{},
        };
    }

    pub fn deinit(self: *TreeBuilder) void {
        self.stack.deinit(self.allocator);
    }

    fn createNode(self: *TreeBuilder, node_type: NodeType, name: []const u8) !*BehaviorNode {
        const node = try self.allocator.create(BehaviorNode);
        node.* = BehaviorNode.init(self.allocator, node_type, name);
        return node;
    }

    fn addToParent(self: *TreeBuilder, node: *BehaviorNode) !void {
        if (self.stack.items.len > 0) {
            const parent = self.stack.items[self.stack.items.len - 1];
            try parent.addChild(node);
        } else if (self.root == null) {
            self.root = node;
        }
    }

    // === Composite Nodes ===

    pub fn sequence(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.sequence, "sequence");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn selector(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.selector, "selector");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn parallel(self: *TreeBuilder, policy: BehaviorNode.ParallelPolicy) !*TreeBuilder {
        const node = try self.createNode(.parallel, "parallel");
        node.data = .{ .parallel = .{ .policy = policy } };
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn randomSelector(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.random_selector, "random_selector");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    // === Decorator Nodes ===

    pub fn inverter(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.inverter, "inverter");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn repeater(self: *TreeBuilder, count: u32) !*TreeBuilder {
        const node = try self.createNode(.repeater, "repeater");
        node.data = .{ .repeater = .{ .count = count } };
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn limiter(self: *TreeBuilder, max_runs: u32) !*TreeBuilder {
        const node = try self.createNode(.limiter, "limiter");
        node.data = .{ .limiter = .{ .max_runs = max_runs } };
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn cooldown(self: *TreeBuilder, duration: f32) !*TreeBuilder {
        const node = try self.createNode(.cooldown, "cooldown");
        node.data = .{ .cooldown = .{ .duration = duration } };
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn alwaysSucceed(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.always_succeed, "always_succeed");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn alwaysFail(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.always_fail, "always_fail");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn untilSuccess(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.until_success, "until_success");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    pub fn untilFailure(self: *TreeBuilder) !*TreeBuilder {
        const node = try self.createNode(.until_failure, "until_failure");
        try self.addToParent(node);
        try self.stack.append(self.allocator, node);
        return self;
    }

    // === Leaf Nodes ===

    pub fn action(self: *TreeBuilder, name: []const u8, callback: *const fn (*NodeContext) Status) !*TreeBuilder {
        const node = try self.createNode(.action, name);
        node.data = .{ .action = .{ .callback = callback } };
        try self.addToParent(node);
        return self;
    }

    pub fn actionWithCallbacks(
        self: *TreeBuilder,
        name: []const u8,
        callback: *const fn (*NodeContext) Status,
        on_enter: ?*const fn (*NodeContext) void,
        on_exit: ?*const fn (*NodeContext, Status) void,
    ) !*TreeBuilder {
        const node = try self.createNode(.action, name);
        node.data = .{ .action = .{
            .callback = callback,
            .on_enter = on_enter,
            .on_exit = on_exit,
        } };
        try self.addToParent(node);
        return self;
    }

    pub fn condition(self: *TreeBuilder, name: []const u8, callback: *const fn (*NodeContext) bool) !*TreeBuilder {
        const node = try self.createNode(.condition, name);
        node.data = .{ .condition = .{ .callback = callback } };
        try self.addToParent(node);
        return self;
    }

    pub fn wait(self: *TreeBuilder, duration: f32) !*TreeBuilder {
        const node = try self.createNode(.wait, "wait");
        node.data = .{ .wait = .{ .duration = duration } };
        try self.addToParent(node);
        return self;
    }

    pub fn subtree(self: *TreeBuilder, tree: *BehaviorTree) !*TreeBuilder {
        const node = try self.createNode(.subtree, tree.name);
        node.data = .{ .subtree = .{ .tree = tree } };
        try self.addToParent(node);
        return self;
    }

    // === Stack Management ===

    pub fn end(self: *TreeBuilder) !*TreeBuilder {
        if (self.stack.items.len > 0) {
            _ = self.stack.pop();
        }
        return self;
    }

    pub fn build(self: *TreeBuilder, name: []const u8) !BehaviorTree {
        if (self.root) |root| {
            return BehaviorTree.init(self.allocator, root, name);
        }
        return error.NoRootNode;
    }
};

// ============================================================================
// Pre-built Action Nodes
// ============================================================================

/// Common pre-built action nodes
pub const Actions = struct {
    /// Log a message to blackboard "log" key
    pub fn log(ctx: *NodeContext) Status {
        if (ctx.blackboard.get("log_message")) |msg| {
            if (msg == .string) {
                std.debug.print("BT Log: {s}\n", .{msg.string});
            }
        }
        return .success;
    }

    /// Set a blackboard value
    pub fn setBlackboard(ctx: *NodeContext) Status {
        // Read key/value from blackboard configuration
        const key = ctx.blackboard.get("set_key") orelse return .failure;
        const value = ctx.blackboard.get("set_value") orelse return .failure;

        if (key == .string) {
            ctx.blackboard.set(key.string, value) catch return .failure;
            return .success;
        }
        return .failure;
    }

    /// Always succeeds (no-op)
    pub fn succeed(_: *NodeContext) Status {
        return .success;
    }

    /// Always fails
    pub fn fail(_: *NodeContext) Status {
        return .failure;
    }
};

/// Common pre-built condition nodes
pub const Conditions = struct {
    /// Check if a blackboard key exists
    pub fn hasKey(ctx: *NodeContext) bool {
        const key = ctx.blackboard.get("check_key") orelse return false;
        if (key == .string) {
            return ctx.blackboard.get(key.string) != null;
        }
        return false;
    }

    /// Check if a blackboard boolean is true
    pub fn isTrue(ctx: *NodeContext) bool {
        const key = ctx.blackboard.get("check_key") orelse return false;
        if (key == .string) {
            return ctx.blackboard.getBool(key.string) orelse false;
        }
        return false;
    }

    /// Check if a blackboard boolean is false
    pub fn isFalse(ctx: *NodeContext) bool {
        return !isTrue(ctx);
    }

    /// Compare two integer values
    pub fn intGreaterThan(ctx: *NodeContext) bool {
        const key = ctx.blackboard.get("compare_key") orelse return false;
        const threshold = ctx.blackboard.get("compare_value") orelse return false;

        if (key == .string and threshold == .integer) {
            const value = ctx.blackboard.getInt(key.string) orelse return false;
            return value > threshold.integer;
        }
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Blackboard operations" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    try bb.set("health", .{ .integer = 100 });
    try bb.set("is_alive", .{ .boolean = true });
    try bb.set("speed", .{ .float = 5.5 });

    try std.testing.expectEqual(@as(i64, 100), bb.getInt("health").?);
    try std.testing.expectEqual(true, bb.getBool("is_alive").?);
    try std.testing.expect(bb.getFloat("speed").? == 5.5);

    try std.testing.expect(bb.get("nonexistent") == null);

    bb.remove("health");
    try std.testing.expect(bb.getInt("health") == null);
}

test "Status enum" {
    try std.testing.expect(Status.running.isComplete() == false);
    try std.testing.expect(Status.success.isComplete() == true);
    try std.testing.expect(Status.failure.isComplete() == true);
}

test "Sequence node" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    var builder = TreeBuilder.init(allocator);
    defer builder.deinit();

    // Build: sequence(succeed, succeed)
    _ = try builder.sequence();
    _ = try builder.action("a1", Actions.succeed);
    _ = try builder.action("a2", Actions.succeed);
    _ = try builder.end();

    var tree = try builder.build("test_sequence");
    defer tree.deinit();

    const result = tree.update(&bb, 0.016, null);
    try std.testing.expectEqual(Status.success, result);
}

test "Selector node" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    var builder = TreeBuilder.init(allocator);
    defer builder.deinit();

    // Build: selector(fail, succeed, fail)
    _ = try builder.selector();
    _ = try builder.action("a1", Actions.fail);
    _ = try builder.action("a2", Actions.succeed);
    _ = try builder.action("a3", Actions.fail);
    _ = try builder.end();

    var tree = try builder.build("test_selector");
    defer tree.deinit();

    const result = tree.update(&bb, 0.016, null);
    try std.testing.expectEqual(Status.success, result);
}

test "Inverter decorator" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    var builder = TreeBuilder.init(allocator);
    defer builder.deinit();

    // Build: inverter(succeed) -> should be failure
    _ = try builder.inverter();
    _ = try builder.action("a1", Actions.succeed);
    _ = try builder.end();

    var tree = try builder.build("test_inverter");
    defer tree.deinit();

    const result = tree.update(&bb, 0.016, null);
    try std.testing.expectEqual(Status.failure, result);
}

test "Wait node" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    var builder = TreeBuilder.init(allocator);
    defer builder.deinit();

    // Build: wait(0.5)
    _ = try builder.wait(0.5);

    var tree = try builder.build("test_wait");
    defer tree.deinit();

    // First tick - should be running
    var result = tree.update(&bb, 0.2, null);
    try std.testing.expectEqual(Status.running, result);

    // Second tick - still running
    result = tree.update(&bb, 0.2, null);
    try std.testing.expectEqual(Status.running, result);

    // Third tick - should complete
    result = tree.update(&bb, 0.2, null);
    try std.testing.expectEqual(Status.success, result);
}

test "Nested tree" {
    const allocator = std.testing.allocator;

    var bb = Blackboard.init(allocator);
    defer bb.deinit();

    var builder = TreeBuilder.init(allocator);
    defer builder.deinit();

    // Build: selector(sequence(fail, succeed), succeed)
    _ = try builder.selector();
    _ = try builder.sequence();
    _ = try builder.action("a1", Actions.fail);
    _ = try builder.action("a2", Actions.succeed);
    _ = try builder.end(); // end sequence
    _ = try builder.action("a3", Actions.succeed);
    _ = try builder.end(); // end selector

    var tree = try builder.build("test_nested");
    defer tree.deinit();

    // Sequence fails (first child fails), selector tries second child (succeed)
    const result = tree.update(&bb, 0.016, null);
    try std.testing.expectEqual(Status.success, result);
}
