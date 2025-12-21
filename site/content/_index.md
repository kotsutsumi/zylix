---
title: Zylix
layout: hextra-home
---

{{< hextra/hero-badge link="https://github.com/kotsutsumi/zylix" >}}
  <span>Free, open source</span>
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16l4-4-4-4M8 12h8"/></svg>
{{< /hextra/hero-badge >}}

<div class="hx-mt-6 hx-mb-6">
{{< hextra/hero-headline >}}
  Build Cross-Platform Apps&nbsp;<br class="sm:hx-block hx-hidden" />with Zig
{{< /hextra/hero-headline >}}
</div>

{{< hextra/hero-subtitle >}}
  High-performance UI framework with Virtual DOM,&nbsp;<br class="sm:hx-block hx-hidden" />running on Web, iOS, Android, macOS, Linux, and Windows.
{{< /hextra/hero-subtitle >}}

{{< hextra/hero-button text="Get Started" link="en/docs/getting-started" >}}
{{< hextra/hero-button text="Live Demo" link="demo" style="alt" >}}

<div style="margin-top: 4rem;"></div>

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    icon="lightning-bolt"
    title="Blazing Fast"
    subtitle="Zero-cost abstractions with Zig. No garbage collection, predictable performance."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-orange"
  >}}
  {{< hextra/feature-card
    icon="globe-alt"
    title="6 Platforms"
    subtitle="Web/WASM, iOS, Android, macOS, Linux, Windows. One codebase, native performance everywhere."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-lg:hx-min-h-[340px] feature-card-blue"
  >}}
  {{< hextra/feature-card
    icon="cube-transparent"
    title="Virtual DOM"
    subtitle="Efficient diffing algorithm for minimal updates. Only render what changes."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-emerald"
  >}}
  {{< hextra/feature-card
    icon="scale"
    title="Tiny Bundle"
    subtitle="Core library under 50KB. WASM builds are incredibly small and load fast."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-amber"
  >}}
  {{< hextra/feature-card
    icon="shield-check"
    title="Type Safe"
    subtitle="Zig's compile-time checks catch errors before runtime. No null pointer exceptions."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-purple"
  >}}
  {{< hextra/feature-card
    icon="puzzle"
    title="Native Bindings"
    subtitle="C ABI for seamless integration with Swift, Kotlin, C#, and more."
    class="hx-aspect-auto md:hx-aspect-[1.1/1] max-md:hx-min-h-[340px] feature-card-cyan"
  >}}
{{< /hextra/feature-grid >}}

<div style="margin-top: 5rem; margin-bottom: 3rem;">

## Platform Support

| Platform | Framework | Status |
|----------|-----------|--------|
| Web/WASM | HTML/JavaScript | ✅ Production Ready |
| iOS | SwiftUI | 🚧 In Development |
| Android | Jetpack Compose | 🚧 In Development |
| macOS | SwiftUI | 🚧 In Development |
| Linux | GTK4 | 🚧 In Development |
| Windows | WinUI 3 | 🚧 In Development |

<p style="font-size: 0.875rem; color: var(--tw-prose-body); margin-top: 1rem;">
Currently, only Web/WASM has full Zig core integration. Native platforms have UI demos but await C ABI/JNI integration.
</p>

</div>
