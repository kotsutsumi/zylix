---
title: macOS チュートリアル
weight: 4
---

## 概要

macOS 向けの SwiftUI デモアプリを実行し、Todo フローを確認します。

## 前提条件

- macOS 13+
- Xcode 16+
- XcodeGen

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Xcode プロジェクトを生成

```bash
cd platforms/macos
xcodegen generate
```

## 3. ビルド＆実行

```bash
open Zylix.xcodeproj
```

Xcode で `Zylix` スキームを実行します。

## 4. 状態更新を確認

Todo を追加してリストが即時に更新されることを確認します。

主なファイル:

- `platforms/macos/Zylix/Sources/TodoView.swift`（Todo UI）
- `platforms/macos/Zylix/Sources/TodoViewModel.swift`（状態モデル）

## トラブルシューティング

- XcodeGen が無い: `brew install xcodegen`。
- ビルド失敗: Xcode 16+ を確認。

## 次のステップ

- [アーキテクチャ](/docs/architecture/)
- [状態管理](/docs/core-concepts/state-management/)
- [プラットフォームガイド](/docs/platforms/macos/)
