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
| WebGPU Compute | ✅ | 5万パーティクル @ 60fps |

### 今後

| 機能 | 状態 | 説明 |
|------|------|------|
| 宣言的UI DSL | 予定 | Zig comptimeでUI |
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

## ライブデモ

- [カウンターデモ](/demos/counter.html)
- [CSSデモ](/demos/css-demo.html)
- [レイアウトデモ](/demos/layout-demo.html)
- [コンポーネントデモ](/demos/component-demo.html)
- [WebGPUキューブ](/demos/webgpu.html)
- [パーティクル](/demos/particles.html)
