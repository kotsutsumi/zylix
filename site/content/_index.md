---
title: Zylix - Cross-Platform UI Framework
layout: hextra-home
description: Build native apps for Web, iOS, Android, macOS, Linux, and Windows from a single Zig codebase. High performance, tiny bundle size, type-safe.
---

{{< hextra/hero-badge link="https://github.com/kotsutsumi/zylix" >}}
  <span>Free, open source</span>
  {{< icon name="arrow-circle-right" >}}
{{< /hextra/hero-badge >}}

<div class="hx-mt-6 hx-mb-6">
{{< hextra/hero-headline >}}
  Write Once, Run Natively&nbsp;<br class="sm:hx-block hx-hidden" />on 6 Platforms
{{< /hextra/hero-headline >}}
</div>

<div class="hx-mb-6">
{{< hextra/hero-subtitle >}}
  Build cross-platform apps with Zig's blazing-fast performance.&nbsp;<br class="sm:hx-block hx-hidden" />Web, iOS, Android, macOS, Linux, Windows — one codebase, native UI everywhere.
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx-mb-8">
{{< hextra/hero-button text="Get Started" link="docs/getting-started" >}}
{{< hextra/hero-button text="Try Live Demo →" link="demo" style="alt" >}}
</div>

<p class="hx-text-center hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mb-6">
  No signup required. See Zylix components running in your browser.
</p>

<div style="margin-top: 3rem;"></div>

## Features

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    icon="lightning-bolt"
    title="Blazing Fast"
    subtitle="Zero-cost abstractions with Zig. No garbage collection means predictable, consistent performance with no runtime pauses."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-orange"
  >}}
  {{< hextra/feature-card
    icon="globe-alt"
    title="6 Platforms"
    subtitle="Web/WASM, iOS, Android, macOS, Linux, Windows. Write your app once and deploy everywhere with native look and feel."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-lg:hx-min-h-[340px] feature-card-blue"
  >}}
  {{< hextra/feature-card
    icon="cube-transparent"
    title="Virtual DOM"
    subtitle="Efficient diffing algorithm computes minimal DOM updates. Only what changes gets re-rendered, keeping your UI responsive."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-emerald"
  >}}
  {{< hextra/feature-card
    icon="scale"
    title="Tiny Bundle"
    subtitle="Core library under 50KB gzipped. Your users won't wait for megabytes of JavaScript to download and parse."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-amber"
  >}}
  {{< hextra/feature-card
    icon="shield-check"
    title="Type Safe"
    subtitle="Zig's compile-time safety catches bugs before they reach production. No null pointer exceptions, no undefined behavior."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-purple"
  >}}
  {{< hextra/feature-card
    icon="puzzle"
    title="Native Bindings"
    subtitle="C ABI enables seamless integration with Swift, Kotlin, C#, Python, and more. Use native platform APIs when needed."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-cyan"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## Why Zylix?

Traditional cross-platform frameworks force you to choose: **performance OR developer experience**. Zylix gives you both.

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="The Problem"
    subtitle="JavaScript frameworks are slow and bloated. Flutter requires Dart and ships large runtimes. React Native bridges slow down performance. Electron consumes gigabytes of RAM. Native development means writing code 6 times."
  >}}
  {{< hextra/feature-card
    title="The Zylix Solution"
    subtitle="Zig-powered core with zero GC and predictable latency. True native UI with SwiftUI, Compose, GTK4, WinUI. Tiny footprint under 50KB WASM core. Virtual DOM with efficient diffing. C ABI that integrates with any language."
    style="background: linear-gradient(135deg, rgba(251,146,60,0.1), rgba(59,130,246,0.1));"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## Use Cases

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="📱 Mobile Apps"
    subtitle="Build iOS and Android apps with native SwiftUI and Jetpack Compose UI, powered by a shared Zig core."
  >}}
  {{< hextra/feature-card
    title="🖥️ Desktop Apps"
    subtitle="Create macOS, Windows, and Linux desktop apps with native widgets. No Electron, no bloat."
  >}}
  {{< hextra/feature-card
    title="🌐 Web Apps"
    subtitle="Deploy to the web via WebAssembly. Blazing fast, tiny bundles, works in any modern browser."
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 4rem;"></div>

## How It Compares

| Feature | Zylix | React Native | Flutter | Electron |
|:--------|:------|:-------------|:--------|:---------|
| Bundle Size | ~50KB | ~1MB+ | ~5MB+ | ~150MB+ |
| GC Pauses | None | Yes | Yes | Yes |
| Native UI | Yes | Partial | No | No |
| Language | Zig | JavaScript | Dart | JavaScript |
| Platforms | 6 | 2 | 6 | 3 |
| Memory Usage | Low | Medium | Medium | High |

<div style="margin-top: 4rem;"></div>

## Platform Support

| Platform | Framework | Status |
|:---------|:----------|:-------|
| Web/WASM | HTML/JavaScript | ✅ Production Ready |
| iOS | SwiftUI | 🚧 In Development |
| Android | Jetpack Compose | 🚧 In Development |
| macOS | SwiftUI | 🚧 In Development |
| Linux | GTK4 | 🚧 In Development |
| Windows | WinUI 3 | 🚧 In Development |

Web/WASM has full Zig core integration. Native platforms have UI demos and are progressing toward C ABI/JNI integration.

<div style="margin-top: 4rem;"></div>

## Get Started in Minutes

```bash
# Clone the repository
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# Build the core
cd core && zig build

# Run the web sample
cd ../samples/todo-app
python3 -m http.server 8080
# Open http://localhost:8080
```

{{< callout type="info" >}}
**Prerequisites**: Zig 0.13+ and a modern web browser. See the [Getting Started](/docs/getting-started) guide for detailed instructions.
{{< /callout >}}

<div style="margin-top: 4rem;"></div>

## Contribute

Zylix is open source and welcomes contributions from developers of all skill levels.

{{< cards >}}
  {{< card link="https://github.com/kotsutsumi/zylix/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22" title="🏷️ Good First Issues" subtitle="Perfect for newcomers" >}}
  {{< card link="https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md" title="📖 Contributing Guide" subtitle="How to get involved" >}}
  {{< card link="https://github.com/kotsutsumi/zylix" title="⭐ Star on GitHub" subtitle="Show your support" >}}
{{< /cards >}}

<div style="margin-top: 3rem;"></div>
