# Drawer Navigation Template

A side drawer navigation template with hamburger menu, nested navigation, and responsive layout.

## Overview

This template provides a complete drawer-based navigation structure:
- Side drawer with menu items
- Hamburger menu toggle
- Nested navigation sections
- Responsive behavior (persistent on tablet/desktop)
- Header with title and actions

## Project Structure

```
drawer-navigation/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state and navigation
│       └── drawer.zig      # Drawer and screen UI
└── platforms/
    ├── ios/
    ├── android/
    └── web/
```

## Features

### Drawer Menu
- Section headers with icons
- Nested menu items
- Active state highlighting
- User info section
- Footer links

### Header Bar
- Hamburger menu button
- Dynamic title based on current screen
- Action buttons (search, notifications)
- Safe area handling

### Navigation
- Screen-based navigation
- Nested sections (Settings > Account, Notifications, etc.)
- Deep linking support

## Quick Start

```bash
# Build
cd core && zig build

# Run tests
zig build test

# Build for Web
zig build wasm
```

## Customization

### Adding Menu Items

```zig
pub const MenuItem = enum {
    home,
    dashboard,
    profile,
    settings,
    // Add your items
    reports,
    analytics,
};
```

### Menu Sections

```zig
const menu_sections = [_]MenuSection{
    .{
        .title = "Main",
        .items = &[_]MenuItem{ .home, .dashboard },
    },
    .{
        .title = "Account",
        .items = &[_]MenuItem{ .profile, .settings },
    },
};
```

### Drawer Width

```zig
const drawer_config = DrawerConfig{
    .width = 280,
    .overlay_opacity = 0.5,
    .animation_duration = 250,
};
```

## Screens

- **Home** - Welcome dashboard
- **Dashboard** - Analytics overview
- **Profile** - User information
- **Settings** - App preferences
- **Help** - Documentation links

## Related Templates

- [Blank App](../blank-app/) - Minimal starter
- [Tab Navigation](../tab-navigation/) - Tab-based navigation
- [Dashboard Layout](../dashboard-layout/) - Dashboard structure

## License

MIT License
