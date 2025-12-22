// Zylix Test Framework - macOS Accessibility Bridge
// Wraps macOS Accessibility API for UI automation

import Cocoa
import ApplicationServices

/// Accessibility element wrapper
public class AXElement {
    let element: AXUIElement
    let identifier: String

    init(element: AXUIElement, identifier: String) {
        self.element = element
        self.identifier = identifier
    }

    // MARK: - Attributes

    public var title: String? {
        return getAttribute(.title) as? String
    }

    public var value: Any? {
        return getAttribute(.value)
    }

    public var role: String? {
        return getAttribute(.role) as? String
    }

    public var roleDescription: String? {
        return getAttribute(.roleDescription) as? String
    }

    public var isEnabled: Bool {
        return (getAttribute(.enabled) as? Bool) ?? false
    }

    public var isFocused: Bool {
        return (getAttribute(.focused) as? Bool) ?? false
    }

    public var frame: CGRect {
        guard let position = getAttribute(.position),
              let size = getAttribute(.size) else {
            return .zero
        }

        var point = CGPoint.zero
        var cgSize = CGSize.zero

        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &cgSize)

        return CGRect(origin: point, size: cgSize)
    }

    public var children: [AXElement] {
        guard let childElements = getAttribute(.children) as? [AXUIElement] else {
            return []
        }
        return childElements.enumerated().map { index, child in
            AXElement(element: child, identifier: "\(identifier)-child-\(index)")
        }
    }

    // MARK: - Actions

    public func click() -> Bool {
        return performAction(.press)
    }

    public func doubleClick() -> Bool {
        // Perform press twice for double-click
        return performAction(.press) && performAction(.press)
    }

    public func focus() -> Bool {
        return setAttribute(.focused, value: true as CFBoolean)
    }

    public func setValue(_ value: String) -> Bool {
        return setAttribute(.value, value: value as CFString)
    }

    public func showMenu() -> Bool {
        return performAction(.showMenu)
    }

    // MARK: - Private Helpers

    private func getAttribute(_ attribute: NSAccessibility.Attribute) -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private func setAttribute(_ attribute: NSAccessibility.Attribute, value: CFTypeRef) -> Bool {
        let result = AXUIElementSetAttributeValue(element, attribute.rawValue as CFString, value)
        return result == .success
    }

    private func performAction(_ action: NSAccessibility.Action) -> Bool {
        let result = AXUIElementPerformAction(element, action.rawValue as CFString)
        return result == .success
    }
}

/// Accessibility bridge for app automation
public class AccessibilityBridge {

    private var app: AXUIElement?
    private var pid: pid_t?
    private var elements: [String: AXElement] = [:]
    private var elementCounter: Int = 0

    public init() {}

    // MARK: - App Management

    public func launch(bundleId: String, timeout: TimeInterval = 30) throws -> pid_t {
        // Launch the app
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) else {
            throw AccessibilityError.appNotFound(bundleId)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        var launchedPid: pid_t?
        let semaphore = DispatchSemaphore(value: 0)

        workspace.openApplication(at: appURL, configuration: config) { app, error in
            launchedPid = app?.processIdentifier
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + timeout)

        guard let pid = launchedPid else {
            throw AccessibilityError.launchFailed(bundleId)
        }

        self.pid = pid
        self.app = AXUIElementCreateApplication(pid)

        return pid
    }

    public func terminate() {
        guard let pid = pid else { return }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "")
        for app in runningApps where app.processIdentifier == pid {
            app.terminate()
            break
        }

        self.app = nil
        self.pid = nil
        self.elements.removeAll()
    }

    // MARK: - Element Finding

    public func findElement(strategy: String, value: String) -> AXElement? {
        guard let app = app else { return nil }

        let rootElement = AXElement(element: app, identifier: "app")

        switch strategy {
        case "identifier":
            return findByIdentifier(root: rootElement, identifier: value)
        case "title":
            return findByTitle(root: rootElement, title: value)
        case "role":
            return findByRole(root: rootElement, role: value)
        case "predicate":
            return findByPredicate(root: rootElement, predicate: value)
        default:
            return nil
        }
    }

    public func findElements(strategy: String, value: String) -> [AXElement] {
        guard let app = app else { return [] }

        let rootElement = AXElement(element: app, identifier: "app")
        var results: [AXElement] = []

        switch strategy {
        case "identifier":
            findAllByIdentifier(root: rootElement, identifier: value, results: &results)
        case "title":
            findAllByTitle(root: rootElement, title: value, results: &results)
        case "role":
            findAllByRole(root: rootElement, role: value, results: &results)
        default:
            break
        }

        return results
    }

    public func storeElement(_ element: AXElement) -> String {
        elementCounter += 1
        let id = "ax-\(elementCounter)"
        elements[id] = element
        return id
    }

    public func getElement(_ id: String) -> AXElement? {
        return elements[id]
    }

    // MARK: - Private Helpers

    private func findByIdentifier(root: AXElement, identifier: String) -> AXElement? {
        if root.title == identifier {
            return root
        }

        for child in root.children {
            if let found = findByIdentifier(root: child, identifier: identifier) {
                return found
            }
        }

        return nil
    }

    private func findByTitle(root: AXElement, title: String) -> AXElement? {
        if root.title == title {
            return root
        }

        for child in root.children {
            if let found = findByTitle(root: child, title: title) {
                return found
            }
        }

        return nil
    }

    private func findByRole(root: AXElement, role: String) -> AXElement? {
        if root.role == role {
            return root
        }

        for child in root.children {
            if let found = findByRole(root: child, role: role) {
                return found
            }
        }

        return nil
    }

    private func findByPredicate(root: AXElement, predicate: String) -> AXElement? {
        // Simple predicate parsing
        if predicate.contains("title CONTAINS") {
            let value = extractPredicateValue(predicate)
            if let title = root.title, title.contains(value) {
                return root
            }
        }

        for child in root.children {
            if let found = findByPredicate(root: child, predicate: predicate) {
                return found
            }
        }

        return nil
    }

    private func findAllByIdentifier(root: AXElement, identifier: String, results: inout [AXElement]) {
        if root.title == identifier {
            results.append(root)
        }

        for child in root.children {
            findAllByIdentifier(root: child, identifier: identifier, results: &results)
        }
    }

    private func findAllByTitle(root: AXElement, title: String, results: inout [AXElement]) {
        if root.title == title {
            results.append(root)
        }

        for child in root.children {
            findAllByTitle(root: child, title: title, results: &results)
        }
    }

    private func findAllByRole(root: AXElement, role: String, results: inout [AXElement]) {
        if root.role == role {
            results.append(root)
        }

        for child in root.children {
            findAllByRole(root: child, role: role, results: &results)
        }
    }

    private func extractPredicateValue(_ predicate: String) -> String {
        // Extract value from predicate like "title CONTAINS 'value'"
        guard let start = predicate.firstIndex(of: "'"),
              let end = predicate.lastIndex(of: "'"),
              start < end else {
            return ""
        }
        let valueStart = predicate.index(after: start)
        return String(predicate[valueStart..<end])
    }

    // MARK: - Screenshot

    public func takeScreenshot() -> Data? {
        guard let pid = pid else { return nil }

        // Get app window
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            if let windowPid = window[kCGWindowOwnerPID as String] as? Int32,
               windowPid == pid,
               let windowId = window[kCGWindowNumber as String] as? CGWindowID {
                if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowId, .bestResolution) {
                    let bitmapRep = NSBitmapImageRep(cgImage: image)
                    return bitmapRep.representation(using: .png, properties: [:])
                }
            }
        }

        return nil
    }

    public func takeElementScreenshot(_ element: AXElement) -> Data? {
        // Take full screenshot and crop to element bounds
        guard let fullScreenshot = takeScreenshot(),
              let image = NSImage(data: fullScreenshot) else {
            return nil
        }

        let frame = element.frame
        guard frame != .zero else { return nil }

        // Crop to element bounds
        let croppedImage = NSImage(size: frame.size)
        croppedImage.lockFocus()
        image.draw(at: .zero,
                   from: CGRect(origin: frame.origin, size: frame.size),
                   operation: .copy,
                   fraction: 1.0)
        croppedImage.unlockFocus()

        guard let tiffData = croppedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRep.representation(using: .png, properties: [:])
    }
}

// MARK: - Errors

public enum AccessibilityError: Error {
    case appNotFound(String)
    case launchFailed(String)
    case accessDenied
    case elementNotFound
    case actionFailed
}
