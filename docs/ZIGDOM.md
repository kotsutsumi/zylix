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
5. **CSS Utilities**: TailwindCSS v4-like utility system in Zig
   - Compile-time CSS generation
   - Type-safe class names
   - Tree-shaking for minimal output
6. **UI Component System**: shadcn/ui-like components
   - Zig-native reactive primitives (React-like but simpler)
   - Virtual DOM or incremental DOM in Zig
   - Component composition patterns
7. **Declarative UI DSL**: Zig comptime for UI declarations
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
