# Zylix Sample Applications

This directory contains sample applications demonstrating Zylix usage.

## Working Samples

| Sample | Platform | Status | Description |
|--------|----------|--------|-------------|
| [**counter-wasm**](./counter-wasm/) | Web/WASM | ✅ Working | Minimal counter demo with actual WASM integration |
| [**todo-wasm**](./todo-wasm/) | Web/WASM | ✅ Working | Full TodoMVC implementation with WASM |
| [**component-showcase**](./component-showcase/) | Web/WASM | ✅ Working | v0.7.0 Component Library showcase |

## Planned Samples (Not Yet Implemented)

The following samples exist as design documents only. They demonstrate the target API but do not currently run because the Zylix JavaScript framework has not been built yet.

| Sample | Level | Target Features |
|--------|-------|-----------------|
| todo-pro | Beginner | State management, forms, local storage |
| e-commerce | Intermediate | Routing, HTTP requests, shopping cart |
| dashboard | Intermediate | Real-time data, charts, tables |
| chat | Advanced | WebSocket, real-time messaging |
| notes | Advanced | Rich text editing, cloud sync |

> ⚠️ **Note**: These planned samples import from a `zylix` package that does not exist yet. They serve as API design references for future development.

## Getting Started

### Working Samples

```bash
# Counter demo (minimal example)
cd counter-wasm
./build.sh
python3 -m http.server 8080
# Open http://localhost:8080

# TodoMVC demo (full application)
cd todo-wasm
./build.sh
python3 -m http.server 8081
# Open http://localhost:8081

# Component Showcase (v0.7.0 components)
cd component-showcase
python3 -m http.server 8082
# Open http://localhost:8082
```

### Prerequisites

- **Zig** 0.15.0 or later (for WASM compilation)
- **Python 3** (for development server) or any HTTP server
- Modern web browser with WebAssembly support

## Architecture

### counter-wasm

```
Browser
├── index.html     → UI and event handlers
├── zylix.js       → JavaScript ↔ WASM bridge
└── zylix.wasm     → Zig core (state management)
```

The counter demo shows the fundamental Zylix architecture:
1. Zig manages all application state
2. JavaScript handles DOM rendering
3. Events flow: User Action → JS → WASM → State Update → JS → DOM

### todo-wasm

```
Browser
├── index.html      → TodoMVC UI (HTML/CSS)
├── zylix-todo.js   → JavaScript ↔ WASM bridge (todo-specific)
└── zylix.wasm      → Zig core (todo state, filtering, VDOM)
```

The TodoMVC demo demonstrates a complete application:
- Full CRUD operations (add, remove, toggle, update)
- Filtering (all/active/completed)
- Bulk operations (toggle all, clear completed)
- URL hash routing for filter state

### component-showcase

```
Browser
├── index.html          → Component showcase UI
├── zylix-showcase.js   → JavaScript ↔ WASM bridge (v0.7.0 components)
└── zylix.wasm          → Zig core (component tree, state)
```

The Component Showcase demonstrates v0.7.0 Component Library:
- **Layout**: VStack, HStack, Card, Divider, Spacer, Grid
- **Form**: Checkbox, Toggle, Select, Textarea, Radio
- **Feedback**: Alert, Progress, Spinner, Toast, Modal
- **Data Display**: Badge, Tag, Accordion, Avatar, Icon
- Interactive component creation via WASM

### JavaScript SDK

The Zylix JavaScript SDK is now available in `packages/zylix`:

```javascript
// Using the SDK
import { init, state, todo, vdom, component } from 'zylix';

await init('zylix.wasm');

// State management
state.increment();
console.log(state.getCounter());

// Todo API
todo.init();
todo.add('Learn Zylix');

// VDOM and components
vdom.init();
component.init();
```

### Planned Samples

The planned samples (todo-pro, e-commerce, etc.) can now use the SDK. They will be updated to use the actual `zylix` package once it's published to npm.

## Testing

The working samples include Playwright tests:

```bash
# Counter tests
cd counter-wasm
npm install
npm test

# TodoMVC tests
cd todo-wasm
npm install
npm test

# Component Showcase tests
cd component-showcase
npm install
npm test
```

## Contributing

When adding new samples:

1. **Start with WASM**: Build samples that use the Zig core directly via WASM
2. **Test thoroughly**: Include Playwright tests that verify functionality
3. **Be honest**: Mark samples as "planned" if they don't actually run
4. **Keep it simple**: Start with minimal examples that demonstrate one concept

## License

MIT - Part of the Zylix framework
