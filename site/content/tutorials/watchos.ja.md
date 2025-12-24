---
title: watchOS チュートリアル
weight: 7
---

## 概要

SwiftUI と C ABI ブリッジで watchOS のカウンターデモを実行します。

## ステータス

**In Development** — 最小のカウンター実装です。

## 前提条件

- macOS 13+
- Xcode 15+（watchOS SDK）
- Zig 0.15+

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. watchOS 向けにコアをビルド

```bash
cd core
zig build watchos-sim
```

`core/zig-out/watchos-simulator/libzylix.a` が生成されます。

## 3. ライブラリをコピー

```bash
cp core/zig-out/watchos-simulator/libzylix.a platforms/watchos/ZylixWatch/Libraries/
```

## 4. Xcode プロジェクトを開く

```bash
cd platforms/watchos
open ZylixWatch.xcodeproj
```

## 5. 実行

watchOS シミュレータを選んで `ZylixWatch` ターゲットを実行します。

## 6. 状態更新を確認

+ / - / Reset でカウンターが更新されることを確認します。

## トラブルシューティング

- ビルド失敗: `ZylixWatch/Libraries/` に `libzylix.a` があるか確認。
- シミュレータが無い: Xcode の設定で watchOS Runtime を追加。

## 主なファイル

- `platforms/watchos/ZylixWatch/Sources/ContentView.swift`
- `platforms/watchos/ZylixWatch/Sources/ZylixBridge.swift`
- `platforms/watchos/ZylixWatch/Sources/Zylix-Bridging-Header.h`

## 次のステップ

- [プラットフォームガイド](/docs/platforms/watchos/)
- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
