# Project Board

Kanban-style project management board demonstrating task organization.

## Overview

This sample showcases project management patterns:
- Board and column management
- Drag-and-drop card movement
- Task details and editing
- Priority and assignee tracking

## Project Structure

```
project-board/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # Application state
│       └── ui.zig      # UI components
└── platforms/
    └── web/            # Web shell
```

## Features

### Boards
- Multiple boards support
- Column customization
- Board settings

### Cards
- Create and edit tasks
- Priority levels (low, medium, high, urgent)
- Assignee tracking
- Due dates
- Labels and tags

### Columns
- Customizable columns
- Card ordering
- Work-in-progress limits

### Interactions
- Drag and drop cards
- Quick actions
- Keyboard shortcuts

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Boards
void board_create(const char* name);
void board_select(uint32_t board_id);

// Columns
void column_create(const char* name);
void column_move_card(uint32_t card_id, uint32_t to_column, uint32_t position);

// Cards
void card_create(uint32_t column_id, const char* title);
void card_update_priority(uint32_t card_id, uint8_t priority);
void card_assign(uint32_t card_id, uint32_t user_id);
```

## Architecture

```
Board → Columns → Cards → Details
```

## License

MIT License
