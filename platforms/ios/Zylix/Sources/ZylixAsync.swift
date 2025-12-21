// ZylixAsync.swift - iOS Async Processing for Zylix v0.4.0
//
// Provides Swift Concurrency integration for Zylix async system.
// Features:
// - async/await integration
// - URLSession wrapper
// - Task scheduling
// - Cancellation support

import Foundation
import Combine

// MARK: - Future State

public enum FutureState {
    case pending
    case fulfilled
    case rejected
    case cancelled
}

// MARK: - Zylix Future

@MainActor
public class ZylixFuture<T> {
    public private(set) var state: FutureState = .pending
    public private(set) var value: T?
    public private(set) var error: Error?

    private var thenCallbacks: [(T) -> Void] = []
    private var catchCallbacks: [(Error) -> Void] = []
    private var finallyCallbacks: [() -> Void] = []
    private var task: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    public init() {}

    public init(value: T) {
        self.value = value
        self.state = .fulfilled
    }

    public init(error: Error) {
        self.error = error
        self.state = .rejected
    }

    // MARK: - Resolution

    public func resolve(_ value: T) {
        guard state == .pending else { return }
        self.value = value
        self.state = .fulfilled
        thenCallbacks.forEach { $0(value) }
        finallyCallbacks.forEach { $0() }
        timeoutTask?.cancel()
    }

    public func reject(_ error: Error) {
        guard state == .pending else { return }
        self.error = error
        self.state = .rejected
        catchCallbacks.forEach { $0(error) }
        finallyCallbacks.forEach { $0() }
        timeoutTask?.cancel()
    }

    public func cancel() {
        guard state == .pending else { return }
        self.state = .cancelled
        task?.cancel()
        timeoutTask?.cancel()
        finallyCallbacks.forEach { $0() }
    }

    // MARK: - Callbacks

    @discardableResult
    public func then(_ callback: @escaping (T) -> Void) -> Self {
        thenCallbacks.append(callback)
        if case .fulfilled = state, let value = value {
            callback(value)
        }
        return self
    }

    @discardableResult
    public func `catch`(_ callback: @escaping (Error) -> Void) -> Self {
        catchCallbacks.append(callback)
        if case .rejected = state, let error = error {
            callback(error)
        }
        return self
    }

    @discardableResult
    public func finally(_ callback: @escaping () -> Void) -> Self {
        finallyCallbacks.append(callback)
        if state != .pending {
            callback()
        }
        return self
    }

    @discardableResult
    public func timeout(_ seconds: TimeInterval) -> Self {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if self.state == .pending {
                self.reject(ZylixAsyncError.timeout)
            }
        }
        return self
    }

    // MARK: - Async/Await

    public func await() async throws -> T {
        if case .fulfilled = state, let value = value {
            return value
        }
        if case .rejected = state, let error = error {
            throw error
        }
        if case .cancelled = state {
            throw ZylixAsyncError.cancelled
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.then { value in
                continuation.resume(returning: value)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Static Factories

    public static func from(_ operation: @escaping () async throws -> T) -> ZylixFuture<T> {
        let future = ZylixFuture<T>()
        future.task = Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    future.resolve(result)
                }
            } catch {
                await MainActor.run {
                    future.reject(error)
                }
            }
        }
        return future
    }

    public static func resolved(_ value: T) -> ZylixFuture<T> {
        return ZylixFuture(value: value)
    }

    public static func rejected(_ error: Error) -> ZylixFuture<T> {
        return ZylixFuture(error: error)
    }
}

// MARK: - Async Errors

public enum ZylixAsyncError: Error, LocalizedError {
    case timeout
    case cancelled
    case networkError(String)
    case invalidResponse
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .timeout: return "Operation timed out"
        case .cancelled: return "Operation was cancelled"
        case .networkError(let msg): return "Network error: \(msg)"
        case .invalidResponse: return "Invalid response"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        }
    }
}

// MARK: - HTTP Client

public class ZylixHttpClient {
    public static let shared = ZylixHttpClient()

    private let session: URLSession
    private var defaultHeaders: [String: String] = [
        "User-Agent": "Zylix/0.4.0",
        "Accept": "application/json"
    ]

    public init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Request Methods

    public func get(_ url: String, headers: [String: String] = [:]) -> ZylixFuture<HTTPResponse> {
        return request(.get, url: url, body: nil, headers: headers)
    }

    public func post(_ url: String, body: Data? = nil, headers: [String: String] = [:]) -> ZylixFuture<HTTPResponse> {
        return request(.post, url: url, body: body, headers: headers)
    }

    public func put(_ url: String, body: Data? = nil, headers: [String: String] = [:]) -> ZylixFuture<HTTPResponse> {
        return request(.put, url: url, body: body, headers: headers)
    }

    public func delete(_ url: String, headers: [String: String] = [:]) -> ZylixFuture<HTTPResponse> {
        return request(.delete, url: url, body: nil, headers: headers)
    }

    public func postJSON<T: Encodable>(_ url: String, body: T, headers: [String: String] = [:]) -> ZylixFuture<HTTPResponse> {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"

        let bodyData: Data?
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            return ZylixFuture(error: ZylixAsyncError.decodingError(error.localizedDescription))
        }

        return request(.post, url: url, body: bodyData, headers: allHeaders)
    }

    // MARK: - Internal Request

    private func request(_ method: HTTPMethod, url: String, body: Data?, headers: [String: String]) -> ZylixFuture<HTTPResponse> {
        guard let urlObj = URL(string: url) else {
            return ZylixFuture(error: ZylixAsyncError.networkError("Invalid URL"))
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = method.rawValue
        request.httpBody = body

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return ZylixFuture.from {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZylixAsyncError.invalidResponse
            }
            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                data: data
            )
        }
    }
}

// MARK: - HTTP Types

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}

public struct HTTPResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let data: Data

    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }

    public var text: String? {
        String(data: data, encoding: .utf8)
    }

    public func json<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Task Scheduler

public enum TaskPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum TaskState {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

public class ZylixTaskHandle {
    public let id: UUID
    public private(set) var state: TaskState = .queued
    public private(set) var priority: TaskPriority

    private var task: Task<Void, Never>?
    private var isCancelled = false

    init(priority: TaskPriority = .normal) {
        self.id = UUID()
        self.priority = priority
    }

    public func cancel() {
        isCancelled = true
        state = .cancelled
        task?.cancel()
    }

    internal func setTask(_ task: Task<Void, Never>) {
        self.task = task
    }

    internal func markRunning() { state = .running }
    internal func markCompleted() { state = .completed }
    internal func markFailed() { state = .failed }
    internal func checkCancelled() -> Bool { isCancelled }
}

@MainActor
public class ZylixScheduler {
    public static let shared = ZylixScheduler()

    private var tasks: [(handle: ZylixTaskHandle, work: () async -> Void)] = []
    private var isRunning = false
    private var processingTask: Task<Void, Never>?

    private init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        processingTask = Task { await self.processLoop() }
    }

    public func stop() {
        isRunning = false
        processingTask?.cancel()
    }

    @discardableResult
    public func schedule(priority: TaskPriority = .normal, work: @escaping () async -> Void) -> ZylixTaskHandle {
        let handle = ZylixTaskHandle(priority: priority)

        // Insert based on priority
        let index = tasks.firstIndex { $0.handle.priority < priority } ?? tasks.count
        tasks.insert((handle, work), at: index)

        return handle
    }

    @discardableResult
    public func scheduleDelayed(delay: TimeInterval, priority: TaskPriority = .normal, work: @escaping () async -> Void) -> ZylixTaskHandle {
        let handle = ZylixTaskHandle(priority: priority)

        let wrappedWork: () async -> Void = {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !handle.checkCancelled() {
                await work()
            }
        }

        let index = tasks.firstIndex { $0.handle.priority < priority } ?? tasks.count
        tasks.insert((handle, wrappedWork), at: index)

        return handle
    }

    public var pendingCount: Int {
        tasks.filter { $0.handle.state == .queued }.count
    }

    private func processLoop() async {
        while isRunning {
            if let taskInfo = tasks.first, taskInfo.handle.state == .queued {
                tasks.removeFirst()
                let handle = taskInfo.handle

                if !handle.checkCancelled() {
                    handle.markRunning()
                    do {
                        await taskInfo.work()
                        handle.markCompleted()
                    } catch {
                        handle.markFailed()
                    }
                }
            }

            try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
        }
    }
}

// MARK: - Async Utilities

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

public func race<T>(_ futures: [ZylixFuture<T>]) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        for future in futures {
            group.addTask {
                try await future.await()
            }
        }

        guard let first = try await group.next() else {
            throw ZylixAsyncError.cancelled
        }

        group.cancelAll()
        return first
    }
}

public func delay(_ seconds: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

public func retry<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                let backoff = delay * pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
    }

    throw lastError!
}
