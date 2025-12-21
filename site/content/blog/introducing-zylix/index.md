---
title: "Introducing Zylix: Cross-Platform UI Framework in Zig"
date: 2024-12-22
authors:
  - name: Zylix Team
summary: "We're excited to announce Zylix v0.1.0, a high-performance cross-platform UI framework built with Zig. Write your UI logic once and deploy to Web, iOS, Android, macOS, Linux, and Windows."
tags:
  - announcement
  - release
---

We're thrilled to announce the first public release of **Zylix**, a cross-platform UI framework built entirely in Zig. Zylix enables developers to write UI logic once and deploy to six platforms: Web/WASM, iOS, Android, macOS, Linux, and Windows.

## Why Zylix?

Modern app development often requires maintaining separate codebases for each platform. Zylix takes a different approach: a single Zig core that compiles to native code for each target platform, leveraging their native UI frameworks.

### Key Features

- **Virtual DOM Engine**: Efficient diffing algorithm computes minimal UI updates
- **Type-Safe State Management**: Centralized state with compile-time type checking
- **Native Platform Integration**: SwiftUI, Jetpack Compose, GTK4, WinUI 3, and WebAssembly
- **Zero Garbage Collection**: Predictable performance with arena allocation
- **Lightweight**: Core library is just 50-150KB

## Current Status

Zylix v0.1.0 is now available with:

- 9 basic UI components (Container, Text, Button, Image, Input, List, ScrollView, Link, Spacer)
- CSS utility system (TailwindCSS-like syntax)
- Flexbox layout engine
- Event handling system
- Web/WASM platform in Beta, other platforms in Alpha

## Try It Out

Check out our [live demo](/demo) to see Zylix in action, or get started with the [documentation](/docs/getting-started).

```bash
# Clone the repository
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# Build the core library
cd core && zig build

# Run the web demo
zig build wasm -Doptimize=ReleaseSmall
cd ../platforms/web
python3 -m http.server 8080
```

## What's Next?

Our [roadmap](/docs/roadmap) outlines the planned features:

- **v0.2.0**: Expanded component library (30+ components)
- **v0.3.0**: Cross-platform routing system
- **v0.4.0**: Async processing (HTTP, file I/O)
- **v0.5.0**: Hot reload for development
- **v0.6.0**: Sample applications

## Get Involved

Zylix is open source under the MIT license. We welcome contributions from developers of all skill levels.

- [GitHub Repository](https://github.com/kotsutsumi/zylix)
- [Issue Tracker](https://github.com/kotsutsumi/zylix/issues)
- [Discussions](https://github.com/kotsutsumi/zylix/discussions)

Thank you for your interest in Zylix. We're excited to build the future of cross-platform development together.
