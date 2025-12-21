# Zylix TodoMVC WASM Demo

A fully functional TodoMVC implementation using Zylix's Zig core compiled to WebAssembly.

## Status: ✅ Working

This sample demonstrates the Zylix architecture with a complete todo application:

- **Zig Core**: All state management, filtering, and data operations
- **WASM**: Compiled Zig code running in the browser
- **JavaScript Bridge**: Thin layer connecting WASM to DOM

## Architecture

```
Browser
├── index.html      → TodoMVC UI (HTML/CSS)
├── zylix-todo.js   → JavaScript ↔ WASM bridge
└── zylix.wasm      → Zig core (state management)
```

### Data Flow

```
User Action → JavaScript → WASM → Zig State → WASM → JavaScript → DOM Update
```

All application state lives in Zig/WASM:
- Todo items (text, completion status)
- Filter state (all/active/completed)
- Item counts and statistics

JavaScript only handles:
- DOM manipulation
- Event binding
- String encoding/decoding

## Quick Start

```bash
# Build the WASM module
./build.sh

# Start development server
python3 -m http.server 8080

# Open in browser
open http://localhost:8080
```

## Features

- ✅ Add/remove todos
- ✅ Toggle individual completion
- ✅ Toggle all todos
- ✅ Filter (All/Active/Completed)
- ✅ Clear completed
- ✅ Item count display
- ✅ URL hash routing
- ✅ Inline editing (double-click)

## WASM API

The `zylix-todo.js` bridge exposes these methods:

```javascript
// Initialize
await ZylixTodo.init('zylix.wasm');

// Add/Remove
ZylixTodo.add('Buy milk');      // Returns item ID
ZylixTodo.remove(id);           // Returns boolean

// Toggle
ZylixTodo.toggle(id);           // Toggle single item
ZylixTodo.toggleAll();          // Toggle all items

// Filter
ZylixTodo.setFilter(0);         // 0=all, 1=active, 2=completed
ZylixTodo.getFilter();          // Returns current filter

// Query
ZylixTodo.getCount();           // Total count
ZylixTodo.getActiveCount();     // Active (not completed) count
ZylixTodo.getCompletedCount();  // Completed count
ZylixTodo.getVisibleCount();    // Visible based on filter

// Item access
ZylixTodo.getItemText(id);      // Returns string or null
ZylixTodo.getItemCompleted(id); // Returns boolean
ZylixTodo.updateText(id, text); // Update item text

// Cleanup
ZylixTodo.clearCompleted();     // Returns count removed
```

## Testing

```bash
# Install dependencies
npm install

# Run Playwright tests
npm test

# Run with UI
npm run test:ui
```

## Files

| File | Description |
|------|-------------|
| `index.html` | TodoMVC UI with inline CSS |
| `zylix-todo.js` | WASM bridge with full todo API |
| `build.sh` | Build script for WASM |
| `tests/todo.spec.js` | Playwright E2E tests |

## Zig Implementation

The todo logic is implemented in `core/src/todo.zig`:

```zig
const TodoState = struct {
    items: [MAX_ITEMS]TodoItem,
    item_count: u32,
    next_id: u32,
    filter: Filter,

    pub fn add(text: []const u8) ?u32 { ... }
    pub fn remove(id: u32) bool { ... }
    pub fn toggle(id: u32) bool { ... }
    pub fn toggleAll() void { ... }
    pub fn clearCompleted() u32 { ... }
    // ...
};
```

WASM exports are defined in `core/src/wasm.zig`:

```zig
export fn zigdom_todo_add(text_ptr, text_len) u32 { ... }
export fn zigdom_todo_remove(id) bool { ... }
export fn zigdom_todo_toggle(id) bool { ... }
// ...
```

## Build Options

```bash
# Release build (default, smallest size)
./build.sh --release

# Debug build (includes debug info)
./build.sh --debug

# Build and start server
./build.sh --serve
```

## License

MIT - Part of the Zylix framework
