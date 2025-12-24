---
title: Web/WASM
weight: 1
---

Build and deploy Zylix applications to the web using WebAssembly. This guide covers project setup, WASM compilation, JavaScript integration, and deployment strategies.

Platform status definitions follow the [Compatibility Reference](https://github.com/kotsutsumi/zylix/blob/main/docs/COMPATIBILITY.md).

## Prerequisites

Before you begin, ensure you have:

- **Zig** 0.15.0 or later installed
- **Node.js** 18+ (for development server)
- A modern web browser with WASM support
- Basic knowledge of JavaScript and HTML

```bash
# Verify Zig installation
zig version

# Verify Node.js installation
node --version
```

## Project Structure

A typical Zylix web project has this structure:

```
my-zylix-app/
├── core/                    # Zig source code
│   ├── src/
│   │   ├── main.zig        # Entry point
│   │   ├── app.zig         # Application logic
│   │   ├── vdom.zig        # Virtual DOM
│   │   └── state.zig       # State management
│   └── build.zig           # Build configuration
├── web/                     # Web assets
│   ├── index.html          # HTML entry point
│   ├── zylix.js            # JavaScript glue code
│   └── styles.css          # Styles
└── dist/                    # Build output
    └── zylix.wasm          # Compiled WASM
```

## Building for Web

### Step 1: Configure Build

Create or update `build.zig` for WASM target:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // WASM target
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zylix",
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    // Export functions for JavaScript
    exe.rdynamic = true;
    exe.entry = .disabled;

    // Install artifact
    b.installArtifact(exe);
}
```

### Step 2: Export Functions

In your `main.zig`, export functions for JavaScript:

```zig
const std = @import("std");

// Exported initialization function
export fn zylix_init() i32 {
    // Initialize application state
    state.init();
    return 0;
}

// Exported event dispatch function
export fn zylix_dispatch(event_type: u32, payload: ?*anyopaque, len: usize) i32 {
    return handleEvent(event_type, payload, len);
}

// Exported state getter
export fn zylix_get_state() ?*const State {
    return state.getState();
}

// Exported render function
export fn zylix_render() i32 {
    return vdom.render();
}

// Memory allocation for JavaScript
export fn zylix_alloc(len: usize) ?[*]u8 {
    const slice = allocator.alloc(u8, len) catch return null;
    return slice.ptr;
}

// Memory deallocation
export fn zylix_free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}
```

### Step 3: Build WASM

```bash
# Build with size optimization
zig build -Doptimize=ReleaseSmall

# Output: zig-out/bin/zylix.wasm
```

## JavaScript Integration

### Loading WASM Module

Create `zylix.js` for WASM loading and DOM manipulation:

```javascript
class Zylix {
    constructor() {
        this.wasm = null;
        this.memory = null;
        this.elements = new Map();
        this.nextElementId = 1;
    }

    async init(wasmPath) {
        const response = await fetch(wasmPath);
        const buffer = await response.arrayBuffer();

        const imports = {
            env: {
                // Logging
                js_log: (ptr, len) => {
                    console.log(this.readString(ptr, len));
                },

                // DOM manipulation
                js_create_element: (tagPtr, tagLen, parentId) => {
                    const tag = this.readString(tagPtr, tagLen);
                    const element = document.createElement(tag);
                    const id = this.nextElementId++;
                    this.elements.set(id, element);

                    if (parentId === 0) {
                        document.getElementById('app').appendChild(element);
                    } else {
                        this.elements.get(parentId)?.appendChild(element);
                    }
                    return id;
                },

                js_set_text: (elementId, ptr, len) => {
                    const text = this.readString(ptr, len);
                    const element = this.elements.get(elementId);
                    if (element) element.textContent = text;
                },

                js_set_attribute: (elementId, namePtr, nameLen, valuePtr, valueLen) => {
                    const name = this.readString(namePtr, nameLen);
                    const value = this.readString(valuePtr, valueLen);
                    const element = this.elements.get(elementId);
                    if (element) element.setAttribute(name, value);
                },

                js_add_event_listener: (elementId, eventPtr, eventLen, callbackId) => {
                    const eventName = this.readString(eventPtr, eventLen);
                    const element = this.elements.get(elementId);
                    if (element) {
                        element.addEventListener(eventName, () => {
                            this.dispatch(callbackId);
                        });
                    }
                },

                js_remove_element: (elementId) => {
                    const element = this.elements.get(elementId);
                    if (element) {
                        element.remove();
                        this.elements.delete(elementId);
                    }
                },
            }
        };

        const { instance } = await WebAssembly.instantiate(buffer, imports);
        this.wasm = instance.exports;
        this.memory = new Uint8Array(this.wasm.memory.buffer);

        // Initialize Zylix
        this.wasm.zylix_init();
        this.render();

        return this;
    }

    readString(ptr, len) {
        const bytes = this.memory.slice(ptr, ptr + len);
        return new TextDecoder().decode(bytes);
    }

    writeString(str) {
        const bytes = new TextEncoder().encode(str);
        const ptr = this.wasm.zylix_alloc(bytes.length);
        if (ptr === 0) throw new Error('Failed to allocate memory');
        this.memory.set(bytes, ptr);
        return { ptr, len: bytes.length };
    }

    dispatch(callbackId, payload = null) {
        let ptr = 0, len = 0;

        if (payload !== null) {
            const { ptr: p, len: l } = this.writeString(JSON.stringify(payload));
            ptr = p;
            len = l;
        }

        this.wasm.zylix_dispatch(callbackId, ptr, len);

        if (ptr !== 0) {
            this.wasm.zylix_free(ptr, len);
        }

        this.render();
    }

    render() {
        this.wasm.zylix_render();
    }
}

// Global instance
window.zylix = new Zylix();
```

### HTML Entry Point

Create `index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zylix App</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div id="app"></div>

    <script src="zylix.js"></script>
    <script>
        zylix.init('zylix.wasm').then(() => {
            console.log('Zylix initialized');
        }).catch(err => {
            console.error('Failed to initialize Zylix:', err);
        });
    </script>
</body>
</html>
```

## Development Server

### Using a Simple HTTP Server

WASM files require proper MIME types. Use a development server:

```bash
# Using Python
python -m http.server 8080

# Using Node.js (install serve globally)
npx serve dist

# Using Deno
deno run --allow-net --allow-read https://deno.land/std/http/file_server.ts dist
```

### Hot Reload Setup

For development with hot reload:

```javascript
// watch.js - Development watcher
const { watch } = require('fs');
const { exec } = require('child_process');
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8081 });

watch('./core/src', { recursive: true }, (eventType, filename) => {
    if (filename.endsWith('.zig')) {
        console.log(`Rebuilding: ${filename}`);
        exec('zig build -Doptimize=Debug', (err) => {
            if (!err) {
                wss.clients.forEach(client => {
                    client.send('reload');
                });
            }
        });
    }
});
```

## Optimization

### Bundle Size

Optimize WASM bundle size:

```bash
# Build with ReleaseSmall for minimum size
zig build -Doptimize=ReleaseSmall

# Further optimize with wasm-opt (from Binaryen)
wasm-opt -Oz zig-out/bin/zylix.wasm -o dist/zylix.wasm
```

### Streaming Compilation

Enable streaming compilation for faster load:

```javascript
async init(wasmPath) {
    // Use streaming compilation
    const { instance } = await WebAssembly.instantiateStreaming(
        fetch(wasmPath),
        imports
    );
    // ...
}
```

### Code Splitting

For large applications, consider lazy loading:

```javascript
async loadModule(moduleName) {
    const response = await fetch(`modules/${moduleName}.wasm`);
    const buffer = await response.arrayBuffer();
    return WebAssembly.instantiate(buffer, this.imports);
}
```

## Deployment

### Static Hosting

Deploy to any static hosting service:

```bash
# Build for production
zig build -Doptimize=ReleaseSmall

# Copy assets to dist
cp web/* dist/
cp zig-out/bin/zylix.wasm dist/

# Deploy to Vercel
vercel --prod

# Deploy to Netlify
netlify deploy --prod --dir=dist

# Deploy to GitHub Pages
gh-pages -d dist
```

### CORS Configuration

Ensure proper headers for WASM:

```
Content-Type: application/wasm
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

## Debugging

### Browser DevTools

1. Open DevTools → Sources → find WASM file
2. Set breakpoints in WASM code
3. Use Console for logging

### WASM Debugging

Enable debug info in build:

```zig
// build.zig
exe.strip = false;  // Keep debug symbols
```

### Common Issues

| Issue | Solution |
|-------|----------|
| WASM fails to load | Check MIME type is `application/wasm` |
| Memory access error | Verify pointer bounds in Zig code |
| Function not found | Ensure functions are exported with `export` |
| Slow performance | Profile with DevTools, optimize hot paths |

## Example: Todo App

Complete example of a Todo app:

```zig
// app.zig
const std = @import("std");

pub const Todo = struct {
    id: u32,
    text: [256]u8,
    text_len: usize,
    completed: bool,
};

pub var todos: [100]Todo = undefined;
pub var todo_count: usize = 0;
pub var next_id: u32 = 1;

pub fn addTodo(text: []const u8) void {
    if (todo_count >= 100) return;

    var todo = &todos[todo_count];
    todo.id = next_id;
    next_id += 1;

    const len = @min(text.len, 255);
    @memcpy(todo.text[0..len], text[0..len]);
    todo.text_len = len;
    todo.completed = false;

    todo_count += 1;
}

pub fn toggleTodo(id: u32) void {
    for (&todos[0..todo_count]) |*todo| {
        if (todo.id == id) {
            todo.completed = !todo.completed;
            break;
        }
    }
}

pub fn removeTodo(id: u32) void {
    for (todos[0..todo_count], 0..) |todo, i| {
        if (todo.id == id) {
            // Shift remaining todos
            std.mem.copyForwards(
                Todo,
                todos[i..todo_count-1],
                todos[i+1..todo_count]
            );
            todo_count -= 1;
            break;
        }
    }
}
```

## Next Steps

- **[iOS](../ios)**: Build native iOS apps with SwiftUI
  - **[Android](../android)**: Build native Android apps with Jetpack Compose
