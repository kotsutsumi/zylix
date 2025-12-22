import Foundation

/// Zylix Test Framework - iOS Client
/// Connects to WebDriverAgent for E2E testing

public struct ZylixTestClient {
    let host: String
    let port: UInt16

    public init(host: String = "127.0.0.1", port: UInt16 = 8100) {
        self.host = host
        self.port = port
    }

    /// Check if WDA is available
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

    /// Create a new session
    public func createSession(bundleId: String) async throws -> Session {
        let url = URL(string: "http://\(host):\(port)/session")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let capabilities: [String: Any] = [
            "capabilities": [
                "alwaysMatch": [
                    "platformName": "iOS",
                    "bundleId": bundleId
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: capabilities)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any],
              let sessionId = value["sessionId"] as? String else {
            throw ZylixTestError.sessionCreationFailed
        }

        return Session(id: sessionId, client: self)
    }

    /// Delete a session
    public func deleteSession(_ sessionId: String) async throws {
        let url = URL(string: "http://\(host):\(port)/session/\(sessionId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
    }
}

public struct Session {
    public let id: String
    let client: ZylixTestClient

    /// Find element by accessibility ID
    public func find(accessibilityId: String) async throws -> Element {
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
            throw ZylixTestError.elementNotFound
        }

        return Element(id: elementId, sessionId: id, client: client)
    }

    /// Take screenshot
    public func takeScreenshot() async throws -> Data {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/screenshot")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? String,
              let imageData = Data(base64Encoded: value) else {
            throw ZylixTestError.screenshotFailed
        }

        return imageData
    }
}

public struct Element {
    public let id: String
    let sessionId: String
    let client: ZylixTestClient

    public var exists: Bool { !id.isEmpty }

    /// Tap the element
    public func tap() async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/click")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Get element text
    public func getText() async throws -> String {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(sessionId)/element/\(id)/text")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        return json?["value"] as? String ?? ""
    }
}

public enum ZylixTestError: Error {
    case sessionCreationFailed
    case elementNotFound
    case screenshotFailed
    case commandFailed(String)
}
