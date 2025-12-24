---
title: iOS Tutorial
weight: 2
---

## Overview

Build the Zylix demo app with SwiftUI and the C ABI bridge on iOS.

## Prerequisites

- macOS 12+
- Xcode 14+
- XcodeGen

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build the Zig Core

```bash
cd platforms/ios
./build-zig.sh
```

This produces `platforms/ios/lib/libzylix.a`.

## 3. Open the Xcode Project

```bash
open Zylix.xcodeproj
```

## 4. Run

Select an iOS simulator or device and run the `Zylix` scheme.

## 5. Confirm State Updates

Open the Counter tab and tap +/-. The counter should update immediately.

Key files:

- `platforms/ios/Zylix/Sources/ContentView.swift` (Counter UI)
- `platforms/ios/Zylix/Sources/ZylixBridge.swift` (C ABI bridge)

## Troubleshooting

- Build fails: ensure `lib/libzylix.a` exists after `./build-zig.sh`.
- XcodeGen not found: `brew install xcodegen`.

## Next Steps

- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
- [ABI Spec](/docs/ABI.md)
