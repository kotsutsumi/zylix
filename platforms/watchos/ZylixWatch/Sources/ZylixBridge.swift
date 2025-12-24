//
//  ZylixBridge.swift
//  ZylixWatch
//
//  Swift wrapper for Zylix Core C ABI.
//  This is the "thin shell" that connects SwiftUI to the Zig brain.
//

import Foundation
import Combine

// MARK: - Zylix State Models

/// Swift representation of Zylix state
struct ZylixState: Equatable {
    let version: UInt64
    let screen: Screen
    let loading: Bool
    let errorMessage: String?
    let counter: Int64

    enum Screen: UInt32 {
        case home = 0
        case detail = 1
        case settings = 2
    }

    static let initial = ZylixState(
        version: 0,
        screen: .home,
        loading: false,
        errorMessage: nil,
        counter: 0
    )
}

// MARK: - Zylix Events

/// Events that can be dispatched to Zylix Core
enum ZylixEvent {
    case increment
    case decrement
    case reset

    var eventType: UInt32 {
        switch self {
        case .increment: return UInt32(ZYLIX_EVENT_COUNTER_INCREMENT)
        case .decrement: return UInt32(ZYLIX_EVENT_COUNTER_DECREMENT)
        case .reset: return UInt32(ZYLIX_EVENT_COUNTER_RESET)
        }
    }
}

// MARK: - Zylix Bridge

/// Main bridge class connecting SwiftUI to Zylix Core
/// This is an ObservableObject that publishes state changes to SwiftUI
@MainActor
final class ZylixBridge: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: ZylixState = .initial
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var lastError: String?

    // MARK: - Singleton

    static let shared = ZylixBridge()

    // MARK: - Initialization

    private init() {}

    /// Initialize Zylix Core
    func initialize() {
        guard !isInitialized else { return }

        let result = zylix_init()
        if result == ZYLIX_OK {
            isInitialized = true
            refreshState()
            print("[ZylixWatch] Core initialized, ABI version: \(zylix_get_abi_version())")
        } else {
            lastError = String(cString: zylix_get_last_error())
            print("[ZylixWatch] Failed to initialize: \(lastError ?? "unknown")")
        }
    }

    /// Shutdown Zylix Core
    func shutdown() {
        guard isInitialized else { return }

        let result = zylix_deinit()
        if result == ZYLIX_OK {
            isInitialized = false
            state = .initial
            print("[ZylixWatch] Core shutdown")
        }
    }

    // MARK: - Event Dispatch

    /// Dispatch an event to Zylix Core
    func dispatch(_ event: ZylixEvent) {
        guard isInitialized else {
            print("[ZylixWatch] Cannot dispatch: not initialized")
            return
        }

        let result = zylix_dispatch(event.eventType, nil, 0)

        if result == ZYLIX_OK {
            refreshState()
        } else {
            lastError = String(cString: zylix_get_last_error())
            print("[ZylixWatch] Dispatch failed: \(lastError ?? "unknown")")
        }
    }

    // MARK: - State Management

    /// Refresh state from Zylix Core
    private func refreshState() {
        guard let statePtr = zylix_get_state() else {
            return
        }

        let rawState = statePtr.pointee

        // Read counter from view_data
        var counter: Int64 = 0
        if let viewData = rawState.view_data {
            let appState = viewData.assumingMemoryBound(to: zylix_app_state_t.self).pointee
            counter = appState.counter
        }

        // Convert to Swift state
        state = ZylixState(
            version: rawState.version,
            screen: ZylixState.Screen(rawValue: rawState.screen) ?? .home,
            loading: rawState.loading,
            errorMessage: rawState.error_message.map { String(cString: $0) },
            counter: counter
        )
    }

    /// Get current state version (for polling)
    var stateVersion: UInt64 {
        return zylix_get_state_version()
    }
}

// MARK: - Convenience Extensions

extension ZylixBridge {
    /// Increment counter
    func increment() {
        dispatch(.increment)
    }

    /// Decrement counter
    func decrement() {
        dispatch(.decrement)
    }

    /// Reset counter
    func reset() {
        dispatch(.reset)
    }
}
