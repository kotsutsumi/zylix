---
title: イベントシステム
weight: 4
---

Zylix は型安全なイベントシステムを使用してユーザーインタラクションを処理します。イベントはプラットフォームシェルからコアを通じて流れ、状態変更と UI 更新をトリガーします。

## イベントアーキテクチャ

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant Shell as プラットフォームシェル
    participant Core as Zylix Core (Zig)
    participant Handler as イベントハンドラ
    participant State as 状態更新

    User->>Shell: ボタンタップ
    Note over Shell: Zylix イベントに変換
    Shell->>Core: zylix_dispatch(EVENT_TODO_ADD, "買い物", 6)

    Note over Core: イベントタイプを検証
    Note over Core: ペイロードを解析
    Note over Core: ハンドラにルーティング

    Core->>Handler: イベントをディスパッチ
    Note over Handler: switch (event) {<br/>  .todo_add => addTodo(text),<br/>  .todo_toggle => toggleTodo(id),<br/>}

    Handler->>State: 状態を更新
    Note over State: state.todos[id].completed = true<br/>state.version += 1<br/>scheduleRender()

    State-->>Core: 結果コード
    Core-->>Shell: 結果を返す
```

## イベントタイプ

### 組み込みイベント

Zylix は UI インタラクション用の一般的なイベントタイプを提供します。

```zig
pub const EventType = enum(u8) {
    none = 0,
    click = 1,
    double_click = 2,
    mouse_enter = 3,
    mouse_leave = 4,
    mouse_down = 5,
    mouse_up = 6,
    focus = 7,
    blur = 8,
    input = 9,
    change = 10,
    submit = 11,
    key_down = 12,
    key_up = 13,
    key_press = 14,
};
```

### アプリケーションイベント

判別共用体を使用して独自のイベントを定義します。

```zig
// events.zig
pub const Event = union(enum) {
    // カウンターイベント
    counter_increment,
    counter_decrement,
    counter_reset,

    // Todo イベント
    todo_add: []const u8,        // ペイロード: Todo テキスト
    todo_toggle: u32,            // ペイロード: Todo ID
    todo_remove: u32,            // ペイロード: Todo ID
    todo_clear_completed,
    todo_set_filter: Filter,     // ペイロード: フィルタータイプ

    // ナビゲーションイベント
    navigate: Screen,            // ペイロード: ターゲット画面
};
```

## イベントディスパッチ

### ABI エクスポート

イベントは C ABI を通じてディスパッチされます。

```zig
// abi.zig
export fn zylix_dispatch(
    event_type: u32,
    payload: ?*anyopaque,
    len: usize
) c_int {
    // イベントタイプを検証
    if (event_type > MAX_EVENT_TYPE) {
        return ERROR_INVALID_EVENT;
    }

    // ハンドラにルーティング
    const result = handleEvent(event_type, payload, len);

    // 状態が変更された場合はレンダリングをトリガー
    if (result == SUCCESS and state.isDirty()) {
        scheduleRender();
    }

    return result;
}
```

### プラットフォームディスパッチ

各プラットフォームは異なる方法でディスパッチを呼び出します。

{{< tabs items="Swift,Kotlin,JavaScript,C#,C" >}}

{{< tab >}}
```swift
// iOS/macOS
@_silgen_name("zylix_dispatch")
func zylix_dispatch(
    _ eventType: UInt32,
    _ payload: UnsafeRawPointer?,
    _ len: Int
) -> Int32

// 使用例
let text = "買い物"
text.withCString { ptr in
    zylix_dispatch(EVENT_TODO_ADD, ptr, text.count)
}
```
{{< /tab >}}

{{< tab >}}
```kotlin
// Android
external fun dispatch(eventType: Int, payload: ByteArray?, len: Int): Int

// 使用例
val text = "買い物".toByteArray()
ZylixLib.dispatch(EVENT_TODO_ADD, text, text.size)
```
{{< /tab >}}

{{< tab >}}
```javascript
// Web/WASM
function dispatch(eventType, payload) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(payload);
    const ptr = zylix.alloc(bytes.length);
    zylix.memory.set(bytes, ptr);
    const result = zylix.dispatch(eventType, ptr, bytes.length);
    zylix.free(ptr, bytes.length);
    return result;
}

// 使用例
dispatch(EVENT_TODO_ADD, "買い物");
```
{{< /tab >}}

{{< tab >}}
```csharp
// Windows
[LibraryImport("zylix", EntryPoint = "zylix_dispatch")]
public static partial int Dispatch(
    uint eventType,
    IntPtr payload,
    nuint len
);

// 使用例
var text = "買い物"u8.ToArray();
fixed (byte* ptr = text) {
    ZylixInterop.Dispatch(EVENT_TODO_ADD, (IntPtr)ptr, (nuint)text.Length);
}
```
{{< /tab >}}

{{< tab >}}
```c
// Linux (GTK)
extern int zylix_dispatch(
    uint32_t event_type,
    void* payload,
    size_t len
);

// 使用例
const char* text = "買い物";
zylix_dispatch(EVENT_TODO_ADD, (void*)text, strlen(text));
```
{{< /tab >}}

{{< /tabs >}}

## イベントハンドラ

### ハンドラ登録

```zig
// コールバック ID 定数
pub const CALLBACK_INCREMENT = 1;
pub const CALLBACK_DECREMENT = 2;
pub const CALLBACK_RESET = 3;
pub const CALLBACK_ADD_TODO = 10;
pub const CALLBACK_TOGGLE_TODO = 11;
pub const CALLBACK_REMOVE_TODO = 12;

// ハンドラディスパッチ
pub fn handleCallback(id: u32, data: ?*anyopaque) void {
    switch (id) {
        CALLBACK_INCREMENT => state.handleIncrement(),
        CALLBACK_DECREMENT => state.handleDecrement(),
        CALLBACK_RESET => state.handleReset(),
        CALLBACK_ADD_TODO => {
            if (data) |ptr| {
                const text = @as([*:0]const u8, @ptrCast(ptr));
                todo.addTodo(std.mem.sliceTo(text, 0));
            }
        },
        CALLBACK_TOGGLE_TODO => {
            if (data) |ptr| {
                const id = @as(*const u32, @ptrCast(@alignCast(ptr))).*;
                todo.toggleTodo(id);
            }
        },
        else => {},
    }
}
```

### イベントハンドラ構造体

```zig
pub const EventHandler = struct {
    event_type: EventType = .none,
    callback_id: u32 = 0,
    prevent_default: bool = false,
    stop_propagation: bool = false,
};
```

## 特定イベントの処理

### クリックイベント

```zig
fn handleClick(callback_id: u32) void {
    switch (callback_id) {
        CALLBACK_INCREMENT => {
            const app = state.getStore().getStateMut();
            app.counter += 1;
            state.getStore().commit();
        },
        CALLBACK_SUBMIT => {
            submitForm();
        },
        else => {},
    }
}
```

### 入力イベント

```zig
fn handleInput(callback_id: u32, text: []const u8) void {
    switch (callback_id) {
        CALLBACK_TEXT_INPUT => {
            const app = state.getStore().getStateMut();
            const len = @min(text.len, app.input_text.len - 1);
            @memcpy(app.input_text[0..len], text[0..len]);
            app.input_len = len;
            state.getStore().commit();
        },
        CALLBACK_SEARCH => {
            performSearch(text);
        },
        else => {},
    }
}
```

### キーボードイベント

```zig
pub const KeyEvent = struct {
    key_code: u16,
    modifiers: KeyModifiers,
};

pub const KeyModifiers = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    meta: bool = false,
};

fn handleKeyDown(event: KeyEvent) void {
    // Enter キー
    if (event.key_code == 13) {
        if (state.getInput().len > 0) {
            todo.addTodo(state.getInput());
            state.clearInput();
        }
    }

    // Escape キー
    if (event.key_code == 27) {
        state.clearInput();
    }

    // Ctrl+Z - 元に戻す
    if (event.key_code == 90 and event.modifiers.ctrl) {
        state.undo();
    }
}
```

## イベント検証

### タイプ検証

```zig
fn validateEvent(event_type: u32) !EventType {
    if (event_type > @intFromEnum(EventType.key_press)) {
        return error.InvalidEventType;
    }
    return @enumFromInt(event_type);
}
```

### ペイロード検証

```zig
fn validatePayload(
    event_type: EventType,
    payload: ?*anyopaque,
    len: usize
) !void {
    switch (event_type) {
        .todo_add => {
            if (payload == null or len == 0) {
                return error.MissingPayload;
            }
            if (len > MAX_TODO_TEXT_LEN) {
                return error.PayloadTooLarge;
            }
        },
        .todo_toggle, .todo_remove => {
            if (len != @sizeOf(u32)) {
                return error.InvalidPayloadSize;
            }
        },
        else => {},
    }
}
```

## イベントキュー

複数のイベントをバッチ処理するため：

```zig
pub const EventQueue = struct {
    events: [MAX_QUEUED_EVENTS]QueuedEvent = undefined,
    count: usize = 0,

    pub fn push(self: *EventQueue, event: QueuedEvent) !void {
        if (self.count >= MAX_QUEUED_EVENTS) {
            return error.QueueFull;
        }
        self.events[self.count] = event;
        self.count += 1;
    }

    pub fn processAll(self: *EventQueue) void {
        for (self.events[0..self.count]) |event| {
            processEvent(event);
        }
        self.count = 0;
    }
};
```

## エラー処理

### 結果コード

```zig
pub const EventResult = enum(c_int) {
    success = 0,
    error_invalid_event = -1,
    error_invalid_payload = -2,
    error_handler_failed = -3,
    error_state_locked = -4,
};
```

### エラーリカバリ

```zig
fn dispatchWithRecovery(
    event_type: u32,
    payload: ?*anyopaque,
    len: usize
) EventResult {
    // 最初に検証
    const event = validateEvent(event_type) catch {
        return .error_invalid_event;
    };

    validatePayload(event, payload, len) catch {
        return .error_invalid_payload;
    };

    // 処理を試行
    handleEvent(event, payload, len) catch |err| {
        // エラーをログ
        std.log.err("イベントハンドラが失敗: {}", .{err});

        // リカバリを試行
        state.rollback();

        return .error_handler_failed;
    };

    return .success;
}
```

## ベストプラクティス

### 1. イベントを細かく保つ

```zig
// 良い例: 具体的なイベント
pub const Event = union(enum) {
    todo_add: []const u8,
    todo_toggle: u32,
    todo_remove: u32,
    todo_edit: struct { id: u32, text: []const u8 },
};

// 悪い例: 汎用的なイベント
pub const Event = union(enum) {
    todo_action: struct {
        action_type: u8,
        id: ?u32,
        text: ?[]const u8,
    },
};
```

### 2. コールバック ID に定数を使用

```zig
// 良い例: 名前付き定数
pub const CALLBACK_INCREMENT = 1;
pub const CALLBACK_DECREMENT = 2;

node.props.on_click = CALLBACK_INCREMENT;

// 悪い例: マジックナンバー
node.props.on_click = 1;
```

### 3. 処理前に検証

```zig
// 良い例: 最初に検証
fn handleTodoAdd(text: []const u8) !void {
    if (text.len == 0) return error.EmptyText;
    if (text.len > MAX_TEXT_LEN) return error.TextTooLong;
    if (todo_count >= MAX_TODOS) return error.TooManyTodos;

    // 追加しても安全
    addTodo(text);
}
```

### 4. 関連イベントをバッチ処理

```zig
// 良い例: 可能な場合はバッチ処理
fn handleBulkComplete(ids: []const u32) void {
    for (ids) |id| {
        completeTodo(id);
    }
    // すべての変更後に単一コミット
    state.commit();
    scheduleRender();
}
```

## デバッグ

### ロギング

```zig
fn logEvent(event_type: EventType, payload: ?*anyopaque) void {
    std.log.debug(
        "イベント: {s}, ペイロード: {}",
        .{ @tagName(event_type), payload != null }
    );
}
```

### イベント履歴

```zig
var event_history: [256]EventRecord = undefined;
var history_index: usize = 0;

fn recordEvent(event: Event) void {
    event_history[history_index] = .{
        .event = event,
        .timestamp = std.time.milliTimestamp(),
    };
    history_index = (history_index + 1) % 256;
}
```

## 次のステップ

{{< cards >}}
  {{< card link="../state-management" title="状態管理" subtitle="イベントが状態変更をトリガーする仕組み" >}}
  {{< card link="../components" title="コンポーネント" subtitle="コンポーネントにイベントハンドラをアタッチ" >}}
{{< /cards >}}
