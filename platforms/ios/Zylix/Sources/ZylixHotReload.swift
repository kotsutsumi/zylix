// ZylixHotReload.swift - iOS Hot Reload for Zylix v0.5.0
//
// Provides hot reload functionality for iOS development.
// Features:
// - Simulator integration
// - State preservation
// - Error overlay
// - WebSocket communication

import Foundation
import UIKit
import Combine

// MARK: - Hot Reload State

public enum HotReloadState {
    case disconnected
    case connecting
    case connected
    case reloading
    case error(Error)
}

// MARK: - Hot Reload Error

public enum HotReloadError: Error, LocalizedError {
    case connectionFailed(String)
    case invalidMessage
    case stateRestorationFailed
    case buildFailed(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .invalidMessage: return "Invalid hot reload message"
        case .stateRestorationFailed: return "State restoration failed"
        case .buildFailed(let msg): return "Build failed: \(msg)"
        }
    }
}

// MARK: - Build Error

public struct BuildError: Codable {
    public let file: String
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: String
}

// MARK: - Hot Reload Client

@MainActor
public class ZylixHotReloadClient: ObservableObject {
    public static let shared = ZylixHotReloadClient()

    @Published public private(set) var state: HotReloadState = .disconnected
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var lastError: BuildError?

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 10

    private var stateManager: StatePreservationManager
    private var errorOverlay: ErrorOverlayWindow?
    private var handlers: [String: (Data) -> Void] = [:]

    public var serverURL: URL = URL(string: "ws://localhost:3001")!

    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        self.stateManager = StatePreservationManager()
    }

    // MARK: - Connection

    public func connect() {
        guard state != .connected && state != .connecting else { return }

        state = .connecting
        let request = URLRequest(url: serverURL)
        webSocket = urlSession.webSocketTask(with: request)
        webSocket?.resume()

        receiveMessage()
        isConnected = true
        state = .connected
        reconnectAttempts = 0

        print("[Zylix HMR] Connected to \(serverURL)")
    }

    public func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        state = .disconnected
        reconnectTimer?.invalidate()
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[Zylix HMR] Max reconnect attempts reached")
            return
        }

        reconnectAttempts += 1
        let delay = Double(min(30, pow(2.0, Double(reconnectAttempts - 1))))

        print("[Zylix HMR] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message)
                    self.receiveMessage()
                }
            case .failure(let error):
                Task { @MainActor in
                    print("[Zylix HMR] Error: \(error)")
                    self.state = .error(error)
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
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
            if let payload = json["payload"] {
                handleErrorOverlay(payload)
            }
        case "state_sync":
            if let payload = json["payload"] as? [String: Any] {
                handleStateSync(payload)
            }
        case "ping":
            send(["type": "pong"])
        default:
            if let handler = handlers[type],
               let payloadData = try? JSONSerialization.data(withJSONObject: json["payload"] ?? [:]) {
                handler(payloadData)
            }
        }
    }

    private func handleReload() {
        print("[Zylix HMR] Full reload triggered")
        state = .reloading

        // Save state before reload
        stateManager.saveState()

        // Notify app to reload
        NotificationCenter.default.post(name: .zylixHotReload, object: nil)
    }

    private func handleHotUpdate(_ payload: [String: Any]) {
        guard let module = payload["module"] as? String else { return }
        print("[Zylix HMR] Hot update for: \(module)")

        // Hide any existing error overlay
        hideErrorOverlay()

        // Notify observers of hot update
        NotificationCenter.default.post(
            name: .zylixHotUpdate,
            object: nil,
            userInfo: ["module": module]
        )
    }

    private func handleErrorOverlay(_ payload: Any) {
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let error = try? JSONDecoder().decode(BuildError.self, from: data) {
            lastError = error
            showErrorOverlay(error)
        }
    }

    private func handleStateSync(_ state: [String: Any]) {
        stateManager.mergeState(state)
    }

    // MARK: - Error Overlay

    private func showErrorOverlay(_ error: BuildError) {
        errorOverlay?.dismiss()

        errorOverlay = ErrorOverlayWindow(error: error)
        errorOverlay?.show()
    }

    public func hideErrorOverlay() {
        errorOverlay?.dismiss()
        errorOverlay = nil
        lastError = nil
    }

    // MARK: - Send

    private func send(_ data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(jsonString)) { error in
            if let error = error {
                print("[Zylix HMR] Send error: \(error)")
            }
        }
    }

    // MARK: - State Preservation

    public func saveState(_ key: String, value: Any) {
        stateManager.set(key, value: value)
    }

    public func loadState(_ key: String) -> Any? {
        return stateManager.get(key)
    }

    public func restoreState() {
        stateManager.restoreState()
    }

    // MARK: - Handlers

    public func on(_ event: String, handler: @escaping (Data) -> Void) {
        handlers[event] = handler
    }

    public func off(_ event: String) {
        handlers.removeValue(forKey: event)
    }
}

// MARK: - State Preservation Manager

class StatePreservationManager {
    private var state: [String: Any] = [:]
    private let userDefaults = UserDefaults.standard
    private let stateKey = "__ZYLIX_HOT_RELOAD_STATE__"

    func set(_ key: String, value: Any) {
        state[key] = value
    }

    func get(_ key: String) -> Any? {
        return state[key]
    }

    func mergeState(_ newState: [String: Any]) {
        for (key, value) in newState {
            state[key] = value
        }
    }

    func saveState() {
        // Save to UserDefaults
        if let data = try? JSONSerialization.data(withJSONObject: state) {
            userDefaults.set(data, forKey: stateKey)
        }

        // Save UI state
        saveUIState()
    }

    func restoreState() {
        // Restore from UserDefaults
        if let data = userDefaults.data(forKey: stateKey),
           let restored = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            state = restored
        }

        // Restore UI state
        restoreUIState()

        // Clear stored state
        userDefaults.removeObject(forKey: stateKey)
    }

    private func saveUIState() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return }

        // Save scroll positions
        saveScrollPositions(in: window)

        // Save text field values
        saveTextFieldValues(in: window)
    }

    private func restoreUIState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else { return }

            self?.restoreScrollPositions(in: window)
            self?.restoreTextFieldValues(in: window)
        }
    }

    private func saveScrollPositions(in view: UIView) {
        if let scrollView = view as? UIScrollView,
           let identifier = scrollView.accessibilityIdentifier {
            state["scroll_\(identifier)"] = [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ]
        }

        for subview in view.subviews {
            saveScrollPositions(in: subview)
        }
    }

    private func restoreScrollPositions(in view: UIView) {
        if let scrollView = view as? UIScrollView,
           let identifier = scrollView.accessibilityIdentifier,
           let offset = state["scroll_\(identifier)"] as? [String: CGFloat] {
            scrollView.setContentOffset(
                CGPoint(x: offset["x"] ?? 0, y: offset["y"] ?? 0),
                animated: false
            )
        }

        for subview in view.subviews {
            restoreScrollPositions(in: subview)
        }
    }

    private func saveTextFieldValues(in view: UIView) {
        if let textField = view as? UITextField,
           let identifier = textField.accessibilityIdentifier {
            state["text_\(identifier)"] = textField.text
        }

        for subview in view.subviews {
            saveTextFieldValues(in: subview)
        }
    }

    private func restoreTextFieldValues(in view: UIView) {
        if let textField = view as? UITextField,
           let identifier = textField.accessibilityIdentifier,
           let text = state["text_\(identifier)"] as? String {
            textField.text = text
        }

        for subview in view.subviews {
            restoreTextFieldValues(in: subview)
        }
    }
}

// MARK: - Error Overlay Window

class ErrorOverlayWindow: UIWindow {
    private let error: BuildError

    init(error: BuildError) {
        self.error = error

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            super.init(windowScene: scene)
        } else {
            super.init(frame: UIScreen.main.bounds)
        }

        windowLevel = .alert + 1
        backgroundColor = UIColor.black.withAlphaComponent(0.9)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            container.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "⚠️ Build Error"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let locationLabel = UILabel()
        locationLabel.text = "\(error.file):\(error.line):\(error.column)"
        locationLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        locationLabel.textColor = .gray
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(locationLabel)

        let messageLabel = UILabel()
        messageLabel.text = error.message
        messageLabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.backgroundColor = UIColor(white: 0.2, alpha: 1)
        messageLabel.layer.cornerRadius = 8
        messageLabel.clipsToBounds = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(messageLabel)

        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.backgroundColor = UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.layer.cornerRadius = 8
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            locationLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            messageLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            dismissButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            dismissButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 100),
            dismissButton.heightAnchor.constraint(equalToConstant: 44),
            dismissButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    func show() {
        makeKeyAndVisible()
    }

    func dismiss() {
        isHidden = true
        resignKey()
    }

    @objc private func dismissTapped() {
        ZylixHotReloadClient.shared.hideErrorOverlay()
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let zylixHotReload = Notification.Name("ZylixHotReload")
    static let zylixHotUpdate = Notification.Name("ZylixHotUpdate")
}

// MARK: - SwiftUI Integration

import SwiftUI

public struct HotReloadableView<Content: View>: View {
    @ObservedObject private var hotReload = ZylixHotReloadClient.shared
    @State private var reloadTrigger = UUID()
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .id(reloadTrigger)
            .onReceive(NotificationCenter.default.publisher(for: .zylixHotReload)) { _ in
                reloadTrigger = UUID()
            }
    }
}

public extension View {
    func hotReloadable() -> some View {
        HotReloadableView { self }
    }
}
