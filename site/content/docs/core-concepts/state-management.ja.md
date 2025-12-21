---
title: 状態管理
weight: 2
---

Zylix は集中型のバージョン追跡付き状態管理を採用しています。すべてのアプリケーション状態は Zig で管理され、プラットフォームシェルには読み取り専用で公開されます。

## 設計原則

1. **単一の信頼源**: グローバルストアがすべてのアプリケーションデータを所有
2. **不変更新**: 状態遷移は新しいバージョンを作成
3. **バージョン追跡**: すべての変更にバージョン番号を割り当て
4. **差分検出**: 変更を追跡して効率的なレンダリングを実現

## 状態構造

### アプリケーション状態

```zig
pub const AppState = struct {
    /// カウンター値
    counter: i64 = 0,

    /// フォーム入力
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,

    /// Todo アイテム
    todos: [MAX_TODOS]Todo = undefined,
    todo_count: usize = 0,

    /// 現在のフィルター
    filter: Filter = .all,

    /// ビューデータポインタを取得（ABI 用）
    pub fn getViewData(self: *const AppState) ?*const anyopaque {
        return @ptrCast(self);
    }

    /// ビューデータサイズを取得（ABI 用）
    pub fn getViewDataSize(_: *const AppState) usize {
        return @sizeOf(AppState);
    }
};

pub const Todo = struct {
    id: u32,
    text: [128]u8,
    text_len: usize,
    completed: bool,
};

pub const Filter = enum(u8) {
    all = 0,
    active = 1,
    completed = 2,
};
```

### UI 状態

```zig
pub const UIState = struct {
    /// 現在の画面
    screen: Screen = .home,

    /// ローディング状態
    loading: bool = false,

    pub const Screen = enum(u32) {
        home = 0,
        detail = 1,
        settings = 2,
    };
};
```

### 統合状態

```zig
pub const State = struct {
    /// 状態バージョン（単調増加）
    version: u64 = 0,

    /// アプリケーション固有の状態
    app: AppState = .{},

    /// UI 状態ヒント
    ui: UIState = .{},

    /// 最後のエラーメッセージ
    last_error: ?[]const u8 = null,

    /// 状態変更後にバージョンを増加
    pub fn bumpVersion(self: *State) void {
        self.version +%= 1;
    }
};
```

## ジェネリックストア

`Store` は型安全な状態管理を提供します。

```zig
pub fn Store(comptime T: type) type {
    return struct {
        const Self = @This();

        current: T,
        previous: T,
        version: u64 = 0,
        dirty: bool = false,

        pub fn init(initial: T) Self {
            return .{
                .current = initial,
                .previous = initial,
            };
        }

        /// 現在の状態を取得（読み取り専用）
        pub fn getState(self: *const Self) *const T {
            return &self.current;
        }

        /// 変更可能な状態を取得（内部使用）
        pub fn getStateMut(self: *Self) *T {
            return &self.current;
        }

        /// 前の状態を取得（差分検出用）
        pub fn getPrevState(self: *const Self) *const T {
            return &self.previous;
        }

        /// 変更をコミット
        pub fn commit(self: *Self) void {
            if (self.dirty) {
                self.previous = self.current;
                self.version += 1;
                self.dirty = false;
            }
        }

        /// 関数で状態を更新してコミット
        pub fn updateAndCommit(self: *Self, update_fn: *const fn (*T) void) void {
            update_fn(&self.current);
            self.dirty = true;
            self.commit();
        }
    };
}
```

## 状態アクセス

### 状態の読み取り

```zig
const state = @import("state.zig");

// 現在の状態を取得（読み取り専用）
const current = state.getState();
std.debug.print("カウンター: {d}\n", .{current.app.counter});

// バージョンを取得
const version = state.getVersion();
std.debug.print("バージョン: {d}\n", .{version});

// 初期化状態を確認
if (state.isInitialized()) {
    // 状態は準備完了
}
```

### リデューサー

状態変更はリデューサー関数を通じて処理されます。

```zig
/// インクリメントイベントを処理
pub fn handleIncrement() void {
    const increment = struct {
        fn f(app: *AppState) void {
            app.counter += 1;
        }
    }.f;
    global_store.updateAndCommit(&increment);
    _ = calculateDiff();
}

/// デクリメントイベントを処理
pub fn handleDecrement() void {
    const decrement = struct {
        fn f(app: *AppState) void {
            app.counter -= 1;
        }
    }.f;
    global_store.updateAndCommit(&decrement);
    _ = calculateDiff();
}

/// リセットイベントを処理
pub fn handleReset() void {
    const reset_counter = struct {
        fn f(app: *AppState) void {
            app.counter = 0;
        }
    }.f;
    global_store.updateAndCommit(&reset_counter);
    _ = calculateDiff();
}
```

### テキスト入力の処理

複雑な状態更新の例：

```zig
/// テキスト入力イベントを処理
pub fn handleTextInput(text: []const u8) void {
    const app = global_store.getStateMut();

    // テキストを状態バッファにコピー
    const copy_len = @min(text.len, app.input_text.len - 1);
    @memcpy(app.input_text[0..copy_len], text[0..copy_len]);
    app.input_text[copy_len] = 0;  // null 終端
    app.input_len = copy_len;

    // dirty フラグを設定してコミット
    global_store.dirty = true;
    global_store.commit();
    _ = calculateDiff();
}
```

## 差分追跡

Zylix は状態バージョン間の変更を追跡します。

```zig
pub fn Diff(comptime T: type) type {
    return struct {
        const Self = @This();

        changed: bool = false,
        version: u64 = 0,
        fields_changed: u32 = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn calculate(old: *const T, new: *const T, version: u64) Self {
            var result = Self{
                .version = version,
            };

            // フィールドを比較して変更を検出
            if (!std.mem.eql(u8, std.mem.asBytes(old), std.mem.asBytes(new))) {
                result.changed = true;
                result.fields_changed = countChangedFields(old, new);
            }

            return result;
        }
    };
}
```

### 差分の使用

```zig
// 状態変更後に差分を計算
const diff = state.calculateDiff();

if (diff.changed) {
    std.debug.print("状態が変更されました！フィールド数: {d}\n", .{diff.fields_changed});

    // 再レンダリングをトリガー
    reconciler.scheduleRender();
}
```

## ABI 互換状態

クロス言語相互運用のために、状態は C ABI を通じて公開されます。

```zig
/// C ABI 互換の状態構造体
pub const ABIState = extern struct {
    version: u64,
    screen: u32,
    loading: bool,
    error_message: ?[*:0]const u8,
    view_data: ?*const anyopaque,
    view_data_size: usize,
};

// ABI 形式に変換
pub fn toABI(self: *const State) ABIState {
    return .{
        .version = self.version,
        .screen = @intFromEnum(self.ui.screen),
        .loading = self.ui.loading,
        .error_message = if (self.last_error) |err|
            @ptrCast(err.ptr)
        else
            null,
        .view_data = self.app.getViewData(),
        .view_data_size = self.app.getViewDataSize(),
    };
}
```

### プラットフォームからのアクセス

```swift
// Swift
let state = zylix_get_state()
print("カウンター: \(state.pointee.counter)")
```

```kotlin
// Kotlin
val state = ZylixBridge.getState()
println("カウンター: ${state.counter}")
```

```javascript
// JavaScript (WASM)
const state = zylix.getState();
console.log(`カウンター: ${state.counter}`);
```

```csharp
// C#
var statePtr = ZylixInterop.GetState();
var state = Marshal.PtrToStructure<ZylixState>(statePtr);
Console.WriteLine($"カウンター: {state.counter}");
```

## メモリアリーナ

Zylix は一時的な状態操作にアリーナアロケーションを使用します。

```zig
/// 一時アロケーション用のスクラッチアリーナ
var scratch_arena: Arena(4096) = Arena(4096).init();

/// スクラッチアリーナを取得
pub fn getScratchArena() *Arena(4096) {
    return &scratch_arena;
}

/// スクラッチアリーナをリセット（各イベントディスパッチサイクル後に呼び出し）
pub fn resetScratchArena() void {
    scratch_arena.reset();
}
```

### スクラッチアリーナの使用

```zig
// 一時作業用のアリーナを取得
const arena = state.getScratchArena();

// 一時バッファを割り当て
const buf = arena.alloc(u8, 256) orelse return;

// バッファを使用
formatMessage(buf, "Hello");

// 処理後にリセット（ディスパッチサイクル内）
state.resetScratchArena();
```

## ライフサイクル

### 初期化

```zig
pub fn init() void {
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = true;
}
```

### 終了処理

```zig
pub fn deinit() void {
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = false;
}
```

## ベストプラクティス

### 1. 状態をフラットに保つ

```zig
// 良い例: フラットな状態
pub const AppState = struct {
    todos: [MAX_TODOS]Todo = undefined,
    todo_count: usize = 0,
    selected_id: ?u32 = null,
    filter: Filter = .all,
};

// 悪い例: 深くネストした状態
pub const AppState = struct {
    ui: struct {
        list: struct {
            items: struct {
                todos: [MAX_TODOS]Todo,
            },
        },
    },
};
```

### 2. 有限状態に列挙型を使用

```zig
// 良い例: 明示的な状態
pub const LoadingState = enum {
    idle,
    loading,
    success,
    error,
};

// 悪い例: ブールフラグ
pub const State = struct {
    is_loading: bool,
    has_error: bool,
    is_success: bool,  // 不整合な状態が可能
};
```

### 3. レンダリング前にバージョンチェック

```zig
var last_rendered_version: u64 = 0;

fn shouldRender() bool {
    const current_version = state.getVersion();
    if (current_version > last_rendered_version) {
        last_rendered_version = current_version;
        return true;
    }
    return false;
}
```

### 4. 関連する更新をバッチ処理

```zig
// 良い例: 関連する変更を単一コミット
pub fn handleTodoComplete(id: u32) void {
    const app = global_store.getStateMut();

    // 複数の関連更新
    if (findTodo(app, id)) |todo| {
        todo.completed = true;
        app.completed_count += 1;
        app.active_count -= 1;
    }

    // 単一コミット
    global_store.dirty = true;
    global_store.commit();
}
```

## テスト

```zig
test "状態の初期化" {
    init();
    try std.testing.expect(isInitialized());
    try std.testing.expectEqual(@as(u64, 0), getVersion());

    deinit();
    try std.testing.expect(!isInitialized());
}

test "カウンターのインクリメント" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i64, 0), getState().app.counter);

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 1), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 1), getVersion());

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 2), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 2), getVersion());
}
```

## 次のステップ

- **[コンポーネント](../components)**: 状態を反映した UI を構築
  - **[イベント](../events)**: 状態変更をトリガー
