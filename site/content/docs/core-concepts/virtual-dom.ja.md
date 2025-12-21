---
title: Virtual DOM
weight: 1
---

Virtual DOM は Zylix の UI レンダリングエンジンの核心です。実際の DOM/ネイティブ UI の軽量な仮想表現を構築し、効率的な差分検出により最小限の更新を実現します。

## 概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    Virtual DOM ワークフロー                       │
│                                                                  │
│   状態変更 ──▶ 新 VTree 構築 ──▶ 差分検出 ──▶ パッチ適用        │
│                                                                  │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐  │
│   │ State   │     │ VTree   │     │  Diff   │     │ Native  │  │
│   │ v1 → v2 │ ──▶ │  Build  │ ──▶ │ Compare │ ──▶ │   UI    │  │
│   └─────────┘     └─────────┘     └─────────┘     └─────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## VNode 構造体

VNode は仮想 DOM の基本単位です。

```zig
pub const VNode = struct {
    /// ノードタイプ (div, span, button など)
    tag: Tag,

    /// 差分検出用のユニークキー
    key: ?[]const u8 = null,

    /// ノードプロパティ
    props: Props = .{},

    /// 子ノード配列
    children: []const VNode = &.{},

    /// テキストコンテンツ（テキストノードの場合）
    text: ?[]const u8 = null,

    /// 要素ノードを作成
    pub fn element(tag: Tag) VNode {
        return .{ .tag = tag };
    }

    /// テキストノードを作成
    pub fn textNode(text: []const u8) VNode {
        return .{ .tag = .text, .text = text };
    }

    /// キーを設定
    pub fn setKey(self: *VNode, key: []const u8) void {
        const len = @min(key.len, self.key_buf.len - 1);
        @memcpy(self.key_buf[0..len], key[0..len]);
        self.key_buf[len] = 0;
        self.key = self.key_buf[0..len];
    }

    /// テキストを設定
    pub fn setText(self: *VNode, text: []const u8) void {
        const len = @min(text.len, self.text_buf.len - 1);
        @memcpy(self.text_buf[0..len], text[0..len]);
        self.text_buf[len] = 0;
        self.text = self.text_buf[0..len];
    }
};
```

### タグ定義

```zig
pub const Tag = enum(u8) {
    text = 0,     // テキストノード
    div = 1,      // コンテナ
    span = 2,     // インラインテキスト
    button = 3,   // ボタン
    input = 4,    // 入力フィールド
    ul = 5,       // 順序なしリスト
    li = 6,       // リストアイテム
    h1 = 7,       // 見出し
    p = 8,        // 段落
    // ...
};
```

### プロパティ

```zig
pub const Props = struct {
    /// スタイル参照
    style_id: u32 = 0,

    /// CSS クラス名
    class_name: [64]u8 = [_]u8{0} ** 64,
    class_name_len: u16 = 0,

    /// イベントハンドラ
    on_click: u32 = 0,
    on_input: u32 = 0,
    on_change: u32 = 0,

    /// 入力タイプ
    input_type: InputType = .text,

    /// プレースホルダー
    placeholder: [128]u8 = [_]u8{0} ** 128,
    placeholder_len: u16 = 0,

    /// クラス名を設定
    pub fn setClass(self: *Props, class: []const u8) void {
        const len = @min(class.len, self.class_name.len - 1);
        @memcpy(self.class_name[0..len], class[0..len]);
        self.class_name[len] = 0;
        self.class_name_len = @intCast(len);
    }
};
```

## VTree 管理

VTree は VNode のコレクションを管理します。

```zig
pub fn VTree(comptime max_nodes: usize) type {
    return struct {
        const Self = @This();

        /// ノード配列
        nodes: [max_nodes]VNode = undefined,

        /// 使用中のノード数
        count: usize = 0,

        /// ルートノード ID
        root: u32 = 0,

        /// 新しいノードを作成
        pub fn create(self: *Self, node: VNode) u32 {
            if (self.count >= max_nodes) {
                return 0; // エラー: 最大ノード数超過
            }

            const id = @as(u32, @intCast(self.count));
            self.nodes[self.count] = node;
            self.count += 1;
            return id;
        }

        /// ノードを取得
        pub fn get(self: *const Self, id: u32) ?*const VNode {
            if (id >= self.count) return null;
            return &self.nodes[id];
        }

        /// 子ノードを追加
        pub fn addChild(self: *Self, parent_id: u32, child_id: u32) bool {
            if (parent_id >= self.count or child_id >= self.count) {
                return false;
            }

            var parent = &self.nodes[parent_id];
            if (parent.child_count >= MAX_CHILDREN) {
                return false;
            }

            parent.child_ids[parent.child_count] = child_id;
            parent.child_count += 1;
            return true;
        }

        /// ツリーをリセット
        pub fn reset(self: *Self) void {
            self.count = 0;
            self.root = 0;
        }
    };
}
```

## 差分アルゴリズム

### パッチタイプ

```zig
pub const Patch = union(enum) {
    /// ノードを完全に置換
    replace: VNode,

    /// プロパティのみ更新
    update_props: Props,

    /// テキストを更新
    update_text: []const u8,

    /// 子を挿入
    insert_child: struct { index: usize, node: VNode },

    /// 子を削除
    remove_child: usize,

    /// 子を移動
    move_child: struct { from: usize, to: usize },
};
```

### 差分検出

```zig
pub fn diff(old: VNode, new: VNode, patches: *PatchList) void {
    // 1. タグが異なる場合は完全置換
    if (old.tag != new.tag) {
        patches.append(.{ .replace = new });
        return;
    }

    // 2. テキストノードの場合
    if (old.tag == .text) {
        if (!std.mem.eql(u8, old.text.?, new.text.?)) {
            patches.append(.{ .update_text = new.text.? });
        }
        return;
    }

    // 3. プロパティ差分
    if (!propsEqual(old.props, new.props)) {
        patches.append(.{ .update_props = new.props });
    }

    // 4. 子ノード差分
    diffChildren(old.children, new.children, patches);
}
```

### キー最適化

キー付きリストでは O(n) で効率的な差分検出が可能です。

```zig
fn diffKeyedChildren(old: []const VNode, new: []const VNode, patches: *PatchList) void {
    // キーマップを構築
    var old_key_map: std.StringHashMap(usize) = .{};
    for (old, 0..) |node, i| {
        if (node.key) |k| {
            old_key_map.put(k, i);
        }
    }

    // 新しいリストを走査
    for (new, 0..) |node, new_idx| {
        if (node.key) |k| {
            if (old_key_map.get(k)) |old_idx| {
                if (old_idx != new_idx) {
                    patches.append(.{ .move_child = .{ .from = old_idx, .to = new_idx } });
                }
                // 再帰的に差分検出
                diff(old[old_idx], node, patches);
            } else {
                // 新規ノード
                patches.append(.{ .insert_child = .{ .index = new_idx, .node = node } });
            }
        }
    }

    // 削除されたノードを検出
    for (old, 0..) |node, old_idx| {
        if (node.key) |k| {
            var found = false;
            for (new) |n| {
                if (n.key) |nk| {
                    if (std.mem.eql(u8, k, nk)) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found) {
                patches.append(.{ .remove_child = old_idx });
            }
        }
    }
}
```

## 使用例

### 基本的なツリー構築

```zig
const vdom = @import("vdom.zig");

pub fn buildUI() u32 {
    var tree = vdom.VTree(1024){};

    // コンテナを作成
    var container = vdom.VNode.element(.div);
    container.props.setClass("app-container");
    const container_id = tree.create(container);

    // 見出しを追加
    var heading = vdom.VNode.element(.h1);
    heading.setText("Hello, Zylix!");
    const heading_id = tree.create(heading);
    _ = tree.addChild(container_id, heading_id);

    // ボタンを追加
    var button = vdom.VNode.element(.button);
    button.setText("クリック");
    button.props.on_click = CALLBACK_INCREMENT;
    const button_id = tree.create(button);
    _ = tree.addChild(container_id, button_id);

    tree.root = container_id;
    return container_id;
}
```

### リストレンダリング

```zig
pub fn renderTodoList(tree: *VTree, todos: []const Todo) u32 {
    const list_id = tree.create(vdom.VNode.element(.ul));

    for (todos) |todo| {
        var item = vdom.VNode.element(.li);

        // キーを設定（差分検出の最適化）
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "todo-{d}", .{todo.id}) catch "todo";
        item.setKey(key);

        // 完了状態に応じてクラスを設定
        if (todo.completed) {
            item.props.setClass("todo-item completed");
        } else {
            item.props.setClass("todo-item");
        }

        item.setText(todo.text);
        item.props.on_click = CALLBACK_TOGGLE_TODO + todo.id;

        const item_id = tree.create(item);
        _ = tree.addChild(list_id, item_id);
    }

    return list_id;
}
```

## パフォーマンス特性

| 操作 | 計算量 | メモリ |
|------|--------|--------|
| ノード作成 | O(1) | 64 bytes |
| ツリー構築 | O(n) | n × 64 bytes |
| 差分検出 | O(n) | パッチ数に依存 |
| キー検索 | O(1) | ハッシュマップ使用時 |

## ベストプラクティス

### 1. キーを使用する

リスト内のアイテムには必ずユニークなキーを設定してください。

```zig
// 良い例: ユニークなキー
item.setKey(todo.uuid);

// 悪い例: インデックスをキーに使用
item.setKey(std.fmt.bufPrint(&buf, "{d}", .{index}));
```

### 2. ツリーを浅く保つ

深くネストしたツリーは差分検出のコストが増加します。

```zig
// 良い例: 浅いツリー
container
  ├── header
  ├── content
  └── footer

// 悪い例: 深いツリー
wrapper
  └── inner
      └── deep
          └── content
```

### 3. 条件付きレンダリング

状態に応じて異なるノードを返します。

```zig
pub fn renderContent(loading: bool) VNode {
    if (loading) {
        var spinner = VNode.element(.div);
        spinner.props.setClass("spinner");
        spinner.setText("読み込み中...");
        return spinner;
    } else {
        return renderActualContent();
    }
}
```

## 次のステップ

- **[状態管理](../state-management)**: 状態の管理方法
  - **[コンポーネント](../components)**: 再利用可能な UI
