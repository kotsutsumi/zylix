// Zylix Test Framework - Selector API
// Provides unified element selection across all platforms

const std = @import("std");

/// Component types that can be selected
/// Mirror of component.ComponentType for test framework independence
pub const ComponentType = enum(u8) {
    // Basic Components (0-9)
    Container = 0,
    Text = 1,
    Button = 2,
    Input = 3,
    Image = 4,
    Link = 5,
    List = 6,
    ListItem = 7,
    Heading = 8,
    Paragraph = 9,

    // Form Components (10-19)
    Select = 10,
    Checkbox = 11,
    Radio = 12,
    Textarea = 13,
    ToggleSwitch = 14,
    Slider = 15,
    DatePicker = 16,
    TimePicker = 17,
    FileInput = 18,
    ColorPicker = 19,
    Form = 20,

    // Layout Components (21-29)
    Stack = 21,
    Grid = 22,
    ScrollView = 23,
    Spacer = 24,
    Divider = 25,
    Card = 26,
    AspectRatio = 27,
    SafeArea = 28,

    // Navigation Components (30-39)
    NavBar = 30,
    TabBar = 31,
    Drawer = 32,
    Breadcrumb = 33,
    Pagination = 34,

    // Feedback Components (40-49)
    Alert = 40,
    Toast = 41,
    Modal = 42,
    Progress = 43,
    Spinner = 44,
    Skeleton = 45,
    Badge = 46,

    // Data Display Components (50-59)
    Table = 50,
    Avatar = 51,
    Icon = 52,
    Tag = 53,
    Tooltip = 54,
    Accordion = 55,
    Carousel = 56,

    // Reserved
    Custom = 255,
};

/// Selector for finding UI elements
pub const Selector = struct {
    component_type: ?ComponentType = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    test_id: ?[]const u8 = null,
    index: ?usize = null,
    parent: ?*const Selector = null,
    enabled: ?bool = null,
    visible: ?bool = null,

    const Self = @This();

    /// Select by component type
    pub fn byType(comptime T: ComponentType) Self {
        return .{ .component_type = T };
    }

    /// Select by exact text content
    pub fn byText(text: []const u8) Self {
        return .{ .text = text };
    }

    /// Select by partial text content
    pub fn byTextContaining(text: []const u8) Self {
        return .{ .text_contains = text };
    }

    /// Select by test ID (data-testid attribute)
    pub fn byTestId(id: []const u8) Self {
        return .{ .test_id = id };
    }

    /// Select by accessibility ID
    pub fn byAccessibilityId(id: []const u8) Self {
        return .{ .accessibility_id = id };
    }

    /// Select by index among matching elements
    pub fn byIndex(idx: usize) Self {
        return .{ .index = idx };
    }

    // Chaining methods

    /// Filter by component type
    pub fn withType(self: Self, comptime T: ComponentType) Self {
        var new = self;
        new.component_type = T;
        return new;
    }

    /// Filter by exact text
    pub fn withText(self: Self, text: []const u8) Self {
        var new = self;
        new.text = text;
        return new;
    }

    /// Filter by partial text
    pub fn withTextContaining(self: Self, text: []const u8) Self {
        var new = self;
        new.text_contains = text;
        return new;
    }

    /// Filter by test ID
    pub fn withTestId(self: Self, id: []const u8) Self {
        var new = self;
        new.test_id = id;
        return new;
    }

    /// Filter by accessibility ID
    pub fn withAccessibilityId(self: Self, id: []const u8) Self {
        var new = self;
        new.accessibility_id = id;
        return new;
    }

    /// Select specific index among matches
    pub fn atIndex(self: Self, idx: usize) Self {
        var new = self;
        new.index = idx;
        return new;
    }

    /// Filter by enabled state
    pub fn isEnabled(self: Self, enabled: bool) Self {
        var new = self;
        new.enabled = enabled;
        return new;
    }

    /// Filter by visibility
    pub fn isVisible(self: Self, visible: bool) Self {
        var new = self;
        new.visible = visible;
        return new;
    }

    /// Set parent selector for nested selection
    pub fn within(self: Self, parent_selector: *const Selector) Self {
        var new = self;
        new.parent = parent_selector;
        return new;
    }

    /// Check if selector matches any criteria
    pub fn isValid(self: Self) bool {
        return self.component_type != null or
            self.text != null or
            self.text_contains != null or
            self.accessibility_id != null or
            self.test_id != null;
    }

    /// Convert selector to debug string
    pub fn toDebugString(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var parts = std.ArrayList([]const u8).init(allocator);
        defer parts.deinit();

        if (self.component_type) |ct| {
            try parts.append(try std.fmt.allocPrint(allocator, "type={s}", .{@tagName(ct)}));
        }
        if (self.text) |t| {
            try parts.append(try std.fmt.allocPrint(allocator, "text=\"{s}\"", .{t}));
        }
        if (self.text_contains) |tc| {
            try parts.append(try std.fmt.allocPrint(allocator, "textContains=\"{s}\"", .{tc}));
        }
        if (self.test_id) |tid| {
            try parts.append(try std.fmt.allocPrint(allocator, "testId=\"{s}\"", .{tid}));
        }
        if (self.accessibility_id) |aid| {
            try parts.append(try std.fmt.allocPrint(allocator, "accessibilityId=\"{s}\"", .{aid}));
        }
        if (self.index) |idx| {
            try parts.append(try std.fmt.allocPrint(allocator, "index={d}", .{idx}));
        }
        if (self.enabled) |e| {
            try parts.append(try std.fmt.allocPrint(allocator, "enabled={}", .{e}));
        }
        if (self.visible) |v| {
            try parts.append(try std.fmt.allocPrint(allocator, "visible={}", .{v}));
        }

        if (parts.items.len == 0) {
            return "Selector{}";
        }

        var result = std.ArrayList(u8).init(allocator);
        try result.appendSlice("Selector{");
        for (parts.items, 0..) |part, i| {
            if (i > 0) try result.appendSlice(", ");
            try result.appendSlice(part);
        }
        try result.appendSlice("}");

        return result.toOwnedSlice();
    }
};

/// Builder for complex selector queries
pub const SelectorBuilder = struct {
    selectors: std.ArrayList(Selector),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .selectors = std.ArrayList(Selector).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.selectors.deinit();
    }

    /// Add a selector to the chain
    pub fn add(self: *Self, selector: Selector) !*Self {
        try self.selectors.append(selector);
        return self;
    }

    /// Build the final selector chain
    pub fn build(self: *Self) []const Selector {
        return self.selectors.items;
    }
};

/// XPath-like selector for complex queries
pub const XPathSelector = struct {
    path: []const u8,

    const Self = @This();

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    /// Parse XPath into Selector chain
    pub fn parse(self: Self, allocator: std.mem.Allocator) ![]Selector {
        var selectors = std.ArrayList(Selector).init(allocator);
        defer selectors.deinit();

        var iter = std.mem.splitSequence(u8, self.path, "/");
        while (iter.next()) |segment| {
            if (segment.len == 0) continue;

            var selector = Selector{};

            // Parse segment like "Button[@text='Submit']"
            if (std.mem.indexOf(u8, segment, "[")) |bracket_start| {
                const type_name = segment[0..bracket_start];
                selector.component_type = parseComponentType(type_name);

                const attr_part = segment[bracket_start + 1 .. segment.len - 1];
                selector = parseAttributes(selector, attr_part);
            } else {
                selector.component_type = parseComponentType(segment);
            }

            try selectors.append(selector);
        }

        return selectors.toOwnedSlice();
    }

    fn parseComponentType(name: []const u8) ?ComponentType {
        inline for (std.meta.fields(ComponentType)) |field| {
            if (std.mem.eql(u8, name, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return null;
    }

    fn parseAttributes(base: Selector, attrs: []const u8) Selector {
        var selector = base;

        // Simple attribute parsing: @attr='value'
        if (std.mem.indexOf(u8, attrs, "@text=")) |_| {
            if (extractQuotedValue(attrs, "@text=")) |value| {
                selector.text = value;
            }
        }
        if (std.mem.indexOf(u8, attrs, "@testId=")) |_| {
            if (extractQuotedValue(attrs, "@testId=")) |value| {
                selector.test_id = value;
            }
        }
        if (std.mem.indexOf(u8, attrs, "@accessibilityId=")) |_| {
            if (extractQuotedValue(attrs, "@accessibilityId=")) |value| {
                selector.accessibility_id = value;
            }
        }

        return selector;
    }

    fn extractQuotedValue(input: []const u8, prefix: []const u8) ?[]const u8 {
        if (std.mem.indexOf(u8, input, prefix)) |start| {
            const value_start = start + prefix.len;
            if (value_start < input.len and (input[value_start] == '\'' or input[value_start] == '"')) {
                const quote = input[value_start];
                const content_start = value_start + 1;
                if (std.mem.indexOfScalarPos(u8, input, content_start, quote)) |end| {
                    return input[content_start..end];
                }
            }
        }
        return null;
    }
};

// Tests
test "selector creation" {
    const sel = Selector.byTestId("login-button");
    try std.testing.expect(sel.test_id != null);
    try std.testing.expectEqualStrings("login-button", sel.test_id.?);
}

test "selector chaining" {
    const sel = Selector.byType(.Button)
        .withTestId("submit")
        .isEnabled(true);

    try std.testing.expect(sel.component_type == .Button);
    try std.testing.expectEqualStrings("submit", sel.test_id.?);
    try std.testing.expect(sel.enabled.? == true);
}

test "selector validity" {
    const valid = Selector.byText("Hello");
    const invalid = Selector{};

    try std.testing.expect(valid.isValid());
    try std.testing.expect(!invalid.isValid());
}
