import Foundation

/// Zylix Test Framework - watchOS Client
/// Extends iOS client with watchOS-specific actions

public struct ZylixWatchTestClient {
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

    /// Create a watchOS session
    public func createSession(
        bundleId: String,
        deviceName: String = "Apple Watch Series 9 (45mm)",
        platformVersion: String = "11.0"
    ) async throws -> WatchSession {
        let url = URL(string: "http://\(host):\(port)/session")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let capabilities: [String: Any] = [
            "capabilities": [
                "alwaysMatch": [
                    "platformName": "iOS",
                    "bundleId": bundleId,
                    "deviceName": deviceName,
                    "platformVersion": platformVersion
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: capabilities)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any],
              let sessionId = value["sessionId"] as? String else {
            throw ZylixWatchError.sessionCreationFailed
        }

        return WatchSession(id: sessionId, client: self)
    }

    /// Delete a session
    public func deleteSession(_ sessionId: String) async throws {
        let url = URL(string: "http://\(host):\(port)/session/\(sessionId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
    }
}

public struct WatchSession {
    public let id: String
    let client: ZylixWatchTestClient

    // MARK: - watchOS-Specific Actions

    /// Rotate Digital Crown
    public func rotateDigitalCrown(
        direction: CrownDirection,
        velocity: Double = 0.5
    ) async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/wda/digitalCrown/rotate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "direction": direction.rawValue,
            "velocity": velocity
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ZylixWatchError.commandFailed("Digital Crown rotation failed")
        }
    }

    /// Press Side Button
    public func pressSideButton(durationMs: Int = 100) async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/wda/sideButton/press")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["duration": durationMs]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ZylixWatchError.commandFailed("Side button press failed")
        }
    }

    /// Double-press Side Button (Apple Pay)
    public func doublePresssSideButton() async throws {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/wda/sideButton/doublePress")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ZylixWatchError.commandFailed("Double press failed")
        }
    }

    /// Get companion device info
    public func getCompanionDeviceInfo() async throws -> CompanionInfo? {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/wda/companion/info")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? [String: Any] else {
            return nil
        }

        return CompanionInfo(
            deviceName: value["deviceName"] as? String,
            udid: value["udid"] as? String,
            isPaired: value["isPaired"] as? Bool ?? false
        )
    }

    // MARK: - Standard Actions

    /// Find element by accessibility ID
    public func find(accessibilityId: String) async throws -> WatchElement {
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
            throw ZylixWatchError.elementNotFound
        }

        return WatchElement(id: elementId, sessionId: id, client: client)
    }

    /// Take screenshot
    public func takeScreenshot() async throws -> Data {
        let url = URL(string: "http://\(client.host):\(client.port)/session/\(id)/screenshot")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let value = json?["value"] as? String,
              let imageData = Data(base64Encoded: value) else {
            throw ZylixWatchError.screenshotFailed
        }

        return imageData
    }
}

public struct WatchElement {
    public let id: String
    let sessionId: String
    let client: ZylixWatchTestClient

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

// MARK: - Supporting Types

public enum CrownDirection: String {
    case up = "up"
    case down = "down"
}

public struct CompanionInfo {
    public let deviceName: String?
    public let udid: String?
    public let isPaired: Bool
}

public enum ZylixWatchError: Error {
    case sessionCreationFailed
    case elementNotFound
    case screenshotFailed
    case commandFailed(String)
}
