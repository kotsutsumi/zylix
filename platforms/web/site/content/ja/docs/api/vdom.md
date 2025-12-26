---
title: "仮想DOM"
weight: 4
---

# 仮想DOM

VDOMモジュール（`vdom.zig`）は、キーベースの差分検出を含む効率的なUI調整のための仮想DOM実装を提供します。

## 概要

仮想DOMは、UI構造をツリーとして表現し、前のバージョンと効率的に差分を計算して最小限の更新を算出できます：

```
┌─────────────────────────────────────────────┐
│                 VTree                        │
│  ┌─────────────┐                            │
│  │   VNode     │ ◄── ルートノード            │
│  │  (element)  │                            │
│  └──────┬──────┘                            │
│         │                                    │
│    ┌────┴────┐                              │
│    ▼         ▼                              │
│ ┌──────┐ ┌──────┐                           │
│ │VNode │ │VNode │ ◄── 子ノード              │
│ │(text)│ │(elem)│                           │
│ └──────┘ └──────┘                           │
└─────────────────────────────────────────────┘
```

## 定数

```zig
/// VNodeごとの最大子ノード数
pub const MAX_VNODE_CHILDREN: usize = 64;

/// VNodeごとの最大プロパティ数
pub const MAX_VNODE_PROPS: usize = 16;

/// 最大タグ名長
pub const MAX_TAG_LEN: usize = 32;

/// 最大プロパティキー長
pub const MAX_PROP_KEY_LEN: usize = 32;

/// 最大プロパティ値長
pub const MAX_PROP_VALUE_LEN: usize = 256;

/// キー付き子ノードの最大キー長
pub const MAX_KEY_LEN: usize = 64;

/// 差分ごとの最大パッチ数
pub const MAX_PATCHES: usize = 1024;
```

## 型

### VNode

仮想DOMツリー内の単一ノードを表します。

```zig
pub const VNode = struct {
    /// ノードタイプ（element、textなど）
    node_type: NodeType,

    /// このノードの一意識別子
    dom_id: u32,

    /// 要素タグ名（要素ノード用）
    tag: [MAX_TAG_LEN]u8,
    tag_len: usize,

    /// テキストコンテンツ（テキストノード用）
    text: [MAX_PROP_VALUE_LEN]u8,
    text_len: usize,

    /// 調整用のキー（オプション）
    key: [MAX_KEY_LEN]u8,
    key_len: usize,

    /// プロパティ（属性）
    props: [MAX_VNODE_PROPS]Prop,
    prop_count: usize,

    /// 子ノードのインデックス（VTree.nodes配列へのインデックス）
    children: [MAX_VNODE_CHILDREN]u32,
    child_count: usize,

    /// 要素ノードを作成
    pub fn element(tag: []const u8) VNode;

    /// テキストノードを作成
    pub fn text(content: []const u8) VNode;

    /// 調整用のキーを設定
    pub fn setKey(self: *VNode, k: []const u8) void;

    /// プロパティを追加
    pub fn addProp(self: *VNode, k: []const u8, v: []const u8) void;

    /// キーでプロパティ値を取得
    pub fn getProp(self: *const VNode, k: []const u8) ?[]const u8;

    /// タグをスライスとして取得
    pub fn getTag(self: *const VNode) []const u8;

    /// テキストコンテンツをスライスとして取得
    pub fn getText(self: *const VNode) []const u8;

    /// キーをスライスとして取得
    pub fn getKey(self: *const VNode) []const u8;
};
```

### NodeType

```zig
pub const NodeType = enum(u8) {
    element,
    text,
    component,
    fragment,
};
```

### Prop

ノードプロパティ（属性）を表します。

```zig
pub const Prop = struct {
    key: [MAX_PROP_KEY_LEN]u8,
    key_len: usize,
    value: [MAX_PROP_VALUE_LEN]u8,
    value_len: usize,

    /// キーをスライスとして取得
    pub fn getKey(self: *const Prop) []const u8;

    /// 値をスライスとして取得
    pub fn getValue(self: *const Prop) []const u8;
};
```

### VTree

仮想DOMツリーのコンテナ。

```zig
pub const VTree = struct {
    /// ツリー内のすべてのノード（フラット配列）
    nodes: [MAX_PATCHES]VNode,
    node_count: usize,

    /// ルートノードインデックス
    root: u32,

    /// 変更追跡用のバージョン
    version: u64,

    /// 空のツリーを初期化
    pub fn init() VTree;

    /// ツリーにノードを追加
    pub fn addNode(self: *VTree, node: VNode) !u32;

    /// インデックスでノードを取得
    pub fn getNode(self: *const VTree, index: u32) ?*const VNode;

    /// インデックスで可変ノードを取得
    pub fn getNodeMut(self: *VTree, index: u32) ?*VNode;

    /// 親ノードに子を追加
    pub fn addChild(self: *VTree, parent_idx: u32, child_idx: u32) !void;

    /// バージョンを更新
    pub fn bumpVersion(self: *VTree) void;
};
```

## 差分検出

### Differ

2つの仮想DOMツリー間のパッチを計算します。

```zig
pub const Differ = struct {
    /// 差分で生成されたパッチ
    patches: [MAX_PATCHES]Patch,
    patch_count: usize,

    /// 差分検出器を初期化
    pub fn init() Differ;

    /// 2つのツリー間の差分を計算
    pub fn diff(
        self: *Differ,
        old_tree: *const VTree,
        new_tree: *const VTree
    ) void;

    /// パッチをスライスとして取得
    pub fn getPatches(self: *const Differ) []const Patch;
};
```

### Patch

単一のDOM操作を表します。

```zig
pub const Patch = struct {
    /// パッチ操作のタイプ
    op: PatchOp,

    /// ターゲットDOM ID
    dom_id: u32,

    /// 操作タイプに応じた追加データ
    data: PatchData,
};

pub const PatchOp = enum(u8) {
    none,
    replace,        // ノードを置換
    update_text,    // テキストコンテンツを更新
    update_props,   // プロパティを更新
    insert_child,   // 新しい子を挿入
    remove_child,   // 子を削除
    move_child,     // 子を新しい位置に移動
    remove_node,    // ノードを完全に削除
};

pub const PatchData = union {
    none: void,
    node_index: u32,
    text: [MAX_PROP_VALUE_LEN]u8,
    props: [MAX_VNODE_PROPS]Prop,
    child: ChildPatch,
};

pub const ChildPatch = struct {
    child_dom_id: u32,
    position: u32,
};
```

## キーベースの差分検出

VDOMは効率的なリスト更新のためのキーベースの調整をサポートしています。子にキーがある場合、差分検出器はO(n)のマッチングアルゴリズムを使用します：

### 動作原理

1. **キー検出**: 差分検出器は子にキーがあるかどうかをチェック
2. **キーマップ構築**: キーによる古い子のハッシュマップを作成
3. **マッチング**: 新しい子をキーで古い子とマッチング
4. **パッチ生成**: 移動、追加、削除のための最小限のパッチを生成

### 利点

- **状態の保持**: キー付き要素は再レンダリング間で状態を維持
- **効率的な更新**: 変更された要素のみ更新
- **最適な順序付け**: リストの並べ替えのDOM操作を最小化

### 使用方法

```zig
// キー付き子を作成
var item1 = VNode.element("li");
item1.setKey("item-1");
item1.addProp("class", "list-item");

var item2 = VNode.element("li");
item2.setKey("item-2");
item2.addProp("class", "list-item");

// ツリーに追加
const idx1 = try tree.addNode(item1);
const idx2 = try tree.addNode(item2);
try tree.addChild(parent_idx, idx1);
try tree.addChild(parent_idx, idx2);
```

### キーハッシュ関数

キーはO(1)ルックアップのためにdjb2を使用してハッシュされます：

```zig
fn hashKey(key: []const u8) u32 {
    var hash: u32 = 5381;
    for (key) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }
    return hash;
}
```

## 例

### シンプルなツリーの作成

```zig
const vdom = @import("vdom.zig");

// ツリーを作成
var tree = vdom.VTree.init();

// ルート要素を作成
var root = vdom.VNode.element("div");
root.addProp("id", "app");
root.addProp("class", "container");

// ルートをツリーに追加
const root_idx = try tree.addNode(root);
tree.root = root_idx;

// 子テキストを作成
var text = vdom.VNode.text("Hello, World!");
const text_idx = try tree.addNode(text);

// テキストをルートの子として追加
try tree.addChild(root_idx, text_idx);
```

### ツリーの差分検出

```zig
// 古いツリーを作成
var old_tree = vdom.VTree.init();
var old_root = vdom.VNode.element("div");
var old_text = vdom.VNode.text("Hello");
const old_root_idx = try old_tree.addNode(old_root);
const old_text_idx = try old_tree.addNode(old_text);
old_tree.root = old_root_idx;
try old_tree.addChild(old_root_idx, old_text_idx);

// 更新されたテキストで新しいツリーを作成
var new_tree = vdom.VTree.init();
var new_root = vdom.VNode.element("div");
var new_text = vdom.VNode.text("Hello, World!");
const new_root_idx = try new_tree.addNode(new_root);
const new_text_idx = try new_tree.addNode(new_text);
new_tree.root = new_root_idx;
try new_tree.addChild(new_root_idx, new_text_idx);

// 差分を計算
var differ = vdom.Differ.init();
differ.diff(&old_tree, &new_tree);

// パッチを処理
for (differ.getPatches()) |patch| {
    switch (patch.op) {
        .update_text => {
            // テキストコンテンツを更新
            const text_slice = patch.data.text[0..findLen(patch.data.text)];
            // DOMに適用...
        },
        .insert_child => {
            // 位置に子を挿入
            const child_id = patch.data.child.child_dom_id;
            const position = patch.data.child.position;
            // DOMに適用...
        },
        // 他のパッチタイプを処理...
        else => {},
    }
}
```

### キー付きリストの調整

```zig
// 古いリスト: [A, B, C]
var old_tree = vdom.VTree.init();
var old_list = vdom.VNode.element("ul");
const old_list_idx = try old_tree.addNode(old_list);
old_tree.root = old_list_idx;

var item_a = vdom.VNode.element("li");
item_a.setKey("a");
var item_b = vdom.VNode.element("li");
item_b.setKey("b");
var item_c = vdom.VNode.element("li");
item_c.setKey("c");

// アイテムを追加...

// 新しいリスト: [C, A, B]（並べ替え）
var new_tree = vdom.VTree.init();
// 同じキーだが順序が異なるアイテム...

// 差分は削除/挿入ではなく移動パッチを生成
var differ = vdom.Differ.init();
differ.diff(&old_tree, &new_tree);

// パッチにはmove_child操作が含まれる
for (differ.getPatches()) |patch| {
    if (patch.op == .move_child) {
        // 再作成ではなく効率的に並べ替え
    }
}
```

## プラットフォーム統合

### Web（WASM）

VDOMパッチはJavaScript経由で実際のDOMに適用できます：

```javascript
function applyPatch(patch, domNodes) {
    const target = domNodes.get(patch.dom_id);

    switch (patch.op) {
        case PatchOp.UPDATE_TEXT:
            target.textContent = patch.text;
            break;

        case PatchOp.INSERT_CHILD:
            const newNode = createNode(patch.child_dom_id);
            target.insertBefore(newNode, target.children[patch.position]);
            break;

        case PatchOp.REMOVE_CHILD:
            target.removeChild(domNodes.get(patch.child_dom_id));
            break;

        case PatchOp.MOVE_CHILD:
            const child = domNodes.get(patch.child_dom_id);
            target.insertBefore(child, target.children[patch.position]);
            break;
    }
}
```

### ネイティブプラットフォーム

ネイティブプラットフォームでは、パッチはプラットフォーム固有のUI更新に変換されます：

**iOS（SwiftUI）:**
```swift
// VTreeの変更は@Publishedプロパティの更新をトリガー
// SwiftUIが効率的な再レンダリングを処理
```

**Android（Compose）:**
```kotlin
// VTreeの変更がStateオブジェクトを更新
// Composeが影響を受けるコンポーネントを再コンポーズ
```
