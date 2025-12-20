# Changelog

All notable changes to Zylix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive README with project documentation
- Contributing guidelines (CONTRIBUTING.md)
- Security policy (SECURITY.md)
- Code of conduct (CODE_OF_CONDUCT.md)

## [0.1.0] - 2024-12-21

### Added

#### Documentation Website
- Hugo-based documentation site with Hextra theme
- Multilingual support structure
- Platform-specific tutorials for all 6 platforms
- API reference documentation
- Getting started guides

#### Windows Platform (Phase 11)
- WinUI 3 integration with native Windows UI
- C# bindings for Zylix core
- Todo demo application
- Full state management and event handling

#### Linux Platform (Phase 10)
- GTK4 native application support
- C bindings with GObject integration
- Todo demo application
- Cross-desktop compatibility

#### macOS Platform (Phase 9)
- SwiftUI native application support
- Swift bindings for Zylix core
- Todo demo application
- macOS-specific UI patterns

#### Android Platform (Phase 8)
- Jetpack Compose integration
- Kotlin bindings via JNI
- Todo demo application
- Material Design support

#### iOS Platform (Phase 7)
- SwiftUI integration
- Swift bindings for Zylix core
- Todo demo application
- iOS-specific UI patterns

#### Web Platform (Phase 6)
- WebAssembly (WASM) compilation
- JavaScript interop layer
- Todo demo application
- Browser-based rendering

#### Core Framework (Phases 1-5)
- Virtual DOM implementation with efficient diffing algorithm
- Declarative UI DSL for component definition
- Flexbox layout engine
- CSS utility system
- State management with reactive updates
- Event system with cross-platform support
- C ABI layer for language bindings
- Component lifecycle management

### Fixed
- Memory optimization for WASM builds (reduced array sizes)
- JNI bridge compatibility with Zig C ABI signatures

## [0.0.1] - 2024-12-01

### Added
- Initial project scaffolding
- Core library structure
- Platform directory organization
- Project planning documentation
- Apache 2.0 license

[Unreleased]: https://github.com/kotsutsumi/zylix/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kotsutsumi/zylix/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kotsutsumi/zylix/releases/tag/v0.0.1
