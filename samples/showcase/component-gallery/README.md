# Component Gallery

A comprehensive showcase of all Zylix UI components with interactive examples.

## Overview

This showcase demonstrates every UI component available in Zylix:
- Layout components (Row, Column, Stack, Grid)
- Input components (Button, TextField, Checkbox, Toggle, Slider)
- Display components (Text, Image, Icon, Card)
- Navigation components (TabBar, NavBar, Drawer)
- Feedback components (Alert, Toast, Progress, Skeleton)
- List components (List, ListItem, ScrollView)

## Features

- Interactive component playground
- Property customization panel
- Code snippets for each component
- Theme switching (Light/Dark)
- Responsive layout examples
- Accessibility demonstrations

## Project Structure

```
component-gallery/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       ├── components/     # Component catalog
│       │   ├── buttons.zig
│       │   ├── inputs.zig
│       │   ├── layout.zig
│       │   ├── display.zig
│       │   ├── navigation.zig
│       │   └── feedback.zig
│       └── ui/
│           ├── gallery.zig # Main gallery view
│           └── preview.zig # Component previewer
└── platforms/
    ├── ios/
    ├── android/
    └── web/
```

## Quick Start

```bash
# Build
cd core && zig build

# Run tests
zig build test

# Build for Web
zig build wasm
```

## Component Categories

### Layout Components

| Component | Description |
|-----------|-------------|
| `Row` | Horizontal flex container |
| `Column` | Vertical flex container |
| `Stack` | Layered/overlapping container |
| `Grid` | CSS Grid-like layout |
| `ScrollView` | Scrollable container |
| `Spacer` | Flexible space element |

### Input Components

| Component | Description |
|-----------|-------------|
| `Button` | Clickable button with variants |
| `TextField` | Text input field |
| `TextArea` | Multi-line text input |
| `Checkbox` | Boolean checkbox |
| `Toggle` | On/off switch |
| `Slider` | Range slider |
| `Select` | Dropdown selector |
| `DatePicker` | Date selection |

### Display Components

| Component | Description |
|-----------|-------------|
| `Text` | Text with typography styles |
| `Image` | Image display |
| `Icon` | Vector icons |
| `Card` | Content card container |
| `Badge` | Small status indicator |
| `Avatar` | User avatar |
| `Divider` | Horizontal/vertical line |

### Navigation Components

| Component | Description |
|-----------|-------------|
| `TabBar` | Bottom tab navigation |
| `NavBar` | Top navigation bar |
| `Drawer` | Side drawer menu |
| `Breadcrumb` | Navigation breadcrumbs |
| `Stepper` | Multi-step indicator |

### Feedback Components

| Component | Description |
|-----------|-------------|
| `Alert` | Alert message box |
| `Toast` | Temporary notification |
| `Progress` | Progress indicator |
| `Spinner` | Loading spinner |
| `Skeleton` | Loading placeholder |
| `Modal` | Modal dialog |

## Usage Example

```zig
const zylix = @import("zylix");

// Create a button with primary style
const button = zylix.ui.button("Click Me", .{
    .variant = .primary,
    .size = .medium,
    .on_click = handleClick,
});

// Create a text field
const text_field = zylix.ui.textField(.{
    .placeholder = "Enter your name",
    .value = state.name,
    .on_change = handleNameChange,
});

// Create a card layout
const card = zylix.ui.card(.{
    .elevation = 2,
    .padding = .all(16),
}, .{
    zylix.ui.text("Card Title", .{ .style = .heading }),
    zylix.ui.text("Card content goes here."),
    button,
});
```

## Theme Customization

```zig
const theme = zylix.Theme{
    .primary = Color.fromHex("#3B82F6"),
    .secondary = Color.fromHex("#6B7280"),
    .background = Color.white,
    .surface = Color.fromHex("#F3F4F6"),
    .text = Color.black,
    .border_radius = 8,
    .spacing = 16,
};

zylix.setTheme(theme);
```

## Related Samples

- [Animation Studio](../animation-studio/) - Animation demonstrations
- [Theme Builder](../theme-builder/) - Theme customization tool
- [Blank App](../../templates/blank-app/) - Minimal starter template

## License

MIT License
