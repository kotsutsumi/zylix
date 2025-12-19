# ZigDom - Zig as Web Execution Layer

## Philosophy

> **JavaScript is I/O, Zig is Execution**

ZigDom positions Zig as the central execution layer for web applications:

- **DOM execution**: JavaScript handles (I/O layer)
- **Application logic**: Zig handles (Execution layer)
- **GPU data generation**: Zig handles (Compute layer)
- **WebGPU API calls**: JavaScript bridges (I/O layer)

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

## Why Not JavaScript?

| Aspect | JavaScript | WebWorker | Zig (WASM) |
|--------|-----------|-----------|------------|
| Parallelism | Cooperative | Isolated processes | Shared memory |
| Memory | GC managed | GC managed | Manual, predictable |
| GC Pauses | Yes | Yes | **None** |
| GPU Data | TypedArray (GC) | TypedArray | **Direct layout** |
| Type Safety | Runtime | Runtime | **Compile-time** |

## GPU Integration

### Memory Layout (GPU-Compatible)

```zig
// 16-byte aligned for GPU
pub const Vec3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    _pad: f32 = 0,  // Padding for alignment
};

// 32-byte vertex (matches WGSL layout)
pub const Vertex = extern struct {
    position: Vec3,  // 16 bytes
    color: Vec4,     // 16 bytes
};

// 256-byte uniform buffer (WebGPU requirement)
pub const Uniforms = extern struct {
    model: Mat4,      // 64 bytes
    view: Mat4,       // 64 bytes
    projection: Mat4, // 64 bytes
    _padding: [64]u8, // Pad to 256
};
```

### Data Flow

1. **Zig generates** transform matrices every frame
2. **Data sits in** WASM linear memory (already GPU-compatible)
3. **JavaScript reads** pointer + size from Zig exports
4. **JavaScript calls** `queue.writeBuffer(wasmMemory, ptr, size)`
5. **GPU renders** using Zig-generated data

### Performance Benefits

- **Zero copy**: Data layout matches GPU requirements
- **No GC pauses**: Predictable frame times
- **Batch operations**: Zig can prepare multiple frames ahead
- **SIMD potential**: Zig's vector types map to WASM SIMD

## Exported Functions

### Counter Demo (Basic WASM)
```zig
export fn zylix_init() i32
export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque, len: usize) i32
export fn zylix_wasm_get_counter() i64
```

### WebGPU Integration
```zig
export fn zigdom_gpu_init() void
export fn zigdom_gpu_update(delta_time: f32) void
export fn zigdom_gpu_set_aspect(aspect: f32) void
export fn zigdom_gpu_get_vertex_buffer() ?*const anyopaque
export fn zigdom_gpu_get_vertex_buffer_size() usize
export fn zigdom_gpu_get_uniform_buffer() ?*const anyopaque
export fn zigdom_gpu_get_uniform_buffer_size() usize
export fn zigdom_gpu_get_vertex_count() u32
```

### CSS Utility System
```zig
export fn zigdom_css_init() void
export fn zigdom_css_create_style() u32
export fn zigdom_css_set_display(id: u32, display: u8) void
export fn zigdom_css_set_bg_color(id: u32, r: u8, g: u8, b: u8, a: u8) void
export fn zigdom_css_generate(id: u32) ?[*]const u8
export fn zigdom_css_generate_len() usize
// ... and more style property setters
```

### Layout Engine
```zig
export fn zigdom_layout_init() void
export fn zigdom_layout_create_node() u32
export fn zigdom_layout_set_size(id: u32, w: f32, h: f32) void
export fn zigdom_layout_set_flex_direction(id: u32, dir: u8) void
export fn zigdom_layout_add_child(parent: u32, child: u32) void
export fn zigdom_layout_compute(w: f32, h: f32) void
export fn zigdom_layout_get_x(id: u32) f32
export fn zigdom_layout_get_y(id: u32) f32
export fn zigdom_layout_get_width(id: u32) f32
export fn zigdom_layout_get_height(id: u32) f32
```

## Use Cases

1. **3D Visualization**: Zig handles all matrix math, JavaScript renders
2. **Simulations**: Physics/particles computed in Zig, visualized via WebGPU
3. **Data Processing**: Heavy computation in Zig, results displayed in DOM
4. **Games**: Game logic in Zig, rendering via WebGPU

## Future Directions

### Near-term
1. **WASM Threads**: Parallel computation with SharedArrayBuffer
2. **WebGPU Compute**: ✅ Done - Compute shaders with Zig-generated data (50K particles @ 60fps)
3. **WGSL Generation**: Generate shaders from Zig struct definitions
4. **Hot Reload**: Swap WASM modules without page refresh

### Long-term: ZigDom Full-Stack Framework
5. **CSS Utilities**: ✅ Done - TailwindCSS v4-like utility system in Zig
   - Type-safe Style struct with builder pattern
   - Color system (TailwindCSS palette)
   - Spacing, typography, flexbox, shadows
   - CSS string generation from Zig
6. **Layout Engine**: ✅ Done - Flexbox layout computation in Zig
   - Tree-based LayoutNode structure
   - Flexbox algorithm (row/column, justify, align, gap)
   - LayoutResult with computed x, y, width, height
   - Up to 256 nodes, 16 children per node
7. **UI Component System**: shadcn/ui-like components
   - Zig-native reactive primitives (React-like but simpler)
   - Virtual DOM or incremental DOM in Zig
   - Component composition patterns
8. **Declarative UI DSL**: Zig comptime for UI declarations
   ```zig
   // Future vision
   const ui = zdom.div(.{ .class = "flex gap-4" }, .{
       zdom.button(.{ .variant = .primary }, "Click me"),
       zdom.input(.{ .type = .text, .placeholder = "Enter..." }),
   });
   ```

## Relationship to Zylix

ZigDom is the **web platform implementation** of Zylix's philosophy:

| Platform | UI Layer | Bridge | Core (Zig) |
|----------|----------|--------|------------|
| iOS | SwiftUI | C ABI | Zylix Core |
| Android | Compose | JNI | Zylix Core |
| macOS | SwiftUI | C ABI | Zylix Core |
| **Web** | **DOM/WebGPU** | **WASM exports** | **ZigDom** |

The same Zig code (state management, logic, math) runs on all platforms.
JavaScript is simply another "shell" like SwiftUI or Compose.
