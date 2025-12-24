---
title: Components
weight: 3
---

Components are Zylix's reusable UI building blocks. They encapsulate structure, styling, and behavior into composable units that can be rendered to any platform.

## Terms

- **Component**: A declarative UI element (button, text, container).
- **Props**: Data that configures the component.
- **State**: Interactive flags (hover, focus, checked).

## Concept

Components are data. The renderer decides how to map them to native UI on each platform.

## Implementation

### Component Types

Zylix provides built-in component types for common UI elements:

```zig
pub const ComponentType = enum(u8) {
    container = 0,   // div-like container
    text = 1,        // text/span element
    button = 2,      // clickable button
    input = 3,       // text input field
    image = 4,       // image element
    link = 5,        // anchor link
    list = 6,        // ul/ol list
    list_item = 7,   // li item
    heading = 8,     // h1-h6
    paragraph = 9,   // p element
    custom = 255,    // custom component
};
```

### Component State

Each component tracks its interactive state:

```zig
pub const ComponentState = packed struct {
    hover: bool = false,      // Mouse is over component
    focus: bool = false,      // Component has focus
    active: bool = false,     // Pressed/clicked
    disabled: bool = false,   // Not interactive
    checked: bool = false,    // For checkbox/radio
    expanded: bool = false,   // For expandable components
    loading: bool = false,    // Loading indicator
    error_state: bool = false, // Error indicator
};
```

### Component Properties

### Common Properties

```zig
pub const ComponentProps = extern struct {
    // Identity
    id: u32 = 0,                    // Unique component ID

    // Class name for styling
    class_name: TextBuffer = std.mem.zeroes(TextBuffer),
    class_name_len: u16 = 0,

    // Text content
    text: TextBuffer = std.mem.zeroes(TextBuffer),
    text_len: u16 = 0,

    // Style references
    style_id: u32 = 0,              // Default style
    hover_style_id: u32 = 0,        // On hover
    focus_style_id: u32 = 0,        // On focus
    active_style_id: u32 = 0,       // On active
    disabled_style_id: u32 = 0,     // When disabled

    // Layout reference
    layout_id: u32 = 0,
};
```

### Input Properties

```zig
pub const ComponentProps = extern struct {
    // ... common props ...

    // Input-specific
    input_type: InputType = .text,
    placeholder: TextBuffer = std.mem.zeroes(TextBuffer),
    placeholder_len: u16 = 0,
    value: TextBuffer = std.mem.zeroes(TextBuffer),
    value_len: u16 = 0,
    max_length: u16 = 0,
};

pub const InputType = enum(u8) {
    text = 0,
    password = 1,
    email = 2,
    number = 3,
    search = 4,
    tel = 5,
    url = 6,
    checkbox = 7,
    radio = 8,
};
```

### Link Properties

```zig
pub const ComponentProps = extern struct {
    // ... common props ...

    // Link-specific
    href: TextBuffer = std.mem.zeroes(TextBuffer),
    href_len: u16 = 0,
    target_blank: bool = false,
};
```

### Image Properties

```zig
pub const ComponentProps = extern struct {
    // ... common props ...

    // Image-specific
    src: TextBuffer = std.mem.zeroes(TextBuffer),
    src_len: u16 = 0,
    alt: TextBuffer = std.mem.zeroes(TextBuffer),
    alt_len: u16 = 0,
};
```

### Heading Properties

```zig
pub const ComponentProps = extern struct {
    // ... common props ...

    // Heading-specific
    heading_level: HeadingLevel = .h1,
};

pub const HeadingLevel = enum(u8) {
    h1 = 1, h2 = 2, h3 = 3,
    h4 = 4, h5 = 5, h6 = 6,
};
```

## Event Handlers

Components can have multiple event handlers:

```zig
pub const EventHandler = struct {
    event_type: EventType = .none,
    callback_id: u32 = 0,           // ID for callback lookup
    prevent_default: bool = false,
    stop_propagation: bool = false,
};

pub const MAX_EVENT_HANDLERS = 8;
```

### Event Types

```zig
pub const EventType = enum(u8) {
    none = 0,
    click = 1,
    double_click = 2,
    mouse_enter = 3,
    mouse_leave = 4,
    mouse_down = 5,
    mouse_up = 6,
    focus = 7,
    blur = 8,
    input = 9,
    change = 10,
    submit = 11,
    key_down = 12,
    key_up = 13,
    key_press = 14,
};
```

## Component Tree

Components form a hierarchical tree structure:

```zig
pub const Component = struct {
    id: u32 = 0,
    component_type: ComponentType = .container,
    props: ComponentProps = .{},
    state: ComponentState = .{},
    handlers: [MAX_EVENT_HANDLERS]EventHandler = undefined,
    handler_count: u8 = 0,

    // Tree structure
    parent_id: u32 = 0,
    children: [MAX_CHILDREN]u32 = undefined,
    child_count: u16 = 0,
};
```

## Creating Components

### Container

```zig
fn createContainer(tree: *VTree, class: []const u8) u32 {
    var node = VNode.element(.div);
    node.props.setClass(class);
    return tree.create(node);
}

// Usage
const container = createContainer(tree, "main-container");
```

### Button

```zig
fn createButton(
    tree: *VTree,
    text: []const u8,
    onclick_id: u32
) u32 {
    var node = VNode.element(.button);
    node.setText(text);
    node.props.on_click = onclick_id;
    node.props.setClass("btn");
    return tree.create(node);
}

// Usage
const button = createButton(tree, "Click Me", CALLBACK_INCREMENT);
```

### Input Field

```zig
fn createInput(
    tree: *VTree,
    placeholder: []const u8,
    oninput_id: u32
) u32 {
    var node = VNode.element(.input);
    node.props.setPlaceholder(placeholder);
    node.props.on_input = oninput_id;
    node.props.setClass("text-input");
    return tree.create(node);
}

// Usage
const input = createInput(tree, "Enter task...", CALLBACK_TEXT_INPUT);
```

### List

```zig
fn createList(tree: *VTree, items: []const Item) u32 {
    const list_id = tree.create(VNode.element(.ul));

    for (items) |item| {
        const item_id = createListItem(tree, item);
        _ = tree.addChild(list_id, item_id);
    }

    return list_id;
}

fn createListItem(tree: *VTree, item: Item) u32 {
    var node = VNode.element(.li);

    // Set key for efficient updates
    var key_buf: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&key_buf, "item-{d}", .{item.id}) catch "item";
    node.setKey(key);

    // Add text
    const text_id = tree.create(VNode.textNode(item.text));
    const item_id = tree.create(node);
    _ = tree.addChild(item_id, text_id);

    return item_id;
}
```

## Component Patterns

### Compound Components

Build complex components from simpler ones:

```zig
fn createTodoItem(tree: *VTree, todo: Todo) u32 {
    // Container
    var container = VNode.element(.li);
    container.setKey(todo.id_str);
    if (todo.completed) {
        container.props.setClass("todo-item completed");
    } else {
        container.props.setClass("todo-item");
    }
    const container_id = tree.create(container);

    // Checkbox
    var checkbox = VNode.element(.input);
    checkbox.props.input_type = @intFromEnum(InputType.checkbox);
    checkbox.props.on_change = CALLBACK_TOGGLE;
    const checkbox_id = tree.create(checkbox);

    // Text
    const text_id = tree.create(VNode.textNode(todo.text));

    // Delete button
    var delete_btn = VNode.element(.button);
    delete_btn.setText("×");
    delete_btn.props.on_click = CALLBACK_DELETE;
    delete_btn.props.setClass("delete-btn");
    const delete_id = tree.create(delete_btn);

    // Assemble
    _ = tree.addChild(container_id, checkbox_id);
    _ = tree.addChild(container_id, text_id);
    _ = tree.addChild(container_id, delete_id);

    return container_id;
}
```

### Conditional Rendering

```zig
fn createLoadingOrContent(tree: *VTree, loading: bool, content: []const u8) u32 {
    if (loading) {
        var spinner = VNode.element(.div);
        spinner.props.setClass("spinner");
        spinner.setText("Loading...");
        return tree.create(spinner);
    } else {
        return tree.create(VNode.textNode(content));
    }
}
```

### List Rendering

```zig
fn renderTodoList(tree: *VTree, todos: []const Todo, filter: Filter) u32 {
    const list_id = tree.create(VNode.element(.ul));

    for (todos) |todo| {
        // Apply filter
        const show = switch (filter) {
            .all => true,
            .active => !todo.completed,
            .completed => todo.completed,
        };

        if (show) {
            const item_id = createTodoItem(tree, todo);
            _ = tree.addChild(list_id, item_id);
        }
    }

    return list_id;
}
```

## Render Commands

Components generate render commands for platform execution:

```zig
pub const RenderCommandType = enum(u8) {
    none = 0,
    create_element = 1,
    create_text = 2,
    update_text = 3,
    set_attribute = 4,
    remove_attribute = 5,
    add_class = 6,
    remove_class = 7,
    set_style = 8,
    append_child = 9,
    insert_before = 10,
    remove_child = 11,
    add_event_listener = 12,
    remove_event_listener = 13,
    set_property = 14,
};
```

## Platform Rendering

Each platform interprets components differently:

### Web (JavaScript)

```javascript
function applyCommand(cmd) {
    switch (cmd.type) {
        case 'create_element':
            return document.createElement(cmd.tag);
        case 'create_text':
            return document.createTextNode(cmd.text);
        case 'set_attribute':
            element.setAttribute(cmd.name, cmd.value);
            break;
        case 'add_event_listener':
            element.addEventListener(cmd.event, callback);
            break;
    }
}
```

### iOS (SwiftUI)

```swift
struct ZylixComponent: View {
    let component: ComponentData

    var body: some View {
        switch component.type {
        case .container:
            VStack { renderChildren() }
        case .button:
            Button(component.text) { handleClick() }
        case .input:
            TextField(component.placeholder, text: $text)
        case .text:
            Text(component.text)
        }
    }
}
```

### Android (Compose)

```kotlin
@Composable
fun ZylixComponent(component: ComponentData) {
    when (component.type) {
        ComponentType.Container -> Column { renderChildren() }
        ComponentType.Button -> Button(onClick = { handleClick() }) {
            Text(component.text)
        }
        ComponentType.Input -> TextField(
            value = text,
            onValueChange = { handleInput(it) }
        )
        ComponentType.Text -> Text(component.text)
    }
}
```

## Best Practices

### 1. Keep Components Focused

```zig
// Good: Single responsibility
fn createHeader(tree: *VTree, title: []const u8) u32 { ... }
fn createNavigation(tree: *VTree, items: []NavItem) u32 { ... }
fn createFooter(tree: *VTree, year: u32) u32 { ... }

// Avoid: Monolithic component
fn createEntirePage(tree: *VTree, everything: Everything) u32 { ... }
```

### 2. Use Meaningful Keys

```zig
// Good: Stable, unique keys
node.setKey(item.uuid);

// Avoid: Index-based keys
node.setKey(std.fmt.bufPrint(&buf, "{d}", .{index}));
```

### 3. Extract Reusable Patterns

```zig
// Good: Reusable button factory
fn createIconButton(
    tree: *VTree,
    icon: []const u8,
    label: []const u8,
    callback: u32
) u32 {
    var btn = VNode.element(.button);
    btn.props.setClass("icon-btn");
    btn.props.on_click = callback;
    // ... icon and label setup
    return tree.create(btn);
}
```

## Pitfalls

- Forgetting stable IDs can cause diff mismatches.
- Overusing custom components reduces platform-native fidelity.
- Large text buffers without length updates lead to truncated text.

## Implementation Links

- [core/src/component.zig](https://github.com/kotsutsumi/zylix/blob/main/core/src/component.zig)
- [core/src/vdom.zig](https://github.com/kotsutsumi/zylix/blob/main/core/src/vdom.zig)

## Samples

- [samples/component-showcase](https://github.com/kotsutsumi/zylix/tree/main/samples/component-showcase)

## Next Steps

- [Events](../events) - Handle component interactions
- [State Management](../state-management) - Connect components to state
- [Virtual DOM](../virtual-dom) - Understand rendering internals
