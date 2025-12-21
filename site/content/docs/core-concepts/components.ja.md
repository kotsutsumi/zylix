---
title: コンポーネント
weight: 3
---

コンポーネントは Zylix の再利用可能な UI 構成要素です。構造、スタイル、動作をカプセル化し、任意のプラットフォームにレンダリングできる合成可能なユニットです。

## コンポーネントタイプ

Zylix は一般的な UI 要素用の組み込みコンポーネントタイプを提供します。

```zig
pub const ComponentType = enum(u8) {
    container = 0,   // div 相当のコンテナ
    text = 1,        // text/span 要素
    button = 2,      // クリック可能なボタン
    input = 3,       // テキスト入力フィールド
    image = 4,       // 画像要素
    link = 5,        // アンカーリンク
    list = 6,        // ul/ol リスト
    list_item = 7,   // li アイテム
    heading = 8,     // h1-h6
    paragraph = 9,   // p 要素
    custom = 255,    // カスタムコンポーネント
};
```

## コンポーネント状態

各コンポーネントはインタラクティブな状態を追跡します。

```zig
pub const ComponentState = packed struct {
    hover: bool = false,      // マウスがコンポーネント上にある
    focus: bool = false,      // コンポーネントがフォーカスを持つ
    active: bool = false,     // 押下/クリック中
    disabled: bool = false,   // インタラクション不可
    checked: bool = false,    // チェックボックス/ラジオ用
    expanded: bool = false,   // 展開可能なコンポーネント用
    loading: bool = false,    // ローディング表示
    error_state: bool = false, // エラー表示
};
```

## コンポーネントプロパティ

### 共通プロパティ

```zig
pub const ComponentProps = extern struct {
    // ID
    id: u32 = 0,                    // ユニークなコンポーネント ID

    // スタイル用クラス名
    class_name: TextBuffer = std.mem.zeroes(TextBuffer),
    class_name_len: u16 = 0,

    // テキストコンテンツ
    text: TextBuffer = std.mem.zeroes(TextBuffer),
    text_len: u16 = 0,

    // スタイル参照
    style_id: u32 = 0,              // デフォルトスタイル
    hover_style_id: u32 = 0,        // ホバー時
    focus_style_id: u32 = 0,        // フォーカス時
    active_style_id: u32 = 0,       // アクティブ時
    disabled_style_id: u32 = 0,     // 無効時

    // レイアウト参照
    layout_id: u32 = 0,
};
```

### 入力プロパティ

```zig
pub const ComponentProps = extern struct {
    // ... 共通プロパティ ...

    // 入力固有
    input_type: InputType = .text,
    placeholder: TextBuffer = std.mem.zeroes(TextBuffer),
    placeholder_len: u16 = 0,
    value: TextBuffer = std.mem.zeroes(TextBuffer),
    value_len: u16 = 0,
    max_length: u16 = 0,
};

pub const InputType = enum(u8) {
    text = 0,
    password = 1,
    email = 2,
    number = 3,
    search = 4,
    tel = 5,
    url = 6,
    checkbox = 7,
    radio = 8,
};
```

### 見出しプロパティ

```zig
pub const ComponentProps = extern struct {
    // ... 共通プロパティ ...

    // 見出し固有
    heading_level: HeadingLevel = .h1,
};

pub const HeadingLevel = enum(u8) {
    h1 = 1, h2 = 2, h3 = 3,
    h4 = 4, h5 = 5, h6 = 6,
};
```

## イベントハンドラ

コンポーネントは複数のイベントハンドラを持つことができます。

```zig
pub const EventHandler = struct {
    event_type: EventType = .none,
    callback_id: u32 = 0,           // コールバック検索用 ID
    prevent_default: bool = false,
    stop_propagation: bool = false,
};

pub const MAX_EVENT_HANDLERS = 8;
```

### イベントタイプ

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

## コンポーネントツリー

コンポーネントは階層的なツリー構造を形成します。

```zig
pub const Component = struct {
    id: u32 = 0,
    component_type: ComponentType = .container,
    props: ComponentProps = .{},
    state: ComponentState = .{},
    handlers: [MAX_EVENT_HANDLERS]EventHandler = undefined,
    handler_count: u8 = 0,

    // ツリー構造
    parent_id: u32 = 0,
    children: [MAX_CHILDREN]u32 = undefined,
    child_count: u16 = 0,
};
```

## コンポーネントの作成

### コンテナ

```zig
fn createContainer(tree: *VTree, class: []const u8) u32 {
    var node = VNode.element(.div);
    node.props.setClass(class);
    return tree.create(node);
}

// 使用例
const container = createContainer(tree, "main-container");
```

### ボタン

```zig
fn createButton(
    tree: *VTree,
    text: []const u8,
    onclick_id: u32
) u32 {
    var node = VNode.element(.button);
    node.setText(text);
    node.props.on_click = onclick_id;
    node.props.setClass("btn");
    return tree.create(node);
}

// 使用例
const button = createButton(tree, "クリック", CALLBACK_INCREMENT);
```

### 入力フィールド

```zig
fn createInput(
    tree: *VTree,
    placeholder: []const u8,
    oninput_id: u32
) u32 {
    var node = VNode.element(.input);
    node.props.setPlaceholder(placeholder);
    node.props.on_input = oninput_id;
    node.props.setClass("text-input");
    return tree.create(node);
}

// 使用例
const input = createInput(tree, "タスクを入力...", CALLBACK_TEXT_INPUT);
```

### リスト

```zig
fn createList(tree: *VTree, items: []const Item) u32 {
    const list_id = tree.create(VNode.element(.ul));

    for (items) |item| {
        const item_id = createListItem(tree, item);
        _ = tree.addChild(list_id, item_id);
    }

    return list_id;
}

fn createListItem(tree: *VTree, item: Item) u32 {
    var node = VNode.element(.li);

    // 効率的な更新のためにキーを設定
    var key_buf: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&key_buf, "item-{d}", .{item.id}) catch "item";
    node.setKey(key);

    // テキストを追加
    const text_id = tree.create(VNode.textNode(item.text));
    const item_id = tree.create(node);
    _ = tree.addChild(item_id, text_id);

    return item_id;
}
```

## コンポーネントパターン

### 複合コンポーネント

シンプルなコンポーネントから複雑なコンポーネントを構築します。

```zig
fn createTodoItem(tree: *VTree, todo: Todo) u32 {
    // コンテナ
    var container = VNode.element(.li);
    container.setKey(todo.id_str);
    if (todo.completed) {
        container.props.setClass("todo-item completed");
    } else {
        container.props.setClass("todo-item");
    }
    const container_id = tree.create(container);

    // チェックボックス
    var checkbox = VNode.element(.input);
    checkbox.props.input_type = @intFromEnum(InputType.checkbox);
    checkbox.props.on_change = CALLBACK_TOGGLE;
    const checkbox_id = tree.create(checkbox);

    // テキスト
    const text_id = tree.create(VNode.textNode(todo.text));

    // 削除ボタン
    var delete_btn = VNode.element(.button);
    delete_btn.setText("×");
    delete_btn.props.on_click = CALLBACK_DELETE;
    delete_btn.props.setClass("delete-btn");
    const delete_id = tree.create(delete_btn);

    // 組み立て
    _ = tree.addChild(container_id, checkbox_id);
    _ = tree.addChild(container_id, text_id);
    _ = tree.addChild(container_id, delete_id);

    return container_id;
}
```

### 条件付きレンダリング

```zig
fn createLoadingOrContent(tree: *VTree, loading: bool, content: []const u8) u32 {
    if (loading) {
        var spinner = VNode.element(.div);
        spinner.props.setClass("spinner");
        spinner.setText("読み込み中...");
        return tree.create(spinner);
    } else {
        return tree.create(VNode.textNode(content));
    }
}
```

### リストレンダリング

```zig
fn renderTodoList(tree: *VTree, todos: []const Todo, filter: Filter) u32 {
    const list_id = tree.create(VNode.element(.ul));

    for (todos) |todo| {
        // フィルター適用
        const show = switch (filter) {
            .all => true,
            .active => !todo.completed,
            .completed => todo.completed,
        };

        if (show) {
            const item_id = createTodoItem(tree, todo);
            _ = tree.addChild(list_id, item_id);
        }
    }

    return list_id;
}
```

## レンダーコマンド

コンポーネントはプラットフォーム実行用のレンダーコマンドを生成します。

```zig
pub const RenderCommandType = enum(u8) {
    none = 0,
    create_element = 1,
    create_text = 2,
    update_text = 3,
    set_attribute = 4,
    remove_attribute = 5,
    add_class = 6,
    remove_class = 7,
    set_style = 8,
    append_child = 9,
    insert_before = 10,
    remove_child = 11,
    add_event_listener = 12,
    remove_event_listener = 13,
    set_property = 14,
};
```

## プラットフォームレンダリング

各プラットフォームはコンポーネントを異なる方法で解釈します。

### Web (JavaScript)

```javascript
function applyCommand(cmd) {
    switch (cmd.type) {
        case 'create_element':
            return document.createElement(cmd.tag);
        case 'create_text':
            return document.createTextNode(cmd.text);
        case 'set_attribute':
            element.setAttribute(cmd.name, cmd.value);
            break;
        case 'add_event_listener':
            element.addEventListener(cmd.event, callback);
            break;
    }
}
```

### iOS (SwiftUI)

```swift
struct ZylixComponent: View {
    let component: ComponentData

    var body: some View {
        switch component.type {
        case .container:
            VStack { renderChildren() }
        case .button:
            Button(component.text) { handleClick() }
        case .input:
            TextField(component.placeholder, text: $text)
        case .text:
            Text(component.text)
        }
    }
}
```

### Android (Compose)

```kotlin
@Composable
fun ZylixComponent(component: ComponentData) {
    when (component.type) {
        ComponentType.Container -> Column { renderChildren() }
        ComponentType.Button -> Button(onClick = { handleClick() }) {
            Text(component.text)
        }
        ComponentType.Input -> TextField(
            value = text,
            onValueChange = { handleInput(it) }
        )
        ComponentType.Text -> Text(component.text)
    }
}
```

## ベストプラクティス

### 1. コンポーネントを単一責任に保つ

```zig
// 良い例: 単一責任
fn createHeader(tree: *VTree, title: []const u8) u32 { ... }
fn createNavigation(tree: *VTree, items: []NavItem) u32 { ... }
fn createFooter(tree: *VTree, year: u32) u32 { ... }

// 悪い例: モノリシックなコンポーネント
fn createEntirePage(tree: *VTree, everything: Everything) u32 { ... }
```

### 2. 意味のあるキーを使用

```zig
// 良い例: 安定したユニークなキー
node.setKey(item.uuid);

// 悪い例: インデックスベースのキー
node.setKey(std.fmt.bufPrint(&buf, "{d}", .{index}));
```

### 3. 再利用可能なパターンを抽出

```zig
// 良い例: 再利用可能なボタンファクトリ
fn createIconButton(
    tree: *VTree,
    icon: []const u8,
    label: []const u8,
    callback: u32
) u32 {
    var btn = VNode.element(.button);
    btn.props.setClass("icon-btn");
    btn.props.on_click = callback;
    // ... アイコンとラベルのセットアップ
    return tree.create(btn);
}
```

## 次のステップ

- **[イベント](../events)**: コンポーネントのインタラクションを処理
  - **[状態管理](../state-management)**: コンポーネントと状態を接続
