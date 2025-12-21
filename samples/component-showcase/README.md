# Zylix Component Showcase

v0.7.0 Component Library demonstration with WebAssembly.

## Features

This showcase demonstrates the v0.7.0 Component Library expansion:

### Layout Components
- **VStack** - Vertical stack layout
- **HStack** - Horizontal stack layout
- **Card** - Container with border and background
- **Divider** - Visual separator
- **Spacer** - Flexible space element
- **Grid** - Grid-based layout

### Form Components
- **Checkbox** - Checkable input with label
- **Toggle Switch** - On/off toggle
- **Select** - Dropdown selection
- **Textarea** - Multi-line text input
- **Radio** - Radio button groups

### Feedback Components
- **Alert** - Info, success, warning, error messages
- **Progress** - Linear progress indicator
- **Spinner** - Loading animation
- **Toast** - Notification popups
- **Modal** - Dialog overlays

### Data Display Components
- **Badge** - Numeric indicators
- **Tag** - Label chips
- **Accordion** - Collapsible content sections
- **Avatar** - User profile images
- **Icon** - Named icons

## Quick Start

```bash
# Serve the demo
python3 -m http.server 8081

# Open in browser
open http://localhost:8081
```

## Testing

```bash
# Install dependencies
npm install

# Run Playwright E2E tests
npm test

# Run tests with UI
npm run test:ui
```

## Architecture

```
component-showcase/
├── index.html          # Component showcase UI
├── zylix-showcase.js   # JavaScript ↔ WASM bridge
├── zylix.wasm          # Zig core (component tree)
├── package.json        # NPM config with test scripts
├── playwright.config.js # Playwright configuration
└── tests/
    └── showcase.spec.js # E2E test suite
```

## Component API

The JavaScript bridge exposes all v0.7.0 component functions:

```javascript
// Initialize
await ZylixShowcase.init('zylix.wasm');

// Create layout components
const vstackId = ZylixShowcase.createVStack();
const hstackId = ZylixShowcase.createHStack();
const cardId = ZylixShowcase.createCard();

// Create form components
const checkboxId = ZylixShowcase.createCheckbox('Enable feature');
const toggleId = ZylixShowcase.createToggleSwitch('Dark mode');
const selectId = ZylixShowcase.createSelect('Choose option');

// Create feedback components
const alertId = ZylixShowcase.createAlert('Hello!', ZylixShowcase.AlertStyle.SUCCESS);
const progressId = ZylixShowcase.createProgress(ZylixShowcase.ProgressStyle.LINEAR);
ZylixShowcase.setProgressValue(progressId, 0.75);

// Create data display components
const badgeId = ZylixShowcase.createBadge(5);
const tagId = ZylixShowcase.createTag('v0.7.0');
const accordionId = ZylixShowcase.createAccordion('Click to expand');

// Component tree operations
ZylixShowcase.addChild(vstackId, cardId);
ZylixShowcase.addChild(cardId, textId);

// State management
ZylixShowcase.setChecked(checkboxId, true);
ZylixShowcase.setExpanded(accordionId, true);
```

## Enums

```javascript
// Alert styles
ZylixShowcase.AlertStyle.INFO     // 0
ZylixShowcase.AlertStyle.SUCCESS  // 1
ZylixShowcase.AlertStyle.WARNING  // 2
ZylixShowcase.AlertStyle.ERROR    // 3

// Progress styles
ZylixShowcase.ProgressStyle.LINEAR   // 0
ZylixShowcase.ProgressStyle.CIRCULAR // 1

// Stack alignment
ZylixShowcase.StackAlignment.START         // 0
ZylixShowcase.StackAlignment.CENTER        // 1
ZylixShowcase.StackAlignment.END           // 2
ZylixShowcase.StackAlignment.STRETCH       // 3
ZylixShowcase.StackAlignment.SPACE_BETWEEN // 4
ZylixShowcase.StackAlignment.SPACE_AROUND  // 5
ZylixShowcase.StackAlignment.SPACE_EVENLY  // 6
```

## License

MIT - Part of the Zylix framework
