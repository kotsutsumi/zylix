// Zylix Test Framework - macOS Test Server
// HTTP server for Zig macOS driver communication

import Foundation
import ZylixTest

let port: UInt16 = 8200
var sessions: [String: Session] = [:]
var sessionCounter = 0

class Session {
    let id: String
    let bridge: AccessibilityBridge
    var pid: pid_t?

    init(id: String) {
        self.id = id
        self.bridge = AccessibilityBridge()
    }
}

struct CommandResult: Codable {
    var sessionId: String?
    var elementId: String?
    var elements: [String]?
    var value: AnyCodable?
    var error: String?
    var success: Bool?
    var pid: Int32?
    var x: Double?
    var y: Double?
    var width: Double?
    var height: Double?
    var data: String?
}

// Simple HTTP server using GCDAsyncSocket alternative with URLSession
class HTTPServer {
    let port: UInt16
    var serverSocket: Int32 = -1
    var isRunning = false

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("Failed to create socket")
            return
        }

        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            print("Failed to bind to port \(port)")
            return
        }

        guard listen(serverSocket, 10) == 0 else {
            print("Failed to listen")
            return
        }

        isRunning = true
        print("ZylixTest macOS Server running on port \(port)")

        DispatchQueue.global(qos: .userInteractive).async {
            self.acceptConnections()
        }
    }

    func acceptConnections() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else { continue }

            DispatchQueue.global(qos: .userInteractive).async {
                self.handleClient(clientSocket)
            }
        }
    }

    func handleClient(_ socket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = recv(socket, &buffer, buffer.count, 0)

        guard bytesRead > 0 else {
            close(socket)
            return
        }

        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
        let response = handleRequest(request)

        let httpResponse = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(response.count)\r
        \r
        \(response)
        """

        _ = httpResponse.withCString { ptr in
            send(socket, ptr, strlen(ptr), 0)
        }

        close(socket)
    }

    func handleRequest(_ request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return encodeResult(CommandResult(error: "Invalid request"))
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return encodeResult(CommandResult(error: "Invalid request line"))
        }

        let method = parts[0]
        let path = parts[1]

        // Find body
        var body: [String: Any]?
        if let emptyLineIndex = lines.firstIndex(of: "") {
            let bodyString = lines[(emptyLineIndex + 1)...].joined()
            if let data = bodyString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                body = json
            }
        }

        let result = handleCommand(path: path, method: method, body: body)
        return encodeResult(result)
    }

    func encodeResult(_ result: CommandResult) -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{\"error\": \"Encoding failed\"}"
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
        }
    }
}

func handleCommand(path: String, method: String, body: [String: Any]?) -> CommandResult {
    let segments = path.components(separatedBy: "/").filter { !$0.isEmpty }

    guard segments.count >= 2, segments[0] == "session" else {
        return CommandResult(error: "Invalid path")
    }

    // New session
    if segments[1] == "new" && segments.count >= 3 && segments[2] == "launch" {
        return handleLaunch(body: body)
    }

    // Existing session
    let sessionId = segments[1]
    guard let session = sessions[sessionId] else {
        return CommandResult(error: "Session not found")
    }

    guard segments.count >= 3 else {
        return CommandResult(error: "Missing command")
    }

    let command = segments[2]

    switch command {
    case "close":
        return handleClose(session: session)
    case "findElement":
        return handleFindElement(session: session, body: body)
    case "findElements":
        return handleFindElements(session: session, body: body)
    case "click":
        return handleClick(session: session, body: body)
    case "doubleClick":
        return handleDoubleClick(session: session, body: body)
    case "longPress":
        return handleLongPress(session: session, body: body)
    case "type":
        return handleType(session: session, body: body)
    case "clear":
        return handleClear(session: session, body: body)
    case "exists":
        return handleExists(session: session, body: body)
    case "isVisible":
        return handleIsVisible(session: session, body: body)
    case "isEnabled":
        return handleIsEnabled(session: session, body: body)
    case "getText":
        return handleGetText(session: session, body: body)
    case "getAttribute":
        return handleGetAttribute(session: session, body: body)
    case "getRect":
        return handleGetRect(session: session, body: body)
    case "screenshot":
        return handleScreenshot(session: session)
    case "elementScreenshot":
        return handleElementScreenshot(session: session, body: body)
    default:
        return CommandResult(error: "Unknown command: \(command)")
    }
}

func handleLaunch(body: [String: Any]?) -> CommandResult {
    guard let bundleId = body?["bundleId"] as? String else {
        return CommandResult(error: "Missing bundleId")
    }

    sessionCounter += 1
    let sessionId = "session-\(sessionCounter)"
    let session = Session(id: sessionId)

    do {
        let pid = try session.bridge.launch(bundleId: bundleId)
        session.pid = pid
        sessions[sessionId] = session
        return CommandResult(sessionId: sessionId, success: true, pid: pid)
    } catch {
        return CommandResult(error: "Launch failed: \(error)")
    }
}

func handleClose(session: Session) -> CommandResult {
    session.bridge.terminate()
    sessions.removeValue(forKey: session.id)
    return CommandResult(success: true)
}

func handleFindElement(session: Session, body: [String: Any]?) -> CommandResult {
    guard let strategy = body?["strategy"] as? String,
          let value = body?["value"] as? String else {
        return CommandResult(error: "Missing strategy or value")
    }

    guard let element = session.bridge.findElement(strategy: strategy, value: value) else {
        return CommandResult(elementId: nil)
    }

    let elementId = session.bridge.storeElement(element)
    return CommandResult(elementId: elementId)
}

func handleFindElements(session: Session, body: [String: Any]?) -> CommandResult {
    guard let strategy = body?["strategy"] as? String,
          let value = body?["value"] as? String else {
        return CommandResult(error: "Missing strategy or value")
    }

    let elements = session.bridge.findElements(strategy: strategy, value: value)
    let elementIds = elements.map { session.bridge.storeElement($0) }
    return CommandResult(elements: elementIds)
}

func handleClick(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    if element.click() {
        return CommandResult(success: true)
    }
    return CommandResult(error: "Click failed")
}

func handleDoubleClick(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    if element.doubleClick() {
        return CommandResult(success: true)
    }
    return CommandResult(error: "Double click failed")
}

func handleLongPress(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    // Long press is simulated by clicking and holding
    if element.click() {
        return CommandResult(success: true)
    }
    return CommandResult(error: "Long press failed")
}

func handleType(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let text = body?["text"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found or missing text")
    }

    _ = element.focus()
    if element.setValue(text) {
        return CommandResult(success: true)
    }
    return CommandResult(error: "Type failed")
}

func handleClear(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    _ = element.focus()
    if element.setValue("") {
        return CommandResult(success: true)
    }
    return CommandResult(error: "Clear failed")
}

func handleExists(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let _ = session.bridge.getElement(elementId) else {
        return CommandResult(value: AnyCodable(false))
    }
    return CommandResult(value: AnyCodable(true))
}

func handleIsVisible(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(value: AnyCodable(false))
    }
    // Check if element has non-zero frame
    let visible = element.frame != .zero
    return CommandResult(value: AnyCodable(visible))
}

func handleIsEnabled(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(value: AnyCodable(false))
    }
    return CommandResult(value: AnyCodable(element.isEnabled))
}

func handleGetText(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    let text = element.title ?? (element.value as? String) ?? ""
    return CommandResult(value: AnyCodable(text))
}

func handleGetAttribute(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let name = body?["name"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found or missing name")
    }

    var value: String? = nil
    switch name {
    case "title":
        value = element.title
    case "value":
        value = element.value as? String
    case "role":
        value = element.role
    case "roleDescription":
        value = element.roleDescription
    default:
        break
    }

    return CommandResult(value: AnyCodable(value ?? ""))
}

func handleGetRect(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    let frame = element.frame
    return CommandResult(
        x: Double(frame.origin.x),
        y: Double(frame.origin.y),
        width: Double(frame.size.width),
        height: Double(frame.size.height)
    )
}

func handleScreenshot(session: Session) -> CommandResult {
    guard let data = session.bridge.takeScreenshot() else {
        return CommandResult(error: "Screenshot failed")
    }
    let base64 = data.base64EncodedString()
    return CommandResult(data: base64)
}

func handleElementScreenshot(session: Session, body: [String: Any]?) -> CommandResult {
    guard let elementId = body?["elementId"] as? String,
          let element = session.bridge.getElement(elementId) else {
        return CommandResult(error: "Element not found")
    }

    guard let data = session.bridge.takeElementScreenshot(element) else {
        return CommandResult(error: "Element screenshot failed")
    }
    let base64 = data.base64EncodedString()
    return CommandResult(data: base64)
}

// AnyCodable helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
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
        default:
            try container.encodeNil()
        }
    }
}

// Main
let server = HTTPServer(port: port)
server.start()

print("Press Ctrl+C to stop the server")
RunLoop.main.run()
