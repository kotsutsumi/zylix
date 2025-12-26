# Performance Optimizations

This module contains performance optimizations for the Zylix core runtime.

## Modules

### simd.zig - SIMD Optimizations

SIMD-accelerated functions for Virtual DOM operations using Zig's native `@Vector` types.

#### Key Functions

| Function | Purpose | Speedup |
|----------|---------|---------|
| `simdHashKey` | DJB2 hash with 4-byte parallel processing | ~1.1x |
| `simdFindDiffPos` | Find first differing position in strings | **3x** |
| `simdMemEql` | Memory equality (delegates to std.mem.eql) | Optimized by Zig |
| `simdFnv1a` | FNV-1a hash with 8-byte chunks | ~1.2x |

#### Usage in VDOM

```zig
const simd = @import("perf/simd.zig");

// Key hashing for reconciliation
const hash = simd.simdHashKey("item-123");

// Fast text diff detection
const diff_pos = simd.simdFindDiffPos(old_text, new_text);

// Memory comparison
if (simd.simdMemEql(key_a, key_b)) {
    // Keys match
}
```

#### Implementation Notes

1. **simdHashKey**: Processes 4 bytes per iteration using pre-computed multipliers (33^4, 33^3, 33^2, 33). Mathematically equivalent to scalar DJB2.

2. **simdFindDiffPos**: Uses 16-byte vector XOR with `@reduce(.Or, ...)` for fast difference detection. Early exit on first mismatch.

3. **simdMemEql**: Delegates to `std.mem.eql` which is already SIMD-optimized by the Zig compiler.

### benchmark.zig - Benchmark Suite

Measures SIMD vs scalar performance for various operations.

#### Running Benchmarks

```bash
cd core
zig run src/perf/benchmark.zig
```

#### Sample Output

```
========================================
       SIMD Benchmark Results
       (100000 iterations each)
========================================

  MemEql (1KB):         1.16x speedup
  FindDiffPos (87B):    3.01x speedup
  HashKey (4 keys):     ~1.0x (equivalent)

  Average: 1.25x speedup
========================================
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                    vdom.zig                      │
│  ┌─────────────┐  ┌─────────────┐               │
│  │   Differ    │  │ VNodeProps  │               │
│  │  hashKey()  │  │  equals()   │               │
│  └──────┬──────┘  └──────┬──────┘               │
│         │                │                       │
│         ▼                ▼                       │
│  ┌─────────────────────────────────────────┐    │
│  │              perf/simd.zig              │    │
│  │  ┌───────────┐  ┌────────────────────┐  │    │
│  │  │simdHashKey│  │   simdMemEql       │  │    │
│  │  │(4B/iter)  │  │ (std.mem.eql)      │  │    │
│  │  └───────────┘  └────────────────────┘  │    │
│  │  ┌───────────────────────────────────┐  │    │
│  │  │       simdFindDiffPos             │  │    │
│  │  │    (16B vectors, 3x speedup)      │  │    │
│  │  └───────────────────────────────────┘  │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Platform Support

| Platform | SIMD Support | Notes |
|----------|-------------|-------|
| macOS (ARM64) | Native NEON | Full optimization |
| macOS (x86_64) | SSE/AVX | Full optimization |
| iOS | Native NEON | Full optimization |
| Android (ARM64) | Native NEON | Full optimization |
| Android (x86) | SSE | Full optimization |
| WASM | Portable | Zig compiler optimizes |
| Linux | SSE/AVX/NEON | Full optimization |

Zig's `@Vector` types are portable and the compiler selects the best SIMD instructions for each target automatically.

### pool.zig - Memory Pool

O(1) allocation for fixed-size objects, reducing allocation overhead.

#### Components

| Type | Purpose | Use Case |
|------|---------|----------|
| `ObjectPool(T, N)` | Fixed-size object pool | VNode allocation |
| `ArenaPool(N)` | Bump allocator | Temporary allocations |
| `SlabAllocator` | Multi-size slab allocator | Mixed object sizes |

#### Usage

```zig
const pool = @import("perf/pool.zig");

// Object pool for VNodes
var vnode_pool = pool.ObjectPool(VNode, 256).init();

const node = vnode_pool.alloc() orelse return error.OutOfMemory;
defer vnode_pool.free(node);

// Arena for temporary strings
var arena = pool.ArenaPool(4096).init();
const temp = arena.alloc(128) orelse return error.OutOfMemory;
// ... use temp ...
arena.reset(); // Free all at once
```

### cache.zig - LRU Cache

Caches diff results to avoid recomputing identical comparisons.

#### Components

| Type | Purpose | Lookup |
|------|---------|--------|
| `LRUCache(K, V, N)` | Generic LRU cache | O(n) |
| `HashCache(V, N)` | Hash-based cache | O(1) |
| `DiffCache` | Specialized diff cache | O(1) |

#### Usage

```zig
const cache = @import("perf/cache.zig");

// Diff result cache
var diff_cache = cache.DiffCache.init();

// Check cache before diffing
if (diff_cache.lookup(old_hash, new_hash)) |cached| {
    if (cached.equal) return; // No diff needed
}

// Store result after diffing
diff_cache.store(old_hash, new_hash, equal, patch_count);

// Get statistics
const stats = diff_cache.getStats();
std.debug.print("Hit rate: {d:.1}%\n", .{stats.hit_rate * 100});
```

## Future Optimizations

- [ ] Batch patch application
- [ ] Incremental tree updates
- [ ] Component-level memoization
