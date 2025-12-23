# Zylix

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.md)
[![Zig](https://img.shields.io/badge/Zig-0.15.0+-orange.svg)](https://ziglang.org/)

**High-performance cross-platform UI framework powered by Zig**

Zylix enables you to build native applications for Web, iOS, Android, macOS, Linux, and Windows from a single codebase. Leveraging Zig's zero-cost abstractions and predictable performance, Zylix provides a Virtual DOM architecture with native platform bindings.

[Documentation](https://zylix.dev/en/docs) | [Live Demo](https://zylix.dev/demo) | [Getting Started](https://zylix.dev/en/docs/getting-started)

## Features

- **Blazing Fast** - Zero-cost abstractions with Zig. No garbage collection, predictable performance.
- **6 Platforms** - Web/WASM, iOS, Android, macOS, Linux, Windows. One codebase, native performance everywhere.
- **Virtual DOM** - Efficient diffing algorithm for minimal updates. Only render what changes.
- **Tiny Bundle** - Core library under 50KB. WASM builds are incredibly small and load fast.
- **Type Safe** - Zig's compile-time checks catch errors before runtime. No null pointer exceptions.
- **Native Bindings** - C ABI for seamless integration with Swift, Kotlin, C#, and more.

## Platform Support

| Platform | Framework | Status | Notes |
|----------|-----------|--------|-------|
| Web/WASM | HTML/JavaScript | ✅ Production Ready | Full Zig core integration, JavaScript SDK |
| iOS | SwiftUI | ✅ Working | ZylixSwift package with C FFI integration |
| macOS | SwiftUI | ✅ Working | Shares ZylixSwift package with iOS |
| Android | Jetpack Compose | 🚧 In Development | UI demo only, JNI pending |
| Linux | GTK4 | 🚧 In Development | Build infrastructure ready |
| Windows | WinUI 3 | 🚧 In Development | Build infrastructure ready |

> **Note**: Web/WASM and iOS/macOS platforms have full integration with the Zig core. See the [Roadmap](docs/ROADMAP.md) for details.

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/download/) 0.15.0 or later

### Try the Working Samples

```bash
# Counter demo (minimal example)
cd samples/counter-wasm
./build.sh
python3 -m http.server 8080
# Open http://localhost:8080

# TodoMVC demo (full application)
cd samples/todo-wasm
./build.sh
python3 -m http.server 8081
# Open http://localhost:8081
```

### Use the JavaScript SDK

```bash
npm install zylix
```

```javascript
import { init, state, todo } from 'zylix';

await init('node_modules/zylix/wasm/zylix.wasm');

// Counter operations
state.increment();
console.log(state.getCounter()); // 1

// Todo operations
todo.init();
todo.add('Learn Zylix');
console.log(todo.getCount()); // 1
```

### Platform-Specific Setup

Each platform has its own setup requirements. See the platform documentation:

- [Web/WASM](https://zylix.dev/en/docs/platforms/web)
- [iOS](https://zylix.dev/en/docs/platforms/ios)
- [Android](https://zylix.dev/en/docs/platforms/android)
- [macOS](https://zylix.dev/en/docs/platforms/macos)
- [Linux](https://zylix.dev/en/docs/platforms/linux)
- [Windows](https://zylix.dev/en/docs/platforms/windows)

## Project Structure

```
zylix/
├── core/           # Zig core library (Virtual DOM, state management, events)
├── packages/       # Published packages
│   └── zylix/      # JavaScript SDK (npm package)
├── platforms/      # Platform-specific implementations
│   ├── android/    # Kotlin/Jetpack Compose + JNI
│   ├── ios/        # Swift/SwiftUI + ZylixSwift package
│   ├── linux/      # GTK4 native app
│   ├── macos/      # SwiftUI native app
│   ├── web/        # WASM demos
│   └── windows/    # WinUI 3 implementation
├── samples/        # Working example applications
│   ├── counter-wasm/  # Minimal counter demo
│   └── todo-wasm/     # Full TodoMVC implementation
├── site/           # Documentation website (Hugo)
└── docs/           # Internal documentation
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

- [Official Documentation](https://zylix.dev/en/docs)
- [Architecture Guide](docs/ARCHITECTURE.md)
- [ABI Specification](docs/ABI.md)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Support

If you find Zylix useful, consider supporting the project! Your support helps maintain and improve Zylix.

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/kotsutsumi)

Feel free to buy me a coffee! Every bit of support is greatly appreciated.

## License

Zylix is licensed under the [Apache License 2.0](LICENSE.md).

## Acknowledgments

- [Zig Programming Language](https://ziglang.org/)
- [Hugo](https://gohugo.io/) for documentation
- [Hextra](https://github.com/imfing/hextra) theme
