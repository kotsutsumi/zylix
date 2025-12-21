import Foundation
import CZylix

// MARK: - Result Type

/// Result codes returned by Zylix functions
public enum ZylixResult: Int32, Error {
    case ok = 0
    case invalidArgument = 1
    case outOfMemory = 2
    case invalidState = 3
    case notInitialized = 4

    public var description: String {
        switch self {
        case .ok: return "Success"
        case .invalidArgument: return "Invalid argument"
        case .outOfMemory: return "Out of memory"
        case .invalidState: return "Invalid state"
        case .notInitialized: return "Not initialized"
        }
    }
}

// MARK: - Event Priority

/// Priority levels for queued events
public enum ZylixEventPriority: UInt8 {
    case low = 0
    case normal = 1
    case high = 2
    case immediate = 3
}

// MARK: - State Wrapper

/// Swift-friendly wrapper for Zylix state
public struct ZylixStateSnapshot {
    /// State version number (increments on changes)
    public let version: UInt64

    /// Current screen identifier
    public let screen: UInt32

    /// Whether a loading operation is in progress
    public let isLoading: Bool

    /// Current error message, if any
    public let errorMessage: String?

    init(from cState: CZylix.ZylixState) {
        self.version = cState.version
        self.screen = cState.screen
        self.isLoading = cState.loading

        if let errorPtr = cState.error_message {
            self.errorMessage = String(cString: errorPtr)
        } else {
            self.errorMessage = nil
        }
    }
}

// MARK: - Diff Wrapper

/// Swift-friendly wrapper for Zylix diff information
public struct ZylixDiffSnapshot {
    /// Bitmask of changed field IDs
    public let changedMask: UInt64

    /// Number of fields that changed
    public let changeCount: UInt8

    /// Version when diff was computed
    public let version: UInt64

    init(from cDiff: CZylix.ZylixDiff) {
        self.changedMask = cDiff.changed_mask
        self.changeCount = cDiff.change_count
        self.version = cDiff.version
    }

    /// Check if a specific field changed
    public func hasFieldChanged(_ fieldId: UInt16) -> Bool {
        return (changedMask & (1 << fieldId)) != 0
    }
}

// MARK: - ZylixCore

/// Main interface to Zylix Core
///
/// ZylixCore provides a Swift-friendly API for interacting with the
/// Zig-compiled Zylix engine. It manages lifecycle, state, and events.
///
/// Example usage:
/// ```swift
/// let zylix = ZylixCore.shared
/// try zylix.initialize()
///
/// // Dispatch an event
/// try zylix.dispatch(eventType: 0x1000)
///
/// // Get current state
/// if let state = zylix.state {
///     print("Version: \(state.version)")
/// }
/// ```
public final class ZylixCore {

    // MARK: - Singleton

    /// Shared instance of ZylixCore
    public static let shared = ZylixCore()

    // MARK: - Properties

    /// Whether the core has been initialized
    public private(set) var isInitialized = false

    /// Current ABI version
    public var abiVersion: UInt32 {
        return zylix_get_abi_version()
    }

    /// Current state snapshot
    public var state: ZylixStateSnapshot? {
        guard let statePtr = zylix_get_state() else {
            return nil
        }
        return ZylixStateSnapshot(from: statePtr.pointee)
    }

    /// Current state version
    public var stateVersion: UInt64 {
        return zylix_get_state_version()
    }

    /// Current diff information
    public var diff: ZylixDiffSnapshot? {
        guard let diffPtr = zylix_get_diff() else {
            return nil
        }
        return ZylixDiffSnapshot(from: diffPtr.pointee)
    }

    /// Number of events in queue
    public var queueDepth: UInt32 {
        return zylix_queue_depth()
    }

    /// Last error message
    public var lastError: String {
        guard let errorPtr = zylix_get_last_error() else {
            return "Unknown error"
        }
        return String(cString: errorPtr)
    }

    // MARK: - Initialization

    private init() {}

    /// Initialize Zylix Core
    ///
    /// Must be called before using any other ZylixCore methods.
    /// Safe to call multiple times.
    ///
    /// - Throws: ZylixResult if initialization fails
    public func initialize() throws {
        let result = zylix_init()
        guard result == ZylixResult.ok.rawValue else {
            throw ZylixResult(rawValue: result) ?? .invalidState
        }
        isInitialized = true
    }

    /// Shutdown Zylix Core
    ///
    /// Releases all resources. Call `initialize()` again to resume use.
    ///
    /// - Throws: ZylixResult if shutdown fails
    public func shutdown() throws {
        let result = zylix_deinit()
        guard result == ZylixResult.ok.rawValue else {
            throw ZylixResult(rawValue: result) ?? .invalidState
        }
        isInitialized = false
    }

    // MARK: - Event Dispatch

    /// Dispatch an event immediately
    ///
    /// - Parameters:
    ///   - eventType: Event type identifier
    ///   - payload: Optional payload data
    /// - Throws: ZylixResult if dispatch fails
    public func dispatch(eventType: UInt32, payload: Data? = nil) throws {
        let result: Int32

        if let payload = payload {
            result = payload.withUnsafeBytes { buffer in
                zylix_dispatch(eventType, buffer.baseAddress, buffer.count)
            }
        } else {
            result = zylix_dispatch(eventType, nil, 0)
        }

        guard result == ZylixResult.ok.rawValue else {
            throw ZylixResult(rawValue: result) ?? .invalidState
        }
    }

    /// Queue an event for later processing
    ///
    /// - Parameters:
    ///   - eventType: Event type identifier
    ///   - payload: Optional payload data (max 256 bytes)
    ///   - priority: Event priority
    /// - Throws: ZylixResult if queuing fails
    public func queueEvent(
        eventType: UInt32,
        payload: Data? = nil,
        priority: ZylixEventPriority = .normal
    ) throws {
        let result: Int32

        if let payload = payload {
            result = payload.withUnsafeBytes { buffer in
                zylix_queue_event(eventType, buffer.baseAddress, buffer.count, priority.rawValue)
            }
        } else {
            result = zylix_queue_event(eventType, nil, 0, priority.rawValue)
        }

        guard result == ZylixResult.ok.rawValue else {
            throw ZylixResult(rawValue: result) ?? .invalidState
        }
    }

    /// Process queued events
    ///
    /// - Parameter maxEvents: Maximum number of events to process
    /// - Returns: Number of events actually processed
    @discardableResult
    public func processEvents(maxEvents: UInt32 = 100) -> UInt32 {
        return zylix_process_events(maxEvents)
    }

    /// Clear all queued events
    public func clearQueue() {
        zylix_queue_clear()
    }

    // MARK: - State Queries

    /// Check if a specific field changed
    ///
    /// - Parameter fieldId: Field identifier to check
    /// - Returns: true if the field changed
    public func fieldChanged(_ fieldId: UInt16) -> Bool {
        return zylix_field_changed(fieldId)
    }
}

// MARK: - Event Type Constants

extension ZylixCore {
    /// Event type constants for dispatching
    public enum EventType: UInt32 {
        // Lifecycle events
        case appInit = 0x0001
        case appTerminate = 0x0002
        case appForeground = 0x0003
        case appBackground = 0x0004
        case appLowMemory = 0x0005

        // User interaction
        case buttonPress = 0x0100
        case textInput = 0x0101
        case textCommit = 0x0102
        case selection = 0x0103
        case scroll = 0x0104
        case gesture = 0x0105

        // Navigation
        case navigate = 0x0200
        case navigateBack = 0x0201
        case tabSwitch = 0x0202

        // Counter PoC events
        case counterIncrement = 0x1000
        case counterDecrement = 0x1001
        case counterReset = 0x1002
    }

    /// Dispatch an event using EventType enum
    public func dispatch(_ event: EventType, payload: Data? = nil) throws {
        try dispatch(eventType: event.rawValue, payload: payload)
    }
}

// MARK: - Convenience Extensions

extension ZylixCore {
    /// Process events on each run loop iteration
    ///
    /// Call this from your app's main run loop or a CADisplayLink callback
    /// to ensure events are processed regularly.
    public func tick() {
        guard isInitialized else { return }
        processEvents(maxEvents: 10)
    }

    // MARK: - Counter Convenience Methods

    /// Increment the counter
    public func increment() throws {
        try dispatch(.counterIncrement)
    }

    /// Decrement the counter
    public func decrement() throws {
        try dispatch(.counterDecrement)
    }

    /// Reset the counter to zero
    public func reset() throws {
        try dispatch(.counterReset)
    }

    /// Get the current counter value from app state
    public var counterValue: Int64 {
        guard let state = zylix_get_state(),
              let viewData = state.pointee.view_data else {
            return 0
        }
        let appState = viewData.assumingMemoryBound(to: ZylixAppState.self)
        return appState.pointee.counter
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI
import Combine

/// Observable wrapper for ZylixCore state
///
/// Use this class with SwiftUI to automatically update views when state changes.
///
/// Example:
/// ```swift
/// struct ContentView: View {
///     @StateObject var zylix = ZylixObservable()
///
///     var body: some View {
///         Text("Version: \(zylix.stateVersion)")
///     }
/// }
/// ```
@MainActor
public class ZylixObservable: ObservableObject {
    /// Current state version
    @Published public private(set) var stateVersion: UInt64 = 0

    /// Current state snapshot
    @Published public private(set) var state: ZylixStateSnapshot?

    /// Current counter value
    @Published public private(set) var counter: Int64 = 0

    /// Whether core is initialized
    @Published public private(set) var isInitialized = false

    private var displayLink: CADisplayLink?
    private var lastVersion: UInt64 = 0

    public init() {
        do {
            try ZylixCore.shared.initialize()
            isInitialized = true
            updateState()
            startDisplayLink()
        } catch {
            print("Failed to initialize ZylixCore: \(error)")
        }
    }

    deinit {
        stopDisplayLink()
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLink() {
        ZylixCore.shared.tick()

        let currentVersion = ZylixCore.shared.stateVersion
        if currentVersion != lastVersion {
            lastVersion = currentVersion
            updateState()
        }
    }

    private func updateState() {
        stateVersion = ZylixCore.shared.stateVersion
        state = ZylixCore.shared.state
        counter = ZylixCore.shared.counterValue
    }

    /// Dispatch an event using raw event type
    public func dispatch(eventType: UInt32, payload: Data? = nil) {
        do {
            try ZylixCore.shared.dispatch(eventType: eventType, payload: payload)
            updateState()
        } catch {
            print("Dispatch failed: \(error)")
        }
    }

    /// Dispatch an event using EventType enum
    public func dispatch(_ event: ZylixCore.EventType, payload: Data? = nil) {
        dispatch(eventType: event.rawValue, payload: payload)
    }

    // MARK: - Counter Convenience Methods

    /// Increment the counter
    public func increment() {
        dispatch(.counterIncrement)
    }

    /// Decrement the counter
    public func decrement() {
        dispatch(.counterDecrement)
    }

    /// Reset the counter
    public func reset() {
        dispatch(.counterReset)
    }
}
#endif
