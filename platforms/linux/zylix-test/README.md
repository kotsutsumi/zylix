# Zylix Test Framework - Linux Driver

AT-SPI2 (Assistive Technology Service Provider Interface) based test driver for Linux desktop E2E testing.

## Overview

This Python server bridges the Zylix Test Framework (Zig) with Linux AT-SPI2 for desktop application automation on GNOME, KDE, and other Linux desktop environments.

## Requirements

- Linux with AT-SPI2 enabled
- Python 3.8+
- python3-pyatspi (pyatspi2)
- python3-gi (GObject Introspection)
- X11 or Wayland display server

## Installation

### Debian/Ubuntu

```bash
sudo apt install python3-pyatspi at-spi2-core python3-gi gnome-screenshot
```

### Fedora

```bash
sudo dnf install python3-pyatspi at-spi2-core python3-gobject gnome-screenshot
```

### Arch Linux

```bash
sudo pacman -S python-atspi at-spi2-core python-gobject gnome-screenshot
```

## Running the Server

```bash
cd platforms/linux/zylix-test
python3 zylix_test_server.py
```

The server runs on `http://127.0.0.1:8300` by default.

## Enable Accessibility

AT-SPI2 must be enabled for desktop automation to work:

### GNOME

```bash
gsettings set org.gnome.desktop.interface toolkit-accessibility true
```

### KDE

Enable accessibility in System Settings → Accessibility.

### Environment Variable

```bash
export GTK_MODULES=gail:atk-bridge
export QT_ACCESSIBILITY=1
```

## Usage

### From Zig Test Code

```zig
const zylix_test = @import("zylix_test");

test "Linux app login flow" {
    // Create Linux driver
    var driver = try zylix_test.createLinuxDriver(allocator, .{
        .display = ":0",
    });
    defer driver.deinit();

    // Launch app
    try driver.launchApp(.{
        .desktop_file = "org.gnome.Calculator.desktop",
    });
    defer driver.close() catch {};

    // Or launch by executable
    try driver.launchApp(.{
        .executable = "/usr/bin/gnome-calculator",
    });

    // Find and interact with elements
    if (try driver.findElement(.{ .strategy = .name, .value = "7" })) |button| {
        defer button.deinit();
        try button.click();
    }

    // Wait for element
    if (try driver.waitForElement(.{ .strategy = .role, .value = "entry" }, 5000)) |entry| {
        defer entry.deinit();
        try entry.typeText("123");
    }
}
```

## API Endpoints

### Session Management

- `POST /session/new/launch` - Launch app and create session
- `POST /session/new/attach` - Attach to running app
- `POST /session/{id}/close` - Close session and terminate app

### Element Finding

- `POST /session/{id}/findElement` - Find single element
- `POST /session/{id}/findElements` - Find all matching elements

### Element Interactions

- `POST /session/{id}/click` - Click element
- `POST /session/{id}/doubleClick` - Double-click element
- `POST /session/{id}/rightClick` - Right-click element
- `POST /session/{id}/type` - Type text into element
- `POST /session/{id}/clear` - Clear element text
- `POST /session/{id}/focus` - Focus element

### Element Queries

- `POST /session/{id}/getText` - Get element text
- `POST /session/{id}/getName` - Get element accessible name
- `POST /session/{id}/getRole` - Get element AT-SPI role
- `POST /session/{id}/getDescription` - Get element description
- `POST /session/{id}/isVisible` - Check element visibility
- `POST /session/{id}/isEnabled` - Check if element is enabled
- `POST /session/{id}/isFocused` - Check if element is focused
- `POST /session/{id}/getBounds` - Get element bounding rect
- `POST /session/{id}/getAttribute` - Get element attribute

### Screenshots

- `POST /session/{id}/screenshot` - Take app screenshot
- `POST /session/{id}/elementScreenshot` - Take element screenshot

### Window & Input

- `POST /session/{id}/window` - Get window information
- `POST /session/{id}/keys` - Send keyboard input

## Selector Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| `role` | AT-SPI role | `"push button"`, `"entry"` |
| `name` | Accessible name | `"Submit"`, `"Username"` |
| `description` | Accessible description | `"Enter your password"` |
| `application` | Application name | `"Calculator"` |
| `state` | State-based | `"focusable"` |
| `path` | Hierarchical path | `"window/panel/button"` |

## AT-SPI Roles

Common AT-SPI roles for element finding:

| Role | Description |
|------|-------------|
| `push button` | Clickable buttons |
| `entry` | Text input fields |
| `text` | Static text |
| `label` | Labels |
| `check box` | Checkboxes |
| `radio button` | Radio buttons |
| `combo box` | Dropdown lists |
| `menu` | Menus |
| `menu item` | Menu items |
| `list` | List containers |
| `list item` | List items |
| `tree` | Tree views |
| `tree item` | Tree items |
| `tab` | Tab pages |
| `slider` | Sliders |
| `progress bar` | Progress indicators |
| `frame` | Window frames |
| `dialog` | Dialog windows |
| `panel` | Panel containers |

## Troubleshooting

### AT-SPI Not Working

Check if AT-SPI bus is running:

```bash
ps aux | grep at-spi
# Should show at-spi2-registryd running
```

Start the registry daemon:

```bash
/usr/libexec/at-spi2-registryd &
```

### Element Not Found

Use Accerciser to inspect the AT-SPI tree:

```bash
sudo apt install accerciser
accerciser
```

### Permission Denied

Some desktop environments require accessibility to be explicitly enabled. Check your desktop environment's accessibility settings.

### Wayland Issues

On Wayland, some features may require additional permissions. Consider running apps under XWayland for full automation support.

## Development

### Debug Mode

Set `ATSPI_DEBUG=1` for verbose AT-SPI output:

```bash
ATSPI_DEBUG=1 python3 zylix_test_server.py
```

### Running Tests

```bash
python3 -m pytest tests/
```

## License

MIT
