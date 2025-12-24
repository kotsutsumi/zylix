---
title: Windows Tutorial
weight: 6
---

## Overview

Run the WinUI 3 demo app on Windows.

## Prerequisites

- Windows 10 1809+ or Windows 11
- Visual Studio 2022
- .NET 8 SDK
- Windows App SDK
- Zig 0.15+

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build the Zig Core

```bash
cd core
zig build windows-x64 -Doptimize=ReleaseFast
```

## 3. Build and Run the App

```bash
cd ../platforms/windows
# Open Zylix/Zylix.csproj in Visual Studio
```

Run the app from Visual Studio (F5).

## 4. Confirm State Updates

Use the Counter window or Todo window and verify updates occur immediately.

Key files:

- `platforms/windows/Zylix/ZylixBridge.cs` (P/Invoke bridge)
- `platforms/windows/Zylix/MainWindow.xaml` (Counter UI)
- `platforms/windows/Zylix/TodoWindow.xaml` (Todo UI)

## Troubleshooting

- Build fails: ensure Windows App SDK and .NET 8 are installed.
- Zig missing: install Zig 0.15+ and confirm `zig version`.

## Next Steps

- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
- [Platform Guide](/docs/platforms/windows/)
