---
title: macOS Tutorial
weight: 4
---

## Overview

Run the macOS SwiftUI demo app and explore the Todo flow.

## Prerequisites

- macOS 13+
- Xcode 16+
- XcodeGen

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Generate the Xcode Project

```bash
cd platforms/macos
xcodegen generate
```

## 3. Build and Run

```bash
open Zylix.xcodeproj
```

Run the `Zylix` scheme in Xcode.

## 4. Confirm State Updates

Add a new Todo item and verify the list updates immediately.

Key files:

- `platforms/macos/Zylix/Sources/TodoView.swift` (Todo UI)
- `platforms/macos/Zylix/Sources/TodoViewModel.swift` (State model)

## Troubleshooting

- XcodeGen not found: `brew install xcodegen`.
- Build fails: ensure Xcode 16+ is installed.

## Next Steps

- [Architecture](/docs/architecture/)
- [State Management](/docs/core-concepts/state-management/)
- [Platform Guide](/docs/platforms/macos/)
