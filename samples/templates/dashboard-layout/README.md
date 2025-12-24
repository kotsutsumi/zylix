# Dashboard Layout Template

A business dashboard template with header, sidebar, content area, and responsive widget grid.

## Overview

This template provides a complete dashboard structure:
- Fixed header with branding and user menu
- Collapsible sidebar navigation
- Main content area with widget grid
- Responsive layout for all screen sizes
- Dark/light theme support

## Project Structure

```
dashboard-layout/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       └── dashboard.zig   # Dashboard UI
└── platforms/
```

## Features

### Layout Zones
- **Header**: Logo, search, notifications, user profile
- **Sidebar**: Navigation menu, collapsible on mobile
- **Content**: Widget grid with drag-drop support
- **Footer**: Status bar, version info

### Widgets
- Stats cards with trends
- Charts placeholders
- Recent activity feed
- Quick actions panel

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## Related Templates

- [Blank App](../blank-app/) - Minimal starter
- [Tab Navigation](../tab-navigation/) - Tab-based navigation
- [Drawer Navigation](../drawer-navigation/) - Side drawer navigation

## License

MIT License
