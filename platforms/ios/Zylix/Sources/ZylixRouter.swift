// ZylixRouter.swift - iOS Router for Zylix v0.3.0
//
// Provides SwiftUI NavigationStack integration for Zylix routing system.
// Features:
// - NavigationStack/NavigationPath integration
// - Deep link handling (Universal Links)
// - Route parameters and query strings
// - Navigation guards
// - Type-safe routing

import SwiftUI
import Combine

// MARK: - Route Definition

/// A route parameter extracted from URL
public struct RouteParam: Equatable, Hashable {
    public let name: String
    public let value: String
}

/// Parsed URL components
public struct ParsedURL: Equatable {
    public let path: String
    public let params: [RouteParam]
    public let query: [String: String]
    public let fragment: String?

    public func getParam(_ name: String) -> String? {
        params.first { $0.name == name }?.value
    }

    public func getQuery(_ key: String) -> String? {
        query[key]
    }
}

/// Route guard result
public enum GuardResult {
    case allow
    case deny(message: String?)
    case redirect(to: String)
}

/// Route metadata
public struct RouteMeta {
    public var title: String?
    public var requiresAuth: Bool = false
    public var permissions: [String] = []

    public init(title: String? = nil, requiresAuth: Bool = false, permissions: [String] = []) {
        self.title = title
        self.requiresAuth = requiresAuth
        self.permissions = permissions
    }
}

/// A single route definition
public struct Route: Identifiable {
    public let id = UUID()
    public let path: String
    public let meta: RouteMeta
    public var guards: [(RouteContext) -> GuardResult] = []
    public var children: [Route] = []

    public init(
        path: String,
        meta: RouteMeta = RouteMeta(),
        guards: [(RouteContext) -> GuardResult] = [],
        children: [Route] = []
    ) {
        self.path = path
        self.meta = meta
        self.guards = guards
        self.children = children
    }
}

/// Context passed to route handlers
public class RouteContext: ObservableObject {
    @Published public var url: ParsedURL
    @Published public var isAuthenticated: Bool = false
    @Published public var userRoles: [String] = []
    public weak var router: ZylixRouter?
    public var userData: Any?

    public init(url: ParsedURL, router: ZylixRouter? = nil) {
        self.url = url
        self.router = router
    }

    public func hasRole(_ role: String) -> Bool {
        userRoles.contains(role)
    }
}

// MARK: - Navigation Event

public enum NavigationEvent {
    case push
    case replace
    case back
    case forward
    case deepLink
}

// MARK: - Router

@MainActor
public class ZylixRouter: ObservableObject {
    @Published public var currentPath: String = "/"
    @Published public var navigationPath = NavigationPath()
    @Published public var currentContext: RouteContext?

    private var routes: [Route] = []
    private var history: [String] = []
    private var historyIndex: Int = -1
    private var navigationCallbacks: [(NavigationEvent, String, RouteContext) -> Void] = []
    private var notFoundHandler: ((ParsedURL) -> Void)?
    private var basePath: String = ""

    public init() {}

    // MARK: - Configuration

    public func defineRoutes(_ routes: [Route]) -> ZylixRouter {
        self.routes = routes
        return self
    }

    public func setBasePath(_ path: String) -> ZylixRouter {
        self.basePath = path
        return self
    }

    public func onNotFound(_ handler: @escaping (ParsedURL) -> Void) -> ZylixRouter {
        self.notFoundHandler = handler
        return self
    }

    public func onNavigate(_ callback: @escaping (NavigationEvent, String, RouteContext) -> Void) -> ZylixRouter {
        navigationCallbacks.append(callback)
        return self
    }

    // MARK: - Navigation

    public func push(_ path: String, userData: Any? = nil) {
        navigate(path, event: .push, userData: userData)
    }

    public func replace(_ path: String, userData: Any? = nil) {
        navigate(path, event: .replace, userData: userData)
    }

    public func back() {
        guard canGoBack else { return }
        historyIndex -= 1
        let path = history[historyIndex]
        navigate(path, event: .back, updateHistory: false)
    }

    public func forward() {
        guard canGoForward else { return }
        historyIndex += 1
        let path = history[historyIndex]
        navigate(path, event: .forward, updateHistory: false)
    }

    public var canGoBack: Bool {
        historyIndex > 0
    }

    public var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    // MARK: - Deep Linking

    public func handleDeepLink(_ url: URL) {
        let path = url.path.isEmpty ? "/" : url.path
        navigate(path, event: .deepLink)
    }

    public func handleUniversalLink(_ url: URL) {
        // Extract path from universal link
        var path = url.path
        if !basePath.isEmpty && path.hasPrefix(basePath) {
            path = String(path.dropFirst(basePath.count))
        }
        if path.isEmpty { path = "/" }
        navigate(path, event: .deepLink)
    }

    // MARK: - URL Parsing

    public func parseURL(_ urlString: String) -> ParsedURL {
        var path = urlString
        var fragment: String? = nil
        var queryString: String? = nil

        // Extract fragment
        if let hashIndex = path.firstIndex(of: "#") {
            fragment = String(path[path.index(after: hashIndex)...])
            path = String(path[..<hashIndex])
        }

        // Extract query string
        if let queryIndex = path.firstIndex(of: "?") {
            queryString = String(path[path.index(after: queryIndex)...])
            path = String(path[..<queryIndex])
        }

        // Parse query parameters
        var query: [String: String] = [:]
        if let qs = queryString {
            for pair in qs.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    query[String(parts[0])] = String(parts[1])
                }
            }
        }

        return ParsedURL(path: path, params: [], query: query, fragment: fragment)
    }

    // MARK: - Route Matching

    public func matchRoute(_ path: String) -> (Route, [RouteParam])? {
        for route in routes {
            if let params = matchPattern(route.path, path: path) {
                return (route, params)
            }
            // Check children
            for child in route.children {
                let fullPattern = route.path + child.path
                if let params = matchPattern(fullPattern, path: path) {
                    return (child, params)
                }
            }
        }
        return nil
    }

    private func matchPattern(_ pattern: String, path: String) -> [RouteParam]? {
        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: true)
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true)

        guard patternParts.count == pathParts.count else { return nil }

        var params: [RouteParam] = []

        for (patternPart, pathPart) in zip(patternParts, pathParts) {
            if patternPart.hasPrefix(":") {
                let paramName = String(patternPart.dropFirst())
                params.append(RouteParam(name: paramName, value: String(pathPart)))
            } else if patternPart == "*" {
                params.append(RouteParam(name: "wildcard", value: String(pathPart)))
            } else if patternPart != pathPart {
                return nil
            }
        }

        return params
    }

    // MARK: - Private Navigation

    private func navigate(_ path: String, event: NavigationEvent, updateHistory: Bool = true, userData: Any? = nil) {
        let fullPath = basePath + path
        var parsed = parseURL(fullPath)

        // Match route
        guard let (route, params) = matchRoute(parsed.path) else {
            notFoundHandler?(parsed)
            return
        }

        // Update parsed URL with params
        parsed = ParsedURL(path: parsed.path, params: params, query: parsed.query, fragment: parsed.fragment)

        // Create context
        let context = RouteContext(url: parsed, router: self)
        context.userData = userData

        // Check guards
        for guard_ in route.guards {
            let result = guard_(context)
            switch result {
            case .allow:
                continue
            case .deny(let message):
                print("[ZylixRouter] Navigation denied: \(message ?? "No reason")")
                return
            case .redirect(let redirectPath):
                replace(redirectPath)
                return
            }
        }

        // Update history
        if updateHistory && (event == .push || event == .deepLink) {
            // Remove forward history
            if historyIndex < history.count - 1 {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.append(path)
            historyIndex = history.count - 1
        }

        // Update state
        currentPath = path
        currentContext = context

        // Notify callbacks
        for callback in navigationCallbacks {
            callback(event, path, context)
        }
    }
}

// MARK: - Common Guards

public func requireAuth(_ context: RouteContext) -> GuardResult {
    if context.isAuthenticated {
        return .allow
    }
    return .redirect(to: "/login")
}

public func requireRole(_ role: String) -> (RouteContext) -> GuardResult {
    return { context in
        if context.hasRole(role) {
            return .allow
        }
        return .deny(message: "Insufficient permissions")
    }
}

// MARK: - SwiftUI Router View

public struct RouterView<Content: View>: View {
    @ObservedObject var router: ZylixRouter
    let content: (RouteContext?) -> Content

    public init(router: ZylixRouter, @ViewBuilder content: @escaping (RouteContext?) -> Content) {
        self.router = router
        self.content = content
    }

    public var body: some View {
        NavigationStack(path: $router.navigationPath) {
            content(router.currentContext)
        }
        .onOpenURL { url in
            router.handleDeepLink(url)
        }
    }
}

// MARK: - Router Link

public struct RouterLink<Label: View>: View {
    let path: String
    let label: () -> Label
    @EnvironmentObject var router: ZylixRouter

    public init(_ path: String, @ViewBuilder label: @escaping () -> Label) {
        self.path = path
        self.label = label
    }

    public var body: some View {
        Button(action: { router.push(path) }) {
            label()
        }
    }
}

// MARK: - Router Environment

private struct RouterKey: EnvironmentKey {
    static let defaultValue: ZylixRouter? = nil
}

public extension EnvironmentValues {
    var zylixRouter: ZylixRouter? {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}

public extension View {
    func zylixRouter(_ router: ZylixRouter) -> some View {
        environment(\.zylixRouter, router)
            .environmentObject(router)
    }
}
