//! Component Tree Export API
//!
//! Extract and manage UI component hierarchies:
//! - Extract component hierarchy from projects
//! - JSON/structured format export
//! - Property and binding information
//! - Visual preview support
//!
//! This module provides component inspection for tooling and debugging.

const std = @import("std");
const project = @import("project.zig");

/// UI error types
pub const UIError = error{
    NotInitialized,
    InvalidProject,
    InvalidComponent,
    ExportFailed,
    ParseError,
    OutOfMemory,
};

/// Component identifier
pub const ComponentId = struct {
    id: u64,
    name: []const u8,
    parent_id: ?u64 = null,

    pub fn isValid(self: *const ComponentId) bool {
        return self.id > 0 and self.name.len > 0;
    }

    pub fn isRoot(self: *const ComponentId) bool {
        return self.parent_id == null;
    }
};

/// Component type
pub const ComponentType = enum(u8) {
    // Containers
    view = 0,
    scroll_view = 1,
    stack = 2,
    grid = 3,
    list = 4,

    // Input
    button = 10,
    text_field = 11,
    text_area = 12,
    checkbox = 13,
    radio = 14,
    toggle = 15,
    slider = 16,
    picker = 17,

    // Display
    text = 20,
    image = 21,
    icon = 22,
    progress = 23,
    loading = 24,

    // Navigation
    navigation = 30,
    tab_bar = 31,
    toolbar = 32,
    menu = 33,

    // Other
    custom = 255,

    pub fn toString(self: ComponentType) []const u8 {
        return switch (self) {
            .view => "View",
            .scroll_view => "ScrollView",
            .stack => "Stack",
            .grid => "Grid",
            .list => "List",
            .button => "Button",
            .text_field => "TextField",
            .text_area => "TextArea",
            .checkbox => "Checkbox",
            .radio => "Radio",
            .toggle => "Toggle",
            .slider => "Slider",
            .picker => "Picker",
            .text => "Text",
            .image => "Image",
            .icon => "Icon",
            .progress => "Progress",
            .loading => "Loading",
            .navigation => "Navigation",
            .tab_bar => "TabBar",
            .toolbar => "Toolbar",
            .menu => "Menu",
            .custom => "Custom",
        };
    }

    pub fn isContainer(self: ComponentType) bool {
        return switch (self) {
            .view, .scroll_view, .stack, .grid, .list, .navigation, .tab_bar, .toolbar, .menu => true,
            else => false,
        };
    }

    pub fn isInteractive(self: ComponentType) bool {
        return switch (self) {
            .button, .text_field, .text_area, .checkbox, .radio, .toggle, .slider, .picker => true,
            else => false,
        };
    }
};

/// Property value
pub const PropertyValue = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    color: Color,
    size: Size,
    point: Point,
    edge_insets: EdgeInsets,
    null_value: void,

    pub fn toString(self: PropertyValue, allocator: std.mem.Allocator) ![]u8 {
        return switch (self) {
            .string => |s| try std.fmt.allocPrint(allocator, "\"{s}\"", .{s}),
            .number => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
            .boolean => |b| try std.fmt.allocPrint(allocator, "{}", .{b}),
            .null_value => try allocator.dupe(u8, "null"),
            else => try allocator.dupe(u8, "<complex>"),
        };
    }
};

/// Color
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toHex(self: Color) [9]u8 {
        var buf: [9]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "#{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ self.r, self.g, self.b, self.a }) catch unreachable;
        return buf;
    }
};

/// Size
pub const Size = struct {
    width: f32,
    height: f32,
};

/// Point
pub const Point = struct {
    x: f32,
    y: f32,
};

/// Edge insets
pub const EdgeInsets = struct {
    top: f32,
    right: f32,
    bottom: f32,
    left: f32,
};

/// Component property
pub const ComponentProperty = struct {
    name: []const u8,
    value: PropertyValue,
    is_bound: bool = false,
    binding_path: ?[]const u8 = null,
};

/// Component information
pub const ComponentInfo = struct {
    id: ComponentId,
    component_type: ComponentType,
    /// Display name (may differ from id.name)
    display_name: ?[]const u8 = null,
    /// Custom type name (for custom components)
    custom_type: ?[]const u8 = null,
    /// Source file location
    source_file: ?[]const u8 = null,
    /// Source line number
    source_line: ?u32 = null,
    /// Properties
    properties: []const ComponentProperty = &.{},
    /// Children count
    children_count: u32 = 0,
    /// Is visible
    visible: bool = true,
    /// Is enabled
    enabled: bool = true,
};

/// Component tree node
pub const ComponentNode = struct {
    info: ComponentInfo,
    children: []const ComponentNode = &.{},

    pub fn getDepth(self: *const ComponentNode) u32 {
        var max_depth: u32 = 0;
        for (self.children) |child| {
            const child_depth = child.getDepth();
            if (child_depth > max_depth) {
                max_depth = child_depth;
            }
        }
        return max_depth + 1;
    }

    pub fn getTotalCount(self: *const ComponentNode) u32 {
        var count: u32 = 1;
        for (self.children) |child| {
            count += child.getTotalCount();
        }
        return count;
    }
};

/// Component tree
pub const ComponentTree = struct {
    root: ?ComponentNode = null,
    project_name: []const u8,
    exported_at: i64,

    pub fn isEmpty(self: *const ComponentTree) bool {
        return self.root == null;
    }

    pub fn getDepth(self: *const ComponentTree) u32 {
        if (self.root) |root| {
            return root.getDepth();
        }
        return 0;
    }

    pub fn getTotalCount(self: *const ComponentTree) u32 {
        if (self.root) |root| {
            return root.getTotalCount();
        }
        return 0;
    }
};

/// Export format
pub const ExportFormat = enum(u8) {
    json = 0,
    yaml = 1,
    xml = 2,

    pub fn extension(self: ExportFormat) []const u8 {
        return switch (self) {
            .json => ".json",
            .yaml => ".yaml",
            .xml => ".xml",
        };
    }
};

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?UIError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: UIError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) UIError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return UIError.NotInitialized;
        }
    };
}

/// UI Component Manager
pub const UI = struct {
    allocator: std.mem.Allocator,
    components: std.AutoHashMapUnmanaged(u64, ComponentInfo) = .{},
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) UI {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UI) void {
        self.components.deinit(self.allocator);
    }

    /// Export component tree for a project
    pub fn exportTree(self: *UI, project_id: project.ProjectId) *Future(ComponentTree) {
        const future = self.allocator.create(Future(ComponentTree)) catch {
            const err_future = self.allocator.create(Future(ComponentTree)) catch unreachable;
            err_future.* = Future(ComponentTree).init();
            err_future.fail(UIError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ComponentTree).init();

        if (!project_id.isValid()) {
            future.fail(UIError.InvalidProject);
            return future;
        }

        // In real implementation, would parse project files and build tree
        const tree = ComponentTree{
            .root = null, // Empty tree for stub
            .project_name = project_id.name,
            .exported_at = std.time.timestamp(),
        };

        future.complete(tree);
        return future;
    }

    /// Get component information
    pub fn getComponentInfo(self: *const UI, component_id: ComponentId) ?ComponentInfo {
        return self.components.get(component_id.id);
    }

    /// Register a component (for testing/simulation)
    pub fn registerComponent(self: *UI, info: ComponentInfo) !void {
        try self.components.put(self.allocator, info.id.id, info);
    }

    /// Find components by type
    pub fn findByType(self: *UI, component_type: ComponentType) ![]ComponentInfo {
        var result: std.ArrayListUnmanaged(ComponentInfo) = .{};
        var iter = self.components.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.component_type == component_type) {
                try result.append(self.allocator, entry.value_ptr.*);
            }
        }
        return try result.toOwnedSlice(self.allocator);
    }

    /// Get component count
    pub fn count(self: *const UI) usize {
        return self.components.count();
    }

    /// Export tree to string
    pub fn exportToString(self: *UI, project_id: project.ProjectId, format: ExportFormat) *Future([]const u8) {
        const future = self.allocator.create(Future([]const u8)) catch {
            const err_future = self.allocator.create(Future([]const u8)) catch unreachable;
            err_future.* = Future([]const u8).init();
            err_future.fail(UIError.OutOfMemory);
            return err_future;
        };
        future.* = Future([]const u8).init();

        if (!project_id.isValid()) {
            future.fail(UIError.InvalidProject);
            return future;
        }

        // Generate simple output
        const output = switch (format) {
            .json => "{\"project\": \"" ++ project_id.name ++ "\", \"components\": []}",
            .yaml => "project: " ++ project_id.name ++ "\ncomponents: []",
            .xml => "<project name=\"" ++ project_id.name ++ "\"><components/></project>",
        };

        future.complete(output);
        return future;
    }
};

/// Create a UI component manager
pub fn createUIManager(allocator: std.mem.Allocator) UI {
    return UI.init(allocator);
}

// Tests
test "UI initialization" {
    const allocator = std.testing.allocator;
    var ui = createUIManager(allocator);
    defer ui.deinit();

    try std.testing.expectEqual(@as(usize, 0), ui.count());
}

test "ComponentType methods" {
    try std.testing.expect(ComponentType.view.isContainer());
    try std.testing.expect(ComponentType.stack.isContainer());
    try std.testing.expect(!ComponentType.button.isContainer());

    try std.testing.expect(ComponentType.button.isInteractive());
    try std.testing.expect(ComponentType.text_field.isInteractive());
    try std.testing.expect(!ComponentType.text.isInteractive());

    try std.testing.expect(std.mem.eql(u8, "Button", ComponentType.button.toString()));
}

test "ComponentId methods" {
    const root_id = ComponentId{ .id = 1, .name = "root", .parent_id = null };
    try std.testing.expect(root_id.isValid());
    try std.testing.expect(root_id.isRoot());

    const child_id = ComponentId{ .id = 2, .name = "child", .parent_id = 1 };
    try std.testing.expect(child_id.isValid());
    try std.testing.expect(!child_id.isRoot());

    const invalid_id = ComponentId{ .id = 0, .name = "" };
    try std.testing.expect(!invalid_id.isValid());
}

test "Color toHex" {
    const red = Color{ .r = 255, .g = 0, .b = 0 };
    const hex = red.toHex();
    try std.testing.expect(std.mem.eql(u8, "#FF0000FF", &hex));
}

test "ComponentTree methods" {
    const empty_tree = ComponentTree{
        .root = null,
        .project_name = "test",
        .exported_at = 0,
    };
    try std.testing.expect(empty_tree.isEmpty());
    try std.testing.expectEqual(@as(u32, 0), empty_tree.getDepth());
    try std.testing.expectEqual(@as(u32, 0), empty_tree.getTotalCount());
}

test "Export tree" {
    const allocator = std.testing.allocator;
    var ui = createUIManager(allocator);
    defer ui.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = ui.exportTree(project_id);
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());

    const tree = try future.get();
    try std.testing.expect(std.mem.eql(u8, "test", tree.project_name));
}

test "Register and find component" {
    const allocator = std.testing.allocator;
    var ui = createUIManager(allocator);
    defer ui.deinit();

    const info = ComponentInfo{
        .id = .{ .id = 1, .name = "button1" },
        .component_type = .button,
    };

    try ui.registerComponent(info);
    try std.testing.expectEqual(@as(usize, 1), ui.count());

    const found = ui.getComponentInfo(.{ .id = 1, .name = "button1" });
    try std.testing.expect(found != null);
    try std.testing.expectEqual(ComponentType.button, found.?.component_type);
}

test "Find by type" {
    const allocator = std.testing.allocator;
    var ui = createUIManager(allocator);
    defer ui.deinit();

    try ui.registerComponent(.{ .id = .{ .id = 1, .name = "btn1" }, .component_type = .button });
    try ui.registerComponent(.{ .id = .{ .id = 2, .name = "txt1" }, .component_type = .text });
    try ui.registerComponent(.{ .id = .{ .id = 3, .name = "btn2" }, .component_type = .button });

    const buttons = try ui.findByType(.button);
    defer allocator.free(buttons);
    try std.testing.expectEqual(@as(usize, 2), buttons.len);
}

test "ExportFormat extension" {
    try std.testing.expect(std.mem.eql(u8, ".json", ExportFormat.json.extension()));
    try std.testing.expect(std.mem.eql(u8, ".yaml", ExportFormat.yaml.extension()));
    try std.testing.expect(std.mem.eql(u8, ".xml", ExportFormat.xml.extension()));
}
