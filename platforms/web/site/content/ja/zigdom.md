---
title: "ZigDom"
weight: 4
---

# ZigDom

**Web実行レイヤーとしてのZig**

> **「JavaScriptはI/O、Zigは実行」**

ZigDomは、ZigをWebアプリケーションの中央実行レイヤーとして位置づけます。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│                  Zigコア (WASM)                     │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ 状態/ロジック   │  │ GPUモジュール           │  │
│  │ - AppState      │  │ - Vec3, Mat4            │  │
│  │ - イベントキュー│  │ - 頂点バッファ          │  │
│  │ - 差分エンジン  │  │ - 変換行列              │  │
│  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────┬───────────────────────────┘
                          │ export fn (ポインタ + サイズ)
                          ▼
┌─────────────────────────────────────────────────────┐
│               WASMリニアメモリ                       │
│  [直接転送可能なGPUアライメント済みバッファ]        │
└─────────────────────────┬───────────────────────────┘
                          │ writeBuffer(ptr, size)
                          ▼
┌─────────────────────────────────────────────────────┐
│            JavaScriptブリッジレイヤー                │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ DOM操作         │  │ WebGPU API             │  │
│  │ - イベントバインド│  │ - device.createBuffer  │  │
│  │ - UI更新        │  │ - queue.writeBuffer    │  │
│  └─────────────────┘  │ - renderPass.draw      │  │
│                       └─────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 機能

### 完了済み (Phase 5)

| 機能 | 状態 | 説明 |
|------|------|------|
| CSSユーティリティ | ✅ | ZigでTailwindCSS風システム |
| レイアウトエンジン | ✅ | ZigでFlexboxアルゴリズム |
| コンポーネントシステム | ✅ | React風コンポーネント |
| 宣言的UI DSL | ✅ | Zig comptimeでUI宣言 |
| WebGPU Compute | ✅ | 5万パーティクル @ 60fps |

### 今後

| 機能 | 状態 | 説明 |
|------|------|------|
| 仮想DOM | 予定 | Zigで差分計算 |

## CSSユーティリティシステム

ZigでTailwindCSS風ユーティリティ：

```zig
const style = css.Style.flex()
    .bg(css.colors.blue._500)
    .p(.p4)
    .rounded(.lg)
    .shadow(.md);

// 生成: display: flex; background-color: #3b82f6; padding: 1rem; ...
```

## レイアウトエンジン

ZigでFlexbox計算：

```zig
const container = layout.createNode();
layout.setFlexDirection(container, .row);
layout.setJustifyContent(container, .space_between);
layout.setGap(container, 16);

// 子要素を追加
layout.addChild(container, child1);
layout.addChild(container, child2);

// レイアウト計算
layout.compute(800, 600);

// 結果はZigメモリで利用可能
const x = layout.getX(child1);
const y = layout.getY(child1);
```

## コンポーネントシステム

ZigでReact風コンポーネント：

```zig
const card = Component.container()
    .withStyle(cardStyle);

const title = Component.heading(.h2, "ようこそ")
    .withStyle(titleStyle);

const button = Component.button("クリック")
    .withStyle(btnStyle)
    .onClick(handleClick);

tree.addChild(card, title);
tree.addChild(card, button);
```

## 宣言的UI DSL

Zig comptimeを使用したJSX風の宣言的構文：

```zig
const dsl = @import("dsl.zig");

// シンプルな要素ビルダー
const ui = dsl.div(.{ .class = "container" }, .{
    dsl.h1(.{}, "ZigDomへようこそ"),
    dsl.p(.{}, "Zigのcomptimeで型安全なUI構築！"),
    dsl.button(.{ .onClick = 1 }, "クリック"),
});

// shadcn風プリビルトコンポーネント
const card = dsl.ui.card(.{}, .{
    dsl.ui.cardHeader(.{}, .{
        dsl.ui.cardTitle(.{}, "カードタイトル"),
    }),
    dsl.ui.cardContent(.{}, .{
        dsl.p(.{}, "カードの内容はここに。"),
    }),
    dsl.ui.cardFooter(.{}, .{
        dsl.ui.primaryButton(.{ .onClick = 2 }, "送信"),
    }),
});
```

### 利用可能な要素

| カテゴリ | 要素 |
|----------|------|
| コンテナ | `div`, `span`, `section`, `article`, `header`, `footer`, `nav`, `main`, `aside` |
| テキスト | `h1`-`h6`, `p`, `text` |
| インタラクティブ | `button`, `a`, `input` |
| リスト | `ul`, `ol`, `li` |
| フォーム | `form`, `label` |
| メディア | `img` |

### プリビルトUIコンポーネント

| コンポーネント | 説明 |
|----------------|------|
| `ui.card` | ヘッダー/コンテンツ/フッター付きカード |
| `ui.primaryButton` | プライマリアクションボタン |
| `ui.secondaryButton` | セカンダリアクションボタン |
| `ui.textInput` | テキスト入力フィールド |
| `ui.alert` | アラート/通知ボックス |
| `ui.badge` | バッジ/タグコンポーネント |
| `ui.flex` | Flexboxコンテナ |
| `ui.grid` | Gridコンテナ |
| `ui.stack` | 縦方向スタックレイアウト |

## WebGPU統合

ゼロコピーデータ転送：

```javascript
// JavaScriptはポインタを移動するだけ
const vertexPtr = wasm.zigdom_gpu_get_vertex_buffer();
const vertexSize = wasm.zigdom_gpu_get_vertex_buffer_size();

device.queue.writeBuffer(
    gpuBuffer,
    0,
    wasmMemory.buffer,
    vertexPtr,
    vertexSize
);
```

## WASMエクスポート

### 状態 & イベント
```zig
export fn zylix_init() i32
export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque, len: usize) i32
```

### CSS
```zig
export fn zigdom_css_create_style() u32
export fn zigdom_css_set_display(id: u32, display: u8) void
export fn zigdom_css_generate(id: u32) ?[*]const u8
```

### レイアウト
```zig
export fn zigdom_layout_create_node() u32
export fn zigdom_layout_compute(width: f32, height: f32) void
export fn zigdom_layout_get_x(id: u32) f32
```

### コンポーネント
```zig
export fn zigdom_component_create_button(ptr: [*]const u8, len: usize) u32
export fn zigdom_component_on_click(id: u32, callback_id: u32) void
export fn zigdom_component_render(root_id: u32) void
```

### GPU
```zig
export fn zigdom_gpu_update(delta_time: f32) void
export fn zigdom_gpu_get_vertex_buffer() ?*const anyopaque
export fn zigdom_gpu_get_vertex_buffer_size() usize
```

### DSL
```zig
export fn zigdom_dsl_init() void
export fn zigdom_dsl_create_container(element_type: u8) u32
export fn zigdom_dsl_create_text_element(element_type: u8, ptr: [*]const u8, len: usize) u32
export fn zigdom_dsl_set_class(id: u32, ptr: [*]const u8, len: usize) void
export fn zigdom_dsl_add_child(parent_id: u32, child_id: u32) bool
export fn zigdom_dsl_build(element_id: u32) u32
```

## ライブデモ

- [カウンターデモ](/demos/counter.html)
- [CSSデモ](/demos/css-demo.html)
- [レイアウトデモ](/demos/layout-demo.html)
- [コンポーネントデモ](/demos/component-demo.html)
- [DSLデモ](/demos/dsl-demo.html)
- [WebGPUキューブ](/demos/webgpu.html)
- [パーティクル](/demos/particles.html)
