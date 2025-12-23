---
title: Roadmap
weight: 5
prev: platforms
summary: Development roadmap for Zylix, introducing new capabilities while maintaining performance, simplicity, and native platform integration.
---

This page outlines the development roadmap for Zylix. Each phase introduces new capabilities while maintaining the framework's core principles of performance, simplicity, and native platform integration.

> For the complete detailed roadmap, see [ROADMAP.md](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md).

## Current Status

**Version 0.8.1** is the current release with:

- Virtual DOM engine with efficient diffing
- Type-safe state management
- 40+ UI components (form, layout, navigation, feedback, data display)
- CSS utility system (TailwindCSS-like)
- Flexbox layout engine
- 6-platform support (Web, iOS, Android, macOS, Linux, Windows)
- 7th platform: watchOS support
- C ABI (v2) and WASM bindings
- Event queue with priority system
- State diff API for efficient updates
- TypeScript and Python language bindings
- E2E testing framework
- CI/CD pipeline

## Roadmap Overview

| Version | Focus | Status |
|---------|-------|--------|
| v0.1.0 - v0.6.0 | Foundation & Core Features | Done |
| v0.7.0 | Component Library (40+ types) | Done |
| v0.8.1 | Testing, watchOS, Language Bindings | Current |
| v0.9.0 | Embedded AI (Zylix AI) | Planned |
| v0.10.0 | Device Features & Gestures | Planned |
| v0.11.0 | Performance & Optimization | Planned |
| v0.12.0 | Documentation Excellence | Planned |
| v0.13.0 | Animation (Lottie, Live2D) | Planned |
| v0.14.0 | 3D Graphics | Planned |
| v0.15.0 | Game Development | Planned |
| v0.16.0 - v0.21.0 | Node UI, PDF, Excel, Database, Server, Edge | Planned |

## Completed Milestones

### v0.8.1 - Testing & Language Bindings

- watchOS platform support
- TypeScript bindings (`@zylix/test` npm package)
- Python bindings (`zylix-test` PyPI package)
- E2E testing framework for all platforms
- CI/CD workflows (GitHub Actions)

### v0.7.0 - Component Library

40+ component types across 5 categories:

- **Form**: select, checkbox, radio, textarea, toggle, slider, form
- **Layout**: vstack, hstack, zstack, grid, scroll_view, spacer, divider, card
- **Navigation**: nav_bar, tab_bar
- **Feedback**: alert, toast, modal, progress, spinner
- **Data Display**: icon, avatar, tag, badge, accordion

### v0.6.x - Core Features

- Router with navigation guards and deep linking
- Async utilities (Future/Promise pattern)
- Hot reload development server
- Sample applications
- Platform demos (iOS, Android)

## Upcoming Features

### v0.9.0 - Zylix AI

AI-powered development assistant with:

- Natural language to component generation
- Intelligent debugging assistance
- PR review integration
- Documentation auto-generation

### v0.10.0 - Device Features

- GPS/Location services
- Camera access
- Push notifications (APNs, FCM)
- Advanced gestures (drag & drop, pinch, swipe)

### v0.13.0+ - Advanced Features

- **Animation**: Lottie, Live2D integration
- **3D Graphics**: Three.js-inspired engine
- **Game Development**: 2D engine, physics, audio
- **Document Support**: PDF, Excel manipulation
- **Server Runtime**: Full-stack Zig applications
- **Edge Deployment**: Cloudflare, Vercel, AWS adapters

## Contributing

We welcome contributions! See our [Contributing Guide](https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md) for details.

## Detailed Documentation

- [Full Roadmap (EN)](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md)
- [Full Roadmap (JA)](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)
- [Compatibility Reference](https://github.com/kotsutsumi/zylix/blob/main/docs/COMPATIBILITY.md)
