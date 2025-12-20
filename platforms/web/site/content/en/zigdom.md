---
title: "ZigDom"
weight: 4
---

# ZigDom

**Zig as Web Execution Layer**

> **"JavaScript is I/O, Zig is Execution"**

ZigDom positions Zig as the central execution layer for web applications.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Zig Core (WASM)                    │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ State/Logic     │  │ GPU Module              │  │
│  │ - AppState      │  │ - Vec3, Mat4            │  │
│  │ - Event Queue   │  │ - Vertex buffers        │  │
│  │ - Diff Engine   │  │ - Transform matrices    │  │
│  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────┬───────────────────────────┘
                          │ export fn (pointers + sizes)
                          ▼
┌─────────────────────────────────────────────────────┐
│               WASM Linear Memory                    │
│  [GPU-aligned buffers ready for direct transfer]   │
└─────────────────────────┬───────────────────────────┘
                          │ writeBuffer(ptr, size)
                          ▼
┌─────────────────────────────────────────────────────┐
│            JavaScript Bridge Layer                  │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ DOM Operations  │  │ WebGPU API             │  │
│  │ - Event binding │  │ - device.createBuffer  │  │
│  │ - UI updates    │  │ - queue.writeBuffer    │  │
│  └─────────────────┘  │ - renderPass.draw      │  │
│                       └─────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Features

### Completed (Phase 5)

| Feature | Status | Description |
|---------|--------|-------------|
| CSS Utilities | ✅ | TailwindCSS-like system in Zig |
| Layout Engine | ✅ | Flexbox algorithm in Zig |
| Component System | ✅ | React-like components |
| Declarative UI DSL | ✅ | Zig comptime for UI declarations |
| WebGPU Compute | ✅ | 50K particles @ 60fps |

### Upcoming

| Feature | Status | Description |
|---------|--------|-------------|
| Virtual DOM | ✅ | Reconciliation & diffing in Zig |

## CSS Utility System

TailwindCSS-like utilities in Zig:

```zig
const style = css.Style.flex()
    .bg(css.colors.blue._500)
    .p(.p4)
    .rounded(.lg)
    .shadow(.md);

// Generates: display: flex; background-color: #3b82f6; padding: 1rem; ...
```

## Layout Engine

Flexbox computation in Zig:

```zig
const container = layout.createNode();
layout.setFlexDirection(container, .row);
layout.setJustifyContent(container, .space_between);
layout.setGap(container, 16);

// Add children
layout.addChild(container, child1);
layout.addChild(container, child2);

// Compute layout
layout.compute(800, 600);

// Results available in Zig memory
const x = layout.getX(child1);
const y = layout.getY(child1);
```

## Component System

React-like components in Zig:

```zig
const card = Component.container()
    .withStyle(cardStyle);

const title = Component.heading(.h2, "Welcome")
    .withStyle(titleStyle);

const button = Component.button("Click Me")
    .withStyle(btnStyle)
    .onClick(handleClick);

tree.addChild(card, title);
tree.addChild(card, button);
```

## Declarative UI DSL

JSX-like declarative syntax using Zig comptime:

```zig
const dsl = @import("dsl.zig");

// Simple element builders
const ui = dsl.div(.{ .class = "container" }, .{
    dsl.h1(.{}, "Welcome to ZigDom"),
    dsl.p(.{}, "Build UI with Zig's comptime!"),
    dsl.button(.{ .onClick = 1 }, "Click Me"),
});

// shadcn-like pre-built components
const card = dsl.ui.card(.{}, .{
    dsl.ui.cardHeader(.{}, .{
        dsl.ui.cardTitle(.{}, "Card Title"),
    }),
    dsl.ui.cardContent(.{}, .{
        dsl.p(.{}, "Card content goes here."),
    }),
    dsl.ui.cardFooter(.{}, .{
        dsl.ui.primaryButton(.{ .onClick = 2 }, "Submit"),
    }),
});
```

### Available Elements

| Category | Elements |
|----------|----------|
| Container | `div`, `span`, `section`, `article`, `header`, `footer`, `nav`, `main`, `aside` |
| Text | `h1`-`h6`, `p`, `text` |
| Interactive | `button`, `a`, `input` |
| List | `ul`, `ol`, `li` |
| Form | `form`, `label` |
| Media | `img` |

### Pre-built UI Components

| Component | Description |
|-----------|-------------|
| `ui.card` | Card container with header/content/footer |
| `ui.primaryButton` | Primary action button |
| `ui.secondaryButton` | Secondary action button |
| `ui.textInput` | Text input field |
| `ui.alert` | Alert/notification box |
| `ui.badge` | Badge/tag component |
| `ui.flex` | Flexbox container |
| `ui.grid` | Grid container |
| `ui.stack` | Vertical stack layout |

## Virtual DOM & Reconciliation

Efficient UI updates through diffing:

```zig
const vdom = @import("vdom.zig");

// Build new UI state
const div = vdom.createElement(.div);
const text = vdom.createText("Hello, World!");
vdom.addChild(div, text);
vdom.setRoot(div);

// Commit and get patches
const patch_count = vdom.commit();

// Apply patches (minimal DOM operations)
for (0..patch_count) |i| {
    const patch_type = vdom.getPatchType(i);
    switch (patch_type) {
        .create => // Create new DOM element
        .update_text => // Update text content
        .update_props => // Update properties
        .remove => // Remove element
    }
}
```

### Patch Types

| Type | Description |
|------|-------------|
| `create` | Create new DOM node |
| `remove` | Remove DOM node |
| `replace` | Replace with different element type |
| `update_props` | Update properties (class, style, events) |
| `update_text` | Update text content |
| `reorder` | Reorder children |
| `insert_child` | Insert child at index |
| `remove_child` | Remove child at index |

### Key-based Reconciliation

Use keys for efficient list updates:

```zig
const li = vdom.createElement(.li);
vdom.setKey(li, "item-123"); // Stable key for reconciliation
```

## WebGPU Integration

Zero-copy data transfer:

```javascript
// JavaScript just moves pointers
const vertexPtr = wasm.zigdom_gpu_get_vertex_buffer();
const vertexSize = wasm.zigdom_gpu_get_vertex_buffer_size();

device.queue.writeBuffer(
    gpuBuffer,
    0,
    wasmMemory.buffer,
    vertexPtr,
    vertexSize
);
```

## WASM Exports

### State & Events
```zig
export fn zylix_init() i32
export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque, len: usize) i32
```

### CSS
```zig
export fn zigdom_css_create_style() u32
export fn zigdom_css_set_display(id: u32, display: u8) void
export fn zigdom_css_generate(id: u32) ?[*]const u8
```

### Layout
```zig
export fn zigdom_layout_create_node() u32
export fn zigdom_layout_compute(width: f32, height: f32) void
export fn zigdom_layout_get_x(id: u32) f32
```

### Components
```zig
export fn zigdom_component_create_button(ptr: [*]const u8, len: usize) u32
export fn zigdom_component_on_click(id: u32, callback_id: u32) void
export fn zigdom_component_render(root_id: u32) void
```

### GPU
```zig
export fn zigdom_gpu_update(delta_time: f32) void
export fn zigdom_gpu_get_vertex_buffer() ?*const anyopaque
export fn zigdom_gpu_get_vertex_buffer_size() usize
```

### DSL
```zig
export fn zigdom_dsl_init() void
export fn zigdom_dsl_create_container(element_type: u8) u32
export fn zigdom_dsl_create_text_element(element_type: u8, ptr: [*]const u8, len: usize) u32
export fn zigdom_dsl_set_class(id: u32, ptr: [*]const u8, len: usize) void
export fn zigdom_dsl_add_child(parent_id: u32, child_id: u32) bool
export fn zigdom_dsl_build(element_id: u32) u32
```

### Virtual DOM
```zig
export fn zigdom_vdom_init() void
export fn zigdom_vdom_create_element(tag: u8) u32
export fn zigdom_vdom_create_text(ptr: [*]const u8, len: usize) u32
export fn zigdom_vdom_set_key(id: u32, ptr: [*]const u8, len: usize) void
export fn zigdom_vdom_add_child(parent_id: u32, child_id: u32) bool
export fn zigdom_vdom_commit() u32
export fn zigdom_vdom_get_patch_type(index: u32) u8
export fn zigdom_vdom_get_patch_text(index: u32) ?[*]const u8
```

## Real-World Example: Todo App

A complete TodoMVC-style application demonstrating all ZigDom features:

```zig
// Zig-side state management
const todo = @import("todo.zig");

// Add a todo
const id = todo.getState().add("Learn Zig");

// Toggle completion
_ = todo.getState().toggle(id);

// Render to VDOM
todo.renderTodoApp(todo.getState());

// Commit and get patches
const patches = vdom.commit();
```

**Features Demonstrated**:
- State management in Zig
- VDOM rendering and diffing
- Event handling (toggle, remove, filter)
- Key-based list reconciliation
- Real-time statistics

## Live Demos

- [**Todo App**](/demos/todo-app.html) - Full TodoMVC implementation
- [Counter Demo](/demos/counter.html)
- [CSS Demo](/demos/css-demo.html)
- [Layout Demo](/demos/layout-demo.html)
- [Component Demo](/demos/component-demo.html)
- [DSL Demo](/demos/dsl-demo.html)
- [VDOM Demo](/demos/vdom-demo.html)
- [WebGPU Cube](/demos/webgpu.html)
- [Particles](/demos/particles.html)
