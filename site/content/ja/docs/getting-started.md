---
title: はじめる
weight: 1
prev: /docs
next: architecture
---

数分で Zylix を使い始めましょう。

## 前提条件

- [Zig](https://ziglang.org/) 0.13 以降
- プラットフォーム固有のツール（下記参照）

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

### 2. コアライブラリをビルド

```bash
cd core
zig build
```

これにより、現在のプラットフォーム用の `libzylix.a` がビルドされます。

### 3. 特定のプラットフォーム向けにビルド

{{< tabs items="Web/WASM,iOS,Android,macOS,Linux,Windows" >}}

{{< tab >}}
```bash
# WASM ビルド
zig build wasm -Doptimize=ReleaseSmall

# 出力: zig-out/lib/zylix.wasm
```
{{< /tab >}}

{{< tab >}}
```bash
# iOS 向けビルド
zig build ios -Doptimize=ReleaseFast

# Xcode プロジェクトを開く
cd platforms/ios
xcodegen generate
open Zylix.xcodeproj
```
{{< /tab >}}

{{< tab >}}
```bash
# Android 向けビルド
zig build android -Doptimize=ReleaseFast

# Android Studio で開く
cd platforms/android/zylix-android
./gradlew assembleDebug
```
{{< /tab >}}

{{< tab >}}
```bash
# macOS 向けビルド
zig build -Doptimize=ReleaseFast

# Xcode プロジェクトを開く
cd platforms/macos
xcodegen generate
open Zylix.xcodeproj
```
{{< /tab >}}

{{< tab >}}
```bash
# Linux 向けビルド
zig build linux -Doptimize=ReleaseFast

# GTK アプリをビルド
cd platforms/linux/zylix-gtk
make
./build/zylix-todo
```
{{< /tab >}}

{{< tab >}}
```bash
# Windows 向けビルド
zig build windows-x64 -Doptimize=ReleaseFast

# .NET でビルド
cd platforms/windows/Zylix
dotnet build -c Release
dotnet run
```
{{< /tab >}}

{{< /tabs >}}

## プロジェクト構造

```
zylix/
├── core/                 # Zig コアライブラリ
│   └── src/
│       ├── vdom.zig      # Virtual DOM エンジン
│       ├── diff.zig      # 差分アルゴリズム
│       ├── component.zig # コンポーネントシステム
│       ├── state.zig     # 状態管理
│       ├── todo.zig      # Todo アプリロジック
│       └── wasm.zig      # WASM バインディング
├── platforms/
│   ├── web/              # Web/WASM デモ
│   ├── ios/              # iOS/SwiftUI
│   ├── android/          # Android/Kotlin
│   ├── macos/            # macOS/SwiftUI
│   ├── linux/            # Linux/GTK4
│   └── windows/          # Windows/WinUI 3
└── site/                 # このドキュメント
```

## 次のステップ

- [アーキテクチャ](architecture) - Zylix の仕組みを学ぶ
- [プラットフォーム](platforms) - プラットフォーム固有のガイド
- [API リファレンス](api) - 詳細な API ドキュメント
