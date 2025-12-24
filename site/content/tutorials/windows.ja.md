---
title: Windows チュートリアル
weight: 6
---

## 概要

WinUI 3 のデモアプリを Windows で動かします。

## 前提条件

- Windows 10 1809+ または Windows 11
- Visual Studio 2022
- .NET 8 SDK
- Windows App SDK
- Zig 0.15+

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Zig コアをビルド

```bash
cd core
zig build windows-x64 -Doptimize=ReleaseFast
```

## 3. アプリをビルド＆実行

```bash
cd ../platforms/windows
# Visual Studio で Zylix/Zylix.csproj を開く
```

Visual Studio から実行します（F5）。

## 4. 状態更新を確認

Counter または Todo 画面で更新が即時に反映されることを確認します。

主なファイル:

- `platforms/windows/Zylix/ZylixBridge.cs`（P/Invoke ブリッジ）
- `platforms/windows/Zylix/MainWindow.xaml`（Counter UI）
- `platforms/windows/Zylix/TodoWindow.xaml`（Todo UI）

## トラブルシューティング

- ビルド失敗: Windows App SDK と .NET 8 を確認。
- Zig が無い: Zig 0.15+ を導入し `zig version` を確認。

## 次のステップ

- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
- [プラットフォームガイド](/docs/platforms/windows/)
