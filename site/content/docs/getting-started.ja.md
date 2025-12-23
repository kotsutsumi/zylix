---
title: はじめる
weight: 1
prev: /docs
next: architecture
---

このガイドでは、Zylix をセットアップし、最初のクロスプラットフォームアプリケーションを構築する方法を説明します。

## 前提条件

### 必須ツール

| ツール | バージョン | 説明 |
|--------|-----------|------|
| [Zig](https://ziglang.org/) | 0.15.0+ | コアビルドシステム |
| Git | 最新版 | ソースコード管理 |

### プラットフォーム固有の要件

**Web/WASM 開発:**
- モダンウェブブラウザ（Chrome、Firefox、Safari、Edge）
- ローカルサーバー（Python、Node.js など）

```bash
# Python を使用
python3 -m http.server 8080

# または Node.js
npx serve
```

**iOS 開発:**
- macOS 12+ (Monterey 以降)
- Xcode 14+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (推奨)

```bash
# Homebrew でインストール
brew install xcodegen
```

**Android 開発:**
- Android Studio (Hedgehog 以降)
- Android SDK (API 26+)
- NDK (r25 以降)
- JDK 17+

```bash
# SDK Manager で NDK をインストール
sdkmanager "ndk;25.2.9519653"
```

**macOS 開発:**
- macOS 12+ (Monterey 以降)
- Xcode 14+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (推奨)

```bash
# Homebrew でインストール
brew install xcodegen
```

**Linux 開発:**
- GTK 4.0+
- pkg-config
- GCC または Clang

```bash
# Ubuntu/Debian
sudo apt install libgtk-4-dev pkg-config build-essential

# Fedora
sudo dnf install gtk4-devel pkg-config gcc

# Arch Linux
sudo pacman -S gtk4 pkgconf base-devel
```

**Windows 開発:**
- Windows 10 バージョン 1809+
- .NET 8.0+
- Windows App SDK 1.4+
- Visual Studio 2022（推奨）

```powershell
# .NET SDK をインストール
winget install Microsoft.DotNet.SDK.8

# Windows App SDK
winget install Microsoft.WindowsAppSDK.1.4
```

## インストール

### ステップ 1: リポジトリをクローン

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

### ステップ 2: プロジェクト構造を確認

```
zylix/
├── core/                   # Zig コアライブラリ
│   ├── src/
│   │   ├── abi.zig         # C ABI エクスポート
│   │   ├── component.zig   # コンポーネントシステム
│   │   ├── diff.zig        # 差分アルゴリズム
│   │   ├── events.zig      # イベント定義
│   │   ├── state.zig       # 状態管理
│   │   ├── todo.zig        # Todo アプリロジック
│   │   ├── vdom.zig        # Virtual DOM エンジン
│   │   └── wasm.zig        # WASM バインディング
│   └── build.zig           # ビルド設定
├── platforms/
│   ├── web/                # Web/WASM デモ
│   │   ├── index.html
│   │   └── zylix.js
│   ├── ios/                # iOS/SwiftUI
│   │   └── ZylixTodo/
│   ├── android/            # Android/Compose
│   │   └── zylix-android/
│   ├── macos/              # macOS/SwiftUI
│   │   └── ZylixTodo/
│   ├── linux/              # Linux/GTK4
│   │   └── zylix-gtk/
│   └── windows/            # Windows/WinUI 3
│       └── Zylix/
└── site/                   # ドキュメント
```

### ステップ 3: コアライブラリをビルド

```bash
cd core

# デバッグビルド
zig build

# リリースビルド
zig build -Doptimize=ReleaseFast

# 利用可能なビルドターゲットを表示
zig build --help
```

## プラットフォーム別ビルド手順

### Web/WASM

```bash
# WASM をビルド
cd core
zig build wasm -Doptimize=ReleaseSmall

# 出力ファイルをコピー
cp zig-out/lib/zylix.wasm ../platforms/web/

# ローカルサーバーを起動
cd ../platforms/web
python3 -m http.server 8080

# ブラウザで開く
open http://localhost:8080
```

**期待される出力:**

```
zylix.wasm: 50KB (gzip 後 ~20KB)
Todo アプリが http://localhost:8080 で動作
```

### iOS

```bash
# iOS 向けにビルド (arm64)
cd core
zig build ios -Doptimize=ReleaseFast

# ライブラリをコピー
cp zig-out/lib/libzylix.a ../platforms/ios/ZylixTodo/

# Xcode プロジェクトを生成
cd ../platforms/ios/ZylixTodo
xcodegen generate

# Xcode で開く
open Zylix.xcodeproj
```

**Xcode での設定:**
1. ターゲットを iOS シミュレータまたは実機に設定
2. **Build Phases** → **Link Binary With Libraries** で `libzylix.a` を追加
3. **Build & Run** (⌘R)

### Android

```bash
# Android 向けにビルド（複数 ABI）
cd core

# arm64-v8a
zig build android-arm64 -Doptimize=ReleaseFast

# armeabi-v7a
zig build android-arm -Doptimize=ReleaseFast

# x86_64 (エミュレータ用)
zig build android-x64 -Doptimize=ReleaseFast

# ライブラリをコピー
mkdir -p ../platforms/android/zylix-android/app/src/main/jniLibs/arm64-v8a
mkdir -p ../platforms/android/zylix-android/app/src/main/jniLibs/armeabi-v7a
mkdir -p ../platforms/android/zylix-android/app/src/main/jniLibs/x86_64

cp zig-out/lib/libzylix-arm64.so ../platforms/android/zylix-android/app/src/main/jniLibs/arm64-v8a/libzylix.so
cp zig-out/lib/libzylix-arm.so ../platforms/android/zylix-android/app/src/main/jniLibs/armeabi-v7a/libzylix.so
cp zig-out/lib/libzylix-x64.so ../platforms/android/zylix-android/app/src/main/jniLibs/x86_64/libzylix.so

# Gradle でビルド
cd ../platforms/android/zylix-android
./gradlew assembleDebug
```

### macOS

```bash
# macOS 向けにビルド (ユニバーサルバイナリ)
cd core

# arm64 (Apple Silicon)
zig build macos-arm64 -Doptimize=ReleaseFast

# x86_64 (Intel)
zig build macos-x64 -Doptimize=ReleaseFast

# ユニバーサルバイナリを作成
lipo -create \
  zig-out/lib/libzylix-arm64.a \
  zig-out/lib/libzylix-x64.a \
  -output ../platforms/macos/ZylixTodo/libzylix.a

# Xcode プロジェクトを生成
cd ../platforms/macos/ZylixTodo
xcodegen generate
open Zylix.xcodeproj
```

### Linux

```bash
# Linux 向けにビルド
cd core
zig build linux -Doptimize=ReleaseFast

# ライブラリをコピー
cp zig-out/lib/libzylix.a ../platforms/linux/zylix-gtk/

# GTK アプリをビルド
cd ../platforms/linux/zylix-gtk
make

# 実行
./build/zylix-todo
```

### Windows

```bash
# Windows 向けにビルド
cd core
zig build windows-x64 -Doptimize=ReleaseFast

# DLL をコピー
cp zig-out/lib/zylix.dll ../platforms/windows/Zylix/

# .NET プロジェクトをビルド
cd ../platforms/windows/Zylix
dotnet build -c Release

# 実行
dotnet run
```

## 最初のアプリケーション

### カウンターアプリを作成

以下は、Zylix の基本的な使い方を示すシンプルなカウンターアプリです。

**core/src/counter.zig:**

```zig
const std = @import("std");
const state = @import("state.zig");
const vdom = @import("vdom.zig");

// 状態定義
pub const CounterState = struct {
    count: i64 = 0,
};

// イベント定義
pub const Event = enum(u32) {
    increment = 1,
    decrement = 2,
    reset = 3,
};

// 状態変更ハンドラ
pub fn handleEvent(event: Event) void {
    const s = state.getStore().getStateMut();

    switch (event) {
        .increment => s.count += 1,
        .decrement => s.count -= 1,
        .reset => s.count = 0,
    }

    state.getStore().commit();
}

// UI 構築
pub fn render(tree: *vdom.VTree) u32 {
    const s = state.getStore().getState();

    // コンテナを作成
    const container = tree.create(vdom.VNode.element(.div));

    // カウント表示
    var count_text: [32]u8 = undefined;
    const count_str = std.fmt.bufPrint(&count_text, "カウント: {d}", .{s.count}) catch "0";
    const text_node = tree.create(vdom.VNode.textNode(count_str));
    _ = tree.addChild(container, text_node);

    // ボタン
    const inc_btn = createButton(tree, "+", @intFromEnum(Event.increment));
    const dec_btn = createButton(tree, "-", @intFromEnum(Event.decrement));
    const reset_btn = createButton(tree, "リセット", @intFromEnum(Event.reset));

    _ = tree.addChild(container, inc_btn);
    _ = tree.addChild(container, dec_btn);
    _ = tree.addChild(container, reset_btn);

    return container;
}

fn createButton(tree: *vdom.VTree, label: []const u8, callback_id: u32) u32 {
    var btn = vdom.VNode.element(.button);
    btn.setText(label);
    btn.props.on_click = callback_id;
    return tree.create(btn);
}
```

## トラブルシューティング

### よくある問題

{{< alert "warning" >}}
**Zig バージョンエラー**

エラー: `error: expected Zig version 0.15.x, found 0.14.x`

解決策: Zig を最新バージョンにアップデートしてください。

```bash
# macOS/Linux
brew upgrade zig

# Windows
scoop update zig
```
{{< /alert >}}

{{< alert "warning" >}}
**WASM が読み込めない**

エラー: `Failed to fetch zylix.wasm`

解決策: CORS 対応のローカルサーバーを使用してください。

```bash
# file:// では動作しません
# http:// を使用してください
python3 -m http.server 8080
```
{{< /alert >}}

{{< alert "warning" >}}
**iOS リンクエラー**

エラー: `Undefined symbols for architecture arm64`

解決策: 正しいターゲットでビルドし、ライブラリパスを確認してください。

```bash
zig build ios -Doptimize=ReleaseFast
# libzylix.a が正しい場所にあることを確認
```
{{< /alert >}}

## 次のステップ

- **[アーキテクチャ](../architecture)**: Zylix の内部構造を学ぶ
  - **[コア概念](../core-concepts)**: Virtual DOM、状態管理など
  - **[プラットフォームガイド](../platforms)**: 各プラットフォームの詳細
