---
title: iOS チュートリアル
weight: 2
---

## 概要

SwiftUI と C ABI ブリッジで Zylix デモアプリを iOS で動かします。

## 前提条件

- macOS 12+
- Xcode 14+
- XcodeGen

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Zig コアをビルド

```bash
cd platforms/ios
./build-zig.sh
```

`platforms/ios/lib/libzylix.a` が生成されます。

## 3. Xcode プロジェクトを開く

```bash
open Zylix.xcodeproj
```

## 4. 実行

シミュレータまたは実機を選んで `Zylix` スキームを実行します。

## 5. 状態更新を確認

Counter タブで +/− を押してカウンターが更新されることを確認します。

主なファイル:

- `platforms/ios/Zylix/Sources/ContentView.swift`（Counter UI）
- `platforms/ios/Zylix/Sources/ZylixBridge.swift`（C ABI ブリッジ）

## トラブルシューティング

- ビルド失敗: `./build-zig.sh` 後に `lib/libzylix.a` を確認。
- XcodeGen が無い: `brew install xcodegen`。

## 次のステップ

- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
- [ABI 仕様](/docs/ABI.md)
