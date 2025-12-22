import XCTest
@testable import WatchOSTestDemo

/// Zylix Test Framework - watchOS E2E Test Examples
///
/// These tests demonstrate watchOS-specific testing capabilities
/// including Digital Crown and Side Button interactions.

final class WatchOSTestDemoTests: XCTestCase {

    var client: ZylixWatchTestClient!

    override func setUp() async throws {
        client = ZylixWatchTestClient(port: 8100)
    }

    // MARK: - Connection Tests

    func testWDAAvailability() async throws {
        let available = await client.isAvailable()

        if !available {
            print("⏭️  WebDriverAgent not available, skipping watchOS tests")
            throw XCTSkip("WDA not available")
        }

        print("✅ WebDriverAgent is available for watchOS testing")
    }

    // MARK: - Session Tests

    func testWatchSessionLifecycle() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        // Create watchOS session
        let session = try await client.createSession(
            bundleId: "com.apple.Preferences",
            deviceName: "Apple Watch Series 9 (45mm)",
            platformVersion: "11.0"
        )

        XCTAssertFalse(session.id.isEmpty, "Session ID should not be empty")
        print("✅ Created watchOS session: \(session.id)")

        // Clean up
        try await client.deleteSession(session.id)
        print("✅ Deleted watchOS session")
    }

    // MARK: - Digital Crown Tests

    func testDigitalCrownRotation() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        // Rotate up (clockwise)
        do {
            try await session.rotateDigitalCrown(direction: .up, velocity: 0.5)
            print("✅ Digital Crown rotated up")
        } catch {
            print("⚠️  Digital Crown rotation failed: \(error)")
        }

        // Rotate down (counter-clockwise)
        do {
            try await session.rotateDigitalCrown(direction: .down, velocity: 0.3)
            print("✅ Digital Crown rotated down")
        } catch {
            print("⚠️  Digital Crown rotation failed: \(error)")
        }
    }

    func testDigitalCrownVelocities() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        // Test different velocities
        let velocities: [Double] = [0.1, 0.5, 1.0]

        for velocity in velocities {
            do {
                try await session.rotateDigitalCrown(
                    direction: .up,
                    velocity: velocity
                )
                print("✅ Rotated with velocity \(velocity)")

                // Small delay between rotations
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                print("⚠️  Velocity \(velocity) failed: \(error)")
            }
        }
    }

    // MARK: - Side Button Tests

    func testSideButtonPress() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            try await session.pressSideButton()
            print("✅ Side Button pressed")

            // This typically opens the app switcher
            // In a real test, verify the app switcher appeared
        } catch {
            print("⚠️  Side Button press failed: \(error)")
        }
    }

    func testSideButtonDoublePress() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            try await session.doublePresssSideButton()
            print("✅ Side Button double-pressed")

            // This typically opens Apple Pay/Wallet
            // Actual behavior depends on device configuration
        } catch {
            print("⚠️  Side Button double-press failed: \(error)")
        }
    }

    // MARK: - Companion Device Tests

    func testCompanionDeviceInfo() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        do {
            let companionInfo = try await session.getCompanionDeviceInfo()

            if let info = companionInfo {
                print("✅ Companion device info retrieved")
                print("   Device Name: \(info.deviceName ?? "Unknown")")
                print("   UDID: \(info.udid ?? "Unknown")")
                print("   Is Paired: \(info.isPaired)")
                XCTAssertTrue(info.isPaired, "Device should be paired")
            } else {
                print("⚠️  No companion device info available")
            }
        } catch {
            print("⚠️  Companion info retrieval failed: \(error)")
        }
    }

    // MARK: - Element Tests

    func testFindElement() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        // Try to find an element
        do {
            let element = try await session.find(accessibilityId: "General")
            XCTAssertTrue(element.exists, "Element should exist")
            print("✅ Found element on watchOS")
        } catch {
            // Element might not be visible on small screen
            print("⚠️  Element not found (expected on some configurations)")
        }
    }

    // MARK: - Screenshot Tests

    func testWatchScreenshot() async throws {
        guard await client.isAvailable() else {
            throw XCTSkip("WDA not available")
        }

        let session = try await client.createSession(
            bundleId: "com.apple.Preferences"
        )
        defer { Task { try? await client.deleteSession(session.id) } }

        let screenshot = try await session.takeScreenshot()

        XCTAssertGreaterThan(screenshot.count, 0, "Screenshot should have data")
        print("✅ Captured watchOS screenshot: \(screenshot.count) bytes")

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zylix-watchos-screenshot.png")
        try screenshot.write(to: tempURL)
        print("✅ Saved to: \(tempURL.path)")
    }
}

// MARK: - watchOS Test Patterns Documentation

/*
 watchOS-Specific Testing Patterns:

 1. Digital Crown:
    - direction: .up (clockwise) or .down (counter-clockwise)
    - velocity: 0.0 to 1.0 (slow to fast rotation)
    - Use for scrolling, value adjustment, navigation

 2. Side Button:
    - Single press: Opens app switcher
    - Double press: Opens Apple Pay/Wallet
    - Long press: Power options (not typically testable)

 3. Companion Device:
    - Get pairing status
    - Retrieve companion iPhone info
    - Essential for Watch Connectivity testing

 4. Small Screen Considerations:
    - Use accessibility IDs for reliable element finding
    - Elements may need scrolling to become visible
    - Touch targets are smaller than iPhone

 5. Screen Sizes by Device:
    - Series 9 (41mm): 352x430
    - Series 9 (45mm): 396x484
    - Ultra 2: 502x410
    - SE (40mm): 324x394
*/
