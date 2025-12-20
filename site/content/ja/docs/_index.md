---
title: ドキュメント
next: getting-started
sidebar:
  open: true
---

Zylix 公式ドキュメントへようこそ。Zig で構築された高性能クロスプラットフォーム UI フレームワークの完全なリファレンスです。

## Zylix とは？

Zylix は**Zig で構築された高性能クロスプラットフォーム UI フレームワーク**です。単一のコアロジックから6つのプラットフォームでネイティブアプリケーションを構築できます。

### 主な特徴

| 特徴 | 説明 |
|------|------|
| **Virtual DOM** | 効率的な差分アルゴリズムによる最小限の UI 更新 |
| **6 プラットフォーム** | Web/WASM、iOS、Android、macOS、Linux、Windows |
| **C ABI** | ネイティブフレームワークとのシームレスな統合 |
| **型安全** | Zig のコンパイル時型チェックによる信頼性 |
| **GC フリー** | アリーナアロケーションによる予測可能なパフォーマンス |
| **軽量** | コアライブラリは50-150KB |

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    プラットフォーム層                            │
│   SwiftUI  │  Compose  │  GTK4  │  WinUI 3  │  HTML/JS         │
│   (iOS/    │  (Android)│ (Linux)│ (Windows) │  (Web)           │
│    macOS)  │           │        │           │                   │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                      C ABI / JNI / WASM
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Zylix Core (Zig)                              │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐       │
│  │ Virtual   │ │   差分    │ │  イベント │ │   状態    │       │
│  │   DOM     │ │アルゴリズム│ │  システム │ │   管理    │       │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# コアライブラリをビルド
cd core
zig build

# Web デモを実行
zig build wasm -Doptimize=ReleaseSmall
cd ../platforms/web
python3 -m http.server 8080
# ブラウザで http://localhost:8080 を開く
```

## ドキュメント構成

### 入門

{{< cards >}}
  {{< card link="getting-started" title="はじめる" subtitle="インストールと最初のアプリ" >}}
  {{< card link="architecture" title="アーキテクチャ" subtitle="Zylix の設計思想" >}}
{{< /cards >}}

### コア概念

{{< cards >}}
  {{< card link="core-concepts/virtual-dom" title="Virtual DOM" subtitle="仮想 DOM エンジン" >}}
  {{< card link="core-concepts/state-management" title="状態管理" subtitle="集中型ストア" >}}
  {{< card link="core-concepts/components" title="コンポーネント" subtitle="再利用可能な UI 部品" >}}
  {{< card link="core-concepts/events" title="イベントシステム" subtitle="型安全なイベント処理" >}}
{{< /cards >}}

### プラットフォームガイド

{{< cards >}}
  {{< card link="platforms/web" title="Web/WASM" subtitle="WebAssembly 統合" >}}
  {{< card link="platforms/ios" title="iOS" subtitle="SwiftUI 統合" >}}
  {{< card link="platforms/android" title="Android" subtitle="Jetpack Compose 統合" >}}
  {{< card link="platforms/macos" title="macOS" subtitle="SwiftUI/AppKit 統合" >}}
  {{< card link="platforms/linux" title="Linux" subtitle="GTK4 統合" >}}
  {{< card link="platforms/windows" title="Windows" subtitle="WinUI 3 統合" >}}
{{< /cards >}}

## 対応プラットフォーム

| プラットフォーム | UI フレームワーク | 言語 | バインディング | 最小バージョン |
|-----------------|------------------|------|---------------|---------------|
| Web | HTML/JS | JavaScript | WASM | モダンブラウザ |
| iOS | SwiftUI | Swift | C ABI | iOS 15+ |
| Android | Jetpack Compose | Kotlin | JNI | API 26+ |
| macOS | SwiftUI | Swift | C ABI | macOS 12+ |
| Linux | GTK4 | C | C ABI | GTK 4.0+ |
| Windows | WinUI 3 | C# | P/Invoke | Windows 10+ |

## 設計原則

### 1. ネイティブファースト

各プラットフォームのネイティブ UI フレームワークを活用し、真のネイティブルック＆フィールを実現します。

### 2. 型安全

Zig のコンパイル時型チェックにより、ランタイムエラーを最小化します。

### 3. ゼロアロケーション

ホットパスではヒープアロケーションを行わず、予測可能なパフォーマンスを提供します。

### 4. シンプルさ

API はシンプルで理解しやすく、学習曲線を緩やかにします。

## コミュニティ

- [GitHub リポジトリ](https://github.com/kotsutsumi/zylix)
- [イシュートラッカー](https://github.com/kotsutsumi/zylix/issues)
- [ディスカッション](https://github.com/kotsutsumi/zylix/discussions)

## ライセンス

Zylix は MIT ライセンスの下で公開されています。
