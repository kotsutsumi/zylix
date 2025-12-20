---
title: Documentation
next: getting-started
sidebar:
  open: true
cascade:
  type: docs
---

Welcome to the official Zylix documentation. Zylix is a high-performance, cross-platform UI framework powered by [Zig](https://ziglang.org/), designed to build native applications that run on Web, iOS, Android, macOS, Linux, and Windows from a single codebase.

## Why Zylix?

Modern cross-platform frameworks often sacrifice performance for developer convenience, or require complex toolchains that slow down iteration. Zylix takes a different approach:

- **Zero-Cost Abstractions**: Written in Zig, Zylix provides predictable, garbage-collection-free performance with compile-time safety guarantees
- **True Native Performance**: No JavaScript bridge, no virtual machine overhead. Your UI code compiles directly to native machine code
- **Unified Architecture**: A single Virtual DOM implementation powers all platforms, ensuring consistent behavior everywhere
- **Minimal Bundle Size**: Core library under 50KB. WASM builds are incredibly small and load instantly
- **Platform-Native Look & Feel**: Each platform uses its native UI toolkit (SwiftUI, Jetpack Compose, GTK4, WinUI 3) for authentic user experiences

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Platform Shells                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ SwiftUI │ │ Compose │ │  GTK4   │ │ WinUI 3 │ │ HTML/JS │   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
└───────┼──────────┼──────────┼──────────┼──────────┼─────────────┘
        │          │          │          │          │
        └──────────┴──────────┴─────┬────┴──────────┘
                                    │
                          C ABI / WASM Bindings
                                    │
┌───────────────────────────────────┼─────────────────────────────┐
│                        Zylix Core (Zig)                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  Virtual │ │   Diff   │ │  State   │ │Component │            │
│  │   DOM    │ │Algorithm │ │  Store   │ │ System   │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  Event   │ │  Layout  │ │   CSS    │ │Scheduler │            │
│  │  System  │ │  Engine  │ │  Engine  │ │          │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Links

{{< cards >}}
  {{< card link="getting-started" title="Getting Started" subtitle="Install Zylix and build your first app in minutes" >}}
  {{< card link="core-concepts" title="Core Concepts" subtitle="Understand Virtual DOM, State, Components, and Events" >}}
  {{< card link="architecture" title="Architecture" subtitle="Deep dive into Zylix internals" >}}
  {{< card link="platforms" title="Platform Guides" subtitle="Platform-specific setup and best practices" >}}
  {{< card link="api" title="API Reference" subtitle="Complete API documentation" >}}
  {{< card link="examples" title="Examples" subtitle="Real-world code examples and patterns" >}}
{{< /cards >}}

## Supported Platforms

| Platform | UI Framework | Binding | Min Version | Status |
|----------|-------------|---------|-------------|--------|
| **Web/WASM** | HTML/JavaScript | WebAssembly | Modern browsers | ✅ Production Ready |
| **iOS** | SwiftUI | C ABI | iOS 15+ | ✅ Production Ready |
| **Android** | Jetpack Compose | JNI | API 26+ | ✅ Production Ready |
| **macOS** | SwiftUI | C ABI | macOS 12+ | ✅ Production Ready |
| **Linux** | GTK4 | C ABI | GTK 4.0+ | ✅ Production Ready |
| **Windows** | WinUI 3 | P/Invoke | Windows 10+ | ✅ Production Ready |

## Core Features

### Virtual DOM Engine
Efficient UI updates through intelligent diffing. Zylix computes minimal patches between UI states, ensuring only necessary DOM operations are performed.

### Type-Safe State Management
Centralized state with compile-time type checking. State changes are tracked with version numbers, enabling efficient change detection and time-travel debugging.

### Component System
Composable, reusable UI components with props, state, and event handlers. Components are lightweight structures with zero runtime overhead.

### Cross-Language Bindings
Seamless integration with platform languages through C ABI (Swift, Kotlin, C#) and WASM (JavaScript). All core logic stays in Zig while platforms handle rendering.

## Community & Support

- **GitHub**: [github.com/kotsutsumi/zylix](https://github.com/kotsutsumi/zylix)
- **Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **License**: MIT

## Version

This documentation covers **Zylix 0.1.0** (Development Preview).
