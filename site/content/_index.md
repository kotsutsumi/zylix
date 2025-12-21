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

<!-- Key Metrics -->
<div class="hx-flex hx-flex-wrap hx-justify-center hx-gap-6 hx-mb-8 hx-text-center">
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(251, 146, 60);">6</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Platforms</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(59, 130, 246);">&lt;50KB</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Core Size</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(16, 185, 129);">0ms</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">GC Pause</div>
  </div>
  <div class="hx-px-4">
    <div class="hx-text-3xl hx-font-bold" style="color: rgb(139, 92, 246);">40+</div>
    <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Components</div>
  </div>
</div>

<!-- CTA Buttons -->
<div class="hx-flex hx-flex-wrap hx-justify-center hx-gap-3 hx-mb-4">
{{< hextra/hero-button text="Get Started" link="docs/getting-started" >}}
{{< hextra/hero-button text="Try Live Demo →" link="demo" style="alt" >}}
</div>

<p class="hx-text-center hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mb-12">
  No signup required. See Zylix components running in your browser.
</p>

---

<div style="margin-top: 4rem;"></div>

## Why Zylix?

<div class="hx-mt-4 hx-mb-8 hx-text-lg hx-text-gray-600 dark:hx-text-gray-400">
Traditional cross-platform frameworks force you to choose: performance OR developer experience. Zylix gives you both.
</div>

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-2 hx-gap-6 hx-mb-12">

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800">

### The Problem

- **JavaScript frameworks** are slow and bloated
- **Flutter** requires learning Dart, ships large runtimes
- **React Native** bridges slow down performance
- **Electron** consumes gigabytes of RAM
- **Native development** means writing code 6 times

</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800" style="background: linear-gradient(135deg, rgba(251,146,60,0.05), rgba(59,130,246,0.05));">

### The Zylix Solution

- **Zig-powered core** — zero GC, predictable latency
- **True native UI** — SwiftUI, Compose, GTK4, WinUI
- **Tiny footprint** — under 50KB WASM core
- **Virtual DOM** — efficient diffing, minimal updates
- **C ABI** — integrates with any language

</div>

</div>

---

<div style="margin-top: 4rem;"></div>

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

---

<div style="margin-top: 4rem;"></div>

## Use Cases

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-3 hx-gap-6 hx-mb-8">

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">📱</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">Mobile Apps</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Build iOS and Android apps with native SwiftUI and Jetpack Compose UI, powered by a shared Zig core.</p>
</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">🖥️</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">Desktop Apps</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Create macOS, Windows, and Linux desktop apps with native widgets. No Electron, no bloat.</p>
</div>

<div class="hx-p-6 hx-rounded-xl hx-border hx-border-gray-200 dark:hx-border-gray-800 hx-text-center">
  <div class="hx-text-4xl hx-mb-3">🌐</div>
  <h3 class="hx-text-lg hx-font-semibold hx-mb-2">Web Apps</h3>
  <p class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Deploy to the web via WebAssembly. Blazing fast, tiny bundles, works in any modern browser.</p>
</div>

</div>

---

<div style="margin-top: 4rem;"></div>

## How It Compares

| Feature | Zylix | React Native | Flutter | Electron |
|---------|-------|--------------|---------|----------|
| **Bundle Size** | ~50KB | ~1MB+ | ~5MB+ | ~150MB+ |
| **GC Pauses** | None | Yes | Yes | Yes |
| **Native UI** | Yes | Partial | No | No |
| **Language** | Zig | JavaScript | Dart | JavaScript |
| **Platforms** | 6 | 2 | 6 | 3 |
| **Memory Usage** | Low | Medium | Medium | High |

<p class="hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mt-4">
Bundle sizes are approximate and vary by application complexity.
</p>

---

<div style="margin-top: 4rem;"></div>

## Platform Support

| Platform | Framework | Status |
|----------|-----------|--------|
| Web/WASM | HTML/JavaScript | ✅ Production Ready |
| iOS | SwiftUI | 🚧 In Development |
| Android | Jetpack Compose | 🚧 In Development |
| macOS | SwiftUI | 🚧 In Development |
| Linux | GTK4 | 🚧 In Development |
| Windows | WinUI 3 | 🚧 In Development |

<p class="hx-text-sm hx-text-gray-500 dark:hx-text-gray-400 hx-mt-4">
Web/WASM has full Zig core integration. Native platforms have UI demos and are progressing toward C ABI/JNI integration.
</p>

---

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

---

<div style="margin-top: 4rem;"></div>

## Contribute

Zylix is open source and welcomes contributions from developers of all skill levels.

<div class="hx-grid hx-grid-cols-1 md:hx-grid-cols-3 hx-gap-4 hx-mt-6">

<a href="https://github.com/kotsutsumi/zylix/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">🏷️ Good First Issues</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Perfect for newcomers</div>
</a>

<a href="https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">📖 Contributing Guide</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">How to get involved</div>
</a>

<a href="https://github.com/kotsutsumi/zylix" class="hx-block hx-p-4 hx-rounded-lg hx-border hx-border-gray-200 dark:hx-border-gray-800 hover:hx-border-blue-500 hx-transition-colors hx-no-underline">
  <div class="hx-font-semibold hx-text-gray-900 dark:hx-text-gray-100">⭐ Star on GitHub</div>
  <div class="hx-text-sm hx-text-gray-600 dark:hx-text-gray-400">Show your support</div>
</a>

</div>

<div style="margin-top: 3rem;"></div>
