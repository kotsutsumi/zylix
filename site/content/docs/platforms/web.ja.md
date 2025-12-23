---
title: Web/WASM
weight: 1
---

WebAssembly を使用して Zylix アプリケーションを Web にビルドしてデプロイします。このガイドでは、プロジェクトのセットアップ、WASM コンパイル、JavaScript 統合、デプロイ戦略について説明します。

## 前提条件

始める前に、以下がインストールされていることを確認してください：

- **Zig** 0.15.0 以降
- **Node.js** 18+（開発サーバー用）
- WASM をサポートするモダンブラウザ
- JavaScript と HTML の基本知識

```bash
# Zig インストールの確認
zig version

# Node.js インストールの確認
node --version
```

## プロジェクト構造

典型的な Zylix Web プロジェクトの構造：

```
my-zylix-app/
├── core/                    # Zig ソースコード
│   ├── src/
│   │   ├── main.zig        # エントリーポイント
│   │   ├── app.zig         # アプリケーションロジック
│   │   ├── vdom.zig        # Virtual DOM
│   │   └── state.zig       # 状態管理
│   └── build.zig           # ビルド設定
├── web/                     # Web アセット
│   ├── index.html          # HTML エントリーポイント
│   ├── zylix.js            # JavaScript グルーコード
│   └── styles.css          # スタイル
└── dist/                    # ビルド出力
    └── zylix.wasm          # コンパイル済み WASM
```

## Web 向けビルド

### ステップ 1: ビルド設定

WASM ターゲット用に `build.zig` を作成または更新：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // WASM ターゲット
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zylix",
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    // JavaScript 用に関数をエクスポート
    exe.rdynamic = true;
    exe.entry = .disabled;

    // アーティファクトをインストール
    b.installArtifact(exe);
}
```

### ステップ 2: 関数のエクスポート

`main.zig` で JavaScript 用の関数をエクスポート：

```zig
const std = @import("std");

// 初期化関数をエクスポート
export fn zylix_init() i32 {
    // アプリケーション状態を初期化
    state.init();
    return 0;
}

// イベントディスパッチ関数をエクスポート
export fn zylix_dispatch(event_type: u32, payload: ?*anyopaque, len: usize) i32 {
    return handleEvent(event_type, payload, len);
}

// 状態取得関数をエクスポート
export fn zylix_get_state() ?*const State {
    return state.getState();
}

// レンダリング関数をエクスポート
export fn zylix_render() i32 {
    return vdom.render();
}

// JavaScript 用メモリ割り当て
export fn zylix_alloc(len: usize) ?[*]u8 {
    const slice = allocator.alloc(u8, len) catch return null;
    return slice.ptr;
}

// メモリ解放
export fn zylix_free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}
```

### ステップ 3: WASM ビルド

```bash
# サイズ最適化でビルド
zig build -Doptimize=ReleaseSmall

# 出力: zig-out/bin/zylix.wasm
```

## JavaScript 統合

### WASM モジュールのロード

WASM ロードと DOM 操作用の `zylix.js` を作成：

```javascript
class Zylix {
    constructor() {
        this.wasm = null;
        this.memory = null;
        this.elements = new Map();
        this.nextElementId = 1;
    }

    async init(wasmPath) {
        const response = await fetch(wasmPath);
        const buffer = await response.arrayBuffer();

        const imports = {
            env: {
                // ログ出力
                js_log: (ptr, len) => {
                    console.log(this.readString(ptr, len));
                },

                // DOM 操作
                js_create_element: (tagPtr, tagLen, parentId) => {
                    const tag = this.readString(tagPtr, tagLen);
                    const element = document.createElement(tag);
                    const id = this.nextElementId++;
                    this.elements.set(id, element);

                    if (parentId === 0) {
                        document.getElementById('app').appendChild(element);
                    } else {
                        this.elements.get(parentId)?.appendChild(element);
                    }
                    return id;
                },

                js_set_text: (elementId, ptr, len) => {
                    const text = this.readString(ptr, len);
                    const element = this.elements.get(elementId);
                    if (element) element.textContent = text;
                },
            }
        };

        const { instance } = await WebAssembly.instantiate(buffer, imports);
        this.wasm = instance.exports;
        this.memory = new Uint8Array(this.wasm.memory.buffer);

        // Zylix を初期化
        this.wasm.zylix_init();
        this.render();

        return this;
    }

    readString(ptr, len) {
        const bytes = this.memory.slice(ptr, ptr + len);
        return new TextDecoder().decode(bytes);
    }

    dispatch(callbackId, payload = null) {
        let ptr = 0, len = 0;

        if (payload !== null) {
            const { ptr: p, len: l } = this.writeString(JSON.stringify(payload));
            ptr = p;
            len = l;
        }

        this.wasm.zylix_dispatch(callbackId, ptr, len);

        if (ptr !== 0) {
            this.wasm.zylix_free(ptr, len);
        }

        this.render();
    }

    render() {
        this.wasm.zylix_render();
    }
}

// グローバルインスタンス
window.zylix = new Zylix();
```

### HTML エントリーポイント

`index.html` を作成：

```html
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zylix アプリ</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div id="app"></div>

    <script src="zylix.js"></script>
    <script>
        zylix.init('zylix.wasm').then(() => {
            console.log('Zylix が初期化されました');
        }).catch(err => {
            console.error('Zylix の初期化に失敗:', err);
        });
    </script>
</body>
</html>
```

## 最適化

### バンドルサイズ

WASM バンドルサイズを最適化：

```bash
# ReleaseSmall で最小サイズにビルド
zig build -Doptimize=ReleaseSmall

# wasm-opt でさらに最適化（Binaryen から）
wasm-opt -Oz zig-out/bin/zylix.wasm -o dist/zylix.wasm
```

### ストリーミングコンパイル

高速ロードのためにストリーミングコンパイルを有効化：

```javascript
async init(wasmPath) {
    // ストリーミングコンパイルを使用
    const { instance } = await WebAssembly.instantiateStreaming(
        fetch(wasmPath),
        imports
    );
    // ...
}
```

## デプロイ

### 静的ホスティング

任意の静的ホスティングサービスにデプロイ：

```bash
# 本番用にビルド
zig build -Doptimize=ReleaseSmall

# アセットを dist にコピー
cp web/* dist/
cp zig-out/bin/zylix.wasm dist/

# Vercel にデプロイ
vercel --prod

# Netlify にデプロイ
netlify deploy --prod --dir=dist
```

## デバッグ

### よくある問題

| 問題 | 解決策 |
|------|--------|
| WASM のロードに失敗 | MIME タイプが `application/wasm` か確認 |
| メモリアクセスエラー | Zig コードでポインタ境界を確認 |
| 関数が見つからない | 関数が `export` でエクスポートされているか確認 |
| パフォーマンスが遅い | DevTools でプロファイル、ホットパスを最適化 |

## 次のステップ

- **[iOS](../ios)**: SwiftUI でネイティブ iOS アプリを構築
  - **[Android](../android)**: Jetpack Compose でネイティブ Android アプリを構築
