---
title: "Zylix"
type: docs
---

# Zylix

**ネイティブUIを尊重する、Zig駆動のクロスプラットフォームランタイム**

> 「UIを共通化せず、意味と判断だけを共通化する」

Zylixは、Zigを中核とした「UI非依存・OS尊重型」クロスプラットフォーム実行基盤です。各OSの標準UIを尊重しながら、アプリケーションの状態・ロジック・意味をZigに集約します。

## 主な特徴

- **ネイティブUI**: SwiftUI、Jetpack Compose、WinUI、GTK - カスタムレンダリングなし
- **ゼロランタイム**: VM不要、GC不要、予測可能な実行
- **超軽量バイナリ**: コアライブラリ 10KB未満 (ReleaseSmall)
- **真のクロスプラットフォーム**: iOS, Android, macOS, Windows, Linux, Web

## アーキテクチャ

```
┌─────────────────────────────┐
│     Zylix Core (Zig)        │
│  - 状態管理                 │
│  - ビジネスロジック         │
│  - イベント処理             │
└─────────────┬───────────────┘
              │ C ABI
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌─────────┐ ┌────────┐ ┌────────┐
│   iOS   │ │Android │ │  Web   │
│ SwiftUI │ │Compose │ │  WASM  │
└─────────┘ └────────┘ └────────┘
```

## クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# 全プラットフォーム向けにビルド
cd core
zig build all
```

## ドキュメント

### コンセプト
- [コンセプト]({{< relref "concept" >}}) - 基本思想
- [なぜJavaScriptではないのか？]({{< relref "why-not-js" >}}) - 技術比較
- [アーキテクチャ]({{< relref "architecture" >}}) - システム設計
- [ZigDom]({{< relref "zigdom" >}}) - Webプラットフォーム実装

### APIリファレンス
- [APIリファレンス]({{< relref "docs/api" >}}) - 完全なAPIドキュメント
  - [C ABI]({{< relref "docs/api/abi" >}}) - プラットフォーム統合インターフェース
  - [状態管理]({{< relref "docs/api/state" >}}) - アプリケーション状態
  - [イベント]({{< relref "docs/api/events" >}}) - イベントディスパッチ
  - [Virtual DOM]({{< relref "docs/api/vdom" >}}) - UI差分更新
  - [アニメーション]({{< relref "docs/api/animation" >}}) - アニメーションシステム
  - [AIモジュール]({{< relref "docs/api/ai" >}}) - AI/MLバックエンド
