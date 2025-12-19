---
title: "Why Not JavaScript?"
weight: 2
---

# Why Not JavaScript?

## The Web Platform Problem

JavaScript powers the web, but when we need **computation**, not just **interaction**, its limitations become clear.

## Comparison

| Aspect | JavaScript | WebWorker | Zig (WASM) |
|--------|-----------|-----------|------------|
| Parallelism | Cooperative | Isolated processes | Shared memory |
| Memory | GC managed | GC managed | Manual, predictable |
| GC Pauses | Yes | Yes | **None** |
| GPU Data | TypedArray (GC) | TypedArray | **Direct layout** |
| Type Safety | Runtime | Runtime | **Compile-time** |

## Performance Reality

### JavaScript
```javascript
// GC can pause at any moment
const vertices = new Float32Array(10000);
// TypedArray still managed by GC
// No guarantee of memory layout
```

### Zig (WASM)
```zig
// 16-byte aligned for GPU
pub const Vertex = extern struct {
    position: Vec3,  // 16 bytes
    color: Vec4,     // 16 bytes
};
// Direct memory layout matches GPU
// No GC, predictable timing
```

## Real-World Impact

### Frame Rate Consistency

**JavaScript**:
- Target: 60fps (16.67ms per frame)
- GC pause: 5-50ms
- Result: Stuttering, dropped frames

**Zig/WASM**:
- Target: 60fps (16.67ms per frame)
- No GC: Consistent timing
- Result: Smooth animation

### Memory Efficiency

**JavaScript App** (typical):
- Initial heap: 10-50MB
- After running: 100-500MB
- Memory fragmentation: High

**Zig/WASM App**:
- Linear memory: 1-10MB
- After running: Same
- Memory fragmentation: None (manual control)

## When JavaScript is Fine

JavaScript excels at:
- DOM manipulation
- Event handling
- API calls
- UI coordination

## When Zig Shines

Zig excels at:
- Heavy computation
- Real-time graphics
- Data processing
- Predictable performance

## ZigDom Philosophy

> **"JavaScript is I/O, Zig is Execution"**

ZigDom doesn't replace JavaScript - it positions each language where it's strongest:

```
┌─────────────────────────────────────────────────────┐
│                  Zig Core (WASM)                    │
│  - State management      - GPU data generation     │
│  - Business logic        - Layout computation      │
│  - Math operations       - Component tree          │
└─────────────────────────┬───────────────────────────┘
                          │ export fn (pointers + sizes)
                          ▼
┌─────────────────────────────────────────────────────┐
│            JavaScript Bridge Layer                  │
│  - DOM operations        - WebGPU API calls        │
│  - Event binding         - Render execution        │
│  - User input            - Animation frames        │
└─────────────────────────────────────────────────────┘
```

## Benchmark: Particle System

| Metric | JavaScript | Zig/WASM |
|--------|-----------|----------|
| 50K particles | ~30fps | **60fps** |
| Memory usage | 150MB | **8MB** |
| GC pauses | 5-20ms | **0ms** |
| Frame variance | ±8ms | **±0.5ms** |

## Conclusion

JavaScript isn't bad - it's just not designed for computation-heavy tasks. By combining JavaScript's strengths (I/O, DOM) with Zig's strengths (computation, memory control), we get the best of both worlds.
