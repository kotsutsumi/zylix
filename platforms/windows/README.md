# Zylix Windows (WinUI 3)

Windows platform shell for Zylix using WinUI 3 and C#.

## Requirements

- Windows 10 version 1809+ or Windows 11
- Visual Studio 2022 with:
  - .NET 8.0 SDK
  - Windows App SDK
  - Windows 10 SDK (10.0.19041.0+)
- Zig 0.13+ (for building core library)

## Build

### 1. Build Zylix Core

From the `core/` directory:

```bash
# Build for Windows x64
zig build windows-x64 -Doptimize=ReleaseFast

# Build for Windows ARM64
zig build windows-arm64 -Doptimize=ReleaseFast
```

### 2. Build Windows App

Open `Zylix/Zylix.csproj` in Visual Studio 2022, or use:

```bash
dotnet build Zylix/Zylix.csproj -c Release
```

### 3. Run

```bash
dotnet run --project Zylix/Zylix.csproj
```

## Architecture

```
┌─────────────────────────────────────┐
│         WinUI 3 (XAML)              │
│   - MainWindow.xaml                 │
│   - Data binding                    │
└───────────────┬─────────────────────┘
                │
                │ INotifyPropertyChanged
                ▼
┌─────────────────────────────────────┐
│       ZylixBridge.cs                │
│   - P/Invoke declarations           │
│   - State management                │
└───────────────┬─────────────────────┘
                │
                │ C ABI (DllImport)
                ▼
┌─────────────────────────────────────┐
│       Zylix Core (Zig)              │
│   - zylix.lib                       │
│   - State, Events, Logic            │
└─────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `Zylix.csproj` | Project configuration |
| `App.xaml` | Application resources |
| `MainWindow.xaml` | Main window UI |
| `ZylixBridge.cs` | P/Invoke wrapper for Zig core |

## Notes

- The Zig library (`zylix.lib`) is linked as a static library
- P/Invoke uses `LibraryImport` for source generation (faster than `DllImport`)
- Supports both x64 and ARM64 architectures
