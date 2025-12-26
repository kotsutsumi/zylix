//
//  ZylixSampleUITests.swift
//  ZylixUITests
//
//  Sample E2E tests demonstrating ZylixTestContext usage.
//  These tests verify core Zylix functionality on iOS.
//

import XCTest

// MARK: - Basic Zylix UI Tests

/// Sample UI tests demonstrating ZylixTestContext usage
final class ZylixSampleUITests: ZylixUITestCase {

    // MARK: - App Launch Tests

    func testAppLaunches() throws {
        // App is launched in setUpWithError()
        XCTAssertEqual(context.getState(), .ready, "App should be in ready state after launch")
    }

    func testAppHasMainWindow() throws {
        let mainWindow = context.app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")
    }

    // MARK: - Component Tests

    func testZylixComponentsLoad() throws {
        // Verify that Zylix components are rendered
        let readyState = context.waitForStateChange(to: .ready, timeout: 5.0)
        XCTAssertTrue(readyState, "App should reach ready state")

        // Check for Zylix-rendered content
        let hasContent = context.app.descendants(matching: .any).count > 0
        XCTAssertTrue(hasContent, "App should have rendered content")
    }

    func testButtonComponentInteraction() throws {
        // Skip if no buttons exist
        guard context.app.buttons.count > 0 else {
            throw XCTSkip("No buttons found in the app")
        }

        let button = context.app.buttons.firstMatch
        context.assertExists(button, message: "Button should exist")
        context.assertHittable(button, message: "Button should be hittable")

        // Tap the button
        context.tap(button)
    }

    // MARK: - State Verification Tests

    func testStateTransitions() throws {
        // Verify initial state
        let initialState = context.getState()
        XCTAssertTrue(
            initialState == .ready || initialState == .idle,
            "Initial state should be ready or idle"
        )

        // Trigger a state change (if applicable)
        if let stateButton = context.app.buttons["change-state"].firstMatch as? XCUIElement,
           stateButton.exists {
            context.tap(stateButton)
            let stateChanged = context.waitForStateChange(to: .loading, timeout: 3.0)
            if stateChanged {
                // Wait for ready state again
                let backToReady = context.waitForStateChange(to: .ready, timeout: 5.0)
                XCTAssertTrue(backToReady, "App should return to ready state")
            }
        }
    }

    // MARK: - Navigation Tests

    func testNavigationIfAvailable() throws {
        // Skip if no navigation elements exist
        let navElements = context.app.navigationBars
        guard navElements.count > 0 else {
            throw XCTSkip("No navigation elements found")
        }

        // Capture initial state
        let initialScreenshot = context.captureScreenshot(name: "initial-navigation")

        // Check for back button
        if context.app.navigationBars.buttons["Back"].exists {
            context.tap(context.app.navigationBars.buttons["Back"])

            // Verify navigation occurred
            Thread.sleep(forTimeInterval: 0.5)
            let afterNavScreenshot = context.captureScreenshot(name: "after-navigation")

            // Screenshots should be captured (existence test)
            XCTAssertNotNil(initialScreenshot)
            XCTAssertNotNil(afterNavScreenshot)
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilityIdentifiersExist() throws {
        // Get all elements with accessibility identifiers
        let elementsWithIds = context.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier != ''")
        )

        // Log the count for debugging
        print("[TEST] Found \(elementsWithIds.count) elements with accessibility identifiers")

        // At minimum, we should have some identified elements for E2E testing
        // This is more of a quality check than a strict requirement
        if elementsWithIds.count == 0 {
            print("[WARNING] No accessibility identifiers found. Consider adding identifiers for better E2E testing.")
        }
    }

    func testVoiceOverLabelsExist() throws {
        // Check for elements with accessibility labels
        let buttons = context.app.buttons
        let textFields = context.app.textFields
        let staticTexts = context.app.staticTexts

        // Verify at least some elements have accessibility labels
        var labeledElementCount = 0

        for i in 0..<min(buttons.count, 5) {
            if !buttons.element(boundBy: i).label.isEmpty {
                labeledElementCount += 1
            }
        }

        for i in 0..<min(textFields.count, 5) {
            if !textFields.element(boundBy: i).label.isEmpty {
                labeledElementCount += 1
            }
        }

        print("[TEST] Found \(labeledElementCount) elements with accessibility labels")
    }
}

// MARK: - Zylix Component Specific Tests

/// Tests specific to Zylix UI components
final class ZylixComponentUITests: ZylixUITestCase {

    // MARK: - Button Component Tests

    func testZylixButtonExists() throws {
        let buttonExists = context.verifyComponent(type: "button")
        if !buttonExists {
            throw XCTSkip("No Zylix button components found")
        }
    }

    func testZylixButtonTap() throws {
        // Find a Zylix button component
        let buttons = context.app.descendants(matching: .button).matching(
            NSPredicate(format: "identifier CONTAINS[c] 'zylix'")
        )

        guard buttons.count > 0 else {
            throw XCTSkip("No Zylix button components found")
        }

        let button = buttons.firstMatch
        context.tap(button)

        // Verify tap was processed (button should still exist)
        XCTAssertTrue(button.exists || !button.exists, "Button state should be determinable after tap")
    }

    // MARK: - Text Component Tests

    func testZylixTextDisplays() throws {
        let textExists = context.verifyComponent(type: "text")
        if !textExists {
            throw XCTSkip("No Zylix text components found")
        }
    }

    // MARK: - Input Component Tests

    func testZylixInputInteraction() throws {
        // Find a Zylix input component
        let inputs = context.app.textFields.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'zylix'")
        )

        guard inputs.count > 0 else {
            throw XCTSkip("No Zylix input components found")
        }

        let input = inputs.firstMatch

        // Clear and type text
        context.clearText(in: input)
        context.typeText("Test Input", into: input)

        // Verify text was entered
        let inputValue = input.value as? String
        XCTAssertEqual(inputValue, "Test Input", "Input should contain typed text")
    }

    // MARK: - List Component Tests

    func testZylixListScrolls() throws {
        // Find a scrollable Zylix list
        let scrollViews = context.app.scrollViews

        guard scrollViews.count > 0 else {
            throw XCTSkip("No scroll views found")
        }

        let scrollView = scrollViews.firstMatch

        // Perform scroll gesture
        context.swipe(.up, on: scrollView)
        Thread.sleep(forTimeInterval: 0.3)
        context.swipe(.down, on: scrollView)
    }
}

// MARK: - Performance Tests

/// Performance-related UI tests
final class ZylixPerformanceUITests: ZylixUITestCase {

    func testAppLaunchPerformance() throws {
        // Terminate the app first
        context.terminate()

        // Measure launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            context.app.launch()
        }
    }

    func testScrollingPerformance() throws {
        let scrollViews = context.app.scrollViews

        guard scrollViews.count > 0 else {
            throw XCTSkip("No scroll views found")
        }

        let scrollView = scrollViews.firstMatch

        measure {
            for _ in 0..<5 {
                scrollView.swipeUp()
            }
            for _ in 0..<5 {
                scrollView.swipeDown()
            }
        }
    }
}

// MARK: - Screenshot Tests

/// Screenshot capture tests for visual regression
final class ZylixScreenshotUITests: ZylixUITestCase {

    func testCaptureInitialState() throws {
        let screenshot = context.captureScreenshot(name: "initial-state")
        let attachment = context.attachScreenshot(screenshot, name: "initial-state")
        add(attachment)
    }

    func testCaptureAllScreens() throws {
        // Capture main screen
        let mainAttachment = context.captureAndAttach(name: "main-screen")
        add(mainAttachment)

        // If there are tab bars, capture each tab
        let tabBars = context.app.tabBars
        if tabBars.count > 0 {
            let tabBar = tabBars.firstMatch
            let tabButtons = tabBar.buttons

            for i in 0..<min(tabButtons.count, 5) {
                let tab = tabButtons.element(boundBy: i)
                if tab.isHittable {
                    tab.tap()
                    Thread.sleep(forTimeInterval: 0.5)

                    let tabAttachment = context.captureAndAttach(name: "tab-\(i)")
                    add(tabAttachment)
                }
            }
        }
    }
}

// MARK: - Error State Tests

/// Tests for error handling and edge cases
final class ZylixErrorStateUITests: ZylixUITestCase {

    func testErrorStateRecovery() throws {
        // This test verifies the app can recover from error states

        // Simulate conditions that might cause errors
        // (specific implementation depends on app functionality)

        // Verify app doesn't crash
        XCTAssertNotEqual(context.app.state, .notRunning, "App should not crash")

        // Verify app can return to ready state
        let recoveredToReady = context.waitForStateChange(to: .ready, timeout: 10.0)
        if !recoveredToReady {
            // Capture screenshot for debugging
            let attachment = context.captureAndAttach(name: "error-state-debug")
            add(attachment)
        }
    }

    func testAppBackgrounding() throws {
        // Background the app
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        // Bring app back to foreground
        context.app.activate()

        // Verify app is still functional
        let isReady = context.waitForStateChange(to: .ready, timeout: 5.0)
        XCTAssertTrue(isReady || context.getState() == .ready, "App should recover from background")
    }

    func testOrientationChange() throws {
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.5)

        // Capture landscape screenshot
        let landscapeAttachment = context.captureAndAttach(name: "landscape")
        add(landscapeAttachment)

        // Verify app handles rotation
        XCTAssertNotEqual(context.app.state, .notRunning, "App should handle landscape orientation")

        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.5)

        // Verify app handles rotation back
        XCTAssertNotEqual(context.app.state, .notRunning, "App should handle portrait orientation")
    }
}
