// ZylixAsync.swift - macOS Async Processing for Zylix v0.4.0
//
// macOS-specific async processing with AppKit integration.
// Shares core implementation with iOS, adds macOS-specific features.

import Foundation
import Combine
import AppKit

// Re-export iOS async types (shared implementation)
// Note: In a real project, these would be in a shared framework

// MARK: - macOS-Specific Extensions

extension ZylixHttpClient {
    /// Download file to disk
    public func download(_ url: String, to destination: URL) -> ZylixFuture<URL> {
        return ZylixFuture.from {
            guard let sourceURL = URL(string: url) else {
                throw ZylixAsyncError.networkError("Invalid URL")
            }

            let (tempURL, response) = try await URLSession.shared.download(from: sourceURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw ZylixAsyncError.invalidResponse
            }

            try FileManager.default.moveItem(at: tempURL, to: destination)
            return destination
        }
    }

    /// Upload file
    public func upload(_ url: String, file: URL, mimeType: String = "application/octet-stream") -> ZylixFuture<HTTPResponse> {
        return ZylixFuture.from {
            guard let requestURL = URL(string: url) else {
                throw ZylixAsyncError.networkError("Invalid URL")
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.setValue(mimeType, forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: file)

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

// MARK: - Process Execution

public struct ProcessResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool { exitCode == 0 }
}

public class ZylixProcess {
    /// Execute a shell command
    public static func exec(_ command: String, arguments: [String] = []) -> ZylixFuture<ProcessResult> {
        return ZylixFuture.from {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", ([command] + arguments).joined(separator: " ")]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }
    }

    /// Execute with live output streaming
    public static func execStream(
        _ command: String,
        arguments: [String] = [],
        onOutput: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) -> ZylixFuture<Int32> {
        return ZylixFuture.from {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", ([command] + arguments).joined(separator: " ")]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    DispatchQueue.main.async { onOutput(str) }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    DispatchQueue.main.async { onError(str) }
                }
            }

            try process.run()
            process.waitUntilExit()

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            return process.terminationStatus
        }
    }
}

// MARK: - File System Async Operations

public class ZylixFileSystem {
    /// Read file asynchronously
    public static func read(_ url: URL) -> ZylixFuture<Data> {
        return ZylixFuture.from {
            try Data(contentsOf: url)
        }
    }

    /// Write file asynchronously
    public static func write(_ data: Data, to url: URL) -> ZylixFuture<Void> {
        return ZylixFuture.from {
            try data.write(to: url)
        }
    }

    /// Read text file
    public static func readText(_ url: URL, encoding: String.Encoding = .utf8) -> ZylixFuture<String> {
        return ZylixFuture.from {
            try String(contentsOf: url, encoding: encoding)
        }
    }

    /// Write text file
    public static func writeText(_ text: String, to url: URL, encoding: String.Encoding = .utf8) -> ZylixFuture<Void> {
        return ZylixFuture.from {
            try text.write(to: url, atomically: true, encoding: encoding)
        }
    }

    /// List directory contents
    public static func listDirectory(_ url: URL) -> ZylixFuture<[URL]> {
        return ZylixFuture.from {
            try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        }
    }

    /// Watch directory for changes
    public static func watch(_ url: URL, onChange: @escaping ([URL]) -> Void) -> FSEventStreamRef? {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(onChange as AnyObject).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let callback = Unmanaged<AnyObject>.fromOpaque(info).takeUnretainedValue() as! ([URL]) -> Void
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            callback(paths.map { URL(fileURLWithPath: $0) })
        }

        let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }

        return stream
    }
}

// MARK: - Notification Center Async

extension NotificationCenter {
    /// Async notification observer
    public func notifications(named name: Notification.Name) -> AsyncStream<Notification> {
        AsyncStream { continuation in
            let observer = self.addObserver(forName: name, object: nil, queue: nil) { notification in
                continuation.yield(notification)
            }

            continuation.onTermination = { _ in
                self.removeObserver(observer)
            }
        }
    }
}

// MARK: - App Lifecycle Integration

@MainActor
public class ZylixAppLifecycle {
    public static let shared = ZylixAppLifecycle()

    private var observers: [NSObjectProtocol] = []

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { _ in
                ZylixScheduler.shared.stop()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                ZylixScheduler.shared.start()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Optionally pause scheduler when app is inactive
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
