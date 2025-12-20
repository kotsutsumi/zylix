# Zylix Linux Platform (GTK4)

Native Linux applications using GTK4 and C.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│               GTK4 App Layer (C)                         │
│  ┌─────────────┐  ┌─────────────────────────────────┐   │
│  │  Todo UI    │  │ Application State               │   │
│  │ (GtkWidgets)│  │ (Pure C structs)                │   │
│  └─────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Future: Direct linking
                          ▼
┌─────────────────────────────────────────────────────────┐
│              libzylix.a (Zig → x86_64/ARM64)            │
└─────────────────────────────────────────────────────────┘
```

## Requirements

- Linux (Ubuntu 22.04+, Fedora 36+, Arch, etc.)
- GTK 4.0+
- GCC or Clang
- pkg-config
- Make or Meson

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

## Building

### Using Make

```bash
cd platforms/linux/zylix-gtk

# Build both apps
make

# Build only Todo app
make todo

# Build only Counter app
make counter
```

### Using Meson

```bash
cd platforms/linux/zylix-gtk
meson setup build
meson compile -C build
```

## Running

### With Make

```bash
# Run Todo app (default)
make run

# Run Todo app explicitly
make run-todo

# Run Counter app
make run-counter
```

### Direct execution

```bash
./build/zylix-todo
./build/zylix-counter
```

## Project Structure

```
platforms/linux/
├── README.md                    # This file
└── zylix-gtk/
    ├── Makefile                 # Make build config
    ├── meson.build              # Meson build config
    ├── zylix.h                  # C ABI header
    ├── main.c                   # Counter demo app
    └── todo_app.c               # Todo demo app
```

## Applications

### Todo App (`zylix-todo`)

Full-featured Todo application with GTK4:
- Add, toggle, delete todos
- Filter by All/Active/Completed
- Clear completed items
- Real-time render statistics

### Counter App (`zylix-counter`)

Simple counter demo:
- Increment/Decrement buttons
- Reset functionality
- State version display

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

## Future Integration

The current demos use pure C for state management. Future versions will integrate with Zylix Core:

```c
// Future: Link with libzylix.a
if (zylix_dispatch(ZYLIX_EVENT_TODO_ADD, text, strlen(text)) == ZYLIX_OK) {
    refresh_from_zylix_state();
}
```

## Notes

- Direct C ABI linking (no FFI overhead)
- Uses GTK4's modern widget API
- Supports both x64 and ARM64 architectures
- Follows GNOME HIG (Human Interface Guidelines)
