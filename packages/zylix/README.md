# Zylix

Cross-platform UI framework with a Zig core and JavaScript/WebAssembly bridge.

## Features

- **Zero-copy state management** - All state lives in WASM for performance
- **Virtual DOM** - Efficient DOM diffing and patching
- **Component system** - Build UIs with composable components
- **TodoMVC ready** - Complete todo app implementation included
- **TypeScript support** - Full type definitions included

## Installation

```bash
npm install zylix
```

## Quick Start

```javascript
import { init, state, todo } from 'zylix';

// Initialize WASM module
await init('node_modules/zylix/wasm/zylix.wasm');

// Use state management
state.increment();
console.log(state.getCounter()); // 1

// Use todo API
todo.init();
const id = todo.add('Learn Zylix');
console.log(todo.getCount()); // 1
```

## Modules

### Core (`zylix/core`)

Foundation module for WASM loading and memory management.

```javascript
import { init, deinit, isInitialized, getMemoryUsed } from 'zylix';

await init('zylix.wasm');
console.log(isInitialized()); // true
console.log(getMemoryUsed()); // Memory usage in bytes
```

### State (`zylix/state`)

Application state management with events.

```javascript
import { state } from 'zylix';

// Dispatch events
state.dispatch(state.Events.INCREMENT);

// Convenience methods
state.increment();
state.decrement();
state.reset();

// Get state
console.log(state.getCounter());
console.log(state.getStateVersion());

// Reactive stores
const store = state.createStore({ count: 0 });
const unsubscribe = store.subscribe(value => console.log(value));
store.set({ count: 1 });
unsubscribe();
```

### Todo (`zylix/todo`)

Complete TodoMVC implementation.

```javascript
import { todo } from 'zylix';

// Initialize
todo.init();

// CRUD operations
const id = todo.add('Buy groceries');
todo.toggle(id);
todo.updateText(id, 'Buy organic groceries');
todo.remove(id);

// Bulk operations
todo.toggleAll();
todo.clearCompleted();

// Filtering
todo.setFilter(todo.Filter.ACTIVE);
todo.setFilter(todo.Filter.COMPLETED);
todo.setFilter(todo.Filter.ALL);

// Queries
console.log(todo.getCount());
console.log(todo.getActiveCount());
console.log(todo.getCompletedCount());

// Get items
const items = todo.getVisibleItems();
// [{ id: 1, text: 'Learn Zylix', completed: false }]
```

### VDOM (`zylix/vdom`)

Virtual DOM for efficient UI updates.

```javascript
import { vdom } from 'zylix';

// Initialize
vdom.init();

// Create nodes
const div = vdom.createElement(vdom.Tag.DIV);
vdom.setClass(div, 'container');

const text = vdom.createText('Hello, Zylix!');
vdom.addChild(div, text);

// Set as root and commit
vdom.setRoot(div);
const patchCount = vdom.commit();

// Apply patches to DOM
const container = document.getElementById('app');
vdom.applyPatches(container);
```

### Component (`zylix/component`)

Component-based UI building.

```javascript
import { component } from 'zylix';

// Initialize
component.init();

// Create components
const container = component.createContainer();
const heading = component.createHeading(1, 'Welcome');
const button = component.createButton('Click me');

// Build tree
component.addChild(container, heading);
component.addChild(container, button);

// Add event handlers
component.onClick(button, 1001); // Callback ID

// Render
component.render(container);
```

## Browser Usage

```html
<script type="module">
import { init, state } from './node_modules/zylix/src/index.js';

await init('./node_modules/zylix/wasm/zylix.wasm');

document.getElementById('increment').onclick = () => {
    state.increment();
    document.getElementById('count').textContent = state.getCounter();
};
</script>
```

## Building WASM

If you need to rebuild the WASM module:

```bash
# Requires Zig 0.15.0 or later
cd packages/zylix
npm run prepare:wasm
```

## TypeScript

Full TypeScript definitions are included:

```typescript
import { init, state, todo, vdom, component } from 'zylix';

await init('zylix.wasm');

// All APIs are fully typed
const items: todo.TodoItem[] = todo.getVisibleItems();
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `init(wasmSource, options?)` | Initialize WASM module |
| `deinit()` | Shutdown WASM module |
| `isInitialized()` | Check initialization status |
| `getMemoryUsed()` | Get memory usage in bytes |
| `getMemoryPeak()` | Get peak memory usage |
| `getAbiVersion()` | Get ABI version number |

### State Functions

| Function | Description |
|----------|-------------|
| `dispatch(eventType, payload?)` | Dispatch event to core |
| `getCounter()` | Get counter value |
| `getStateVersion()` | Get state version |
| `increment()` | Increment counter |
| `decrement()` | Decrement counter |
| `reset()` | Reset counter |
| `createStore(initialValue)` | Create reactive store |

### Todo Functions

| Function | Description |
|----------|-------------|
| `init()` | Initialize todo state |
| `add(text)` | Add todo item |
| `remove(id)` | Remove todo item |
| `toggle(id)` | Toggle completion |
| `toggleAll()` | Toggle all items |
| `clearCompleted()` | Clear completed items |
| `setFilter(filter)` | Set filter mode |
| `getFilter()` | Get current filter |
| `getCount()` | Get total count |
| `getActiveCount()` | Get active count |
| `getCompletedCount()` | Get completed count |
| `getVisibleItems()` | Get filtered items |
| `getAllItems()` | Get all items |

## Architecture

```
JavaScript (UI/Events)
        ↓
    zylix.js (Bridge)
        ↓
    zylix.wasm (Zig Core)
        ↓
JavaScript (DOM Updates)
```

All state management and business logic runs in WASM. JavaScript handles:
- Loading the WASM module
- String encoding/decoding
- DOM manipulation
- Event binding

## Requirements

- Modern browser with WebAssembly support
- Node.js 16+ (for build tools)
- Zig 0.15.0+ (for rebuilding WASM)

## License

MIT
