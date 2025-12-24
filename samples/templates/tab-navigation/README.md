# Tab Navigation Template

A multi-tab application template with bottom tab bar navigation, state preservation, and multiple screens.

## Overview

This template provides a complete tab-based navigation structure:
- Bottom TabBar with icons and labels
- Multiple tab screens (Home, Search, Profile, Settings)
- State preservation when switching tabs
- Badge support for notifications
- Platform-native tab styling

## Project Structure

```
tab-navigation/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state and navigation
│       ├── router.zig      # Tab routing logic
│       └── screens/
│           ├── home.zig    # Home screen
│           ├── search.zig  # Search screen
│           ├── profile.zig # Profile screen
│           └── settings.zig # Settings screen
└── platforms/
    ├── ios/
    ├── android/
    └── web/
```

## Features

### Tab Bar
- 4 default tabs with customizable icons
- Active/inactive state styling
- Badge indicators for notifications
- Safe area handling for modern devices

### State Preservation
- Each tab maintains its own state
- Scroll position preserved on tab switch
- Form data retained when navigating

### Navigation
- Tab-to-tab navigation
- Deep linking support
- Back button handling per tab

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

### Adding a New Tab

1. Define the tab in `router.zig`:
```zig
pub const Tab = enum {
    home,
    search,
    profile,
    settings,
    // Add your new tab here
    notifications,
};
```

2. Create the screen in `screens/`:
```zig
// screens/notifications.zig
pub fn build(state: *const AppState) VNode {
    return column(.{}, .{
        text("Notifications", .{ .style = .heading }),
        // Your content here
    });
}
```

3. Add to the tab bar icons:
```zig
pub fn getTabIcon(tab: Tab) []const u8 {
    return switch (tab) {
        .notifications => "bell",
        // ...
    };
}
```

### Customizing Tab Bar Style

```zig
const tab_bar_style = TabBarStyle{
    .background = Color.fromHex("#FFFFFF"),
    .active_color = Color.primary,
    .inactive_color = Color.gray,
    .height = 56,
    .show_labels = true,
    .icon_size = 24,
};
```

### Adding Badges

```zig
// In app.zig
pub fn setBadge(tab: Tab, count: u32) void {
    app_state.badges[@intFromEnum(tab)] = count;
}

// Usage
app.setBadge(.notifications, 5);
```

## Tab Screens

### Home
- Welcome message
- Quick actions grid
- Recent activity feed

### Search
- Search input field
- Search filters
- Results list

### Profile
- User avatar and info
- Stats display
- Action buttons

### Settings
- Toggle switches
- Selection lists
- Version info

## Platform Integration

### iOS (SwiftUI)
```swift
TabView(selection: $selectedTab) {
    HomeView().tag(0).tabItem {
        Label("Home", systemImage: "house")
    }
    // ... more tabs
}
```

### Android (Compose)
```kotlin
BottomNavigation {
    tabs.forEachIndexed { index, tab ->
        BottomNavigationItem(
            selected = selectedTab == index,
            onClick = { selectedTab = index },
            icon = { Icon(tab.icon) },
            label = { Text(tab.label) }
        )
    }
}
```

### Web
```javascript
<nav class="tab-bar">
    <button class="tab" data-active={activeTab === 0}>
        <Icon name="home" />
        <span>Home</span>
    </button>
    // ... more tabs
</nav>
```

## Related Templates

- [Blank App](../blank-app/) - Minimal starter
- [Drawer Navigation](../drawer-navigation/) - Side menu navigation
- [Dashboard Layout](../dashboard-layout/) - Dashboard structure

## License

MIT License
