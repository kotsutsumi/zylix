//
//  ZylixTestContext.swift
//  ZylixUITests
//
//  E2E Testing Context for Zylix-based iOS apps.
//  Provides unified testing helpers for XCUITest integration.
//

import XCTest

// MARK: - App State for Testing

/// Application state for E2E testing
public enum ZylixTestAppState: String {
    case idle
    case loading
    case ready
    case error
    case unknown
}

// MARK: - Test Configuration

/// Configuration for Zylix E2E tests
public struct ZylixTestConfig {
    /// Default timeout for waiting operations
    public var defaultTimeout: TimeInterval = 10.0

    /// Screenshot capture on failure
    public var captureScreenshotOnFailure: Bool = true

    /// Log level for test output
    public var logLevel: LogLevel = .info

    /// Reset app state before each test
    public var resetStateBeforeTest: Bool = true

    public enum LogLevel: Int {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
    }

    public init() {}
}

// MARK: - Zylix Test Context

/// Main testing context for Zylix E2E tests
public class ZylixTestContext {

    // MARK: - Properties

    /// The XCUIApplication under test
    public let app: XCUIApplication

    /// Test configuration
    public var config: ZylixTestConfig

    /// Current app state
    public private(set) var currentState: ZylixTestAppState = .unknown

    /// Screenshot storage
    private var screenshots: [XCUIScreenshot] = []

    // MARK: - Initialization

    /// Initialize with app bundle identifier
    public init(bundleIdentifier: String? = nil, config: ZylixTestConfig = ZylixTestConfig()) {
        if let bundleId = bundleIdentifier {
            self.app = XCUIApplication(bundleIdentifier: bundleId)
        } else {
            self.app = XCUIApplication()
        }
        self.config = config
    }

    /// Initialize with existing XCUIApplication
    public init(app: XCUIApplication, config: ZylixTestConfig = ZylixTestConfig()) {
        self.app = app
        self.config = config
    }

    // MARK: - App Lifecycle

    /// Launch the app with optional arguments
    public func launch(arguments: [String] = [], environment: [String: String] = [:]) {
        app.launchArguments = arguments
        app.launchEnvironment = environment

        if config.resetStateBeforeTest {
            app.launchArguments.append("--reset-state")
        }

        app.launch()
        log("App launched", level: .info)
    }

    /// Terminate the app
    public func terminate() {
        app.terminate()
        log("App terminated", level: .info)
    }

    /// Verify that Zylix core is initialized
    public func verifyInitialization(timeout: TimeInterval? = nil) -> Bool {
        let timeoutValue = timeout ?? config.defaultTimeout

        // Wait for app to be ready
        let readyPredicate = NSPredicate(format: "exists == true")
        let mainWindow = app.windows.firstMatch

        let expectation = XCTNSPredicateExpectation(predicate: readyPredicate, object: mainWindow)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeoutValue)

        if result == .completed {
            currentState = .ready
            log("Zylix core initialized successfully", level: .info)
            return true
        } else {
            currentState = .error
            log("Zylix core initialization failed", level: .error)
            return false
        }
    }

    /// Get current app state
    public func getState() -> ZylixTestAppState {
        if app.state == .runningForeground {
            return currentState
        } else if app.state == .notRunning {
            return .idle
        } else {
            return .unknown
        }
    }

    // MARK: - Interaction Helpers

    /// Simulate tap at coordinates
    public func simulateTap(x: CGFloat, y: CGFloat) {
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        normalized.tap()
        log("Tap at (\(x), \(y))", level: .debug)
    }

    /// Simulate tap on element
    public func tap(_ element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeoutValue = timeout ?? config.defaultTimeout

        if element.waitForExistence(timeout: timeoutValue) {
            element.tap()
            log("Tapped element: \(element.identifier)", level: .debug)
        } else {
            log("Element not found for tap: \(element.identifier)", level: .error)
        }
    }

    /// Simulate double tap on element
    public func doubleTap(_ element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeoutValue = timeout ?? config.defaultTimeout

        if element.waitForExistence(timeout: timeoutValue) {
            element.doubleTap()
            log("Double tapped element: \(element.identifier)", level: .debug)
        }
    }

    /// Simulate long press on element
    public func longPress(_ element: XCUIElement, duration: TimeInterval = 1.0, timeout: TimeInterval? = nil) {
        let timeoutValue = timeout ?? config.defaultTimeout

        if element.waitForExistence(timeout: timeoutValue) {
            element.press(forDuration: duration)
            log("Long pressed element: \(element.identifier)", level: .debug)
        }
    }

    /// Simulate swipe gesture
    public func swipe(_ direction: SwipeDirection, on element: XCUIElement? = nil) {
        let target = element ?? app

        switch direction {
        case .up:
            target.swipeUp()
        case .down:
            target.swipeDown()
        case .left:
            target.swipeLeft()
        case .right:
            target.swipeRight()
        }

        log("Swiped \(direction)", level: .debug)
    }

    public enum SwipeDirection {
        case up, down, left, right
    }

    /// Type text into element
    public func typeText(_ text: String, into element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeoutValue = timeout ?? config.defaultTimeout

        if element.waitForExistence(timeout: timeoutValue) {
            element.tap()
            element.typeText(text)
            log("Typed text into element: \(element.identifier)", level: .debug)
        }
    }

    /// Clear text in element
    public func clearText(in element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeoutValue = timeout ?? config.defaultTimeout

        if element.waitForExistence(timeout: timeoutValue) {
            element.tap()

            if let stringValue = element.value as? String {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
                element.typeText(deleteString)
            }

            log("Cleared text in element: \(element.identifier)", level: .debug)
        }
    }

    // MARK: - Wait Helpers

    /// Wait for element to exist
    public func waitForElement(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let timeoutValue = timeout ?? config.defaultTimeout
        return element.waitForExistence(timeout: timeoutValue)
    }

    /// Wait for element to disappear
    public func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let timeoutValue = timeout ?? config.defaultTimeout
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeoutValue)
        return result == .completed
    }

    /// Wait for state change
    public func waitForStateChange(to targetState: ZylixTestAppState, timeout: TimeInterval? = nil) -> Bool {
        let timeoutValue = timeout ?? config.defaultTimeout
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutValue {
            if getState() == targetState {
                log("State changed to \(targetState)", level: .debug)
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        log("Timeout waiting for state: \(targetState)", level: .warning)
        return false
    }

    /// Wait for element property
    public func waitForProperty<T: Equatable>(
        _ keyPath: KeyPath<XCUIElement, T>,
        of element: XCUIElement,
        toBe value: T,
        timeout: TimeInterval? = nil
    ) -> Bool {
        let timeoutValue = timeout ?? config.defaultTimeout
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutValue {
            if element[keyPath: keyPath] == value {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        return false
    }

    // MARK: - Element Query Helpers

    /// Find element by accessibility identifier
    public func element(withIdentifier id: String) -> XCUIElement {
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Find button by label
    public func button(withLabel label: String) -> XCUIElement {
        return app.buttons[label]
    }

    /// Find text field by identifier
    public func textField(withIdentifier id: String) -> XCUIElement {
        return app.textFields[id]
    }

    /// Find static text containing string
    public func staticText(containing text: String) -> XCUIElement {
        return app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// Find all elements of type
    public func elements(ofType type: XCUIElement.ElementType) -> XCUIElementQuery {
        return app.descendants(matching: type)
    }

    // MARK: - Assertion Helpers

    /// Assert element exists
    public func assertExists(_ element: XCUIElement, message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.exists, message.isEmpty ? "Element should exist" : message, file: file, line: line)
    }

    /// Assert element does not exist
    public func assertNotExists(_ element: XCUIElement, message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(element.exists, message.isEmpty ? "Element should not exist" : message, file: file, line: line)
    }

    /// Assert element is hittable
    public func assertHittable(_ element: XCUIElement, message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.isHittable, message.isEmpty ? "Element should be hittable" : message, file: file, line: line)
    }

    /// Assert element is enabled
    public func assertEnabled(_ element: XCUIElement, message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.isEnabled, message.isEmpty ? "Element should be enabled" : message, file: file, line: line)
    }

    /// Assert element label equals
    public func assertLabel(_ element: XCUIElement, equals expected: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(element.label, expected, "Element label should be '\(expected)'", file: file, line: line)
    }

    /// Assert element value equals
    public func assertValue(_ element: XCUIElement, equals expected: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(element.value as? String, expected, "Element value should be '\(expected)'", file: file, line: line)
    }

    // MARK: - Screenshot Helpers

    /// Capture screenshot
    public func captureScreenshot(name: String = "screenshot") -> XCUIScreenshot {
        let screenshot = app.screenshot()
        screenshots.append(screenshot)
        log("Screenshot captured: \(name)", level: .debug)
        return screenshot
    }

    /// Attach screenshot to test report
    public func attachScreenshot(_ screenshot: XCUIScreenshot, name: String = "screenshot") -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }

    /// Capture and attach screenshot
    public func captureAndAttach(name: String = "screenshot") -> XCTAttachment {
        let screenshot = captureScreenshot(name: name)
        return attachScreenshot(screenshot, name: name)
    }

    // MARK: - Logging

    private func log(_ message: String, level: ZylixTestConfig.LogLevel) {
        guard level.rawValue <= config.logLevel.rawValue else { return }

        let prefix: String
        switch level {
        case .none: return
        case .error: prefix = "[ERROR]"
        case .warning: prefix = "[WARN]"
        case .info: prefix = "[INFO]"
        case .debug: prefix = "[DEBUG]"
        }

        print("\(prefix) ZylixTest: \(message)")
    }
}

// MARK: - Zylix Component Testing Helpers

extension ZylixTestContext {

    /// Verify Zylix component exists by type
    public func verifyComponent(type: String, identifier: String? = nil) -> Bool {
        let query: XCUIElementQuery

        if let id = identifier {
            query = app.descendants(matching: .any).matching(identifier: id)
        } else {
            query = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier CONTAINS[c] %@", "zylix-\(type)")
            )
        }

        return query.count > 0
    }

    /// Get Zylix component by type and identifier
    public func component(type: String, identifier: String) -> XCUIElement {
        return element(withIdentifier: "zylix-\(type)-\(identifier)")
    }

    /// Verify button component
    public func verifyButton(identifier: String, label: String? = nil) -> Bool {
        let button = component(type: "button", identifier: identifier)

        if !button.exists {
            return false
        }

        if let expectedLabel = label {
            return button.label == expectedLabel
        }

        return true
    }

    /// Verify text component
    public func verifyText(identifier: String, contains text: String) -> Bool {
        let textElement = component(type: "text", identifier: identifier)

        guard textElement.exists else { return false }

        return textElement.label.contains(text)
    }

    /// Verify input component
    public func verifyInput(identifier: String, value: String? = nil) -> Bool {
        let input = component(type: "input", identifier: identifier)

        guard input.exists else { return false }

        if let expectedValue = value {
            return (input.value as? String) == expectedValue
        }

        return true
    }
}

// MARK: - Test Case Base Class

/// Base class for Zylix XCUITest test cases
open class ZylixUITestCase: XCTestCase {

    /// Shared test context
    public var context: ZylixTestContext!

    /// Test configuration
    open var testConfig: ZylixTestConfig {
        return ZylixTestConfig()
    }

    /// App bundle identifier (override if needed)
    open var bundleIdentifier: String? {
        return nil
    }

    open override func setUpWithError() throws {
        try super.setUpWithError()

        continueAfterFailure = false

        context = ZylixTestContext(bundleIdentifier: bundleIdentifier, config: testConfig)
        context.launch()

        XCTAssertTrue(context.verifyInitialization(), "Zylix core should initialize")
    }

    open override func tearDownWithError() throws {
        if testConfig.captureScreenshotOnFailure {
            let attachment = context.captureAndAttach(name: "final-state")
            add(attachment)
        }

        context.terminate()
        context = nil

        try super.tearDownWithError()
    }
}
