---
title: コア概念
weight: 3
prev: architecture
next: platforms
sidebar:
  open: true
---

Zylix の技術的な基盤を理解するためのコア概念を解説します。

## 概要

Zylix は 4 つの主要コンポーネントで構成されています：

```mermaid
flowchart TB
    User["👆 ユーザー操作<br/>(タップ、クリック、入力、スクロール)"]

    subgraph Shell1["プラットフォームシェル (Swift, Kotlin, JS, C#, C)"]
        Convert["ネイティブイベントを Zylix イベントに変換"]
        Call["呼び出し: zylix_dispatch(event_type, payload)"]
    end

    subgraph Dispatcher["イベントディスパッチャ"]
        Route["イベントを適切なハンドラにルーティング"]
        Validate["イベントペイロードを検証"]
    end

    subgraph Store["状態ストア"]
        Transition["状態遷移を適用"]
        Version["バージョン番号を増加"]
        Trigger["再レンダリングをトリガー"]
    end

    subgraph Builder["Virtual DOM ビルダー"]
        Construct["状態から新しい VNode ツリーを構築"]
        Render["コンポーネントレンダー関数を使用"]
    end

    subgraph Differ["差分アルゴリズム"]
        Compare["旧ツリーと新ツリーを比較"]
        Generate["最小限のパッチセットを生成"]
    end

    subgraph Shell2["プラットフォームシェル"]
        Receive["zylix_get_patches() でパッチを受信"]
        Apply["ネイティブ UI 要素にパッチを適用"]
    end

    Updated["✨ UI 更新完了<br/>ユーザーが変更を確認"]

    User --> Shell1
    Shell1 --> Dispatcher
    Dispatcher --> Store
    Store --> Builder
    Builder --> Differ
    Differ --> Shell2
    Shell2 --> Updated
```

## コア概念

{{< cards >}}
  {{< card link="virtual-dom" title="Virtual DOM" subtitle="仮想 DOM エンジンの仕組み" >}}
  {{< card link="state-management" title="状態管理" subtitle="集中型ストアとバージョン追跡" >}}
  {{< card link="components" title="コンポーネント" subtitle="再利用可能な UI 部品" >}}
  {{< card link="events" title="イベントシステム" subtitle="型安全なイベント処理" >}}
{{< /cards >}}

## 設計原則

### 1. 不変性 (Immutability)

状態と Virtual DOM ノードは不変です。変更は新しいバージョンの作成を意味します。

```zig
// 状態は直接変更されず、新しいバージョンが作成される
const old_version = state.getVersion();
handleIncrement();
const new_version = state.getVersion();
// new_version == old_version + 1
```

### 2. 型安全 (Type Safety)

Zig のコンパイル時型チェックにより、ランタイムエラーを防ぎます。

```zig
// 判別共用体による型安全なイベント
pub const Event = union(enum) {
    todo_add: []const u8,   // 文字列ペイロード
    todo_toggle: u32,        // ID ペイロード
    todo_clear_completed,    // ペイロードなし
};
```

### 3. ゼロアロケーション (Zero Allocation)

ホットパスではヒープアロケーションを行いません。

```zig
// アリーナアロケーションで予測可能なパフォーマンス
var arena = Arena(4096).init();
defer arena.reset();

// すべてのアロケーションはアリーナから
const nodes = arena.alloc(VNode, 100);
```

### 4. 単一責任 (Single Responsibility)

各モジュールは明確な責任を持ちます。

| モジュール | 責任 |
|-----------|------|
| `vdom.zig` | Virtual DOM ツリーの構築と管理 |
| `diff.zig` | 旧新ツリーの比較とパッチ生成 |
| `state.zig` | アプリケーション状態の管理 |
| `events.zig` | イベント定義と処理 |
| `abi.zig` | C ABI エクスポート |

## アーキテクチャパターン

### Elm アーキテクチャ

Zylix は Elm アーキテクチャ（Model-View-Update）に基づいています：

```mermaid
flowchart TB
    subgraph Elm["Elm アーキテクチャ"]
        Model["Model<br/>(状態)"]
        View["View<br/>(描画)"]
        Update["Update<br/>(更新)"]
        Message["Message<br/>(イベント)"]

        Model --> View
        Model --> Update
        Message --> Update
        Update --> Model
        View --> Message
    end
```

- **Model**: 不変のアプリケーション状態
- **View**: 状態から UI を構築
- **Update**: イベントに基づいて状態を更新
- **Message**: ユーザーアクションや外部イベント

## パフォーマンス特性

| 操作 | 計算量 | 説明 |
|------|--------|------|
| ノード作成 | O(1) | バンプアロケーション |
| ツリー差分 | O(n) | 線形時間比較 |
| キー付きリスト | O(n) | ハッシュマップによる最適化 |
| 状態更新 | O(1) | 直接代入 |
| イベント処理 | O(1) | switch 文による分岐 |

## メモリ使用量

| コンポーネント | サイズ |
|---------------|-------|
| VNode | 64 bytes |
| VTree (1000 ノード) | ~64 KB |
| AppState | ~4 KB |
| Arena (デフォルト) | 4 KB |

## 次のステップ

各コア概念の詳細については、以下のページを参照してください：

{{< cards >}}
  {{< card link="virtual-dom" title="Virtual DOM" subtitle="仮想 DOM の詳細" >}}
  {{< card link="state-management" title="状態管理" subtitle="ストアの仕組み" >}}
  {{< card link="components" title="コンポーネント" subtitle="UI 構築パターン" >}}
  {{< card link="events" title="イベント" subtitle="イベント処理の詳細" >}}
{{< /cards >}}
