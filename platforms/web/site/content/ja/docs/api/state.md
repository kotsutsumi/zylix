---
title: "状態管理"
weight: 2
---

# 状態管理

状態モジュール（`state.zig`）は、差分追跡を備えた汎用Storeを使用してZylix Coreのすべてのアプリケーション状態を管理します。

## 概要

状態はZigによって完全に所有され、プラットフォームシェルには読み取り専用で公開されます。状態管理システムは以下を提供します：

- スレッドセーフのための不変状態アクセス
- 効率的なUI更新のための自動差分追跡
- 状態変更のための型安全なリデューサー
- 一時的なアロケーション用のスクラッチアリーナ

## アーキテクチャ

```
┌─────────────────────────────────────────────┐
│                  Store<T>                    │
│  ┌─────────────┐    ┌─────────────┐         │
│  │ 現在の      │    │ 以前の      │         │
│  │ 状態        │    │ 状態        │         │
│  └─────────────┘    └─────────────┘         │
│         │                  │                 │
│         └────────┬─────────┘                 │
│                  ▼                           │
│           ┌─────────────┐                    │
│           │    差分     │                    │
│           └─────────────┘                    │
└─────────────────────────────────────────────┘
```

## 型

### State

アプリケーション状態とUI状態を結合するメイン状態コンテナ。

```zig
pub const State = struct {
    /// 状態バージョン（単調増加）
    version: u64 = 0,

    /// アプリケーション固有の状態
    app: AppState = .{},

    /// UI状態ヒント
    ui: UIState = .{},

    /// 最後のエラーメッセージ
    last_error: ?[]const u8 = null,

    /// ABI互換構造体に変換
    pub fn toABI(self: *const State) ABIState;

    /// 状態変更後にバージョンをインクリメント
    pub fn bumpVersion(self: *State) void;
};
```

### AppState

アプリケーション固有の状態（アプリケーションごとにカスタマイズ可能）。

```zig
pub const AppState = struct {
    /// カウンター値（PoCの例）
    counter: i64 = 0,

    /// フォームテキスト（PoCの例）
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,

    /// ABI用のビューデータポインタを取得
    pub fn getViewData(self: *const AppState) ?*const anyopaque;

    /// ABI用のビューデータサイズを取得
    pub fn getViewDataSize(self: *const AppState) usize;
};
```

### UIState

プラットフォームシェル用のUI状態ヒント。

```zig
pub const UIState = struct {
    /// 現在の画面
    screen: Screen = .home,

    /// 読み込みインジケータ
    loading: bool = false,

    pub const Screen = enum(u32) {
        home = 0,
        detail = 1,
        settings = 2,
    };
};
```

### ABIState

C相互運用用のABI互換構造体。

```zig
pub const ABIState = extern struct {
    version: u64,
    screen: u32,
    loading: bool,
    error_message: ?[*:0]const u8,
    view_data: ?*const anyopaque,
    view_data_size: usize,
};
```

## 関数

### ライフサイクル

#### init

```zig
pub fn init() void
```

グローバル状態を初期化します。状態操作の前に呼び出す必要があります。

#### deinit

```zig
pub fn deinit() void
```

状態を非初期化し、リソースを解放します。

#### isInitialized

```zig
pub fn isInitialized() bool
```

状態が初期化されているかどうかをチェックします。

### 状態アクセス

#### getState

```zig
pub fn getState() *const State
```

現在の状態を取得（読み取り専用）。ストアと同期した状態へのポインタを返します。

#### getAppState

```zig
pub fn getAppState() *const AppState
```

ストアから直接アプリ状態を取得します。

#### getVersion

```zig
pub fn getVersion() u64
```

現在の状態バージョンを取得します。

#### getStore

```zig
pub fn getStore() *Store(AppState)
```

高度な操作用のグローバルストアを取得します。

### 差分追跡

#### getDiff

```zig
pub fn getDiff() *const Diff(AppState)
```

最後に計算された差分を取得します。

#### calculateDiff

```zig
pub fn calculateDiff() *const Diff(AppState)
```

最後のコミット以降の差分を計算して返します。

**例:**

```zig
// 状態変更後
const diff = state.calculateDiff();
if (diff.hasChanges()) {
    if (diff.hasFieldChangedByName("counter")) {
        // カウンターが変更された、UIを更新
    }
}
```

### スクラッチアリーナ

#### getScratchArena

```zig
pub fn getScratchArena() *Arena(4096)
```

一時的なアロケーション用のスクラッチアリーナを取得します。各イベントディスパッチサイクル後にリセットされます。

#### resetScratchArena

```zig
pub fn resetScratchArena() void
```

スクラッチアリーナをリセットします。イベント処理後に自動的に呼び出されます。

### 状態リデューサー

状態の変更はリデューサー関数を通じて処理されます：

#### handleIncrement

```zig
pub fn handleIncrement() void
```

カウンターをインクリメントし、変更をコミットします。

#### handleDecrement

```zig
pub fn handleDecrement() void
```

カウンターをデクリメントし、変更をコミットします。

#### handleReset

```zig
pub fn handleReset() void
```

カウンターをゼロにリセットします。

#### handleTextInput

```zig
pub fn handleTextInput(text: []const u8) void
```

テキスト入力を処理し、入力バッファにコピーします。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `text` | `[]const u8` | 入力テキスト（255文字に切り捨て） |

#### handleNavigate

```zig
pub fn handleNavigate(screen: UIState.Screen) void
```

別の画面へのナビゲーションを処理します。

### エラー処理

#### setError

```zig
pub fn setError(err: ?[]const u8) void
```

最後のエラーメッセージを設定します。クリアするには`null`を渡します。

## Store汎用型

`Store(T)`型は差分追跡を備えた効率的な状態管理を提供します：

```zig
pub fn Store(comptime T: type) type {
    return struct {
        current: T,
        previous: T,
        version: u64,
        dirty: bool,

        /// デフォルト状態で初期化
        pub fn init(initial: T) Store(T);

        /// 現在の状態を取得（読み取り専用）
        pub fn getState(self: *const Self) *const T;

        /// 可変状態を取得（内部使用）
        pub fn getStateMut(self: *Self) *T;

        /// 差分用に以前の状態を取得
        pub fn getPrevState(self: *const Self) *const T;

        /// リデューサー関数で状態を更新
        pub fn update(self: *Self, reducer: *const fn(*T) void) void;

        /// 変更をコミット（バージョンをインクリメント、前の状態にコピー）
        pub fn commit(self: *Self) void;

        /// 現在のバージョンを取得
        pub fn getVersion(self: *const Self) u64;
    };
}
```

## 使用例

### Swift（iOS）

```swift
import ZylixCore

class AppViewModel: ObservableObject {
    @Published var counter: Int64 = 0
    @Published var inputText: String = ""

    private var lastVersion: UInt64 = 0

    func refresh() {
        guard let state = zylix_get_state() else { return }

        // バージョンが変更された場合のみ更新
        if state.pointee.version > lastVersion {
            lastVersion = state.pointee.version

            // 差分を使用して何が変更されたかをチェック
            if zylix_field_changed(0) {  // counterフィールド
                counter = zylix_get_counter()
            }
        }
    }

    func increment() {
        zylix_dispatch(0x1000, nil, 0)
        refresh()
    }
}
```

### Kotlin（Android）

```kotlin
class AppViewModel : ViewModel() {
    private val _counter = MutableStateFlow(0L)
    val counter: StateFlow<Long> = _counter.asStateFlow()

    private var lastVersion = 0L

    fun refresh() {
        val version = ZylixCore.getStateVersion()
        if (version > lastVersion) {
            lastVersion = version

            if (ZylixCore.fieldChanged(0)) {
                _counter.value = ZylixCore.getCounter()
            }
        }
    }

    fun increment() {
        ZylixCore.dispatch(0x1000, null, 0)
        refresh()
    }
}
```
