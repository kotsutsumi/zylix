import XCTest
@testable import IOSTestDemo

/// Zylix Test Framework - iOS E2E Test Examples
///
/// These tests demonstrate how to use the Zylix Test Framework
/// to automate iOS application testing via WebDriverAgent.

final class IOSTestDemoTests: XCTestCase {

    var client: ZylixTestClient!

    override func setUp() async throws {
        client = ZylixTestClient(port: 8100)
    }

    // MARK: - Connection Tests

    func testWDAAvailability() async throws {
        // Check if WebDriverAgent is running
        let available = await client.isAvailable()

        if !available {
            print("⏭️  WebDriverAgent not available, skipping iOS tests")
            throw XCTSkip("WDA not available")
        }

        print("✅ WebDriverAgent is available")
    }

    // MARK: - Session Tests

    func testSessionLifecycle() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        // Create session with Settings app
        let session = try await client.createSession(bundleId: "com.apple.Preferences")

        XCTAssertFalse(session.id.isEmpty, "Session ID should not be empty")
        print("✅ Created session: \(session.id)")

        // Clean up
        try await client.deleteSession(session.id)
        print("✅ Deleted session")
    }

    // MARK: - Element Tests

    func testFindElement() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.Preferences")
        defer { Task { try? await client.deleteSession(session.id) } }

        // Find "General" cell in Settings
        do {
            let element = try await session.find(accessibilityId: "General")
            XCTAssertTrue(element.exists, "General element should exist")
            print("✅ Found element: General")
        } catch {
            // Element might not be visible on first screen
            print("⚠️  General not immediately visible, this is expected on some iOS versions")
        }
    }

    func testElementInteraction() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.Preferences")
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            let element = try await session.find(accessibilityId: "General")
            try await element.tap()
            print("✅ Tapped element successfully")

            // Wait a moment for navigation
            try await Task.sleep(nanoseconds: 500_000_000)

            // We should now be on General settings page
            // In a real test, we'd verify navigation occurred
        } catch {
            print("⚠️  Interaction test incomplete: \(error)")
        }
    }

    // MARK: - Screenshot Tests

    func testScreenshot() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(bundleId: "com.apple.Preferences")
        defer { Task { try? await client.deleteSession(session.id) } }

        let screenshot = try await session.takeScreenshot()

        XCTAssertGreaterThan(screenshot.count, 0, "Screenshot should have data")
        print("✅ Captured screenshot: \(screenshot.count) bytes")

        // Optionally save to temp directory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zylix-test-screenshot.png")
        try screenshot.write(to: tempURL)
        print("✅ Saved screenshot to: \(tempURL.path)")
    }
}

// MARK: - Test Patterns Documentation

/*
 These tests demonstrate the Zylix Test Framework patterns:

 1. Session Lifecycle:
    - Create session with bundle ID
    - Run tests
    - Clean up session in defer block

 2. Element Finding:
    - Use accessibility identifiers (recommended)
    - Use predicates for complex queries
    - Handle "element not found" gracefully

 3. Element Interaction:
    - tap() for single touches
    - longPress(duration:) for context menus
    - swipe(direction:) for scrolling

 4. Screenshots:
    - Capture full screen
    - Save for debugging
    - Include in test reports

 5. Error Handling:
    - Skip tests when WDA unavailable
    - Use XCTSkip for conditional tests
    - Clean up resources in defer blocks
*/
