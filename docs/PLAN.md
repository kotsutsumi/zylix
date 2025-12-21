# Zylix Project Plan

## 1. Philosophy Statement

> **「UIを共通化せず、意味と判断だけを共通化する」**
>
> Zylixは、Zigを中核とした「UI非依存・OS尊重型」クロスプラットフォーム実行基盤である。
> 各OSの標準UIを尊重しながら、アプリケーションの状態・ロジック・意味をZigに集約する。

---

## 2. Architecture Overview

```
                    ┌─────────────────────────────┐
                    │     Zylix Core (Zig)        │
                    │  ┌───────────────────────┐  │
                    │  │ State Management      │  │
                    │  │ Business Logic        │  │
                    │  │ ViewModel Generation  │  │
                    │  │ Diff Calculation      │  │
                    │  │ Event Handling        │  │
                    │  └───────────────────────┘  │
                    └─────────────┬───────────────┘
                                  │
                              C ABI
                                  │
        ┌─────────┬─────────┬─────────┼─────────┬─────────┬─────────┐
        ▼         ▼         ▼         ▼         ▼         ▼         ▼
   ┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │   iOS   │ │Android │ │ macOS  │ │Windows │ │ Linux  │ │  Web   │
   │ SwiftUI │ │Compose │ │SwiftUI │ │ WinUI  │ │  GTK4  │ │  WASM  │
   └─────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

---

## 3. PoC Scope (Phase 1)

### 3.1 Target Platforms
| Platform | UI Framework | Priority |
|----------|--------------|----------|
| iOS      | SwiftUI      | P0       |
| Android  | Jetpack Compose | P0    |
| macOS    | SwiftUI      | P1       |

### 3.2 Minimal Feature Set
- Counter application (increment/decrement)
- State synchronization between Zig and UI
- Event dispatching from UI to Zig Core
- State retrieval from Zig Core to UI

---

## 4. Directory Structure

```
zylix/
├── docs/
│   ├── PLAN.md                 # This file
│   ├── ARCHITECTURE.md         # Detailed architecture
│   └── ABI.md                  # C ABI specification
├── core/                       # Zylix Core (Zig)
│   ├── build.zig
│   ├── src/
│   │   ├── main.zig
│   │   ├── state.zig           # State management
│   │   ├── events.zig          # Event handling
│   │   ├── abi.zig             # C ABI exports
│   │   ├── scheduler.zig       # Time/timer management
│   │   ├── llm.zig             # LLM integration hooks
│   │   ├── gpu.zig             # GPU/WebGPU support
│   │   ├── particles.zig       # Particle system
│   │   └── wasm.zig            # WASM entry point
│   └── tests/
├── platforms/
│   ├── ios/                    # iOS (SwiftUI)
│   │   ├── Zylix/
│   │   └── ZylixCore.xcframework
│   ├── android/                # Android (Compose)
│   │   ├── app/
│   │   └── zylix-core/
│   ├── macos/                  # macOS (SwiftUI)
│   │   └── Zylix/
│   ├── windows/                # Windows (WinUI 3)
│   │   └── Zylix/
│   ├── linux/                  # Linux (GTK4)
│   │   └── zylix-gtk/
│   └── web/                    # Web (WASM + WebGPU)
└── examples/
    └── counter/                # PoC Counter app
```

---

## 5. Implementation Phases

### Phase 1: Foundation (PoC)
| Task | Description | Status |
|------|-------------|--------|
| 1.1  | Zig project setup (build.zig) | ✅ Done |
| 1.2  | Core state structure definition | ✅ Done |
| 1.3  | C ABI layer implementation | ✅ Done |
| 1.4  | iOS SwiftUI shell | ✅ Done |
| 1.5  | Android Compose shell | ✅ Done |
| 1.6  | Counter app integration test | ✅ Done |

### Phase 2: Core Enhancement
| Task | Description | Status |
|------|-------------|--------|
| 2.1  | Generic state container | ✅ Done |
| 2.2  | Diff calculation engine | ✅ Done |
| 2.3  | Event queue system | ✅ Done |
| 2.4  | Memory management patterns | ✅ Done |

### Phase 3: Platform Expansion
| Task | Description | Status |
|------|-------------|--------|
| 3.1  | Windows (WinUI) support | ✅ Done |
| 3.2  | Linux (GTK) support | ✅ Done |
| 3.3  | Web (WASM) support | ✅ Done |

### Phase 4: Advanced Features
| Task | Description | Status |
|------|-------------|--------|
| 4.1  | Scheduler / Time management | ✅ Done |
| 4.2  | AI / LLM integration hooks | ✅ Done |
| 4.3  | NeuronGraph support | 🔗 External (neuron-graph repo) |

### Phase 5: ZigDom Full-Stack (Web)
| Task | Description | Status |
|------|-------------|--------|
| 5.1  | CSS utility system (TailwindCSS-like) | ✅ Done |
| 5.2  | Layout engine (Flexbox/Grid) | ✅ Done |
| 5.3  | UI component system | ✅ Done |
| 5.4  | Declarative UI DSL (comptime) | Pending |
| 5.5  | Virtual DOM / Reconciliation | Pending |

---

## 6. C ABI Design Principles

```zig
// All exports must be extern "C"
// Use only POD types or pointers
// Memory ownership must be explicit

// Example: State retrieval
pub export fn zylix_get_state() *const ZylixState;

// Example: Event dispatch
pub export fn zylix_dispatch_event(event_type: u32, payload: ?*const anyopaque) void;

// Example: Initialize/Deinit
pub export fn zylix_init() void;
pub export fn zylix_deinit() void;
```

### Memory Ownership Rules
1. Zig allocates → Zig frees
2. Host allocates → Host frees
3. Transfer ownership → Explicit handoff functions
4. Shared read → Immutable pointer, Zig lifetime

---

## 7. Differentiation from Existing Solutions

| Aspect | Flutter | Electron | Tauri | Zylix |
|--------|---------|----------|-------|-------|
| UI Rendering | Skia (custom) | Chromium | WebView | **OS Native** |
| Runtime | Dart VM | Node.js | Rust + WebView | **None** |
| Binary Size | ~15MB+ | ~150MB+ | ~3MB+ | **<1MB** |
| Memory | High | Very High | Medium | **Low** |
| OS Integration | Limited | Limited | Medium | **Full** |
| IME/A11y | Custom | Chromium | WebView | **Native** |

### Why Zig?
1. **No hidden runtime** - Predictable execution
2. **C ABI native** - Zero-cost FFI
3. **Cross-compilation** - Single toolchain for all targets
4. **Manual memory control** - No GC pauses
5. **Readable** - C-like simplicity with modern features

---

## 8. Success Criteria for PoC

- [x] Zig core compiles to static library for iOS/Android/macOS
- [x] Swift can call Zig functions via C ABI
- [x] Kotlin can call Zig functions via JNI/C ABI
- [x] Counter state is managed entirely in Zig
- [x] UI updates reflect Zig state changes
- [x] No crashes, no memory leaks
- [x] Binary size < 500KB (core only) - ~8.5KB with ReleaseSmall (Phase 2)
- [x] WASM builds and runs in browser (Phase 3) - ~544KB debug, ~398B ReleaseSmall
- [x] WebGPU integration via ZigDom (Phase 3) - 63fps rotating cube demo
- [x] WebGPU Compute particles (Phase 3) - 50K particles @ 60fps
- [x] Windows (WinUI 3) support (Phase 3) - C# shell with P/Invoke
- [x] Linux (GTK4) support (Phase 3) - C shell with direct ABI linking
- [x] Scheduler / Time management (Phase 4) - Event-based timers, time scale, pause/resume
- [x] AI / LLM integration hooks (Phase 4) - Provider-agnostic, streaming, tools, token estimation
- [x] CSS utility system (Phase 5) - TailwindCSS-like, type-safe, CSS generation from Zig
- [x] Layout engine (Phase 5) - Flexbox algorithm in Zig, tree-based layout computation
- [x] UI component system (Phase 5) - React-like components, event handling, render commands

---

## 9. Constraints (Non-Goals)

1. **NO** Zig-to-Swift/Kotlin transpilation
2. **NO** UI rendering in Zig
3. **NO** Flutter/Widget compatibility layer
4. **NO** VM or runtime daemon
5. **NO** Unnecessary abstractions

---

## 10. Next Steps

1. Setup Zig build system with cross-compilation targets
2. Define minimal State and Event types
3. Implement C ABI exports
4. Create iOS Xcode project with SwiftUI
5. Create Android project with Jetpack Compose
6. Build and test Counter PoC

---

## Related Projects

| Project | Relationship | Description |
|---------|--------------|-------------|
| [NeuronGraph](https://github.com/kotsutsumi/neuron-graph) | External (Brain) | WebGPU-based SNN library implementing "Information Organism" |

**Zylix + NeuronGraph Architecture**:
- **Zylix** = Body (状態管理、プラットフォームシェル、イベントシステム)
- **NeuronGraph** = Brain (SNN物理、臓器システム、7D意識ベクトル)
- Integration via C ABI / WASM when needed

---

## Future Roadmap

For v0.2.0 and beyond, see **[ROADMAP.md](./ROADMAP.md)** for detailed planning:

| Version | Focus |
|---------|-------|
| v0.2.0 | Component Library Expansion (30+ components) |
| v0.3.0 | Routing System |
| v0.4.0 | Async Processing Support |
| v0.5.0 | Hot Reload (Development) |
| v0.6.0 | Practical Sample Applications |

---

## References

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Cross-compilation](https://ziglang.org/learn/build-system/)
- [Swift C Interop](https://developer.apple.com/documentation/swift/c-interoperability)
- [Kotlin JNI](https://kotlinlang.org/docs/native-c-interop.html)
