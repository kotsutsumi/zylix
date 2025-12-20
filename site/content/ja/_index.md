---
title: Zylix
layout: hextra-home
---

{{< hextra/hero-badge >}}
  <div class="hx-w-2 hx-h-2 hx-rounded-full hx-bg-primary-400"></div>
  <span>無料・オープンソース</span>
  {{< icon name="arrow-circle-right" attributes="height=14" >}}
{{< /hextra/hero-badge >}}

<div class="hx-mt-6 hx-mb-6">
{{< hextra/hero-headline >}}
  Zig でクロスプラットフォーム&nbsp;<br class="sm:hx-block hx-hidden" />アプリを構築
{{< /hextra/hero-headline >}}
</div>

<div class="hx-mb-12">
{{< hextra/hero-subtitle >}}
  Virtual DOM を搭載した高性能 UI フレームワーク。&nbsp;<br class="sm:hx-block hx-hidden" />Web、iOS、Android、macOS、Linux、Windows で動作。
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx-mb-6">
{{< hextra/hero-button text="はじめる" link="docs/getting-started" >}}
{{< hextra/hero-button text="ライブデモ" link="demo" style="alt" >}}
</div>

<div class="hx-mt-6"></div>

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="超高速"
    subtitle="Zig によるゼロコスト抽象化。ガベージコレクションなし、予測可能なパフォーマンス。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px]"
    style="background: radial-gradient(ellipse at 50% 80%,rgba(251,146,60,0.15),hsla(0,0%,100%,0));"
  >}}
  {{< hextra/feature-card
    title="6 プラットフォーム"
    subtitle="Web/WASM、iOS、Android、macOS、Linux、Windows。1つのコードベースで、どこでもネイティブ性能。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-lg:hx-min-h-[340px]"
    style="background: radial-gradient(ellipse at 50% 80%,rgba(59,130,246,0.15),hsla(0,0%,100%,0));"
  >}}
  {{< hextra/feature-card
    title="Virtual DOM"
    subtitle="効率的な差分検出アルゴリズムで最小限の更新。変更部分のみをレンダリング。"
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px]"
    style="background: radial-gradient(ellipse at 50% 80%,rgba(16,185,129,0.15),hsla(0,0%,100%,0));"
  >}}
  {{< hextra/feature-card
    title="軽量バンドル"
    subtitle="コアライブラリは 50KB 未満。WASM ビルドは驚くほど小さく、高速にロード。"
  >}}
  {{< hextra/feature-card
    title="型安全"
    subtitle="Zig のコンパイル時チェックでランタイム前にエラーを検出。null ポインタ例外なし。"
  >}}
  {{< hextra/feature-card
    title="ネイティブバインディング"
    subtitle="Swift、Kotlin、C# などとシームレスに統合できる C ABI。"
  >}}
{{< /hextra/feature-grid >}}

<div class="hx-mt-16">

## プラットフォームサポート

| プラットフォーム | フレームワーク | ステータス |
|----------|-----------|--------|
| Web/WASM | HTML/JavaScript | ✅ 本番対応 |
| iOS | SwiftUI | ✅ 本番対応 |
| Android | Jetpack Compose | ✅ 本番対応 |
| macOS | SwiftUI | ✅ 本番対応 |
| Linux | GTK4 | ✅ 本番対応 |
| Windows | WinUI 3 | ✅ 本番対応 |

</div>
