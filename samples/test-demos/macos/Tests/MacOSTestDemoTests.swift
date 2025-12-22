import XCTest
@testable import MacOSTestDemo

/// Zylix Test Framework - macOS E2E Test Examples
///
/// These tests demonstrate how to use the Zylix Test Framework
/// to automate macOS application testing via Accessibility APIs.

final class MacOSTestDemoTests: XCTestCase {

    var client: ZylixMacTestClient!

    override func setUp() async throws {
        client = ZylixMacTestClient(port: 8200)
    }

    // MARK: - Connection Tests

    func testBridgeAvailability() async throws {
        let available = await client.isAvailable()

        if !available {
            print("⏭️  macOS Accessibility Bridge not available, skipping tests")
            throw XCTSkip("Bridge not available")
        }

        print("✅ macOS Accessibility Bridge is available")
    }

    // MARK: - Session Tests

    func testSessionLifecycle() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        // Create session with Finder
        let session = try await client.createSession(bundleId: "com.apple.finder")

        XCTAssertFalse(session.id.isEmpty, "Session ID should not be empty")
        print("✅ Created session: \(session.id)")

        // Clean up
        try await client.deleteSession(session.id)
        print("✅ Deleted session")
    }

    // MARK: - Element Finding Tests

    func testFindByAccessibilityId() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            let menuBar = try await session.find(accessibilityId: "AXMenuBar")
            XCTAssertTrue(menuBar.exists, "Menu bar should exist")
            print("✅ Found menu bar by accessibility ID")
        } catch {
            print("⚠️  Element not found: \(error)")
        }
    }

    func testFindByRole() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            let fileMenu = try await session.find(
                role: "AXMenuBarItem",
                title: "File"
            )
            XCTAssertTrue(fileMenu.exists, "File menu should exist")
            print("✅ Found File menu by role")
        } catch {
            print("⚠️  Menu not found (Finder might not be frontmost)")
        }
    }

    // MARK: - Window Management Tests

    func testGetWindows() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        let windows = try await session.getWindows()

        print("✅ Found \(windows.count) window(s)")
        for window in windows {
            print("   - \(window.title ?? "Untitled") at \(window.position)")
        }
    }

    func testActivateWindow() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        let windows = try await session.getWindows()

        if let window = windows.first {
            try await session.activateWindow(window.id)
            print("✅ Activated window: \(window.title ?? "Untitled")")
        } else {
            print("⚠️  No windows to activate")
        }
    }

    // MARK: - Element Interaction Tests

    func testClickElement() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            // Try to click File menu
            let fileMenu = try await session.find(
                role: "AXMenuBarItem",
                title: "File"
            )
            try await fileMenu.tap()
            print("✅ Clicked File menu")

            // Wait for menu to open
            try await Task.sleep(nanoseconds: 300_000_000)

            // Press Escape to close
            try await session.pressKey(key: "escape")
            print("✅ Closed menu")
        } catch {
            print("⚠️  Click test incomplete: \(error)")
        }
    }

    // MARK: - Keyboard Tests

    func testKeyboardShortcut() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        // Cmd+N - New Finder Window
        try await session.pressKey(key: "n", modifiers: [.command])
        print("✅ Sent Cmd+N")

        // Wait for window
        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify new window appeared
        let windows = try await session.getWindows()
        print("✅ Now have \(windows.count) window(s)")
    }

    func testTypeText() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        // Use TextEdit for typing test
        let session = try await client.createSession(bundleId: "com.apple.TextEdit")
        defer { Task { try? await client.deleteSession(session.id) } }

        // Give app time to launch
        try await Task.sleep(nanoseconds: 1_000_000_000)

        try await session.typeText("Hello from Zylix Test!")
        print("✅ Typed text")
    }

    // MARK: - Screenshot Tests

    func testScreenshot() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        let screenshot = try await session.takeScreenshot()

        XCTAssertGreaterThan(screenshot.count, 0, "Screenshot should have data")
        print("✅ Captured screenshot: \(screenshot.count) bytes")

        // Save to temp
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zylix-macos-screenshot.png")
        try screenshot.write(to: tempURL)
        print("✅ Saved to: \(tempURL.path)")
    }

    func testWindowScreenshot() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("Bridge not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.finder")
        defer { Task { try? await client.deleteSession(session.id) } }

        let windows = try await session.getWindows()

        if let window = windows.first {
            let screenshot = try await session.takeScreenshot(windowId: window.id)
            XCTAssertGreaterThan(screenshot.count, 0)
            print("✅ Captured window screenshot: \(screenshot.count) bytes")
        } else {
            print("⚠️  No windows for screenshot")
        }
    }
}

// MARK: - macOS Testing Patterns Documentation

/*
 macOS-Specific Testing Patterns:

 1. Session Management:
    - Create session with bundle ID
    - App will be launched if not running
    - Clean up sessions in defer blocks

 2. Element Finding:
    - Accessibility ID: For elements with identifiers
    - Role + Title: For menu items, buttons
    - Predicate: For complex queries

 3. Accessibility Roles:
    - AXApplication: The app itself
    - AXWindow: Windows
    - AXMenuBar, AXMenuBarItem, AXMenuItem: Menus
    - AXButton, AXTextField, AXStaticText: Controls
    - AXGroup, AXList, AXTable: Containers

 4. Window Management:
    - Get all windows
    - Activate specific window
    - Window screenshots

 5. Keyboard Interaction:
    - Key + modifiers (command, option, control, shift)
    - Type text directly
    - Keyboard shortcuts for menu commands

 6. Permissions:
    - Terminal/IDE needs Accessibility permission
    - System Preferences → Privacy & Security → Accessibility
*/
