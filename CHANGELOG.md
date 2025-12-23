# Changelog

All notable changes to Zylix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0] - 2025-12-24

### Added

#### Zylix Device - Cross-Platform Device Features Module
- **Core Module**: `core/src/device/device.zig` - Unified device features API
- **Privacy Aware**: Platform-specific permission handling
- **Cross-Platform**: Same API across iOS, Android, macOS, Windows, Linux, Web

#### Location Services
- **GPS/Location**: `location.zig` - Location updates and tracking
- **Geofencing**: Region monitoring with enter/exit events
- **Geocoding**: Address to coordinate conversion
- **Accuracy Levels**: Best, navigation, 10m, 100m, 1km, 3km

#### Camera Access
- **Photo Capture**: `camera.zig` - Camera preview and photo capture
- **Video Recording**: Video recording with quality settings
- **Camera Selection**: Front/back camera switching
- **Flash Control**: Auto, on, off, torch modes
- **Focus Modes**: Auto, continuous, locked

#### Sensor Integration
- **Motion Sensors**: `sensors.zig` - Accelerometer, gyroscope, magnetometer
- **Device Motion**: Combined sensor data with attitude (pitch, roll, yaw)
- **Barometer**: Atmospheric pressure and altitude
- **Pedometer**: Step counting and distance
- **Heart Rate**: Health sensor support (watchOS)
- **Compass**: Heading/direction data

#### Notification System
- **Local Notifications**: `notifications.zig` - Scheduled notifications
- **Push Support**: Token-based push notification registration
- **Triggers**: Immediate, interval, calendar, location-based
- **Actions**: Interactive notification actions and categories
- **Sound Support**: Custom notification sounds

#### Audio System
- **Audio Playback**: `audio.zig` - Audio file playback
- **Audio Recording**: Voice and sound recording
- **Session Management**: Audio session categories
- **Background Audio**: Background playback support

#### Background Processing
- **Background Tasks**: `background.zig` - Background task scheduling
- **Background Fetch**: Periodic background data fetching
- **Background Sync**: Data synchronization in background
- **Transfer Tasks**: Background upload/download support
- **Task Constraints**: Network, charging, battery, idle constraints

#### Haptic Feedback
- **Haptics Engine**: `haptics.zig` - Haptic feedback generation
- **Impact Styles**: Light, medium, heavy, soft, rigid
- **Notification Types**: Success, warning, error haptics
- **Custom Patterns**: Transient, continuous, pause elements

#### Permission Handling
- **Permission Manager**: `permissions.zig` - Unified permission API
- **Permission Types**: Camera, microphone, location, photos, notifications, etc.
- **Status Tracking**: Authorized, denied, restricted, not determined
- **Rationale Support**: Android-style permission rationale

#### Zylix Gesture - Advanced Gesture Recognition Module
- **Core Module**: `core/src/gesture/gesture.zig` - Unified gesture API
- **Platform Optimized**: Native feel on each platform
- **Composable**: Multiple gestures can work simultaneously

#### Gesture Recognizers
- **Tap Recognizer**: `recognizers.zig` - Single and multi-tap detection
- **Long Press**: Long press with configurable duration
- **Pan Gesture**: Dragging/panning with velocity tracking
- **Swipe Gesture**: Directional swipes (up, down, left, right)
- **Pinch Gesture**: Two-finger pinch for zooming
- **Rotation Gesture**: Two-finger rotation detection

#### Drag and Drop
- **Drag Manager**: `drag_drop.zig` - Cross-platform drag and drop
- **Platform Aware**: Long-press on mobile, direct drag on desktop
- **Drop Targets**: Configurable drop target registration
- **Data Types**: Text, URL, file, image, custom data
- **Drop Operations**: Copy, move, link operations

#### iOS Platform Implementation
- **ZylixDevice.swift**: Native device features using iOS frameworks
  - CoreLocation for GPS/location services
  - AVFoundation for camera and audio
  - CoreMotion for sensors (accelerometer, gyroscope)
  - UserNotifications for local/push notifications
  - CoreHaptics for haptic feedback
- **ZylixGesture.swift**: UIKit gesture recognizers with SwiftUI modifiers
  - All gesture types (Tap, LongPress, Pan, Swipe, Pinch, Rotation, EdgePan)
  - ZylixGestureManager singleton for centralized management
  - SwiftUI View extensions (zylixOnTap, zylixOnLongPress, etc.)
- **DeviceTestView.swift**: Interactive test UI for device features

#### Android Platform Implementation
- **ZylixDevice.kt**: Native device features using Android frameworks
  - LocationManager for GPS services
  - CameraX for camera access
  - SensorManager for motion sensors
  - NotificationManager for notifications
  - Vibrator/VibratorManager for haptics
  - MediaRecorder for audio recording
- **ZylixGesture.kt**: Jetpack Compose gesture support
  - Complete gesture type system matching Zig core
  - Compose Modifier extensions for all gesture types
  - StateFlow-based gesture state tracking
- **DeviceTestScreen.kt**: Compose-based test UI

#### Web Platform Implementation
- **zylix-device.js**: Web APIs for device features
  - Geolocation API for location services
  - Vibration API for haptic feedback
  - Generic Sensor API for accelerometer/gyroscope
  - Notification API for web notifications
  - MediaDevices API for camera/microphone
- **zylix-gesture.js**: Pointer Events API integration
  - Touch tracking with multi-finger support
  - All recognizer types with event callbacks
  - ZylixGestureManager and convenience functions
- **device-test.html**: Interactive test page for device features
- **gesture-test.html**: Interactive test page for gesture recognition

### Changed
- Module version updated to v0.10.0
- Device module follows same patterns as AI module

## [0.9.0] - 2025-12-24

### Added

#### Zylix AI - On-Device AI Inference Module
- **Core Module**: `core/src/ai/ai.zig` - Unified AI inference API
- **Privacy First**: All processing on-device, no external network calls
- **Offline Operation**: Full functionality without internet connection

#### Embedding Model Support
- **Text Embedding**: `embedding.zig` - Text to vector conversion
- **Semantic Search**: Cosine similarity for vector comparison
- **RAG Support**: Foundation for retrieval-augmented generation

#### Large Language Model (LLM) Support
- **Text Generation**: `llm.zig` - Chat and completion
- **Chat Format**: System/User/Assistant message roles
- **Streaming**: Real-time token generation support
- **Context Length**: Configurable up to 32K tokens

#### Vision Language Model (VLM) Support
- **Image Analysis**: `vlm.zig` - Image understanding
- **OCR**: Text extraction from images
- **Visual QA**: Question answering about images
- **Formats**: RGB, RGBA, Grayscale, BGR, BGRA

#### Whisper Speech-to-Text
- **Transcription**: `whisper.zig` - Audio to text
- **Streaming**: `whisper_stream.zig` - Real-time transcription
- **Multi-language**: Support for multiple languages
- **Timestamps**: Word-level timing information

#### Audio Processing
- **Decoder**: `audio_decoder.zig` - Multi-format audio decoding
- **Formats**: MP3, FLAC, OGG, WAV support via miniaudio
- **Sample Rates**: Automatic resampling to 16kHz for Whisper

#### Platform-Specific Backends
- **Apple Metal**: `metal.zig` - GPU acceleration for macOS/iOS
- **Core ML**: `coreml.zig` - Apple ML framework integration
- **llama.cpp**: `llama_cpp.zig` - GGUF model support
- **mtmd.cpp**: `mtmd_cpp.zig` - Multimodal support

### Changed

#### Website UI/UX
- **Design Tokens**: Unified CSS custom properties (:root variables) for consistent styling
- **Hero Section**: Reduced badge opacity, improved CTA hierarchy with gradient/shadow differentiation
- **Card Styling**: Enhanced borders (rgba(255,255,255,0.12)) and shadows for visual separation
- **Sidebar Navigation**: Active state highlighting with left border accent and background
- **Tables**: Improved styling and mobile responsiveness with horizontal scroll
- **Japanese Typography**: Adjusted letter-spacing (0.01em) and line-height for readability
- **Mobile**: 44px minimum tap targets, header backdrop opacity, improved spacing
- **Accessibility**: Focus states, reduced motion support, semantic improvements

## [0.8.1] - 2025-12-23

### Breaking Changes

#### ABI v2 Migration
- **ABI Version**: Bumped from 1 to 2
- **zylix_copy_string**: Signature changed - added `src_len` parameter
  - Old: `zylix_copy_string(src, dst, dst_len)`
  - New: `zylix_copy_string(src, src_len, dst, dst_len)`
  - **Migration Required**: All platform bindings (Swift, Kotlin, C#) must be updated to pass the source length parameter

### Added

#### watchOS Support
- **Core**: watchOS platform support in Zig driver
- **Core**: SimulatorType extended with Apple Watch device types
  - Apple Watch Series 9 (41mm, 45mm)
  - Apple Watch Series 10 (42mm, 46mm)
  - Apple Watch Ultra 2
  - Apple Watch SE (40mm, 44mm)
- **Core**: watchOS-specific configuration options
  - `is_watchos` flag
  - `watchos_version` setting
  - `companion_device_udid` for paired iPhone
- **Core**: watchOS-specific actions
  - `rotateDigitalCrown()` - Digital Crown rotation
  - `pressSideButton()` - Side button press
  - `doublePresssSideButton()` - Double press for Apple Pay
  - `getCompanionDeviceInfo()` - Companion device information

#### Language Bindings
- **TypeScript**: `@zylix/test` npm package (v0.8.0)
  - Full platform support (Web, iOS, watchOS, Android, macOS)
  - 10 selector types (testId, accessibilityId, XPath, CSS, etc.)
  - Element actions (tap, type, swipe, longPress, etc.)
  - Complete TypeScript type definitions
  - ESM + CommonJS dual exports
- **Python**: `zylix-test` PyPI package (v0.8.0)
  - Full async/await support
  - Full platform support (Web, iOS, watchOS, Android, macOS)
  - 10 selector types
  - Complete type annotations (mypy strict compatible)
  - PEP 561 typed package

#### CI/CD
- **GitHub Actions**: Comprehensive CI workflow
  - Core build (Ubuntu, macOS, Windows) with Zig 0.15.2
  - iOS/watchOS build with Swift
  - Android build with Kotlin/Gradle (JDK 17)
  - Windows build with .NET 8.0
  - Web tests with Node.js 20
  - Documentation build with Hugo
- **GitHub Actions**: Release workflow for automated releases

#### E2E Testing
- **Core**: E2E test framework (`core/src/test/e2e/`)
  - Web E2E tests (ChromeDriver)
  - iOS/watchOS E2E tests (WebDriverAgent)
  - Android E2E tests (Appium/UIAutomator2)
  - Desktop E2E tests (macOS/Windows/Linux)

#### Sample Demos
- **Samples**: Platform-specific test demos (`samples/test-demos/`)
  - Web (Playwright)
  - iOS (Swift/WebDriverAgent)
  - watchOS (Swift/WDA + Digital Crown)
  - Android (Kotlin/Appium)
  - macOS (Swift/Accessibility Bridge)

#### Documentation
- **API Reference**: Comprehensive API documentation
- **Platform Guides**: Setup guides for all platforms

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

[Unreleased]: https://github.com/kotsutsumi/zylix/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/kotsutsumi/zylix/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/kotsutsumi/zylix/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/kotsutsumi/zylix/compare/v0.8.0...v0.8.1
[0.7.0]: https://github.com/kotsutsumi/zylix/compare/v0.6.2...v0.7.0
[0.6.2]: https://github.com/kotsutsumi/zylix/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/kotsutsumi/zylix/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/kotsutsumi/zylix/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kotsutsumi/zylix/compare/v0.1.0...v0.5.0
[0.1.0]: https://github.com/kotsutsumi/zylix/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kotsutsumi/zylix/releases/tag/v0.0.1
