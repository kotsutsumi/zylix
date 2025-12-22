// Zylix Test Framework - iOS XCUITest Bridge Server
// HTTP server that receives commands from Zig iOS driver

import Foundation
import XCTest

/// Zylix Test Server for iOS
/// Provides HTTP endpoints for Zig driver to control XCUITest
public final class ZylixTestServer {

    // MARK: - Properties

    private let port: UInt16
    private var listener: Any? // NWListener on iOS 12+
    private var sessions: [String: Session] = [:]
    private var sessionCounter: Int = 0
    private let queue = DispatchQueue(label: "com.zylix.test.server", qos: .userInteractive)

    // MARK: - Types

    /// Session manages XCUIApplication instance
    public class Session {
        let id: String
        let app: XCUIApplication
        var elements: [String: XCUIElement] = [:]
        var elementCounter: Int = 0

        init(id: String, bundleId: String) {
            self.id = id
            self.app = XCUIApplication(bundleIdentifier: bundleId)
        }

        func storeElement(_ element: XCUIElement) -> String {
            elementCounter += 1
            let id = "element-\(elementCounter)"
            elements[id] = element
            return id
        }

        func getElement(_ id: String) -> XCUIElement? {
            return elements[id]
        }
    }

    /// Command result
    public struct CommandResult: Codable {
        var sessionId: String?
        var elementId: String?
        var elements: [String]?
        var value: AnyCodable?
        var error: String?
        var success: Bool?
    }

    // MARK: - Initialization

    public init(port: UInt16 = 8100) {
        self.port = port
    }

    // MARK: - Server Lifecycle

    /// Start the server
    public func start() throws {
        // Note: Full NWListener implementation requires Network.framework
        // This provides the command handling structure
        print("ZylixTestServer starting on port \(port)")
    }

    /// Stop the server
    public func stop() {
        sessions.values.forEach { session in
            session.app.terminate()
        }
        sessions.removeAll()
        print("ZylixTestServer stopped")
    }

    // MARK: - Command Handlers

    /// Handle incoming command
    public func handleCommand(path: String, method: String, body: [String: Any]?) -> CommandResult {
        let components = path.split(separator: "/").map(String.init)

        guard components.count >= 2, components[0] == "session" else {
            return CommandResult(error: "Invalid path")
        }

        // New session
        if components[1] == "new" {
            return handleNewSession(body: body)
        }

        // Existing session commands
        let sessionId = components[1]
        guard let session = sessions[sessionId] else {
            return CommandResult(error: "Session not found")
        }

        guard components.count >= 3 else {
            return CommandResult(error: "Missing command")
        }

        let command = components[2]

        switch command {
        case "close":
            return handleClose(session: session)
        case "element":
            return handleFindElement(session: session, body: body)
        case "elements":
            return handleFindElements(session: session, body: body)
        default:
            // Element-specific commands: /session/{id}/element/{elementId}/{action}
            if command == "element", components.count >= 5 {
                let elementId = components[3]
                let action = components[4]
                return handleElementAction(session: session, elementId: elementId, action: action, body: body)
            }

            // WDA-style commands: /session/{id}/wda/...
            if command == "wda", components.count >= 4 {
                return handleWDACommand(session: session, subpath: Array(components[3...]), body: body)
            }

            return handleSessionCommand(session: session, command: command, body: body)
        }
    }

    // MARK: - Session Management

    private func handleNewSession(body: [String: Any]?) -> CommandResult {
        guard let capabilities = body?["capabilities"] as? [String: Any],
              let alwaysMatch = capabilities["alwaysMatch"] as? [String: Any],
              let bundleId = alwaysMatch["bundleId"] as? String else {
            return CommandResult(error: "Missing bundleId in capabilities")
        }

        sessionCounter += 1
        let sessionId = "session-\(sessionCounter)"
        let session = Session(id: sessionId, bundleId: bundleId)

        // Launch the app
        session.app.launch()

        sessions[sessionId] = session

        return CommandResult(sessionId: sessionId, success: true)
    }

    private func handleClose(session: Session) -> CommandResult {
        session.app.terminate()
        sessions.removeValue(forKey: session.id)
        return CommandResult(success: true)
    }

    // MARK: - Element Finding

    private func handleFindElement(session: Session, body: [String: Any]?) -> CommandResult {
        guard let strategy = body?["using"] as? String,
              let value = body?["value"] as? String else {
            return CommandResult(error: "Missing strategy or value")
        }

        guard let element = findElement(in: session.app, strategy: strategy, value: value) else {
            return CommandResult(elementId: nil)
        }

        let elementId = session.storeElement(element)
        return CommandResult(elementId: elementId)
    }

    private func handleFindElements(session: Session, body: [String: Any]?) -> CommandResult {
        guard let strategy = body?["using"] as? String,
              let value = body?["value"] as? String else {
            return CommandResult(error: "Missing strategy or value")
        }

        let elements = findElements(in: session.app, strategy: strategy, value: value)
        let elementIds = elements.map { session.storeElement($0) }

        return CommandResult(elements: elementIds)
    }

    private func findElement(in app: XCUIApplication, strategy: String, value: String) -> XCUIElement? {
        let query: XCUIElementQuery

        switch strategy {
        case "accessibility id":
            // First try exact match, then descendants
            let element = app.descendants(matching: .any).matching(identifier: value).firstMatch
            if element.exists {
                return element
            }
            return nil

        case "name":
            query = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", value))

        case "xpath":
            // XPath requires parsing - simplified implementation
            return app.descendants(matching: .any).firstMatch

        case "-ios class chain":
            // Class chain requires parsing - simplified implementation
            return app.descendants(matching: .any).firstMatch

        case "-ios predicate string":
            query = app.descendants(matching: .any).matching(NSPredicate(format: value))

        default:
            return nil
        }

        let element = query.firstMatch
        return element.exists ? element : nil
    }

    private func findElements(in app: XCUIApplication, strategy: String, value: String) -> [XCUIElement] {
        let query: XCUIElementQuery

        switch strategy {
        case "accessibility id":
            query = app.descendants(matching: .any).matching(identifier: value)

        case "name":
            query = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", value))

        case "-ios predicate string":
            query = app.descendants(matching: .any).matching(NSPredicate(format: value))

        default:
            return []
        }

        return (0..<query.count).compactMap { query.element(boundBy: $0) }
    }

    // MARK: - Element Actions

    private func handleElementAction(session: Session, elementId: String, action: String, body: [String: Any]?) -> CommandResult {
        guard let element = session.getElement(elementId) else {
            return CommandResult(error: "Element not found")
        }

        switch action {
        case "click":
            element.tap()
            return CommandResult(success: true)

        case "clear":
            // Select all and delete
            element.tap()
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 100))
            return CommandResult(success: true)

        case "value":
            if let values = body?["value"] as? [String], let text = values.first {
                element.typeText(text)
            }
            return CommandResult(success: true)

        case "text":
            return CommandResult(value: AnyCodable(element.label))

        case "displayed":
            return CommandResult(value: AnyCodable(element.isHittable))

        case "enabled":
            return CommandResult(value: AnyCodable(element.isEnabled))

        case "rect":
            let frame = element.frame
            return CommandResult(value: AnyCodable([
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height
            ]))

        case "attribute":
            // Handle /element/{id}/attribute/{name} pattern
            return CommandResult(value: AnyCodable(element.value as? String ?? ""))

        case "screenshot":
            let screenshot = element.screenshot()
            let data = screenshot.pngRepresentation
            let base64 = data.base64EncodedString()
            return CommandResult(value: AnyCodable(base64))

        default:
            return CommandResult(error: "Unknown action: \(action)")
        }
    }

    // MARK: - Session Commands

    private func handleSessionCommand(session: Session, command: String, body: [String: Any]?) -> CommandResult {
        switch command {
        case "screenshot":
            let screenshot = session.app.screenshot()
            let data = screenshot.pngRepresentation
            let base64 = data.base64EncodedString()
            return CommandResult(value: AnyCodable(base64))

        case "source":
            // Return page source (element tree)
            return CommandResult(value: AnyCodable(session.app.debugDescription))

        case "title":
            return CommandResult(value: AnyCodable(session.app.label))

        default:
            return CommandResult(error: "Unknown command: \(command)")
        }
    }

    // MARK: - WDA Commands

    private func handleWDACommand(session: Session, subpath: [String], body: [String: Any]?) -> CommandResult {
        guard subpath.count >= 2, subpath[0] == "element" else {
            return CommandResult(error: "Invalid WDA command path")
        }

        let elementId = subpath[1]
        guard let element = session.getElement(elementId) else {
            return CommandResult(error: "Element not found")
        }

        guard subpath.count >= 3 else {
            return CommandResult(error: "Missing WDA action")
        }

        let action = subpath[2]

        switch action {
        case "doubleTap":
            element.doubleTap()
            return CommandResult(success: true)

        case "touchAndHold":
            let duration = body?["duration"] as? Double ?? 0.5
            element.press(forDuration: duration)
            return CommandResult(success: true)

        case "swipe":
            guard let direction = body?["direction"] as? String else {
                return CommandResult(error: "Missing direction")
            }

            switch direction {
            case "up": element.swipeUp()
            case "down": element.swipeDown()
            case "left": element.swipeLeft()
            case "right": element.swipeRight()
            default: break
            }
            return CommandResult(success: true)

        case "scroll":
            guard let direction = body?["direction"] as? String else {
                return CommandResult(error: "Missing direction")
            }

            // Use swipe for scroll simulation
            switch direction {
            case "up": element.swipeUp()
            case "down": element.swipeDown()
            case "left": element.swipeLeft()
            case "right": element.swipeRight()
            default: break
            }
            return CommandResult(success: true)

        default:
            return CommandResult(error: "Unknown WDA action: \(action)")
        }
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable value
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Cannot encode AnyCodable"))
        }
    }
}
