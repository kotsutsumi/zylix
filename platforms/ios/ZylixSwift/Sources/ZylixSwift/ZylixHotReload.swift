// ZylixHotReload.swift - iOS Hot Reload for Zylix
//
// Provides hot reload functionality for iOS development.
// Features:
// - Simulator integration
// - State preservation
// - Error overlay
// - WebSocket communication

import SwiftUI
import Combine

// MARK: - Hot Reload State

/// State of the hot reload connection
public enum HotReloadState: String {
    case disconnected
    case connecting
    case connected
    case reloading
    case error
}

// MARK: - Build Error

/// Build error information
public struct BuildError: Identifiable {
    public let id = UUID()
    public let file: String
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: String

    public init(file: String, line: Int, column: Int, message: String, severity: String = "error") {
        self.file = file
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }

    public var location: String {
        "\(file):\(line):\(column)"
    }
}

// MARK: - Hot Reload Client

/// Hot reload client for development
@MainActor
public class ZylixHotReloadClient: ObservableObject {
    public static let shared = ZylixHotReloadClient()

    @Published public private(set) var state: HotReloadState = .disconnected
    @Published public private(set) var lastError: BuildError?
    @Published public private(set) var isErrorOverlayVisible = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?

    private let stateManager = StatePreservationManager()
    private var handlers: [String: ([String: Any]) -> Void] = [:]
    private var hotUpdateListeners: [(String) -> Void] = []

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var reconnectTask: Task<Void, Never>?

    /// Server URL for hot reload connection
    /// Default is localhost for iOS simulator
    public var serverUrl: String = "ws://127.0.0.1:3001"

    private init() {}

    // MARK: - Connection

    /// Connect to the hot reload server
    public func connect() {
        guard state != .connected && state != .connecting else { return }

        state = .connecting

        guard let url = URL(string: serverUrl) else {
            state = .error
            return
        }

        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        state = .connected
        reconnectAttempts = 0
        receiveMessage()
    }

    /// Disconnect from the hot reload server
    public func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        reconnectAttempts = 0
        state = .disconnected
    }

    /// Shutdown the client completely
    public func shutdown() {
        disconnect()
        session?.invalidateAndCancel()
        session = nil
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[ZylixHMR] Max reconnect attempts reached")
            return
        }

        reconnectTask?.cancel()

        reconnectAttempts += 1
        let baseDelay = min(30.0, Double(1 << (reconnectAttempts - 1)))
        let jitter = Double.random(in: 0...1)
        let delay = baseDelay + jitter

        print("[ZylixHMR] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            connect()
        }
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in
                        self.handleMessage(text)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            self.handleMessage(text)
                        }
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                print("[ZylixHMR] WebSocket error: \(error)")
                Task { @MainActor in
                    self.state = .error
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "reload":
            handleReload()
        case "hot_update":
            if let payload = json["payload"] as? [String: Any] {
                handleHotUpdate(payload)
            }
        case "error_overlay":
            if let payload = json["payload"] as? [String: Any] {
                handleErrorOverlay(payload)
            }
        case "state_sync":
            if let payload = json["payload"] as? [String: Any] {
                handleStateSync(payload)
            }
        case "ping":
            send(["type": "pong"])
        default:
            if let payload = json["payload"] as? [String: Any] {
                handlers[type]?(payload)
            }
        }
    }

    private func handleReload() {
        print("[ZylixHMR] Full reload triggered")
        state = .reloading

        // Save state before reload
        stateManager.saveState()

        // Post notification for UI to handle
        NotificationCenter.default.post(name: .zylixHotReload, object: nil)
    }

    private func handleHotUpdate(_ payload: [String: Any]) {
        guard let module = payload["module"] as? String else { return }
        print("[ZylixHMR] Hot update for: \(module)")

        hideErrorOverlay()

        // Notify listeners
        hotUpdateListeners.forEach { $0(module) }
    }

    private func handleErrorOverlay(_ payload: [String: Any]) {
        let error = BuildError(
            file: payload["file"] as? String ?? "unknown",
            line: payload["line"] as? Int ?? 1,
            column: payload["column"] as? Int ?? 1,
            message: payload["message"] as? String ?? "Unknown error",
            severity: payload["severity"] as? String ?? "error"
        )
        lastError = error
        showErrorOverlay()
    }

    private func handleStateSync(_ state: [String: Any]) {
        stateManager.mergeState(state)
    }

    // MARK: - Error Overlay

    public func showErrorOverlay() {
        isErrorOverlayVisible = true
    }

    public func hideErrorOverlay() {
        isErrorOverlayVisible = false
        lastError = nil
    }

    // MARK: - Send

    private func send(_ data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let text = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("[ZylixHMR] Send error: \(error)")
            }
        }
    }

    // MARK: - State Preservation

    public func saveState(key: String, value: Any) {
        stateManager.set(key: key, value: value)
    }

    public func loadState(key: String) -> Any? {
        stateManager.get(key: key)
    }

    public func restoreState() {
        stateManager.restoreState()
        if state == .reloading {
            state = .connected
        }
    }

    // MARK: - Event Handlers

    public func on(event: String, handler: @escaping ([String: Any]) -> Void) {
        handlers[event] = handler
    }

    public func off(event: String) {
        handlers.removeValue(forKey: event)
    }

    public func addHotUpdateListener(_ listener: @escaping (String) -> Void) {
        hotUpdateListeners.append(listener)
    }

    public func removeAllHotUpdateListeners() {
        hotUpdateListeners.removeAll()
    }
}

// MARK: - State Preservation Manager

class StatePreservationManager {
    private let userDefaults = UserDefaults.standard
    private let stateKey = "__ZYLIX_HOT_RELOAD_STATE__"
    private var state: [String: Any] = [:]

    func set(key: String, value: Any) {
        state[key] = value
    }

    func get(key: String) -> Any? {
        state[key]
    }

    func mergeState(_ newState: [String: Any]) {
        for (key, value) in newState {
            state[key] = value
        }
    }

    func saveState() {
        // Convert to string representation for storage
        let stringState = state.mapValues { "\($0)" }
        if let data = try? JSONSerialization.data(withJSONObject: stringState) {
            userDefaults.set(data, forKey: stateKey)
        }
    }

    func restoreState() {
        guard let data = userDefaults.data(forKey: stateKey),
              let restoredState = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        for (key, value) in restoredState {
            state[key] = value
        }

        // Clear stored state
        userDefaults.removeObject(forKey: stateKey)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let zylixHotReload = Notification.Name("ZylixHotReload")
    static let zylixHotUpdate = Notification.Name("ZylixHotUpdate")
}

// MARK: - SwiftUI Integration

/// Error overlay view for displaying build errors
public struct ErrorOverlayView: View {
    @ObservedObject var client = ZylixHotReloadClient.shared

    public init() {}

    public var body: some View {
        if client.isErrorOverlayVisible, let error = client.lastError {
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Build Error")
                            .font(.title)
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: { client.hideErrorOverlay() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }

                    Text(error.location)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)

                    ScrollView {
                        Text(error.message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.3))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)

                    Button(action: { client.hideErrorOverlay() }) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(24)
            }
        }
    }
}

/// Wrapper view that enables hot reload for its content
public struct HotReloadable<Content: View>: View {
    @ObservedObject private var client = ZylixHotReloadClient.shared
    @State private var reloadKey = 0
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .id(reloadKey)
            .onReceive(NotificationCenter.default.publisher(for: .zylixHotReload)) { _ in
                reloadKey += 1
            }
            .overlay {
                ErrorOverlayView()
            }
    }
}

/// Hot reload state hook
public struct HotReloadStateView: View {
    @ObservedObject private var client = ZylixHotReloadClient.shared

    public init() {}

    public var state: HotReloadState { client.state }

    public var body: some View {
        EmptyView()
    }
}

/// View modifier for hot reload support
public struct HotReloadModifier: ViewModifier {
    @ObservedObject private var client = ZylixHotReloadClient.shared
    @State private var reloadKey = 0

    public func body(content: Content) -> some View {
        content
            .id(reloadKey)
            .onReceive(NotificationCenter.default.publisher(for: .zylixHotReload)) { _ in
                reloadKey += 1
            }
    }
}

public extension View {
    /// Enable hot reload for this view
    func hotReloadable() -> some View {
        modifier(HotReloadModifier())
    }
}

// MARK: - Connection Indicator

/// Visual indicator for hot reload connection status
public struct HotReloadIndicator: View {
    @ObservedObject private var client = ZylixHotReloadClient.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch client.state {
        case .connected: return .green
        case .connecting, .reloading: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private var statusText: String {
        switch client.state {
        case .connected: return "HMR Connected"
        case .connecting: return "Connecting..."
        case .reloading: return "Reloading..."
        case .error: return "HMR Error"
        case .disconnected: return "HMR Disconnected"
        }
    }
}

// MARK: - Dev Tools Overlay

/// Development tools overlay with HMR controls
public struct DevToolsOverlay: View {
    @ObservedObject private var client = ZylixHotReloadClient.shared
    @State private var isExpanded = false

    public init() {}

    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Development Tools")
                        .font(.headline)

                    Divider()

                    HStack {
                        Text("HMR Status:")
                        Spacer()
                        HotReloadIndicator()
                    }

                    if client.state == .disconnected {
                        Button("Connect") {
                            client.connect()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Disconnect") {
                            client.disconnect()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 8)
            }

            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "wrench.and.screwdriver.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .padding()
    }
}
