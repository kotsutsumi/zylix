---
title: Linux チュートリアル
weight: 5
---

## 概要

GTK4 の Todo/Counter デモを Linux で動かします。

## 前提条件

- GTK 4.0+
- GCC または Clang
- pkg-config
- Make

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. GTK アプリをビルド

```bash
cd platforms/linux/zylix-gtk
make
```

## 3. 実行

```bash
make run-counter
# または
make run-todo
```

## 4. 状態更新を確認

カウンター操作または Todo 追加で UI が更新されることを確認します。

主なファイル:

- `platforms/linux/zylix-gtk/main.c`（Counter UI）
- `platforms/linux/zylix-gtk/todo_app.c`（Todo UI）

## トラブルシューティング

- ビルド失敗: GTK4 開発パッケージと `pkg-config` を確認。
- 起動しない: `./build/zylix-counter` を直接実行してエラーを確認。

## 次のステップ

- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
- [プラットフォームガイド](/docs/platforms/linux/)
