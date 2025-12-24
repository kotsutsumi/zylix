---
title: watchOS Tutorial
weight: 7
---

## Overview

Run the watchOS counter demo with SwiftUI and the C ABI bridge.

## Status

**In Development** — minimal counter implementation.

## Prerequisites

- macOS 13+
- Xcode 15+ (watchOS SDK)
- Zig 0.15+

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build Zylix Core for watchOS

```bash
cd core
zig build watchos-sim
```

This produces `core/zig-out/watchos-simulator/libzylix.a`.

## 3. Copy the Library

```bash
cp core/zig-out/watchos-simulator/libzylix.a platforms/watchos/ZylixWatch/Libraries/
```

## 4. Open the Xcode Project

```bash
cd platforms/watchos
open ZylixWatch.xcodeproj
```

## 5. Run

Select a watchOS Simulator and run the `ZylixWatch` target.

## 6. Confirm State Updates

Use + / - / Reset. The counter should update immediately.

## Troubleshooting

- Build fails: verify `libzylix.a` exists in `ZylixWatch/Libraries/`.
- Simulator missing: install watchOS runtimes in Xcode settings.

## Key Files

- `platforms/watchos/ZylixWatch/Sources/ContentView.swift`
- `platforms/watchos/ZylixWatch/Sources/ZylixBridge.swift`
- `platforms/watchos/ZylixWatch/Sources/Zylix-Bridging-Header.h`

## Next Steps

- [Platform Guide](/docs/platforms/watchos/)
- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
