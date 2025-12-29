// ZylixAsync.swift - iOS Async Processing for Zylix
//
// Provides Swift concurrency integration for Zylix async system.
// Features:
// - Future/Promise pattern
// - HTTP Client with URLSession
// - Task scheduling with priorities
// - Cancellation support

import Foundation
import Combine

// MARK: - Future State

/// State of an async operation
public enum FutureState {
    case pending
    case fulfilled
    case rejected
    case cancelled
}

// MARK: - Async Exceptions

/// Errors that can occur during async operations
public enum ZylixAsyncError: Error, LocalizedError {
    case timeout(message: String = "Operation timed out")
    case cancelled(message: String = "Operation was cancelled")
    case networkError(message: String)
    case invalidResponse(message: String = "Invalid response")
    case decodingError(message: String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let message): return message
        case .cancelled(let message): return message
        case .networkError(let message): return message
        case .invalidResponse(let message): return message
        case .decodingError(let message): return message
        }
    }
}

// MARK: - Zylix Future

/// Promise-like wrapper for async operations
public class ZylixFuture<T> {
    private var _state: FutureState = .pending
    public var state: FutureState { _state }

    private var _value: T?
    public var value: T? { _value }

    private var _error: Error?
    public var error: Error? { _error }

    private var thenCallbacks: [(T) -> Void] = []
    private var catchCallbacks: [(Error) -> Void] = []
    private var finallyCallbacks: [() -> Void] = []

    private var task: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private let lock = NSLock()

    public init() {}

    /// Resolve the future with a value
    public func resolve(_ value: T) {
        lock.lock()
        defer { lock.unlock() }

        guard _state == .pending else { return }
        _value = value
        _state = .fulfilled

        let callbacks = thenCallbacks
        let finalCallbacks = finallyCallbacks

        DispatchQueue.main.async {
            callbacks.forEach { $0(value) }
            finalCallbacks.forEach { $0() }
        }

        timeoutTask?.cancel()
    }

    /// Reject the future with an error
    public func reject(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }

        guard _state == .pending else { return }
        _error = error
        _state = .rejected

        let callbacks = catchCallbacks
        let finalCallbacks = finallyCallbacks

        DispatchQueue.main.async {
            callbacks.forEach { $0(error) }
            finalCallbacks.forEach { $0() }
        }

        timeoutTask?.cancel()
    }

    /// Cancel the future
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }

        guard _state == .pending else { return }
        _state = .cancelled

        task?.cancel()
        timeoutTask?.cancel()

        let finalCallbacks = finallyCallbacks
        DispatchQueue.main.async {
            finalCallbacks.forEach { $0() }
        }
    }

    /// Add a success callback
    @discardableResult
    public func then(_ callback: @escaping (T) -> Void) -> ZylixFuture<T> {
        lock.lock()
        defer { lock.unlock() }

        if _state == .fulfilled, let value = _value {
            DispatchQueue.main.async { callback(value) }
        } else {
            thenCallbacks.append(callback)
        }
        return self
    }

    /// Add an error callback
    @discardableResult
    public func `catch`(_ callback: @escaping (Error) -> Void) -> ZylixFuture<T> {
        lock.lock()
        defer { lock.unlock() }

        if _state == .rejected, let error = _error {
            DispatchQueue.main.async { callback(error) }
        } else {
            catchCallbacks.append(callback)
        }
        return self
    }

    /// Add a completion callback (called on success, failure, or cancel)
    @discardableResult
    public func finally(_ callback: @escaping () -> Void) -> ZylixFuture<T> {
        lock.lock()
        defer { lock.unlock() }

        if _state != .pending {
            DispatchQueue.main.async { callback() }
        } else {
            finallyCallbacks.append(callback)
        }
        return self
    }

    /// Set a timeout for this future
    @discardableResult
    public func timeout(_ seconds: TimeInterval) -> ZylixFuture<T> {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if self._state == .pending {
                self.reject(ZylixAsyncError.timeout())
            }
        }
        return self
    }

    /// Await the future result using async/await
    public func await() async throws -> T {
        switch _state {
        case .fulfilled:
            return _value!
        case .rejected:
            throw _error!
        case .cancelled:
            throw ZylixAsyncError.cancelled()
        case .pending:
            return try await withCheckedThrowingContinuation { continuation in
                then { value in
                    continuation.resume(returning: value)
                }
                self.catch { error in
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Convert to Combine Publisher
    public func toPublisher() -> AnyPublisher<T, Error> {
        Future<T, Error> { promise in
            self.then { value in
                promise(.success(value))
            }
            self.catch { error in
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    // MARK: - Static Factory Methods

    /// Create a future from an async block
    public static func from(_ block: @escaping () async throws -> T) -> ZylixFuture<T> {
        let future = ZylixFuture<T>()
        future.task = Task {
            do {
                let result = try await block()
                future.resolve(result)
            } catch is CancellationError {
                future.cancel()
            } catch {
                future.reject(error)
            }
        }
        return future
    }

    /// Create an already resolved future
    public static func resolved(_ value: T) -> ZylixFuture<T> {
        let future = ZylixFuture<T>()
        future.resolve(value)
        return future
    }

    /// Create an already rejected future
    public static func rejected(_ error: Error) -> ZylixFuture<T> {
        let future = ZylixFuture<T>()
        future.reject(error)
        return future
    }
}

// MARK: - HTTP Response

/// HTTP response wrapper
public struct HttpResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public var isSuccess: Bool { 200..<300 ~= statusCode }

    public var bodyString: String {
        String(data: body, encoding: .utf8) ?? ""
    }

    public func json() throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw ZylixAsyncError.decodingError(message: "Failed to parse JSON")
        }
        return json
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: body)
    }
}

// MARK: - HTTP Client

/// HTTP client with Future-based API
public class ZylixHttpClient {
    public static let shared = ZylixHttpClient()

    private let session: URLSession
    private var defaultHeaders: [String: String] = [
        "User-Agent": "Zylix/0.4.0",
        "Accept": "application/json"
    ]

    public init(configuration: URLSessionConfiguration = .default) {
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Set default headers for all requests
    public func setDefaultHeader(_ key: String, value: String) {
        defaultHeaders[key] = value
    }

    // MARK: - HTTP Methods

    public func get(_ url: String, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        request(method: "GET", url: url, body: nil, headers: headers)
    }

    public func post(_ url: String, body: Data? = nil, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        request(method: "POST", url: url, body: body, headers: headers)
    }

    public func put(_ url: String, body: Data? = nil, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        request(method: "PUT", url: url, body: body, headers: headers)
    }

    public func delete(_ url: String, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        request(method: "DELETE", url: url, body: nil, headers: headers)
    }

    public func patch(_ url: String, body: Data? = nil, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        request(method: "PATCH", url: url, body: body, headers: headers)
    }

    /// POST with JSON body
    public func postJson(_ url: String, json: [String: Any], headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"

        do {
            let body = try JSONSerialization.data(withJSONObject: json)
            return request(method: "POST", url: url, body: body, headers: allHeaders)
        } catch {
            return .rejected(error)
        }
    }

    /// POST with Encodable body
    public func postJson<T: Encodable>(_ url: String, body: T, headers: [String: String] = [:]) -> ZylixFuture<HttpResponse> {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"

        do {
            let data = try JSONEncoder().encode(body)
            return request(method: "POST", url: url, body: data, headers: allHeaders)
        } catch {
            return .rejected(error)
        }
    }

    // MARK: - Private

    private func request(method: String, url: String, body: Data?, headers: [String: String]) -> ZylixFuture<HttpResponse> {
        let future = ZylixFuture<HttpResponse>()

        guard let url = URL(string: url) else {
            future.reject(ZylixAsyncError.invalidResponse(message: "Invalid URL"))
            return future
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Merge headers
        defaultHeaders.merge(headers) { _, new in new }.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled {
                    future.cancel()
                } else {
                    future.reject(ZylixAsyncError.networkError(message: error.localizedDescription))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                future.reject(ZylixAsyncError.invalidResponse())
                return
            }

            let responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }

            future.resolve(HttpResponse(
                statusCode: httpResponse.statusCode,
                headers: responseHeaders,
                body: data
            ))
        }

        task.resume()
        return future
    }
}

// MARK: - Task Scheduler

/// Task priority levels
public enum TaskPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Task state
public enum TaskState {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// Handle to a scheduled task
public class ZylixTaskHandle: Identifiable {
    public let id = UUID()
    public let priority: TaskPriority
    public private(set) var state: TaskState = .queued

    private var cancelled = false
    private var task: Task<Void, Never>?

    init(priority: TaskPriority = .normal) {
        self.priority = priority
    }

    /// Cancel the task
    public func cancel() {
        cancelled = true
        state = .cancelled
        task?.cancel()
    }

    /// Check if cancelled
    public func isCancelled() -> Bool { cancelled }

    internal func setTask(_ task: Task<Void, Never>) {
        self.task = task
    }

    internal func setState(_ state: TaskState) {
        self.state = state
    }
}

/// Task scheduler with priority queue
@MainActor
public class ZylixScheduler {
    public static let shared = ZylixScheduler()

    private var tasks: [(ZylixTaskHandle, @Sendable () async -> Void)] = []
    private var isRunning = false
    private var processingTask: Task<Void, Never>?
    private let lock = NSLock()

    private init() {
        start()
    }

    /// Start the scheduler
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        processingTask = Task { await processLoop() }
    }

    /// Stop the scheduler
    public func stop() {
        isRunning = false
        processingTask?.cancel()
    }

    /// Schedule a task for execution
    @discardableResult
    public func schedule(
        priority: TaskPriority = .normal,
        work: @escaping @Sendable () async -> Void
    ) -> ZylixTaskHandle {
        let handle = ZylixTaskHandle(priority: priority)

        lock.lock()
        tasks.append((handle, work))
        tasks.sort { $0.0.priority > $1.0.priority }
        lock.unlock()

        return handle
    }

    /// Schedule a delayed task
    @discardableResult
    public func scheduleDelayed(
        delay: TimeInterval,
        priority: TaskPriority = .normal,
        work: @escaping @Sendable () async -> Void
    ) -> ZylixTaskHandle {
        let handle = ZylixTaskHandle(priority: priority)

        let wrappedWork: @Sendable () async -> Void = {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !handle.isCancelled() else { return }
            await work()
        }

        lock.lock()
        tasks.append((handle, wrappedWork))
        tasks.sort { $0.0.priority > $1.0.priority }
        lock.unlock()

        return handle
    }

    /// Number of pending tasks
    public var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return tasks.filter { $0.0.state == .queued }.count
    }

    private func processLoop() async {
        while isRunning {
            lock.lock()
            let nextTask = tasks.first(where: { $0.0.state == .queued })
            if let task = nextTask {
                tasks.removeAll { $0.0.id == task.0.id }
            }
            lock.unlock()

            if let (handle, work) = nextTask, !handle.isCancelled() {
                handle.setState(.running)
                await work()
                if handle.state == .running {
                    handle.setState(.completed)
                }
            }

            try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
        }
    }
}

// MARK: - Async Utilities

/// Wait for all futures to complete
public func all<T>(_ futures: [ZylixFuture<T>]) async throws -> [T] {
    try await withThrowingTaskGroup(of: (Int, T).self) { group in
        for (index, future) in futures.enumerated() {
            group.addTask {
                let value = try await future.await()
                return (index, value)
            }
        }

        var results = [(Int, T)]()
        for try await result in group {
            results.append(result)
        }

        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}

/// Wait for the first future to complete
public func race<T>(_ futures: [ZylixFuture<T>]) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        for future in futures {
            group.addTask {
                try await future.await()
            }
        }

        guard let first = try await group.next() else {
            throw ZylixAsyncError.invalidResponse(message: "No futures provided")
        }

        group.cancelAll()
        return first
    }
}

/// Delay execution
public func delay(_ seconds: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

/// Retry an async operation with exponential backoff
public func retry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 30.0,
    block: @escaping () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            return try await block()
        } catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                try await delay(currentDelay)
                currentDelay = min(currentDelay * 2, maxDelay)
            }
        }
    }

    throw lastError!
}

/// Debounce function calls
public class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    public func debounce(action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    public func cancel() {
        task?.cancel()
    }
}

/// Throttle function calls
public class Throttler {
    private var lastExecutionTime: Date?
    private let interval: TimeInterval
    private let lock = NSLock()

    public init(interval: TimeInterval = 0.3) {
        self.interval = interval
    }

    public func throttle(action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if let lastTime = lastExecutionTime {
            guard now.timeIntervalSince(lastTime) >= interval else { return }
        }

        lastExecutionTime = now
        action()
    }
}
