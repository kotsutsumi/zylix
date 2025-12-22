# macOS E2E Test Demo

Demonstrates Zylix Test Framework for macOS app testing with Accessibility Bridge.

## Prerequisites

1. **macOS 13.0+** - Ventura or later
2. **Xcode 15+** - With Command Line Tools
3. **Accessibility Permissions** - System Preferences → Privacy & Security → Accessibility

## Setup

### 1. Enable Accessibility

```bash
# Check accessibility permissions
tccutil reset Accessibility

# Add terminal to accessibility (may need manual approval)
# System Preferences → Privacy & Security → Accessibility → Add Terminal
```

### 2. Build and Run Accessibility Bridge

```bash
cd platforms/macos/zylix-test
swift build
.build/debug/zylix-test-server --port 8200
```

### 3. Verify Server

```bash
curl http://localhost:8200/status
# Should return: {"status":0,"value":{"ready":true}}
```

## Run Tests

```bash
# Using Zig (native)
cd ../../../core
zig build test-e2e

# Using Swift
swift test
```

## Test Examples

### Session Management

```swift
// Tests/MacOSTestDemoTests/SessionTests.swift
import XCTest

final class SessionTests: XCTestCase {
    func testSessionLifecycle() async throws {
        let client = ZylixMacTestClient(port: 8200)

        let session = try await client.createSession(
            bundleId: "com.apple.finder"
        )

        XCTAssertFalse(session.id.isEmpty)
        print("✅ Created session: \(session.id)")

        try await client.deleteSession(session.id)
        print("✅ Deleted session")
    }
}
```

### Element Finding

```swift
func testFindByAccessibilityId() async throws {
    let client = ZylixMacTestClient()
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )
    defer { Task { try? await client.deleteSession(session.id) } }

    // Find by accessibility identifier
    let element = try await session.find(
        accessibilityId: "AXMenuBar"
    )

    XCTAssertTrue(element.exists)
}

func testFindByRole() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    // Find all windows
    let windows = try await session.findAll(
        role: "AXWindow"
    )

    XCTAssertGreaterThan(windows.count, 0)
}

func testFindByTitle() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    // Find menu by title
    let fileMenu = try await session.find(
        role: "AXMenuBarItem",
        title: "File"
    )

    XCTAssertTrue(fileMenu.exists)
}
```

### Window Management

```swift
func testGetWindows() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    let windows = try await session.getWindows()

    for window in windows {
        print("Window: \(window.title ?? "Untitled")")
        print("  Position: \(window.position)")
        print("  Size: \(window.size)")
    }
}

func testActivateWindow() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    let windows = try await session.getWindows()

    if let firstWindow = windows.first {
        try await session.activateWindow(firstWindow.id)
        print("✅ Activated window")
    }
}
```

### Menu Bar Interaction

```swift
func testMenuBarClick() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    // Click File menu
    let fileMenu = try await session.find(
        role: "AXMenuBarItem",
        title: "File"
    )
    try await fileMenu.tap()

    // Wait for menu to open
    try await Task.sleep(nanoseconds: 300_000_000)

    // Click "New Finder Window"
    let newWindowItem = try await session.find(
        role: "AXMenuItem",
        title: "New Finder Window"
    )
    try await newWindowItem.tap()

    print("✅ Menu item clicked")
}
```

### Keyboard Shortcuts

```swift
func testKeyboardShortcut() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    // Cmd+N - New Finder Window
    try await session.pressKey(
        key: "n",
        modifiers: [.command]
    )

    print("✅ Keyboard shortcut sent")
}

func testTypeText() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.TextEdit"
    )

    // Type into the document
    try await session.typeText("Hello from Zylix Test!")

    print("✅ Text typed")
}
```

### Screenshots

```swift
func testScreenshot() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    let screenshot = try await session.takeScreenshot()

    XCTAssertGreaterThan(screenshot.count, 0)
    print("✅ Captured screenshot: \(screenshot.count) bytes")
}

func testWindowScreenshot() async throws {
    let session = try await client.createSession(
        bundleId: "com.apple.finder"
    )

    let windows = try await session.getWindows()

    if let window = windows.first {
        let screenshot = try await session.takeScreenshot(
            windowId: window.id
        )
        print("✅ Captured window screenshot")
    }
}
```

## Zig Native Usage

```zig
const std = @import("std");
const desktop_test = @import("desktop_e2e_test.zig");

test "macOS session" {
    const allocator = std.testing.allocator;

    if (!desktop_test.isBridgeAvailable()) {
        std.debug.print("macOS bridge not available\n", .{});
        return;
    }

    const response = try desktop_test.macosCreateSession(
        allocator,
        "com.apple.finder"
    );
    defer allocator.free(response);

    const session_id = desktop_test.parseSessionId(response) orelse return;

    // Get windows
    const windows_resp = try desktop_test.macosGetWindows(
        allocator,
        session_id
    );
    defer allocator.free(windows_resp);

    std.debug.print("✅ macOS test passed\n", .{});
}
```

## Accessibility Roles

| Role | Description | Example |
|------|-------------|---------|
| AXApplication | Application | Finder, Safari |
| AXWindow | Window | Document window |
| AXButton | Button | Toolbar button |
| AXTextField | Text field | Search field |
| AXMenuBar | Menu bar | App menu bar |
| AXMenuBarItem | Menu bar item | File, Edit |
| AXMenuItem | Menu item | New, Open, Save |
| AXToolbar | Toolbar | Window toolbar |
| AXGroup | Group container | Sidebar group |
| AXList | List | File list |
| AXTable | Table | Column view |
| AXScrollArea | Scroll area | Content area |
| AXStaticText | Static text | Label |
| AXImage | Image | Icon |

## Accessibility Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| AXRole | String | Element type |
| AXTitle | String | Display title |
| AXDescription | String | Accessibility description |
| AXValue | Any | Current value |
| AXEnabled | Bool | Is interactable |
| AXFocused | Bool | Has keyboard focus |
| AXPosition | Point | Screen position |
| AXSize | Size | Element dimensions |
| AXChildren | Array | Child elements |
| AXParent | Element | Parent element |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied | Add Terminal to Accessibility in System Preferences |
| App not found | Check bundle ID: `osascript -e 'id of app "Finder"'` |
| Element not found | Use Accessibility Inspector (Xcode) |
| Bridge not responding | Check port 8200 is not in use |
| Actions failing | Verify app is frontmost |

## Debug Tools

### Accessibility Inspector

```bash
# Open Accessibility Inspector (part of Xcode)
open -a "Accessibility Inspector"
```

### Get Bundle ID

```bash
# Get bundle ID of running app
osascript -e 'id of app "Safari"'
# Returns: com.apple.Safari

# List all running apps
osascript -e 'tell application "System Events" to get bundle identifier of every process whose background only is false'
```

### Check Accessibility

```bash
# Verify accessibility enabled
defaults read com.apple.universalaccess AXIsAccessibilityEnabled
```
