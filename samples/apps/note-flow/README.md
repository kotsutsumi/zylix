# Note Flow

Rich text notes application demonstrating note-taking, folders, and search.

## Overview

Note Flow showcases note-taking patterns:
- Rich text notes
- Folder organization
- Search functionality
- Note tagging
- Quick notes

## Project Structure

```
note-flow/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
```

## Features

### Notes
- Create/edit notes
- Rich text formatting
- Note preview
- Quick notes

### Organization
- Folders
- Tags
- Favorites
- Archive

### Search
- Full-text search
- Tag search
- Recent notes

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Initialization
void app_init(void);
void app_deinit(void);

// Notes
void app_create_note(void);
void app_select_note(uint32_t id);
void app_delete_note(uint32_t id);
void app_toggle_favorite(uint32_t id);

// Folders
void app_select_folder(uint32_t id);
void app_create_folder(const char* name, size_t len);
```

## Data Model

### Note
```zig
const Note = struct {
    id: u32,
    title: [64]u8,
    content: [512]u8,
    folder_id: u32,
    is_favorite: bool,
    updated_at: i64,
};
```

## License

MIT License
