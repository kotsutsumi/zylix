// ZylixHotReload.swift - macOS Hot Reload for Zylix v0.5.0
//
// macOS-specific hot reload with AppKit integration.
// Extends iOS implementation with macOS-specific features.

import Foundation
import AppKit
import Combine

// MARK: - macOS Hot Reload Extensions

extension ZylixHotReloadClient {
    /// Configure for macOS development
    public func configureMacOS() {
        // Default to localhost for macOS development
        serverURL = URL(string: "ws://localhost:3001")!

        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.disconnect()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.state == .disconnected {
                self?.connect()
            }
        }
    }
}

// MARK: - File System Watcher

public class FileSystemWatcher {
    private var eventStream: FSEventStreamRef?
    private let paths: [String]
    private let callback: ([String]) -> Void
    private var latency: CFTimeInterval = 0.1

    public init(paths: [String], callback: @escaping ([String]) -> Void) {
        self.paths = paths
        self.callback = callback
    }

    public func start() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(CallbackWrapper(callback)).toOpaque(),
            retain: nil,
            release: { info in
                guard let info = info else { return }
                Unmanaged<CallbackWrapper>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

        let streamCallback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(info).takeUnretainedValue()

            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            wrapper.callback(paths)
        }

        eventStream = FSEventStreamCreate(
            nil,
            streamCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    public func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    deinit {
        stop()
    }

    private class CallbackWrapper {
        let callback: ([String]) -> Void
        init(_ callback: @escaping ([String]) -> Void) {
            self.callback = callback
        }
    }
}

// MARK: - Development Server

public class MacOSDevServer {
    public static let shared = MacOSDevServer()

    private var httpServer: HTTPServer?
    private var fileWatcher: FileSystemWatcher?
    private let hotReloadClient = ZylixHotReloadClient.shared

    public var port: UInt16 = 3000
    public var watchPaths: [String] = []
    public var isRunning: Bool = false

    private init() {}

    public func start() {
        guard !isRunning else { return }

        // Start HTTP server
        httpServer = HTTPServer(port: port)
        httpServer?.start()

        // Start file watcher
        if !watchPaths.isEmpty {
            fileWatcher = FileSystemWatcher(paths: watchPaths) { [weak self] changedPaths in
                self?.handleFileChanges(changedPaths)
            }
            fileWatcher?.start()
        }

        // Connect hot reload client
        hotReloadClient.configureMacOS()
        hotReloadClient.connect()

        isRunning = true
        print("🚀 Zylix Dev Server running at http://localhost:\(port)")
    }

    public func stop() {
        httpServer?.stop()
        fileWatcher?.stop()
        hotReloadClient.disconnect()
        isRunning = false
    }

    private func handleFileChanges(_ paths: [String]) {
        print("📁 Files changed: \(paths.count)")

        for path in paths {
            let ext = (path as NSString).pathExtension

            if ["swift", "m", "h"].contains(ext) {
                // Trigger full rebuild
                triggerRebuild()
                return
            } else if ["js", "css", "html"].contains(ext) {
                // Trigger hot update
                triggerHotUpdate(path)
            }
        }
    }

    private func triggerRebuild() {
        // Run xcodebuild in background
        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            task.arguments = ["build"]

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        // Notify connected clients
                        NotificationCenter.default.post(name: .zylixHotReload, object: nil)
                    }
                }
            } catch {
                print("Build failed: \(error)")
            }
        }
    }

    private func triggerHotUpdate(_ path: String) {
        NotificationCenter.default.post(
            name: .zylixHotUpdate,
            object: nil,
            userInfo: ["module": path]
        )
    }
}

// MARK: - Simple HTTP Server

class HTTPServer {
    private var listener: Any?
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        // macOS doesn't have NWListener in older versions
        // This is a placeholder for actual HTTP server implementation
        print("HTTP server starting on port \(port)")
    }

    func stop() {
        listener = nil
    }
}

// MARK: - Error Overlay Panel

public class ErrorOverlayPanel: NSPanel {
    private let error: BuildError

    public init(error: BuildError) {
        self.error = error

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "Build Error"
        backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        isFloatingPanel = true
        level = .floating
        center()

        setupUI()
    }

    private func setupUI() {
        let contentView = NSView(frame: bounds)
        contentView.wantsLayer = true

        // Title
        let titleLabel = NSTextField(labelWithString: "⚠️ Build Error")
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textColor = NSColor(red: 1, green: 0.42, blue: 0.42, alpha: 1)
        titleLabel.frame = NSRect(x: 20, y: bounds.height - 50, width: bounds.width - 40, height: 30)
        contentView.addSubview(titleLabel)

        // Location
        let locationLabel = NSTextField(labelWithString: "\(error.file):\(error.line):\(error.column)")
        locationLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        locationLabel.textColor = .gray
        locationLabel.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 20)
        contentView.addSubview(locationLabel)

        // Message
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: bounds.width - 40, height: bounds.height - 160))
        let messageView = NSTextView(frame: scrollView.bounds)
        messageView.string = error.message
        messageView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        messageView.textColor = .white
        messageView.backgroundColor = NSColor(white: 0.2, alpha: 1)
        messageView.isEditable = false
        scrollView.documentView = messageView
        contentView.addSubview(scrollView)

        // Dismiss button
        let dismissButton = NSButton(title: "Dismiss", target: self, action: #selector(dismissPanel))
        dismissButton.bezelStyle = .rounded
        dismissButton.frame = NSRect(x: 20, y: 20, width: 100, height: 30)
        contentView.addSubview(dismissButton)

        self.contentView = contentView
    }

    @objc private func dismissPanel() {
        close()
    }
}

// MARK: - Menu Bar Item

public class DevServerMenuBarItem: NSObject {
    private var statusItem: NSStatusItem?
    private let devServer = MacOSDevServer.shared

    public func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🔥"
        statusItem?.button?.toolTip = "Zylix Dev Server"

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Stopped", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 1
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Start Server",
            action: #selector(startServer),
            keyEquivalent: "s"
        ))

        menu.addItem(NSMenuItem(
            title: "Stop Server",
            action: #selector(stopServer),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu

        for item in menu.items {
            item.target = self
        }
    }

    @objc private func startServer() {
        devServer.start()
        updateStatus()
    }

    @objc private func stopServer() {
        devServer.stop()
        updateStatus()
    }

    private func updateStatus() {
        if let menu = statusItem?.menu,
           let statusItem = menu.item(withTag: 1) {
            statusItem.title = devServer.isRunning ?
                "Status: Running on port \(devServer.port)" :
                "Status: Stopped"
        }
    }
}

// MARK: - Window Controller Integration

public protocol HotReloadable: AnyObject {
    func performHotReload()
}

public extension HotReloadable where Self: NSWindowController {
    func enableHotReload() {
        NotificationCenter.default.addObserver(
            forName: .zylixHotReload,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performHotReload()
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

public struct MacOSHotReloadableView<Content: View>: View {
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
