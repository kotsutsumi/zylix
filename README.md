# Zylix

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.md)
[![Zig](https://img.shields.io/badge/Zig-0.11.0+-orange.svg)](https://ziglang.org/)

**High-performance cross-platform UI framework powered by Zig**

Zylix enables you to build native applications for Web, iOS, Android, macOS, Linux, and Windows from a single codebase. Leveraging Zig's zero-cost abstractions and predictable performance, Zylix provides a Virtual DOM architecture with native platform bindings.

[Documentation](https://zylix.dev) | [Live Demo](https://zylix.dev/demo) | [Getting Started](https://zylix.dev/docs/getting-started)

## Features

- **Blazing Fast** - Zero-cost abstractions with Zig. No garbage collection, predictable performance.
- **6 Platforms** - Web/WASM, iOS, Android, macOS, Linux, Windows. One codebase, native performance everywhere.
- **Virtual DOM** - Efficient diffing algorithm for minimal updates. Only render what changes.
- **Tiny Bundle** - Core library under 50KB. WASM builds are incredibly small and load fast.
- **Type Safe** - Zig's compile-time checks catch errors before runtime. No null pointer exceptions.
- **Native Bindings** - C ABI for seamless integration with Swift, Kotlin, C#, and more.

## Platform Support

| Platform | Framework | Status |
|----------|-----------|--------|
| Web/WASM | HTML/JavaScript | Production Ready |
| iOS | SwiftUI | Production Ready |
| Android | Jetpack Compose | Production Ready |
| macOS | SwiftUI | Production Ready |
| Linux | GTK4 | Production Ready |
| Windows | WinUI 3 | Production Ready |

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/download/) 0.11.0 or later

### Build the Core Library

```bash
cd core
zig build
```

### Platform-Specific Setup

Each platform has its own setup requirements. See the platform documentation:

- [Web/WASM](https://zylix.dev/docs/platforms/web)
- [iOS](https://zylix.dev/docs/platforms/ios)
- [Android](https://zylix.dev/docs/platforms/android)
- [macOS](https://zylix.dev/docs/platforms/macos)
- [Linux](https://zylix.dev/docs/platforms/linux)
- [Windows](https://zylix.dev/docs/platforms/windows)

## Project Structure

```
zylix/
├── core/           # Zig core library (Virtual DOM, state management, events)
├── platforms/      # Platform-specific implementations
│   ├── android/    # Kotlin/Jetpack Compose + JNI
│   ├── ios/        # Swift/SwiftUI bindings
│   ├── linux/      # GTK4 native app
│   ├── macos/      # SwiftUI native app
│   ├── web/        # WASM demos
│   └── windows/    # WinUI 3 implementation
├── site/           # Documentation website (Hugo)
├── docs/           # Internal documentation
└── examples/       # Example projects
```

## Architecture

Zylix uses a layered architecture:

1. **Core Layer (Zig)** - Virtual DOM, state management, event system, diffing algorithm
2. **ABI Layer (C)** - Stable C interface for cross-language bindings
3. **Platform Layer** - Native UI implementations (SwiftUI, Jetpack Compose, GTK4, WinUI 3, HTML/JS)

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
├─────────────────────────────────────────────────────────┤
│  SwiftUI  │ Compose │  GTK4  │ WinUI 3 │  HTML/JS       │
├───────────┴─────────┴────────┴─────────┴────────────────┤
│                      C ABI Layer                         │
├─────────────────────────────────────────────────────────┤
│                    Zylix Core (Zig)                      │
│  Virtual DOM │ State │ Events │ Diff │ Scheduler        │
└─────────────────────────────────────────────────────────┘
```

## Documentation

- [Official Documentation](https://zylix.dev/docs)
- [API Reference](https://zylix.dev/docs/api)
- [Architecture Guide](docs/ARCHITECTURE.md)
- [ABI Specification](docs/ABI.md)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

Before contributing, please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Zylix is licensed under the [Apache License 2.0](LICENSE.md).

## Acknowledgments

- [Zig Programming Language](https://ziglang.org/)
- [Hugo](https://gohugo.io/) for documentation
- [Hextra](https://github.com/imfing/hextra) theme
