# Zylix Linux (GTK4)

Linux platform shell for Zylix using GTK4 and C.

## Requirements

- Linux (Ubuntu 22.04+, Fedora 36+, or similar)
- GTK 4.0+
- GCC or Clang
- pkg-config
- Zig 0.13+ (for building core library)

### Ubuntu/Debian

```bash
sudo apt install build-essential libgtk-4-dev pkg-config
```

### Fedora

```bash
sudo dnf install gcc gtk4-devel pkg-config
```

### Arch Linux

```bash
sudo pacman -S base-devel gtk4 pkg-config
```

## Build

### 1. Build Zylix Core

From the `core/` directory:

```bash
# Build for Linux x64
zig build linux-x64 -Doptimize=ReleaseFast

# Build for Linux ARM64
zig build linux-arm64 -Doptimize=ReleaseFast
```

### 2. Build GTK App

Using Make:

```bash
cd zylix-gtk
make
```

Or using Meson:

```bash
cd zylix-gtk
meson setup build
meson compile -C build
```

### 3. Run

```bash
./build/zylix-counter
# or
make run
```

## Architecture

```
┌─────────────────────────────────────┐
│           GTK4 (C)                  │
│   - main.c                          │
│   - GtkButton, GtkLabel             │
└───────────────┬─────────────────────┘
                │
                │ Function calls
                ▼
┌─────────────────────────────────────┐
│         zylix.h                     │
│   - C ABI declarations              │
│   - Struct definitions              │
└───────────────┬─────────────────────┘
                │
                │ Direct linking
                ▼
┌─────────────────────────────────────┐
│       Zylix Core (Zig)              │
│   - libzylix.a                      │
│   - State, Events, Logic            │
└─────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `main.c` | GTK4 application with counter UI |
| `zylix.h` | C header for Zylix Core |
| `Makefile` | GNU Make build configuration |
| `meson.build` | Meson build configuration |

## Notes

- Direct C ABI linking (no FFI overhead)
- Uses GTK4's modern widget API
- Supports both x64 and ARM64 architectures
- Follows GNOME HIG (Human Interface Guidelines)
