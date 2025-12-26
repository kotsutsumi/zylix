---
title: Roadmap
weight: 5
prev: platforms
summary: Development roadmap for Zylix, introducing new capabilities while maintaining performance, simplicity, and native platform integration.
---

This page outlines the development roadmap for Zylix. Each phase introduces new capabilities while maintaining the framework's core principles of performance, simplicity, and native platform integration.

> For the complete detailed roadmap, see [ROADMAP.md](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md).

**Last Synced:** 2025-12-26

## Current Status

**Version 0.22.0** is the current stable release with:

- P2 Tooling APIs for complete IDE integration
- Component Tree Export, Live Preview Bridge, Hot Reload APIs
- Language Server Protocol (LSP) and Debug Adapter Protocol (DAP) support
- Full C ABI exports for external tooling

## Roadmap Overview

| Version | Focus | Status |
|---------|-------|--------|
| v0.1.0 - v0.6.3 | Foundation, routing, async, hot reload, samples | Done |
| v0.7.0 | Component Library (40+ types) | Done |
| v0.8.1 | Testing, watchOS, language bindings | Done |
| v0.9.0 - v0.10.0 | AI, device APIs, animation, 3D, game | Done |
| v0.18.0 - v0.19.3 | Tooling APIs, C ABI, Zig 0.15 compat | Done |
| v0.20.0 | P0 Tooling APIs, 27 Example Repos | Done |
| v0.21.0 | M5Stack CoreS3 embedded platform support | Done |
| v0.22.0 | P2 Tooling APIs (IDE Integration) | Current |
| v0.23.0 | Testing Frameworks (XCUITest, Espresso) | Next |

## Upcoming: v0.23.0 - Testing Frameworks

Native testing framework integrations:

- **iOS XCUITest Integration**: Native E2E testing for iOS apps (Issue #64)
- **Android Espresso Integration**: Native E2E testing for Android apps (Issue #65)
- **Cross-Platform Test Orchestration**: CI/CD pipeline support (Issue #66)

## Recent Releases

### v0.22.0 - P2 Tooling APIs (2025-12-26)

Complete IDE integration tooling:

- **Component Tree Export API**: C ABI exports for UI hierarchy access (Issue #56)
- **Live Preview Bridge API**: C ABI exports for preview session management (Issue #57)
- **Hot Reload API**: Development preview with live updates (Issue #61)
- **LSP Integration**: Language Server Protocol support (Issue #62)
- **DAP Integration**: Debug Adapter Protocol support (Issue #63)
- Full C ABI exports for external tooling consumption
- Comprehensive unit tests for all tooling APIs

### v0.21.0 - M5Stack Embedded Platform (2025-12-26)

- **Display**: ILI9342C driver (SPI, 320x240, RGB565)
- **Touch**: FT6336U capacitive touch controller
- **Power**: AXP2101 PMIC, AW9523B I/O expander
- **Integration**: Virtual DOM renderer for embedded displays
- **Samples**: Hello World, Counter, Touch Demo

See [M5Stack Implementation Plan](https://github.com/kotsutsumi/zylix/blob/main/docs/M5STACK_IMPLEMENTATION_PLAN.md) for details.

### v0.20.0 - Tooling APIs & Example Repos (2025-12-26)

- **Component Registry API** - IDE tooling for component discovery
- **UI Layout Serialization** - .zy.ui file format support
- **Component Instantiation** - Live Preview component factory
- **27 Example Repositories** - Starter templates, feature showcase, real-world apps, games
- Thread-safety and security fixes (CodeRabbit review)

### v0.19.3 - Zig 0.15 Compatibility (2025-12-26)

- Fixed ArrayList API for Zig 0.15 in tooling/artifacts.zig
- Migrated to `std.ArrayListUnmanaged` pattern

### v0.19.2 - CI Fixes (2025-12-26)

- Made AI dependencies (llama.cpp, whisper.cpp) optional
- Fixed web platform test exclusions for container directories

### v0.19.1 - Integration Platform Bindings (2025-12-26)

- iOS: Motion tracking, audio, IAP, ads, key-value store, app lifecycle
- Android: CameraX, SoundPool, Play Billing, SharedPreferences, ProcessLifecycle
- Tooling C ABI exports and cross-platform compatibility improvements

## Legacy Milestones

### v0.10.0 - Performance & Optimization

- Profiling, diff caching, memory pools
- Render batching and scheduling utilities
- Optimization configuration and metrics

### v0.9.0 - AI & Device Features

- AI module integration (Whisper, Core ML)
- Device API improvements
- Animation and 3D enhancements

## Next

**v0.23.0** will introduce native testing framework integrations including iOS XCUITest, Android Espresso, and cross-platform test orchestration for comprehensive E2E testing support.

## Contributing

We welcome contributions! See our [Contributing Guide](https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md) for details.

## Detailed Documentation

- [Full Roadmap (EN)](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md)
- [Full Roadmap (JA)](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)
- [Compatibility Reference](https://github.com/kotsutsumi/zylix/blob/main/docs/COMPATIBILITY.md)
