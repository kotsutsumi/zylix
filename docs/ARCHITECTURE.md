# Zylix Architecture

## Core Design Philosophy

Zylixは「中央脳（Central Brain）」アーキテクチャを採用する。

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ iOS Shell   │  │Android Shell│  │   Desktop Shell     │  │
│  │ (SwiftUI)   │  │ (Compose)   │  │ (SwiftUI/WinUI/GTK) │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          │                                   │
│                      C ABI Boundary                          │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────────────┐  │
│  │                  Zylix Core (Zig)                      │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │                 State Container                  │  │  │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │  │  │
│  │  │  │App State  │ │ UI State  │ │ Derived State │  │  │  │
│  │  │  └───────────┘ └───────────┘ └───────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Business Logic                      │  │  │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │  │  │
│  │  │  │ Reducers  │ │Validators │ │ Transformers  │  │  │  │
│  │  │  └───────────┘ └───────────┘ └───────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Event System                        │  │  │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │  │  │
│  │  │  │  Queue    │ │ Dispatch  │ │  Handlers     │  │  │  │
│  │  │  └───────────┘ └───────────┘ └───────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

### 1. Zylix Core (Zig) - The Brain

**責務:**
- アプリケーション状態の完全な所有
- ビジネスロジックの実行
- イベントの受信と処理
- 状態変更の計算
- UIヒント（ViewModel）の生成

**非責務:**
- UI描画
- OS APIの直接呼び出し
- ネットワーク通信（将来的にオプション）
- ファイルI/O（将来的にオプション）

### 2. Platform Shell - The Body

**責務:**
- OS標準UIの構築と表示
- ユーザー入力の受信
- イベントのZylix Coreへの転送
- Zylix Coreからの状態取得
- 状態に基づくUI更新

**非責務:**
- ビジネスロジック
- 状態の保持（一時的なUIアニメーション状態を除く）
- アプリケーション判断

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      Data Flow Cycle                         │
│                                                              │
│   User Action                                                │
│       │                                                      │
│       ▼                                                      │
│   ┌─────────┐                                                │
│   │ UI Shell│ ─────────────────────────────────────┐        │
│   └────┬────┘                                       │        │
│        │ capture input                              │        │
│        ▼                                            │        │
│   ┌─────────┐                                       │        │
│   │  Event  │  (e.g., ButtonPressed, TextChanged)  │        │
│   └────┬────┘                                       │        │
│        │ dispatch via C ABI                         │        │
│        ▼                                            │        │
│   ┌─────────────────────────────────────┐          │        │
│   │           Zylix Core                 │          │        │
│   │  ┌─────────────────────────────┐    │          │        │
│   │  │     Event Handler           │    │          │        │
│   │  └──────────────┬──────────────┘    │          │        │
│   │                 │                    │          │        │
│   │                 ▼                    │          │        │
│   │  ┌─────────────────────────────┐    │          │        │
│   │  │    State Mutation           │    │          │        │
│   │  └──────────────┬──────────────┘    │          │        │
│   │                 │                    │          │        │
│   │                 ▼                    │          │        │
│   │  ┌─────────────────────────────┐    │          │        │
│   │  │   ViewModel Generation      │    │          │        │
│   │  └──────────────┬──────────────┘    │          │        │
│   └─────────────────┼───────────────────┘          │        │
│                     │                               │        │
│                     │ return new state              │        │
│                     ▼                               │        │
│   ┌─────────────────────────────────────┐          │        │
│   │         State Snapshot              │◄─────────┘        │
│   └─────────────────┬───────────────────┘  poll/callback    │
│                     │                                        │
│                     ▼                                        │
│   ┌─────────────────────────────────────┐                   │
│   │         UI Update                    │                   │
│   └─────────────────────────────────────┘                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## State Management Model

### State Structure

```zig
// Core state - owned entirely by Zig
pub const AppState = struct {
    // Application data
    data: ApplicationData,

    // UI hints (what to show, not how)
    ui: UIState,

    // Metadata
    version: u64,
    last_event: EventType,
};

pub const UIState = struct {
    // Semantic UI state
    screen: ScreenType,
    loading: bool,
    error_message: ?[]const u8,

    // View-specific data
    view_data: ViewData,
};
```

### State Update Pattern

```
Event ──► Reducer ──► New State ──► Notify Shell
              │
              ▼
        Side Effects (queued, not executed)
```

---

## Event System

### Event Types

```zig
pub const EventType = enum(u32) {
    // Lifecycle
    app_init = 0x0001,
    app_terminate = 0x0002,
    app_foreground = 0x0003,
    app_background = 0x0004,

    // User interaction
    button_press = 0x0100,
    text_input = 0x0101,
    selection_change = 0x0102,

    // Navigation
    navigate_to = 0x0200,
    navigate_back = 0x0201,

    // Custom (app-defined)
    custom_start = 0x1000,
};
```

### Event Dispatch

```zig
// Shell calls this to dispatch events
pub export fn zylix_dispatch(
    event_type: u32,
    payload_ptr: ?*const anyopaque,
    payload_len: usize,
) void;
```

---

## Memory Model

### Ownership Rules

| Scenario | Owner | Lifetime |
|----------|-------|----------|
| AppState | Zig | Application lifetime |
| Event payload (incoming) | Shell | Until dispatch returns |
| State snapshot (outgoing) | Zig | Until next state change |
| String data in state | Zig | Managed by Zig allocator |

### Safe Patterns

```zig
// Pattern 1: Read-only state access
pub export fn zylix_get_state() *const AppState {
    return &global_state;
}

// Pattern 2: Copy out for Shell ownership
pub export fn zylix_copy_string(
    src: [*]const u8,
    len: usize,
    dst: [*]u8,
    dst_len: usize,
) usize {
    const copy_len = @min(len, dst_len);
    @memcpy(dst[0..copy_len], src[0..copy_len]);
    return copy_len;
}
```

---

## Platform Integration Patterns

### iOS (SwiftUI)

```swift
// ZylixBridge.swift
class ZylixBridge: ObservableObject {
    @Published private(set) var state: ZylixState

    init() {
        zylix_init()
        self.state = readState()
    }

    func dispatch(_ event: ZylixEvent) {
        zylix_dispatch(event.type, event.payload, event.payloadSize)
        self.state = readState()
    }

    private func readState() -> ZylixState {
        let ptr = zylix_get_state()
        return ZylixState(from: ptr)
    }
}
```

### Android (Jetpack Compose)

```kotlin
// ZylixBridge.kt
class ZylixBridge {
    private val _state = MutableStateFlow(readState())
    val state: StateFlow<ZylixState> = _state.asStateFlow()

    init {
        zylix_init()
    }

    fun dispatch(event: ZylixEvent) {
        zylix_dispatch(event.type, event.payload, event.payloadSize)
        _state.value = readState()
    }

    private external fun zylix_init()
    private external fun zylix_dispatch(type: Int, payload: ByteArray?, size: Int)
    private external fun zylix_get_state(): Long
}
```

---

## Build Targets

| Target | Triple | Output |
|--------|--------|--------|
| iOS | aarch64-ios | libzylix.a |
| iOS Simulator | aarch64-ios-simulator | libzylix.a |
| Android ARM64 | aarch64-linux-android | libzylix.so |
| Android x86_64 | x86_64-linux-android | libzylix.so |
| macOS | aarch64-macos | libzylix.dylib |
| macOS Intel | x86_64-macos | libzylix.dylib |

---

## Future Considerations

### Phase 2+
- Callback system (Zig → Shell notifications)
- Async operation support
- Resource management (images, etc.)
- Serialization for persistence

### Phase 3+
- Hot reload support (development)
- Debug inspector protocol
- Performance profiling hooks
