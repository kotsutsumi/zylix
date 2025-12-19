---
title: "アーキテクチャ"
weight: 3
---

# アーキテクチャ

## 概要

```
                    ┌─────────────────────────────┐
                    │     Zylix Core (Zig)        │
                    │  ┌───────────────────────┐  │
                    │  │ 状態管理              │  │
                    │  │ ビジネスロジック      │  │
                    │  │ ViewModel生成         │  │
                    │  │ 差分計算              │  │
                    │  │ イベント処理          │  │
                    │  └───────────────────────┘  │
                    └─────────────┬───────────────┘
                                  │
                              C ABI
                                  │
        ┌─────────┬─────────┬─────┼─────┬─────────┬─────────┐
        ▼         ▼         ▼     ▼     ▼         ▼         ▼
   ┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │   iOS   │ │Android │ │ macOS  │ │Windows │ │ Linux  │ │  Web   │
   │ SwiftUI │ │Compose │ │SwiftUI │ │ WinUI  │ │  GTK4  │ │  WASM  │
   └─────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

## コアコンポーネント

### 状態管理

すべてのアプリケーション状態はZigに存在：

```zig
pub const AppState = struct {
    counter: i64 = 0,
    user_name: [256]u8 = undefined,
    user_name_len: usize = 0,
    is_authenticated: bool = false,
};
```

### イベントシステム

イベントはUIからコアへ流れる：

```zig
pub const EventType = enum(u32) {
    none = 0,
    increment = 1,
    decrement = 2,
    reset = 3,
    set_value = 4,
};

pub fn dispatch(event_type: EventType, payload: ?*const anyopaque) void {
    switch (event_type) {
        .increment => state.counter += 1,
        .decrement => state.counter -= 1,
        // ...
    }
}
```

### C ABI境界

C ABIによるゼロコスト相互運用：

```zig
// ネイティブプラットフォーム向けエクスポート
pub export fn zylix_init() i32;
pub export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque) i32;
pub export fn zylix_get_counter() i64;
```

## プラットフォームシェル

### iOS/macOS (SwiftUI)

```swift
import ZylixCore

struct ContentView: View {
    @State private var counter: Int64 = 0

    var body: some View {
        VStack {
            Text("\(counter)")
            Button("増加") {
                zylix_dispatch(1, nil)
                counter = zylix_get_counter()
            }
        }
    }
}
```

### Android (Jetpack Compose)

```kotlin
@Composable
fun CounterScreen() {
    var counter by remember { mutableStateOf(0L) }

    Column {
        Text("$counter")
        Button(onClick = {
            ZylixCore.dispatch(1, null)
            counter = ZylixCore.getCounter()
        }) {
            Text("増加")
        }
    }
}
```

### Web (WASM)

```javascript
const wasm = await WebAssembly.instantiate(wasmBytes);
const { zylix_init, zylix_dispatch, zylix_wasm_get_counter } = wasm.instance.exports;

zylix_init();
document.getElementById('increment').onclick = () => {
    zylix_dispatch(1, 0);
    document.getElementById('counter').textContent = zylix_wasm_get_counter();
};
```

## メモリモデル

### 所有権ルール

1. **Zigが確保 → Zigが解放**
2. **ホストが確保 → ホストが解放**
3. **所有権移転 → 明示的なハンドオフ関数**
4. **共有読み取り → 不変ポインタ、Zigライフタイム**

### メモリレイアウト

```zig
// ゼロコピー転送のためGPUアライメント
pub const Vertex = extern struct {
    position: Vec3,  // 16バイト（パディング済み）
    color: Vec4,     // 16バイト
};

// 256バイトユニフォームバッファ（WebGPU要件）
pub const Uniforms = extern struct {
    model: Mat4,      // 64バイト
    view: Mat4,       // 64バイト
    projection: Mat4, // 64バイト
    _padding: [64]u8, // 256にパディング
};
```

## ビルドシステム

単一ツールチェーンで全ターゲット：

```bash
# 全プラットフォームビルド
zig build all

# 個別ターゲット
zig build ios          # iOS ARM64
zig build ios-sim      # iOSシミュレータ
zig build android-arm64
zig build macos-arm64
zig build windows-x64
zig build linux-x64
zig build wasm         # WebAssembly
```

## 比較

| 側面 | Flutter | Electron | Tauri | Zylix |
|------|---------|----------|-------|-------|
| UIレンダリング | Skia（カスタム） | Chromium | WebView | **OSネイティブ** |
| ランタイム | Dart VM | Node.js | Rust + WebView | **なし** |
| バイナリサイズ | 約15MB以上 | 約150MB以上 | 約3MB以上 | **1MB未満** |
| メモリ | 高 | 非常に高 | 中 | **低** |
| OS統合 | 限定的 | 限定的 | 中程度 | **完全** |
| IME/A11y | カスタム | Chromium | WebView | **ネイティブ** |
