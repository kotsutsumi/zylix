---
title: "Zylix"
type: docs
---

# Zylix

**Zig-powered cross-platform runtime that respects native UIs**

> "Don't unify UI, unify meaning and decisions"

Zylix is a cross-platform execution layer built on Zig that centralizes application state, logic, and meaning while respecting each OS's native UI framework.

## Key Features

- **Native UI**: SwiftUI, Jetpack Compose, WinUI, GTK - no custom rendering
- **Zero Runtime**: No VM, no GC, predictable execution
- **Tiny Binary**: Core library < 10KB (ReleaseSmall)
- **True Cross-Platform**: iOS, Android, macOS, Windows, Linux, Web

## Architecture

```
┌─────────────────────────────┐
│     Zylix Core (Zig)        │
│  - State Management         │
│  - Business Logic           │
│  - Event Handling           │
└─────────────┬───────────────┘
              │ C ABI
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌─────────┐ ┌────────┐ ┌────────┐
│   iOS   │ │Android │ │  Web   │
│ SwiftUI │ │Compose │ │  WASM  │
└─────────┘ └────────┘ └────────┘
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# Build for all platforms
cd core
zig build all
```

## Documentation

### Concepts
- [Concept]({{< relref "concept" >}}) - Core philosophy
- [Why Not JavaScript?]({{< relref "why-not-js" >}}) - Technical comparison
- [Architecture]({{< relref "architecture" >}}) - System design
- [ZigDom]({{< relref "zigdom" >}}) - Web platform implementation

### API Reference
- [API Reference]({{< relref "docs/api" >}}) - Complete API documentation
  - [C ABI]({{< relref "docs/api/abi" >}}) - Platform integration interface
  - [State Management]({{< relref "docs/api/state" >}}) - Application state
  - [Events]({{< relref "docs/api/events" >}}) - Event dispatching
  - [Virtual DOM]({{< relref "docs/api/vdom" >}}) - UI reconciliation
  - [Animation]({{< relref "docs/api/animation" >}}) - Animation system
  - [AI Module]({{< relref "docs/api/ai" >}}) - AI/ML backends
