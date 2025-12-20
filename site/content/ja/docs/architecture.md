---
title: アーキテクチャ
weight: 2
prev: getting-started
next: platforms
---

Zylix のアーキテクチャを理解する。

## 概要

Zylix は、関心事を分離し、プラットフォーム間でのコード再利用を最大化するレイヤードアーキテクチャを採用しています。

```
┌─────────────────────────────────────────────────────────┐
│                   プラットフォーム層                     │
│  SwiftUI │ Compose │ GTK4 │ WinUI 3 │ HTML/JS           │
└─────────────────────────────────────────────────────────┘
                            │
                            │ C ABI / WASM
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Zylix Core (Zig)                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │  VDOM   │ │  Diff   │ │ Events  │ │  State  │        │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘        │
└─────────────────────────────────────────────────────────┘
```

## コアコンポーネント

### Virtual DOM (`vdom.zig`)

Virtual DOM は UI ツリーの軽量な表現です。

```zig
pub const VNode = struct {
    tag: Tag,
    key: ?[]const u8,
    props: Props,
    children: []const VNode,
    text: ?[]const u8,
};
```

主な特徴：
- **デフォルトで不変**: VNode は決して変更されない
- **アリーナアロケーション**: 効率的なメモリ管理
- **キー付き差分検出**: キーによる最適な更新

### 差分アルゴリズム (`diff.zig`)

差分検出アルゴリズムは、古い VNode ツリーと新しいツリーを比較して最小限のパッチを生成します。

```zig
pub const Patch = union(enum) {
    replace: VNode,
    update_props: Props,
    update_text: []const u8,
    insert_child: struct { index: usize, node: VNode },
    remove_child: usize,
    move_child: struct { from: usize, to: usize },
};
```

パフォーマンス特性：
- ツリー比較は **O(n)** 時間計算量
- **最小限のパッチ**: 必要な変更のみ生成
- **キー最適化**: キー付き子要素は O(1) ルックアップ

### イベントシステム (`events.zig`)

判別共用体による型安全なイベント処理。

```zig
pub const Event = union(enum) {
    counter_increment,
    counter_decrement,
    counter_reset,
    todo_add: []const u8,
    todo_toggle: u32,
    todo_remove: u32,
    todo_clear_completed,
    todo_set_filter: Filter,
};
```

### 状態管理 (`state.zig`)

バージョントラッキング付きの集中型状態。

```zig
pub const State = struct {
    version: u64,
    screen: Screen,
    loading: bool,
    error_message: ?[]const u8,
    view_data: ?*anyopaque,
};
```

## データフロー

```
ユーザーアクション → プラットフォームイベント → Zylix ディスパッチ → 状態更新 → VDOM 再構築 → 差分検出 → パッチ → プラットフォーム適用
```

1. **ユーザーアクション**: タッチ、クリック、キーボード入力
2. **プラットフォームイベント**: ネイティブイベントを Zylix イベントに変換
3. **ディスパッチ**: Zylix コアでイベントを処理
4. **状態更新**: 不変の状態遷移
5. **VDOM 再構築**: 新しい仮想ツリーを生成
6. **差分検出**: 新旧比較からパッチを計算
7. **プラットフォーム適用**: ネイティブ UI を更新

## メモリ管理

Zylix は予測可能なパフォーマンスのためにアリーナアロケーションを使用：

```zig
pub const Arena = struct {
    buffer: []u8,
    offset: usize,

    pub fn alloc(self: *Arena, comptime T: type, n: usize) ?[]T;
    pub fn reset(self: *Arena) void;
};
```

メリット：
- **GC 停止なし**: 決定論的な解放
- **キャッシュフレンドリー**: 連続したメモリレイアウト
- **高速アロケーション**: O(1) バンプアロケーション
