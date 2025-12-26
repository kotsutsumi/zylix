---
title: "イベント"
weight: 3
---

# イベントシステム

イベントモジュール（`events.zig`）は、イベントタイプを定義し、プラットフォームシェルからZylix Coreへのイベントディスパッチを処理します。

## 概要

イベントはプラットフォームシェルからZylix Coreへ一方向に流れます：

```
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│ プラット    │ ─────▶ │  イベント   │ ─────▶ │   状態      │
│ フォーム    │  C ABI │  モジュール │        │   更新      │
│ シェル      │        │             │        │             │
└─────────────┘        └─────────────┘        └─────────────┘
```

## イベントタイプ

イベントは、カテゴリに分類された32ビットのタイプコードで識別されます：

### イベントタイプ範囲

| 範囲 | カテゴリ | 説明 |
|-------|----------|-------------|
| `0x0000 - 0x00FF` | ライフサイクル | アプリケーションライフサイクルイベント |
| `0x0100 - 0x01FF` | ユーザーインタラクション | ボタンプレス、テキスト入力、ジェスチャー |
| `0x0200 - 0x02FF` | ナビゲーション | 画面ナビゲーションイベント |
| `0x1000+` | アプリケーション | アプリケーション固有のイベント |

### EventType列挙型

```zig
pub const EventType = enum(u32) {
    // ライフサイクルイベント (0x0000 - 0x00FF)
    app_init = 0x0001,
    app_terminate = 0x0002,
    app_foreground = 0x0003,
    app_background = 0x0004,
    app_low_memory = 0x0005,

    // ユーザーインタラクション (0x0100 - 0x01FF)
    button_press = 0x0100,
    text_input = 0x0101,
    text_commit = 0x0102,
    selection = 0x0103,
    scroll = 0x0104,
    gesture = 0x0105,

    // ナビゲーション (0x0200 - 0x02FF)
    navigate = 0x0200,
    navigate_back = 0x0201,
    tab_switch = 0x0202,

    // カウンターPoCイベント (0x1000+)
    counter_increment = 0x1000,
    counter_decrement = 0x1001,
    counter_reset = 0x1002,

    // 不明/カスタムイベント
    _,

    pub fn fromInt(value: u32) EventType;
};
```

## イベントペイロード

### ButtonEvent

`button_press`イベント用のペイロード。

```zig
pub const ButtonEvent = extern struct {
    button_id: u32,
};
```

**C等価:**

```c
typedef struct {
    uint32_t button_id;
} ZylixButtonEvent;
```

**使用方法:**

```c
ZylixButtonEvent btn = { .button_id = 0 };  // インクリメントボタン
zylix_dispatch(0x0100, &btn, sizeof(btn));
```

### TextEvent

`text_input`および`text_commit`イベント用のペイロード。

```zig
pub const TextEvent = extern struct {
    text_ptr: ?[*]const u8,
    text_len: usize,
    field_id: u32,
};
```

**C等価:**

```c
typedef struct {
    const char* text_ptr;
    size_t text_len;
    uint32_t field_id;
} ZylixTextEvent;
```

**使用方法:**

```c
const char* text = "Hello";
ZylixTextEvent txt = {
    .text_ptr = text,
    .text_len = strlen(text),
    .field_id = 0
};
zylix_dispatch(0x0101, &txt, sizeof(txt));
```

### NavigateEvent

`navigate`イベント用のペイロード。

```zig
pub const NavigateEvent = extern struct {
    screen_id: u32,
    params_ptr: ?*const anyopaque,
    params_len: usize,
};
```

**C等価:**

```c
typedef struct {
    uint32_t screen_id;
    const void* params_ptr;
    size_t params_len;
} ZylixNavigateEvent;
```

**画面ID:**

| ID | 画面 |
|----|--------|
| 0 | home |
| 1 | detail |
| 2 | settings |

## ディスパッチ関数

### dispatch

```zig
pub fn dispatch(
    event_type: u32,
    payload: ?*const anyopaque,
    payload_len: usize
) DispatchResult
```

イベントを適切なハンドラにディスパッチします。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `event_type` | `u32` | イベントタイプ識別子 |
| `payload` | `?*const anyopaque` | イベントペイロード（オプション） |
| `payload_len` | `usize` | ペイロードサイズ（バイト単位） |

**戻り値:** 成功または失敗を示す`DispatchResult`。

### DispatchResult

```zig
pub const DispatchResult = enum {
    ok,
    not_initialized,
    unknown_event,
    invalid_payload,
};
```

| 値 | 説明 |
|-------|-------------|
| `ok` | イベントが正常にディスパッチされました |
| `not_initialized` | 状態が初期化されていません（まず`zylix_init()`を呼び出してください） |
| `unknown_event` | 不明なイベントタイプ |
| `invalid_payload` | ペイロードがないか小さすぎます |

## イベント処理

### ライフサイクルイベント

| イベント | ハンドラ |
|-------|---------|
| `app_init` | No-op（すでに初期化済み） |
| `app_terminate` | `state.deinit()`を呼び出します |
| `app_foreground` | 将来の使用のために予約 |
| `app_background` | 将来の使用のために予約 |
| `app_low_memory` | 将来の使用のために予約 |

### ユーザーインタラクションイベント

| イベント | ハンドラ |
|-------|---------|
| `button_press` | IDによってボタンハンドラにルーティング |
| `text_input` | `state.handleTextInput()`を呼び出します |
| `text_commit` | `state.handleTextInput()`を呼び出します |

**ボタンIDマッピング:**

| ID | アクション |
|----|--------|
| 0 | カウンターをインクリメント |
| 1 | カウンターをデクリメント |
| 2 | カウンターをリセット |

### ナビゲーションイベント

| イベント | ハンドラ |
|-------|---------|
| `navigate` | 画面を指定して`state.handleNavigate()`を呼び出します |
| `navigate_back` | ホーム画面にナビゲート |

### カウンターイベント

| イベント | ハンドラ |
|-------|---------|
| `counter_increment` | `state.handleIncrement()`を呼び出します |
| `counter_decrement` | `state.handleDecrement()`を呼び出します |
| `counter_reset` | `state.handleReset()`を呼び出します |

## プラットフォーム例

### Swift（iOS）

```swift
import ZylixCore

// シンプルなカウンターインクリメント
zylix_dispatch(0x1000, nil, 0)

// ペイロード付きボタンプレス
var btn = ZylixButtonEvent(button_id: 0)
withUnsafePointer(to: &btn) { ptr in
    zylix_dispatch(0x0100, ptr, MemoryLayout<ZylixButtonEvent>.size)
}

// テキスト入力
let text = "Hello, World!"
text.withCString { cString in
    var txt = ZylixTextEvent(
        text_ptr: cString,
        text_len: text.utf8.count,
        field_id: 0
    )
    withUnsafePointer(to: &txt) { ptr in
        zylix_dispatch(0x0101, ptr, MemoryLayout<ZylixTextEvent>.size)
    }
}

// ナビゲーション
var nav = ZylixNavigateEvent(
    screen_id: 1,  // 詳細画面
    params_ptr: nil,
    params_len: 0
)
withUnsafePointer(to: &nav) { ptr in
    zylix_dispatch(0x0200, ptr, MemoryLayout<ZylixNavigateEvent>.size)
}
```

### Kotlin（Android）

```kotlin
// シンプルなカウンターインクリメント
ZylixCore.dispatch(0x1000, null, 0)

// テキスト入力（JNIヘルパーを使用）
ZylixCore.dispatchTextInput("Hello, World!", 0)

// ナビゲーション
ZylixCore.navigate(1)  // 詳細画面
```

### JavaScript（WASM）

```javascript
// シンプルなカウンターインクリメント
wasm.exports.zylix_dispatch(0x1000, 0, 0);

// 複雑なペイロードの場合、メモリを割り当てデータを書き込む
const textBytes = new TextEncoder().encode("Hello");
const ptr = wasm.exports.zylix_alloc(textBytes.length);
new Uint8Array(wasm.exports.memory.buffer, ptr, textBytes.length).set(textBytes);

// WASMメモリにTextEventを作成
const eventPtr = wasm.exports.zylix_alloc(24); // sizeof(TextEvent)
const view = new DataView(wasm.exports.memory.buffer);
view.setUint32(eventPtr, ptr, true);      // text_ptr
view.setBigUint64(eventPtr + 8, BigInt(textBytes.length), true);  // text_len
view.setUint32(eventPtr + 16, 0, true);   // field_id

wasm.exports.zylix_dispatch(0x0101, eventPtr, 24);

// メモリを解放
wasm.exports.zylix_free(ptr);
wasm.exports.zylix_free(eventPtr);
```

## カスタムイベントの追加

カスタムイベントを追加するには：

1. **EventType列挙型でイベントタイプを定義**：

```zig
// events.zig内
pub const EventType = enum(u32) {
    // ... 既存のイベント ...

    // カスタムイベント (0x2000+)
    my_custom_event = 0x2000,
    _,
};
```

2. **ペイロード構造体を定義**（必要な場合）：

```zig
pub const MyCustomEvent = extern struct {
    data_field: u32,
    other_field: i64,
};
```

3. **ディスパッチスイッチにハンドラを追加**：

```zig
.my_custom_event => {
    if (payload) |p| {
        if (payload_len >= @sizeOf(MyCustomEvent)) {
            const evt: *const MyCustomEvent = @ptrCast(@alignCast(p));
            handleMyCustomEvent(evt);
        } else {
            return .invalid_payload;
        }
    }
},
```

4. **ハンドラ関数を実装**：

```zig
fn handleMyCustomEvent(evt: *const MyCustomEvent) void {
    // イベントに基づいて状態を更新
    const app = state.getStore().getStateMut();
    app.my_field = evt.data_field;
    state.getStore().dirty = true;
    _ = state.calculateDiff();
    state.getStore().commit();
}
```
