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

<!-- Key Metrics -->
<div class="hx-flex hx-flex-wrap hx-justify-center hx-gap-6 hx-mb-8 hx-text-center">
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(251, 146, 60);">6</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">プラットフォーム</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(59, 130, 246);">&lt;50KB</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">コアサイズ</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(16, 185, 129);">0ms</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">GC 停止</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(139, 92, 246);">40+</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">コンポーネント</div>
  </div>
</div>

<!-- CTA Buttons -->
<div class="hx-flex hx-flex-wrap hx-justify-center hx-gap-3 hx-mb-4">
{{< hextra/hero-button text="はじめる" link="ja/docs/getting-started" >}}
{{< hextra/hero-button text="ライブデモを試す →" link="demo" style="alt" >}}
</div>

<p class="hx-text-center hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mb-12">
  登録不要。ブラウザで Zylix コンポーネントを体験できます。
</p>

---

<div style="margin-top: 4rem;"></div>

## なぜ Zylix？

<div class="hx-mt-4 hx-mb-8 hx-text-lg hx-text-gray-600 dark:hx-text-gray-400">
従来のクロスプラットフォームフレームワークは、パフォーマンスか開発体験かの選択を迫られます。Zylix は両方を提供します。
</div>

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-2 hx-gap-6 hx-mb-12">

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800">

### 従来の課題

- **JavaScript フレームワーク** は遅く肥大化している
- **Flutter** は Dart の習得が必要で、ランタイムが大きい
- **React Native** はブリッジがパフォーマンスを低下させる
- **Electron** はギガバイト単位のメモリを消費
- **ネイティブ開発** は 6 回同じコードを書く必要がある

</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800" style="background: linear-gradient(135deg, rgba(251,146,60,0.05), rgba(59,130,246,0.05));">

### Zylix のソリューション

- **Zig パワードコア** — GC なし、予測可能なレイテンシ
- **真のネイティブ UI** — SwiftUI、Compose、GTK4、WinUI
- **超軽量** — WASM コア 50KB 未満
- **Virtual DOM** — 効率的な差分検出、最小限の更新
- **C ABI** — あらゆる言語と統合可能

</div>

</div>

---

<div style="margin-top: 4rem;"></div>

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

---

<div style="margin-top: 4rem;"></div>

## ユースケース

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-3 hx-gap-6 hx-mb-8">

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">📱</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">モバイルアプリ</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">ネイティブ SwiftUI と Jetpack Compose UI を使用した iOS・Android アプリを、共通の Zig コアで構築。</p>
</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">🖥️</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">デスクトップアプリ</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">ネイティブウィジェットで macOS、Windows、Linux デスクトップアプリを作成。Electron 不要、肥大化なし。</p>
</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">🌐</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">Web アプリ</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">WebAssembly で Web にデプロイ。超高速、軽量バンドル、すべてのモダンブラウザで動作。</p>
</div>

</div>

---

<div style="margin-top: 4rem;"></div>

## 他フレームワークとの比較

| 特徴 | Zylix | React Native | Flutter | Electron |
|---------|-------|--------------|---------|----------|
| **バンドルサイズ** | 〜50KB | 〜1MB+ | 〜5MB+ | 〜150MB+ |
| **GC 停止** | なし | あり | あり | あり |
| **ネイティブ UI** | ○ | 一部 | × | × |
| **言語** | Zig | JavaScript | Dart | JavaScript |
| **プラットフォーム数** | 6 | 2 | 6 | 3 |
| **メモリ使用量** | 低 | 中 | 中 | 高 |

<p class="hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mt-4">
バンドルサイズはアプリケーションの複雑さにより変動します。
</p>

---

<div style="margin-top: 4rem;"></div>

## プラットフォームサポート

| プラットフォーム | フレームワーク | ステータス |
|----------|-----------|--------|
| Web/WASM | HTML/JavaScript | ✅ 本番対応 |
| iOS | SwiftUI | 🚧 開発中 |
| Android | Jetpack Compose | 🚧 開発中 |
| macOS | SwiftUI | 🚧 開発中 |
| Linux | GTK4 | 🚧 開発中 |
| Windows | WinUI 3 | 🚧 開発中 |

<p class="hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mt-4">
Web/WASM は Zig コアとの完全統合済み。ネイティブプラットフォームは UI デモがあり、C ABI/JNI 統合に向けて進行中。
</p>

---

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

---

<div style="margin-top: 4rem;"></div>

## コントリビュート

Zylix はオープンソースであり、あらゆるスキルレベルの開発者からのコントリビューションを歓迎します。

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-3 hx-gap-4 hx-mt-6">

<a href="https://github.com/kotsutsumi/zylix/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">🏷️ Good First Issues</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">初心者に最適</div>
</a>

<a href="https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">📖 コントリビュートガイド</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">参加方法</div>
</a>

<a href="https://github.com/kotsutsumi/zylix" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">⭐ GitHub でスター</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">サポートを表明</div>
</a>

</div>

<div style="margin-top: 3rem;"></div>
