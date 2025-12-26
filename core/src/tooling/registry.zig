//! Component Registry API (Issue #58)
//!
//! Provides component type registration and metadata querying for IDE tooling.
//! Enables Live Preview tools to discover available components and their properties.
//!
//! Features:
//! - Component type registration with metadata
//! - Property schema definitions
//! - Component discovery and enumeration
//! - C ABI for external tool integration

const std = @import("std");
const component = @import("../component.zig");

// ============================================================================
// Component Metadata Types
// ============================================================================

pub const MAX_COMPONENT_NAME = 64;
pub const MAX_PROPERTY_NAME = 32;
pub const MAX_PROPERTY_DESC = 128;
pub const MAX_PROPERTIES = 32;
pub const MAX_REGISTERED_COMPONENTS = 128;

/// Property value types
pub const PropertyType = enum(u8) {
    string = 0,
    number = 1,
    boolean = 2,
    color = 3,
    enum_type = 4,
    object = 5,
    array = 6,
    callback = 7,
};

/// Property metadata
pub const PropertyMeta = struct {
    name: [MAX_PROPERTY_NAME]u8 = std.mem.zeroes([MAX_PROPERTY_NAME]u8),
    name_len: u8 = 0,
    description: [MAX_PROPERTY_DESC]u8 = std.mem.zeroes([MAX_PROPERTY_DESC]u8),
    description_len: u8 = 0,
    property_type: PropertyType = .string,
    required: bool = false,
    default_value: [64]u8 = std.mem.zeroes([64]u8),
    default_value_len: u8 = 0,

    pub fn setName(self: *PropertyMeta, n: []const u8) void {
        const len = @min(n.len, MAX_PROPERTY_NAME);
        @memcpy(self.name[0..len], n[0..len]);
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const PropertyMeta) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setDescription(self: *PropertyMeta, d: []const u8) void {
        const len = @min(d.len, MAX_PROPERTY_DESC);
        @memcpy(self.description[0..len], d[0..len]);
        self.description_len = @intCast(len);
    }

    pub fn getDescription(self: *const PropertyMeta) []const u8 {
        return self.description[0..self.description_len];
    }

    pub fn setDefault(self: *PropertyMeta, val: []const u8) void {
        const len = @min(val.len, 64);
        @memcpy(self.default_value[0..len], val[0..len]);
        self.default_value_len = @intCast(len);
    }

    pub fn getDefault(self: *const PropertyMeta) []const u8 {
        return self.default_value[0..self.default_value_len];
    }
};

/// Component category for organization
pub const ComponentCategory = enum(u8) {
    basic = 0,
    form = 1,
    layout = 2,
    navigation = 3,
    feedback = 4,
    data_display = 5,
    custom = 255,
};

/// Component metadata
pub const ComponentMeta = struct {
    id: u32 = 0,
    component_type: component.ComponentType = .container,
    name: [MAX_COMPONENT_NAME]u8 = std.mem.zeroes([MAX_COMPONENT_NAME]u8),
    name_len: u8 = 0,
    description: [MAX_PROPERTY_DESC]u8 = std.mem.zeroes([MAX_PROPERTY_DESC]u8),
    description_len: u8 = 0,
    category: ComponentCategory = .basic,
    active: bool = false,

    // Property schema
    properties: [MAX_PROPERTIES]PropertyMeta = undefined,
    property_count: u8 = 0,

    // Flags
    supports_children: bool = true,
    max_children: u8 = 16,
    is_interactive: bool = false,
    is_form_element: bool = false,

    pub fn setName(self: *ComponentMeta, n: []const u8) void {
        const len = @min(n.len, MAX_COMPONENT_NAME);
        @memcpy(self.name[0..len], n[0..len]);
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const ComponentMeta) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setDescription(self: *ComponentMeta, d: []const u8) void {
        const len = @min(d.len, MAX_PROPERTY_DESC);
        @memcpy(self.description[0..len], d[0..len]);
        self.description_len = @intCast(len);
    }

    pub fn getDescription(self: *const ComponentMeta) []const u8 {
        return self.description[0..self.description_len];
    }

    pub fn addProperty(self: *ComponentMeta, prop: PropertyMeta) bool {
        if (self.property_count >= MAX_PROPERTIES) return false;
        self.properties[self.property_count] = prop;
        self.property_count += 1;
        return true;
    }

    pub fn getProperty(self: *const ComponentMeta, name: []const u8) ?*const PropertyMeta {
        for (self.properties[0..self.property_count]) |*prop| {
            if (std.mem.eql(u8, prop.getName(), name)) {
                return prop;
            }
        }
        return null;
    }
};

// ============================================================================
// Component Registry
// ============================================================================

pub const Registry = struct {
    components: [MAX_REGISTERED_COMPONENTS]ComponentMeta = undefined,
    count: u32 = 0,
    next_id: u32 = 1,
    initialized: bool = false,

    pub fn init() Registry {
        var reg = Registry{};
        reg.registerBuiltinComponents();
        reg.initialized = true;
        return reg;
    }

    /// Register built-in component types
    fn registerBuiltinComponents(self: *Registry) void {
        // Container
        _ = self.register(.{
            .component_type = .container,
            .category = .basic,
            .supports_children = true,
            .max_children = 16,
        }, "Container", "Generic container element (div-like)");

        // Text
        _ = self.register(.{
            .component_type = .text,
            .category = .basic,
            .supports_children = false,
        }, "Text", "Text content element");

        // Button
        _ = self.register(.{
            .component_type = .button,
            .category = .basic,
            .supports_children = false,
            .is_interactive = true,
        }, "Button", "Clickable button element");

        // Input
        _ = self.register(.{
            .component_type = .input,
            .category = .form,
            .supports_children = false,
            .is_interactive = true,
            .is_form_element = true,
        }, "Input", "Text input field");

        // Image
        _ = self.register(.{
            .component_type = .image,
            .category = .basic,
            .supports_children = false,
        }, "Image", "Image element");

        // Stack (VStack/HStack)
        _ = self.register(.{
            .component_type = .stack,
            .category = .layout,
            .supports_children = true,
            .max_children = 16,
        }, "Stack", "Vertical or horizontal stack layout");

        // Card
        _ = self.register(.{
            .component_type = .card,
            .category = .layout,
            .supports_children = true,
        }, "Card", "Card container with shadow");

        // Modal
        _ = self.register(.{
            .component_type = .modal,
            .category = .feedback,
            .supports_children = true,
            .is_interactive = true,
        }, "Modal", "Modal dialog overlay");

        // Progress
        _ = self.register(.{
            .component_type = .progress,
            .category = .feedback,
            .supports_children = false,
        }, "Progress", "Progress indicator");

        // Select
        _ = self.register(.{
            .component_type = .select,
            .category = .form,
            .supports_children = false,
            .is_interactive = true,
            .is_form_element = true,
        }, "Select", "Dropdown selector");

        // Checkbox
        _ = self.register(.{
            .component_type = .checkbox,
            .category = .form,
            .supports_children = false,
            .is_interactive = true,
            .is_form_element = true,
        }, "Checkbox", "Boolean toggle checkbox");

        // Alert
        _ = self.register(.{
            .component_type = .alert,
            .category = .feedback,
            .supports_children = false,
        }, "Alert", "Alert notification");
    }

    /// Register a component type
    pub fn register(
        self: *Registry,
        opts: struct {
            component_type: component.ComponentType,
            category: ComponentCategory = .basic,
            supports_children: bool = true,
            max_children: u8 = 16,
            is_interactive: bool = false,
            is_form_element: bool = false,
        },
        name: []const u8,
        description: []const u8,
    ) u32 {
        if (self.count >= MAX_REGISTERED_COMPONENTS) return 0;

        const id = self.next_id;
        self.next_id += 1;

        var meta = ComponentMeta{
            .id = id,
            .component_type = opts.component_type,
            .category = opts.category,
            .active = true,
            .supports_children = opts.supports_children,
            .max_children = opts.max_children,
            .is_interactive = opts.is_interactive,
            .is_form_element = opts.is_form_element,
        };
        meta.setName(name);
        meta.setDescription(description);

        self.components[self.count] = meta;
        self.count += 1;

        return id;
    }

    /// Get component metadata by type
    pub fn getByType(self: *const Registry, comp_type: component.ComponentType) ?*const ComponentMeta {
        for (self.components[0..self.count]) |*meta| {
            if (meta.active and meta.component_type == comp_type) {
                return meta;
            }
        }
        return null;
    }

    /// Get component metadata by ID
    pub fn getById(self: *const Registry, id: u32) ?*const ComponentMeta {
        for (self.components[0..self.count]) |*meta| {
            if (meta.active and meta.id == id) {
                return meta;
            }
        }
        return null;
    }

    /// Get component metadata by name
    pub fn getByName(self: *const Registry, name: []const u8) ?*const ComponentMeta {
        for (self.components[0..self.count]) |*meta| {
            if (meta.active and std.mem.eql(u8, meta.getName(), name)) {
                return meta;
            }
        }
        return null;
    }

    /// List all components in a category
    pub fn listByCategory(self: *const Registry, category: ComponentCategory, buffer: []u32) u32 {
        var count: u32 = 0;
        for (self.components[0..self.count]) |*meta| {
            if (meta.active and meta.category == category) {
                if (count < buffer.len) {
                    buffer[count] = meta.id;
                    count += 1;
                }
            }
        }
        return count;
    }

    /// Get total registered component count
    pub fn getCount(self: *const Registry) u32 {
        return self.count;
    }
};

// ============================================================================
// Global Registry
// ============================================================================

var global_registry: Registry = undefined;
var global_initialized: bool = false;

pub fn initGlobal() void {
    if (!global_initialized) {
        global_registry = Registry.init();
        global_initialized = true;
    }
}

pub fn getRegistry() *Registry {
    if (!global_initialized) initGlobal();
    return &global_registry;
}

pub fn resetGlobal() void {
    global_registry = Registry.init();
}

// ============================================================================
// C ABI Exports
// ============================================================================

/// ABI structure for component metadata
pub const ABIComponentMeta = extern struct {
    id: u32,
    component_type: u8,
    category: u8,
    name: [MAX_COMPONENT_NAME]u8,
    name_len: u8,
    description: [MAX_PROPERTY_DESC]u8,
    description_len: u8,
    supports_children: bool,
    max_children: u8,
    is_interactive: bool,
    is_form_element: bool,
    property_count: u8,
};

var abi_meta_cache: ABIComponentMeta = undefined;

/// Initialize the component registry
pub fn zylix_registry_init() callconv(.c) i32 {
    initGlobal();
    return 0;
}

/// Get component count
pub fn zylix_registry_count() callconv(.c) u32 {
    if (!global_initialized) return 0;
    return global_registry.count;
}

/// Get component metadata by type
pub fn zylix_registry_get_by_type(comp_type: u8) callconv(.c) ?*const ABIComponentMeta {
    if (!global_initialized) return null;

    const meta = global_registry.getByType(@enumFromInt(comp_type)) orelse return null;

    abi_meta_cache = .{
        .id = meta.id,
        .component_type = @intFromEnum(meta.component_type),
        .category = @intFromEnum(meta.category),
        .name = meta.name,
        .name_len = meta.name_len,
        .description = meta.description,
        .description_len = meta.description_len,
        .supports_children = meta.supports_children,
        .max_children = meta.max_children,
        .is_interactive = meta.is_interactive,
        .is_form_element = meta.is_form_element,
        .property_count = meta.property_count,
    };

    return &abi_meta_cache;
}

/// Get component metadata by ID
pub fn zylix_registry_get_by_id(id: u32) callconv(.c) ?*const ABIComponentMeta {
    if (!global_initialized) return null;

    const meta = global_registry.getById(id) orelse return null;

    abi_meta_cache = .{
        .id = meta.id,
        .component_type = @intFromEnum(meta.component_type),
        .category = @intFromEnum(meta.category),
        .name = meta.name,
        .name_len = meta.name_len,
        .description = meta.description,
        .description_len = meta.description_len,
        .supports_children = meta.supports_children,
        .max_children = meta.max_children,
        .is_interactive = meta.is_interactive,
        .is_form_element = meta.is_form_element,
        .property_count = meta.property_count,
    };

    return &abi_meta_cache;
}

/// List components by category
pub fn zylix_registry_list_by_category(
    category: u8,
    buffer: ?[*]u32,
    buffer_len: u32,
) callconv(.c) u32 {
    if (!global_initialized or buffer == null) return 0;

    return global_registry.listByCategory(
        @enumFromInt(category),
        buffer.?[0..@intCast(buffer_len)],
    );
}

// === Export symbols for C ABI ===
comptime {
    @export(&zylix_registry_init, .{ .name = "zylix_registry_init" });
    @export(&zylix_registry_count, .{ .name = "zylix_registry_count" });
    @export(&zylix_registry_get_by_type, .{ .name = "zylix_registry_get_by_type" });
    @export(&zylix_registry_get_by_id, .{ .name = "zylix_registry_get_by_id" });
    @export(&zylix_registry_list_by_category, .{ .name = "zylix_registry_list_by_category" });
}

// ============================================================================
// Tests
// ============================================================================

test "registry initialization" {
    resetGlobal();
    initGlobal();

    const reg = getRegistry();
    try std.testing.expect(reg.count > 0);
    try std.testing.expect(reg.initialized);
}

test "get component by type" {
    resetGlobal();
    initGlobal();

    const reg = getRegistry();

    const button_meta = reg.getByType(.button);
    try std.testing.expect(button_meta != null);
    try std.testing.expectEqualStrings("Button", button_meta.?.getName());
    try std.testing.expect(button_meta.?.is_interactive);
}

test "get component by name" {
    resetGlobal();
    initGlobal();

    const reg = getRegistry();

    const container_meta = reg.getByName("Container");
    try std.testing.expect(container_meta != null);
    try std.testing.expectEqual(component.ComponentType.container, container_meta.?.component_type);
}

test "list by category" {
    resetGlobal();
    initGlobal();

    const reg = getRegistry();

    var buffer: [32]u32 = undefined;
    const form_count = reg.listByCategory(.form, &buffer);
    try std.testing.expect(form_count > 0);
}

test "property metadata" {
    var prop = PropertyMeta{};
    prop.setName("text");
    prop.setDescription("Text content");
    prop.property_type = .string;
    prop.required = true;

    try std.testing.expectEqualStrings("text", prop.getName());
    try std.testing.expectEqualStrings("Text content", prop.getDescription());
    try std.testing.expect(prop.required);
}
