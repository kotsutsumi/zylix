# Zylix Windows (WinUI 3)

Windows platform shell for Zylix using WinUI 3 and C#.

## Requirements

- Windows 10 version 1809+ or Windows 11
- Visual Studio 2022 with:
  - .NET 8.0 SDK
  - Windows App SDK
  - Windows 10 SDK (10.0.19041.0+)
- Zig 0.15.0+ (for building core library)

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
┌─────────────────────────────────────────────────────────┐
│               WinUI 3 App Layer (C#/XAML)               │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │  TodoWindow     │  │ TodoViewModel               │   │
│  │ (WinUI 3 XAML)  │  │ (INotifyPropertyChanged)    │   │
│  └─────────────────┘  └─────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ P/Invoke (LibraryImport)
                            ▼
┌─────────────────────────────────────────────────────────┐
│              libzylix.a (Zig → x64/ARM64)               │
└─────────────────────────────────────────────────────────┘
```

## Applications

### Todo App (Default)

Full-featured Todo application with WinUI 3:
- Add, toggle, delete todos
- Filter by All/Active/Completed
- Clear completed items
- Real-time render statistics
- Native Windows 11 styling

### Counter App

Simple counter demo:
- Increment/Decrement buttons
- Reset functionality
- State version display

To switch between apps, edit `App.xaml.cs`:
```csharp
// For Todo app (default)
_window = new TodoWindow();

// For Counter app
_window = new MainWindow();
```

## Files

| File | Description |
|------|-------------|
| `Zylix.csproj` | Project configuration |
| `App.xaml` | Application resources |
| `App.xaml.cs` | Application entry point |
| `ZylixBridge.cs` | P/Invoke wrapper for Zig core |
| `TodoWindow.xaml` | Todo app UI (WinUI 3 XAML) |
| `TodoWindow.xaml.cs` | Todo app code-behind |
| `TodoViewModel.cs` | Todo state management |
| `MainWindow.xaml` | Counter app UI |
| `MainWindow.xaml.cs` | Counter app code-behind |

## Event Types

| Event Type | Value | Description |
|------------|-------|-------------|
| `TODO_ADD` | `0x3000` | Add new todo |
| `TODO_REMOVE` | `0x3001` | Remove todo |
| `TODO_TOGGLE` | `0x3002` | Toggle completion |
| `TODO_TOGGLE_ALL` | `0x3003` | Toggle all todos |
| `TODO_CLEAR_DONE` | `0x3004` | Clear completed |
| `TODO_SET_FILTER` | `0x3005` | Set filter mode |
| `COUNTER_INCREMENT` | `0x1000` | Increment counter |
| `COUNTER_DECREMENT` | `0x1001` | Decrement counter |
| `COUNTER_RESET` | `0x1002` | Reset counter |

## Filter Types

| Filter | Value | Description |
|--------|-------|-------------|
| `FILTER_ALL` | `0` | Show all todos |
| `FILTER_ACTIVE` | `1` | Show active only |
| `FILTER_COMPLETED` | `2` | Show completed only |

## Notes

- The Zig library (`zylix.lib`) is linked as a static library
- P/Invoke uses `LibraryImport` for source generation (faster than `DllImport`)
- Supports both x64 and ARM64 architectures
- Uses WinUI 3 with Windows App SDK for modern Windows 11 styling
- MVVM pattern with INotifyPropertyChanged for reactive UI
