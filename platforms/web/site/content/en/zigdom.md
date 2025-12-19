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
| WebGPU Compute | ✅ | 50K particles @ 60fps |

### Upcoming

| Feature | Status | Description |
|---------|--------|-------------|
| Declarative UI DSL | Pending | Zig comptime for UI |
| Virtual DOM | Pending | Reconciliation in Zig |

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

## Live Demos

- [Counter Demo](/demos/counter.html)
- [CSS Demo](/demos/css-demo.html)
- [Layout Demo](/demos/layout-demo.html)
- [Component Demo](/demos/component-demo.html)
- [WebGPU Cube](/demos/webgpu.html)
- [Particles](/demos/particles.html)
