import Foundation

/// Zylix Test Framework - macOS Client
/// Connects to Accessibility Bridge for E2E testing

public struct ZylixMacTestClient {
    let host: String
    let port: UInt16

    public init(host: String = "127.0.0.1", port: UInt16 = 8200) {
        self.host = host
        self.port = port
    }

    /// Check if accessibility bridge is available
    public func isAvailable() async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/status") else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Create a new session with an application
    public func createSession(bundleId: String) async throws -> MacSession {
        let url = URL(string: "http://\(host):\(port)/session")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let capabilities: [String: Any] = [
            "capabilities": [
                "bundleId": bundleId,
                "platformName": "macOS"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: capabilities)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any],
              let sessionId = value["sessionId"] as? String else {
            throw ZylixMacError.sessionCreationFailed
        }

        return MacSession(id: sessionId, client: self)
    }

    /// Delete a session
    public func deleteSession(_ sessionId: String) async throws {
        let url = URL(string: "http://\(host):\(port)/session/\(sessionId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
    }
}

public struct MacSession {
    public let id: String
    let client: ZylixMacTestClient

    // MARK: - Element Finding

    /// Find element by accessibility identifier
    public func find(accessibilityId: String) async throws -> MacElement {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/element")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "using": "accessibility id",
            "value": accessibilityId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any],
              let elementId = value["ELEMENT"] as? String else {
            throw ZylixMacError.elementNotFound
        }

        return MacElement(id: elementId, sessionId: id, client: client)
    }

    /// Find element by role
    public func find(role: String, title: String? = nil) async throws -> MacElement {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/element")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var predicate = "role == '\(role)'"
        if let title = title {
            predicate += " AND title == '\(title)'"
        }

        let body: [String: Any] = [
            "using": "predicate string",
            "value": predicate
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any],
              let elementId = value["ELEMENT"] as? String else {
            throw ZylixMacError.elementNotFound
        }

        return MacElement(id: elementId, sessionId: id, client: client)
    }

    // MARK: - Window Management

    /// Get all windows for the application
    public func getWindows() async throws -> [MacWindow] {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/windows")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [[String: Any]] else {
            return []
        }

        return value.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            return MacWindow(
                id: id,
                title: dict["title"] as? String,
                position: CGPoint(
                    x: dict["x"] as? CGFloat ?? 0,
                    y: dict["y"] as? CGFloat ?? 0
                ),
                size: CGSize(
                    width: dict["width"] as? CGFloat ?? 0,
                    height: dict["height"] as? CGFloat ?? 0
                )
            )
        }
    }

    /// Activate a specific window
    public func activateWindow(_ windowId: String) async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/window/\(windowId)/activate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Keyboard

    /// Press a key with modifiers
    public func pressKey(key: String, modifiers: Set<KeyModifier> = []) async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/keys")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "key": key,
            "modifiers": modifiers.map { $0.rawValue }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Type text
    public func typeText(_ text: String) async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/type")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Screenshots

    /// Take a screenshot
    public func takeScreenshot(windowId: String? = nil) async throws -> Data {
        var urlString = "http://\(client.host):\(client.port)/session/\(id)/screenshot"
        if let windowId = windowId {
            urlString += "?window=\(windowId)"
        }

        let url = URL(string: urlString)!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? String,
              let imageData = Data(base64Encoded: value) else {
            throw ZylixMacError.screenshotFailed
        }

        return imageData
    }
}

public struct MacElement {
    public let id: String
    let sessionId: String
    let client: ZylixMacTestClient

    public var exists: Bool { !id.isEmpty }

    /// Click the element
    public func tap() async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/click")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Double-click the element
    public func doubleTap() async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/doubleclick")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Get element title/text
    public func getTitle() async throws -> String {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/attribute/AXTitle")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        return json?["value"] as? String ?? ""
    }

    /// Get element value
    public func getValue() async throws -> Any? {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/attribute/AXValue")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        return json?["value"]
    }
}

// MARK: - Supporting Types

public struct MacWindow {
    public let id: String
    public let title: String?
    public let position: CGPoint
    public let size: CGSize
}

public enum KeyModifier: String {
    case command = "command"
    case option = "option"
    case control = "control"
    case shift = "shift"
    case function = "fn"
}

public enum ZylixMacError: Error {
    case sessionCreationFailed
    case elementNotFound
    case screenshotFailed
    case commandFailed(String)
}
