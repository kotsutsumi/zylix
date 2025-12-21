---
title: Zylix - クロスプラットフォーム UI フレームワーク
layout: hextra-home
description: 単一の Zig コードベースから Web、iOS、Android、macOS、Linux、Windows 向けネイティブアプリを構築。高性能、軽量バンドル、型安全。
---

{{< hextra/hero-badge link="https://github.com/kotsutsumi/zylix" >}}
  <span>無料・オープンソース</span>
  {{< icon name="arrow-circle-right" >}}
{{< /hextra/hero-badge >}}

<div class="hx-mt-6 hx-mb-6">
{{< hextra/hero-headline >}}
  一度書いて、6 プラットフォームで&nbsp;<br class="sm:hx-block hx-hidden" />ネイティブ動作
{{< /hextra/hero-headline >}}
</div>

<div class="hx-mb-6">
{{< hextra/hero-subtitle >}}
  Zig の超高速パフォーマンスでクロスプラットフォームアプリを構築。&nbsp;<br class="sm:hx-block hx-hidden" />Web、iOS、Android、macOS、Linux、Windows — 1つのコードベース、どこでもネイティブ UI。
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx-mb-8">
{{< hextra/hero-button text="はじめる" link="ja/docs/getting-started" >}}
{{< hextra/hero-button text="ライブデモを試す →" link="demo" style="alt" >}}
</div>

<p class="hx-text-center hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mb-6">
  登録不要。ブラウザで Zylix コンポーネントを体験できます。
</p>

<div style="margin-top: 3rem;"></div>

## 特徴

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    icon="lightning-bolt"
    title="超高速"
    subtitle="Zig によるゼロコスト抽象化。ガベージコレクションなしで、予測可能で一貫したパフォーマンスを実現。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-orange"
  >}}
  {{< hextra/feature-card
    icon="globe-alt"
    title="6 プラットフォーム"
    subtitle="Web/WASM、iOS、Android、macOS、Linux、Windows。一度書いて、どこでもネイティブなルック＆フィールでデプロイ。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-lg:hx-min-h-[340px] feature-card-blue"
  >}}
  {{< hextra/feature-card
    icon="cube-transparent"
    title="Virtual DOM"
    subtitle="効率的な差分検出アルゴリズムで最小限の DOM 更新を計算。変更部分のみ再レンダリングし、UI のレスポンシブ性を維持。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-emerald"
  >}}
  {{< hextra/feature-card
    icon="scale"
    title="軽量バンドル"
    subtitle="コアライブラリは gzip 後 50KB 未満。メガバイトの JavaScript のダウンロードとパースを待つ必要はありません。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-amber"
  >}}
  {{< hextra/feature-card
    icon="shield-check"
    title="型安全"
    subtitle="Zig のコンパイル時安全性がバグを本番到達前にキャッチ。null ポインタ例外も未定義動作もありません。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-purple"
  >}}
  {{< hextra/feature-card
    icon="puzzle"
    title="ネイティブバインディング"
    subtitle="C ABI により Swift、Kotlin、C#、Python などとシームレスに統合。必要に応じてネイティブ API を使用可能。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-cyan"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## なぜ Zylix？

従来のクロスプラットフォームフレームワークは、**パフォーマンスか開発体験か**の選択を迫られます。Zylix は両方を提供します。

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="従来の課題"
    subtitle="JavaScript フレームワークは遅く肥大化している。Flutter は Dart の習得が必要で、ランタイムが大きい。React Native はブリッジがパフォーマンスを低下させる。Electron はギガバイト単位のメモリを消費。ネイティブ開発は 6 回同じコードを書く必要がある。"
  >}}
  {{< hextra/feature-card
    title="Zylix のソリューション"
    subtitle="Zig パワードコアで GC なし、予測可能なレイテンシ。SwiftUI、Compose、GTK4、WinUI による真のネイティブ UI。50KB 未満の超軽量 WASM コア。効率的な差分検出を備えた Virtual DOM。あらゆる言語と統合可能な C ABI。"
    style="background: linear-gradient(135deg, rgba(251,146,60,0.1), rgba(59,130,246,0.1));"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## ユースケース

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="📱 モバイルアプリ"
    subtitle="ネイティブ SwiftUI と Jetpack Compose UI を使用した iOS・Android アプリを、共通の Zig コアで構築。"
  >}}
  {{< hextra/feature-card
    title="🖥️ デスクトップアプリ"
    subtitle="ネイティブウィジェットで macOS、Windows、Linux デスクトップアプリを作成。Electron 不要、肥大化なし。"
  >}}
  {{< hextra/feature-card
    title="🌐 Web アプリ"
    subtitle="WebAssembly で Web にデプロイ。超高速、軽量バンドル、すべてのモダンブラウザで動作。"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## 他フレームワークとの比較

| 特徴 | Zylix | React Native | Flutter | Electron |
|:-----|:------|:-------------|:--------|:---------|
| バンドルサイズ | 〜50KB | 〜1MB+ | 〜5MB+ | 〜150MB+ |
| GC 停止 | なし | あり | あり | あり |
| ネイティブ UI | ○ | 一部 | × | × |
| 言語 | Zig | JavaScript | Dart | JavaScript |
| プラットフォーム数 | 6 | 2 | 6 | 3 |
| メモリ使用量 | 低 | 中 | 中 | 高 |

<div style="margin-top: 4rem;"></div>

## プラットフォームサポート

| プラットフォーム | フレームワーク | ステータス |
|:-----------------|:---------------|:-----------|
| Web/WASM | HTML/JavaScript | ✅ 本番対応 |
| iOS | SwiftUI | 🚧 開発中 |
| Android | Jetpack Compose | 🚧 開発中 |
| macOS | SwiftUI | 🚧 開発中 |
| Linux | GTK4 | 🚧 開発中 |
| Windows | WinUI 3 | 🚧 開発中 |

Web/WASM は Zig コアとの完全統合済み。ネイティブプラットフォームは UI デモがあり、C ABI/JNI 統合に向けて進行中。

<div style="margin-top: 4rem;"></div>

## 数分ではじめる

```bash
# リポジトリをクローン
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# コアをビルド
cd core && zig build

# Web サンプルを実行
cd ../samples/todo-app
python3 -m http.server 8080
# http://localhost:8080 を開く
```

{{< callout type="info" >}}
**前提条件**: Zig 0.13+ とモダンな Web ブラウザ。詳細は[はじめる](/ja/docs/getting-started)ガイドをご覧ください。
{{< /callout >}}

<div style="margin-top: 4rem;"></div>

## コントリビュート

Zylix はオープンソースであり、あらゆるスキルレベルの開発者からのコントリビューションを歓迎します。

{{< cards >}}
  {{< card link="https://github.com/kotsutsumi/zylix/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22" title="🏷️ Good First Issues" subtitle="初心者に最適" >}}
  {{< card link="https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md" title="📖 コントリビュートガイド" subtitle="参加方法" >}}
  {{< card link="https://github.com/kotsutsumi/zylix" title="⭐ GitHub でスター" subtitle="サポートを表明" >}}
{{< /cards >}}

<div style="margin-top: 3rem;"></div>
