# Changelog

All notable changes to Zylix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2025-12-22

### Added

#### Component Library Expansion
- **Core**: 57 component types defined in Zig core (up from 9)
- **Core**: New component categories: Form, Layout, Navigation, Feedback, Data Display

#### Native Platform Support
- **iOS**: Full SwiftUI implementations for all 57 component types
- **Android**: Full Jetpack Compose implementations for all 57 component types
- **Windows**: Full WinUI 3 implementations for all 57 component types
- **macOS**: SwiftUI component implementations

#### New Components
- **Form**: DatePicker, TimePicker, FileInput, ColorPicker
- **Layout**: AspectRatio, SafeArea
- **Navigation**: Drawer, Breadcrumb, Pagination
- **Feedback**: Toast, Modal, Skeleton
- **Data Display**: Table, Tooltip, Accordion, Carousel

### Fixed

#### Android
- Gradle dependencies for Jetpack Compose and Navigation
- OkHttp dependency for networking
- `ExperimentalMaterial3Api` opt-in for dropdown menus
- `SelectBuilder` type mismatch in coroutines
- Variable shadowing in `apply` blocks (ZylixHotReload)

## [0.6.2] - 2025-12-21

### Fixed

#### Security
- **Web**: XSS vulnerability in error overlay by escaping dynamic content
- **Web**: Command injection in browser opening function using spawn with arguments array
- **Web**: Added development mode check for dynamic code execution

#### Concurrency
- **Windows**: CancellationTokenSource reuse issue after cancellation
- **Windows**: Multi-frame WebSocket message handling
- **Windows**: Blocking .Wait() calls causing deadlocks (replaced with fire-and-forget)
- **Windows**: Thread-safety issue in file watcher debounce using Interlocked
- **Android**: ConcurrentModificationException in callback iteration using toList()
- **Android**: Reconnect backoff jitter to prevent thundering herd
- **Android**: disconnect() to properly reset state and cancel pending jobs

### Added
- **Android**: removeNavigateCallback() and clearNavigateCallbacks() for memory leak prevention
- **Android**: Deep link handling to preserve query parameters
- **Android**: URL decoding for query parameters
- **Web**: JSON.parse error handling for malformed messages

## [0.6.1] - 2025-12-21

### Fixed

#### Security (Sample Applications)
- **All Samples**: Added escapeHtml, escapeAttr, escapeUrl utilities for XSS prevention
- **All Samples**: Replaced inline onclick handlers with data-action event delegation
- **All Samples**: Secure ID generation using crypto.randomUUID() with fallback

#### Applications Fixed
- todo-pro: XSS prevention, event delegation, secure IDs
- dashboard: XSS prevention, event delegation
- chat: XSS prevention, event delegation, secure message IDs
- e-commerce: XSS prevention, event delegation, secure cart handling
- notes: XSS prevention, event delegation, secure note IDs

## [0.6.0] - 2025-12-21

### Added

#### Sample Applications
- **todo-pro**: Advanced todo app with categories, priorities, and due dates
- **dashboard**: Analytics dashboard with charts and metrics
- **chat**: Real-time chat application with rooms and messages
- **e-commerce**: Shopping cart with product catalog and checkout
- **notes**: Note-taking app with folders and tags

#### Platform Features
- **All Platforms**: Router module with navigation guards and deep linking
- **All Platforms**: Hot reload client with state preservation
- **All Platforms**: Async utilities with promises and futures
- **All Platforms**: Component library with common UI elements

#### Documentation
- Comprehensive ROADMAP.md with development phases
- ROADMAP.ja.md Japanese translation
- Sample applications README

## [0.5.0] - 2025-12-21

### Added

#### GitHub Configuration
- Comprehensive README with project documentation
- Contributing guidelines (CONTRIBUTING.md)
- Security policy (SECURITY.md)
- GitHub issue templates (bug report, feature request)
- Pull request template
- CODEOWNERS file
- Dependabot configuration
- GitHub Actions CI/CD workflows

### Changed
- Updated documentation structure

## [0.1.0] - 2025-12-21

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

## [0.0.1] - 2025-12-01

### Added
- Initial project scaffolding
- Core library structure
- Platform directory organization
- Project planning documentation
- Apache 2.0 license

[Unreleased]: https://github.com/kotsutsumi/zylix/compare/v0.6.2...HEAD
[0.6.2]: https://github.com/kotsutsumi/zylix/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/kotsutsumi/zylix/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/kotsutsumi/zylix/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kotsutsumi/zylix/compare/v0.1.0...v0.5.0
[0.1.0]: https://github.com/kotsutsumi/zylix/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kotsutsumi/zylix/releases/tag/v0.0.1
