---
title: Web/WASM チュートリアル
weight: 1
---

## 概要

WebAssembly で Zylix のカウンターアプリをブラウザで動かします。

## 前提条件

- Zig 0.15+
- モダンブラウザ

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Web サンプルをビルド

```bash
cd samples/counter-wasm
./build.sh
```

`samples/counter-wasm/zylix.wasm` を生成し、`samples/counter-wasm/zylix.js` がブリッジになります。

## 3. 実行

```bash
python3 -m http.server 8080
# http://localhost:8080 を開く
```

## 4. 状態更新を確認

+/- ボタンを押してカウンターが更新されることを確認します。

主なファイル:

- `samples/counter-wasm/index.html`（UIシェル）
- `samples/counter-wasm/zylix.js`（WASMブリッジ）

## トラブルシューティング

- WASM が読み込めない: `./build.sh` を再実行し `zylix.wasm` を確認。
- 画面が表示されない: `file://` ではなく HTTP サーバーを使用。

## 次のステップ

- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
- [API リファレンス](/docs/api-reference/)
