// ZylixRouter.kt - Android Router for Zylix v0.3.0
//
// Provides Jetpack Compose Navigation integration for Zylix routing system.
// Features:
// - NavHost/NavController integration
// - Deep link handling (App Links)
// - Route parameters and query strings
// - Navigation guards
// - Type-safe routing

package com.zylix

import android.net.Uri
import androidx.compose.runtime.*
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

// ============================================================================
// Route Definition
// ============================================================================

/**
 * A route parameter extracted from URL
 */
data class RouteParam(
    val name: String,
    val value: String
)

/**
 * Parsed URL components
 */
data class ParsedURL(
    val path: String,
    val params: List<RouteParam> = emptyList(),
    val query: Map<String, String> = emptyMap(),
    val fragment: String? = null
) {
    fun getParam(name: String): String? = params.find { it.name == name }?.value
    fun getQuery(key: String): String? = query[key]
}

/**
 * Route guard result
 */
sealed class GuardResult {
    object Allow : GuardResult()
    data class Deny(val message: String? = null) : GuardResult()
    data class Redirect(val to: String) : GuardResult()
}

/**
 * Route metadata
 */
data class RouteMeta(
    val title: String? = null,
    val requiresAuth: Boolean = false,
    val permissions: List<String> = emptyList()
)

/**
 * A single route definition
 */
data class Route(
    val path: String,
    val meta: RouteMeta = RouteMeta(),
    val guards: List<(RouteContext) -> GuardResult> = emptyList(),
    val children: List<Route> = emptyList()
)

/**
 * Context passed to route handlers
 */
class RouteContext(
    val url: ParsedURL,
    val router: ZylixRouter? = null
) {
    var isAuthenticated: Boolean = false
    var userRoles: List<String> = emptyList()
    var userData: Any? = null

    fun hasRole(role: String): Boolean = role in userRoles
}

// ============================================================================
// Navigation Event
// ============================================================================

enum class NavigationEvent {
    PUSH,
    REPLACE,
    BACK,
    FORWARD,
    DEEP_LINK
}

// ============================================================================
// Router
// ============================================================================

/**
 * Main router class for Zylix Android
 */
class ZylixRouter {
    private var routes: List<Route> = emptyList()
    private val history = mutableListOf<String>()
    private var historyIndex = -1
    private val navigationCallbacks = mutableListOf<(NavigationEvent, String, RouteContext) -> Unit>()
    private var notFoundHandler: ((ParsedURL) -> Unit)? = null
    private var basePath: String = ""

    private val _currentPath = MutableStateFlow("/")
    val currentPath: StateFlow<String> = _currentPath.asStateFlow()

    private val _currentContext = MutableStateFlow<RouteContext?>(null)
    val currentContext: StateFlow<RouteContext?> = _currentContext.asStateFlow()

    var navController: NavHostController? = null

    // ========================================================================
    // Configuration
    // ========================================================================

    fun defineRoutes(routes: List<Route>): ZylixRouter {
        this.routes = routes
        return this
    }

    fun setBasePath(path: String): ZylixRouter {
        this.basePath = path
        return this
    }

    fun onNotFound(handler: (ParsedURL) -> Unit): ZylixRouter {
        this.notFoundHandler = handler
        return this
    }

    fun onNavigate(callback: (NavigationEvent, String, RouteContext) -> Unit): ZylixRouter {
        navigationCallbacks.add(callback)
        return this
    }

    // ========================================================================
    // Navigation
    // ========================================================================

    fun push(path: String, userData: Any? = null) {
        navigate(path, NavigationEvent.PUSH, userData = userData)
    }

    fun replace(path: String, userData: Any? = null) {
        navigate(path, NavigationEvent.REPLACE, userData = userData)
    }

    fun back() {
        if (!canGoBack()) return
        historyIndex--
        val path = history[historyIndex]
        navigate(path, NavigationEvent.BACK, updateHistory = false)
    }

    fun forward() {
        if (!canGoForward()) return
        historyIndex++
        val path = history[historyIndex]
        navigate(path, NavigationEvent.FORWARD, updateHistory = false)
    }

    fun canGoBack(): Boolean = historyIndex > 0

    fun canGoForward(): Boolean = historyIndex < history.size - 1

    // ========================================================================
    // Deep Linking
    // ========================================================================

    fun handleDeepLink(uri: Uri) {
        val path = uri.path ?: "/"
        navigate(path, NavigationEvent.DEEP_LINK)
    }

    fun handleDeepLink(url: String) {
        val uri = Uri.parse(url)
        handleDeepLink(uri)
    }

    // ========================================================================
    // URL Parsing
    // ========================================================================

    fun parseURL(urlString: String): ParsedURL {
        var path = urlString
        var fragment: String? = null
        var queryString: String? = null

        // Extract fragment
        val hashIndex = path.indexOf('#')
        if (hashIndex >= 0) {
            fragment = path.substring(hashIndex + 1)
            path = path.substring(0, hashIndex)
        }

        // Extract query string
        val queryIndex = path.indexOf('?')
        if (queryIndex >= 0) {
            queryString = path.substring(queryIndex + 1)
            path = path.substring(0, queryIndex)
        }

        // Parse query parameters
        val query = mutableMapOf<String, String>()
        queryString?.split("&")?.forEach { pair ->
            val parts = pair.split("=", limit = 2)
            if (parts.size == 2) {
                query[parts[0]] = parts[1]
            }
        }

        return ParsedURL(path = path, query = query, fragment = fragment)
    }

    // ========================================================================
    // Route Matching
    // ========================================================================

    fun matchRoute(path: String): Pair<Route, List<RouteParam>>? {
        for (route in routes) {
            matchPattern(route.path, path)?.let { params ->
                return route to params
            }
            // Check children
            for (child in route.children) {
                val fullPattern = route.path + child.path
                matchPattern(fullPattern, path)?.let { params ->
                    return child to params
                }
            }
        }
        return null
    }

    private fun matchPattern(pattern: String, path: String): List<RouteParam>? {
        val patternParts = pattern.split("/").filter { it.isNotEmpty() }
        val pathParts = path.split("/").filter { it.isNotEmpty() }

        if (patternParts.size != pathParts.size) return null

        val params = mutableListOf<RouteParam>()

        for ((patternPart, pathPart) in patternParts.zip(pathParts)) {
            when {
                patternPart.startsWith(":") -> {
                    val paramName = patternPart.drop(1)
                    params.add(RouteParam(paramName, pathPart))
                }
                patternPart == "*" -> {
                    params.add(RouteParam("wildcard", pathPart))
                }
                patternPart != pathPart -> return null
            }
        }

        return params
    }

    // ========================================================================
    // Private Navigation
    // ========================================================================

    private fun navigate(
        path: String,
        event: NavigationEvent,
        updateHistory: Boolean = true,
        userData: Any? = null
    ) {
        val fullPath = basePath + path
        var parsed = parseURL(fullPath)

        // Match route
        val matched = matchRoute(parsed.path)
        if (matched == null) {
            notFoundHandler?.invoke(parsed)
            return
        }

        val (route, params) = matched

        // Update parsed URL with params
        parsed = parsed.copy(params = params)

        // Create context
        val context = RouteContext(parsed, this).apply {
            this.userData = userData
        }

        // Check guards
        for (guard in route.guards) {
            when (val result = guard(context)) {
                is GuardResult.Allow -> continue
                is GuardResult.Deny -> {
                    println("[ZylixRouter] Navigation denied: ${result.message}")
                    return
                }
                is GuardResult.Redirect -> {
                    replace(result.to)
                    return
                }
            }
        }

        // Update history
        if (updateHistory && (event == NavigationEvent.PUSH || event == NavigationEvent.DEEP_LINK)) {
            // Remove forward history
            if (historyIndex < history.size - 1) {
                history.subList(historyIndex + 1, history.size).clear()
            }
            history.add(path)
            historyIndex = history.size - 1
        }

        // Update state
        _currentPath.value = path
        _currentContext.value = context

        // Update NavController if available
        navController?.let { nav ->
            try {
                if (event == NavigationEvent.REPLACE) {
                    nav.popBackStack()
                }
                nav.navigate(path)
            } catch (e: Exception) {
                println("[ZylixRouter] NavController error: ${e.message}")
            }
        }

        // Notify callbacks
        for (callback in navigationCallbacks) {
            callback(event, path, context)
        }
    }
}

// ============================================================================
// Common Guards
// ============================================================================

fun requireAuth(context: RouteContext): GuardResult {
    return if (context.isAuthenticated) {
        GuardResult.Allow
    } else {
        GuardResult.Redirect("/login")
    }
}

fun requireRole(role: String): (RouteContext) -> GuardResult {
    return { context ->
        if (context.hasRole(role)) {
            GuardResult.Allow
        } else {
            GuardResult.Deny("Insufficient permissions")
        }
    }
}

// ============================================================================
// Compose Integration
// ============================================================================

/**
 * Remember and provide a ZylixRouter instance
 */
@Composable
fun rememberZylixRouter(): ZylixRouter {
    val navController = rememberNavController()
    return remember {
        ZylixRouter().also { it.navController = navController }
    }
}

/**
 * Composable to observe current route
 */
@Composable
fun ZylixRouter.observeCurrentPath(): State<String> {
    return currentPath.collectAsState()
}

/**
 * Composable to observe current context
 */
@Composable
fun ZylixRouter.observeCurrentContext(): State<RouteContext?> {
    return currentContext.collectAsState()
}

/**
 * Local composition for router access
 */
val LocalZylixRouter = staticCompositionLocalOf<ZylixRouter?> { null }

/**
 * Provider for router
 */
@Composable
fun ZylixRouterProvider(
    router: ZylixRouter,
    content: @Composable () -> Unit
) {
    CompositionLocalProvider(LocalZylixRouter provides router) {
        content()
    }
}
