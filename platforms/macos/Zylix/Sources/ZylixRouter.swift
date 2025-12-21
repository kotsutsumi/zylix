// ZylixRouter.swift - macOS Router for Zylix v0.3.0
//
// Provides SwiftUI NavigationSplitView integration for Zylix routing system.
// Features:
// - NavigationSplitView integration for macOS
// - Deep link handling (Custom URL schemes)
// - Route parameters and query strings
// - Navigation guards
// - Window management integration

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
    public var showInSidebar: Bool = true
    public var icon: String?

    public init(
        title: String? = nil,
        requiresAuth: Bool = false,
        permissions: [String] = [],
        showInSidebar: Bool = true,
        icon: String? = nil
    ) {
        self.title = title
        self.requiresAuth = requiresAuth
        self.permissions = permissions
        self.showInSidebar = showInSidebar
        self.icon = icon
    }
}

/// A single route definition
public struct Route: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    public let meta: RouteMeta
    public var children: [Route] = []

    // Guards stored separately due to Hashable requirement
    internal var guardIds: [UUID] = []

    public init(
        path: String,
        meta: RouteMeta = RouteMeta(),
        children: [Route] = []
    ) {
        self.path = path
        self.meta = meta
        self.children = children
    }

    public static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
    @Published public var selectedRoute: Route?
    @Published public var currentContext: RouteContext?
    @Published public var sidebarRoutes: [Route] = []

    private var routes: [Route] = []
    private var guards: [UUID: (RouteContext) -> GuardResult] = [:]
    private var history: [String] = []
    private var historyIndex: Int = -1
    private var navigationCallbacks: [(NavigationEvent, String, RouteContext) -> Void] = []
    private var notFoundHandler: ((ParsedURL) -> Void)?
    private var basePath: String = ""

    public init() {}

    // MARK: - Configuration

    public func defineRoutes(_ routes: [Route]) -> ZylixRouter {
        self.routes = routes
        self.sidebarRoutes = routes.filter { $0.meta.showInSidebar }
        return self
    }

    public func addGuard(for route: inout Route, guard: @escaping (RouteContext) -> GuardResult) -> ZylixRouter {
        let guardId = UUID()
        route.guardIds.append(guardId)
        guards[guardId] = guard
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

    public func select(_ route: Route) {
        push(route.path)
    }

    // MARK: - Deep Linking

    public func handleDeepLink(_ url: URL) {
        let path = url.path.isEmpty ? "/" : url.path
        navigate(path, event: .deepLink)
    }

    public func handleCustomURLScheme(_ url: URL) {
        // Handle zylix:// URLs
        guard url.scheme == "zylix" else { return }
        let path = "/" + url.host.map { $0 + url.path } .flatMap { $0 } ?? url.path
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
        for guardId in route.guardIds {
            if let guard_ = guards[guardId] {
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
        }

        // Update history
        if updateHistory && (event == .push || event == .deepLink) {
            if historyIndex < history.count - 1 {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.append(path)
            historyIndex = history.count - 1
        }

        // Update state
        currentPath = path
        selectedRoute = route
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

// MARK: - SwiftUI Router View (macOS-specific with NavigationSplitView)

public struct MacOSRouterView<Sidebar: View, Detail: View>: View {
    @ObservedObject var router: ZylixRouter
    let sidebar: () -> Sidebar
    let detail: (RouteContext?) -> Detail

    public init(
        router: ZylixRouter,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping (RouteContext?) -> Detail
    ) {
        self.router = router
        self.sidebar = sidebar
        self.detail = detail
    }

    public var body: some View {
        NavigationSplitView {
            sidebar()
        } detail: {
            detail(router.currentContext)
        }
        .onOpenURL { url in
            router.handleDeepLink(url)
        }
    }
}

// MARK: - Sidebar Navigation List

public struct RouterSidebarList: View {
    @ObservedObject var router: ZylixRouter

    public init(router: ZylixRouter) {
        self.router = router
    }

    public var body: some View {
        List(router.sidebarRoutes, selection: $router.selectedRoute) { route in
            NavigationLink(value: route) {
                Label(
                    route.meta.title ?? route.path,
                    systemImage: route.meta.icon ?? "folder"
                )
            }
        }
        .onChange(of: router.selectedRoute) { _, newValue in
            if let route = newValue {
                router.push(route.path)
            }
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
