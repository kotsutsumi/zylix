# Zylix Counter Demo (WebAssembly)

A minimal working example demonstrating Zylix core running in the browser via WebAssembly.

## Features

- **Working WASM**: Actual Zig core compiled to WebAssembly
- **State Management**: Counter state managed by Zig
- **Event Dispatch**: JavaScript → WASM → State → Render cycle

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/) 0.15.0 or later
- A modern web browser (Chrome, Firefox, Safari, Edge)

### Build & Run

```bash
# From this directory
./build.sh

# Or manually:
cd ../../core
zig build wasm -Doptimize=ReleaseSmall
cd ../samples/counter-wasm
cp ../../core/zig-out/wasm/zylix.wasm .

# Serve the files (any static server works)
python3 -m http.server 8080
# Open http://localhost:8080
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────┐
│  Browser                                            │
│  ┌────────────────┐     ┌────────────────────────┐ │
│  │   index.html   │────▶│     zylix.js           │ │
│  │   (UI)         │◀────│   (JS Glue Code)       │ │
│  └────────────────┘     └──────────┬─────────────┘ │
│                                    │               │
│                         ┌──────────▼─────────────┐ │
│                         │    zylix.wasm          │ │
│                         │    (Zig Core)          │ │
│                         │  - State Management    │ │
│                         │  - Event Handlers      │ │
│                         │  - Counter Logic       │ │
│                         └────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Event Flow

1. User clicks a button in the HTML
2. JavaScript calls `zylix_dispatch(EVENT_TYPE, null, 0)`
3. Zig core processes the event and updates state
4. JavaScript reads new state via `zylix_get_state()`
5. UI updates to reflect new state

### Files

| File | Description |
|------|-------------|
| `index.html` | Minimal HTML with counter UI |
| `zylix.js` | JavaScript glue code for WASM |
| `zylix.wasm` | Compiled Zig core (built by `build.sh`) |
| `build.sh` | Build script |

## API Reference

### Exported WASM Functions

```javascript
// Initialize Zylix core (call once on load)
zylix_init() → i32 (0 = success)

// Shutdown Zylix core
zylix_deinit() → i32

// Dispatch an event
// event_type: 0x1000 = increment, 0x1001 = decrement, 0x1002 = reset
zylix_dispatch(event_type: u32, payload: ptr, len: usize) → i32

// Get current state pointer
zylix_get_state() → ptr to ABIState

// Get counter value directly (WASM utility)
zylix_wasm_get_counter() → i64
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| WASM fails to load | Ensure `zylix.wasm` exists (run `build.sh`) |
| MIME type error | Use a proper HTTP server, not `file://` |
| Functions undefined | Check browser console for WASM instantiation errors |

## License

MIT - Part of the Zylix framework
