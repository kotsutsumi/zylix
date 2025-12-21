/**
 * zylix-router.js - Web Platform Router for Zylix v0.3.0
 *
 * Provides browser History API integration for Zylix routing system.
 * Features:
 * - History API integration (pushState, replaceState, popstate)
 * - Hash-based fallback routing
 * - Deep link handling
 * - Query parameter support
 * - Navigation guards
 */

class ZylixRouter {
    constructor(options = {}) {
        this.routes = [];
        this.currentRoute = null;
        this.history = [];
        this.historyIndex = -1;
        this.guards = [];
        this.callbacks = [];
        this.basePath = options.basePath || '';
        this.mode = options.mode || 'history'; // 'history' or 'hash'
        this.notFoundHandler = options.notFound || null;

        // Bind popstate handler
        this._onPopState = this._onPopState.bind(this);
        window.addEventListener('popstate', this._onPopState);

        // Handle initial route
        if (options.autoStart !== false) {
            this._handleInitialRoute();
        }
    }

    /**
     * Define routes
     * @param {Array} routes - Array of route definitions
     */
    defineRoutes(routes) {
        this.routes = routes.map(route => ({
            ...route,
            pattern: this._compilePattern(route.path),
        }));
        return this;
    }

    /**
     * Add a navigation guard
     * @param {Function} guard - Guard function (to, from) => boolean | Promise<boolean> | { redirect: string }
     */
    addGuard(guard) {
        this.guards.push(guard);
        return this;
    }

    /**
     * Add navigation callback
     * @param {Function} callback - Callback function (event, route, params) => void
     */
    onNavigate(callback) {
        this.callbacks.push(callback);
        return this;
    }

    /**
     * Navigate to a path
     * @param {string} path - Path to navigate to
     * @param {Object} options - Navigation options
     */
    async push(path, options = {}) {
        return this._navigate(path, 'push', options);
    }

    /**
     * Replace current path
     * @param {string} path - Path to replace with
     * @param {Object} options - Navigation options
     */
    async replace(path, options = {}) {
        return this._navigate(path, 'replace', options);
    }

    /**
     * Go back in history
     */
    back() {
        window.history.back();
    }

    /**
     * Go forward in history
     */
    forward() {
        window.history.forward();
    }

    /**
     * Go to specific history index
     * @param {number} delta - Number of steps (negative for back)
     */
    go(delta) {
        window.history.go(delta);
    }

    /**
     * Get current path
     */
    get currentPath() {
        if (this.mode === 'hash') {
            return window.location.hash.slice(1) || '/';
        }
        return window.location.pathname;
    }

    /**
     * Get current query parameters
     */
    get query() {
        const params = new URLSearchParams(window.location.search);
        const result = {};
        for (const [key, value] of params) {
            result[key] = value;
        }
        return result;
    }

    /**
     * Parse a URL into components
     */
    parseUrl(url) {
        const parser = document.createElement('a');
        parser.href = url;

        const queryParams = {};
        const searchParams = new URLSearchParams(parser.search);
        for (const [key, value] of searchParams) {
            queryParams[key] = value;
        }

        return {
            path: parser.pathname,
            query: queryParams,
            hash: parser.hash.slice(1) || null,
            fullPath: parser.pathname + parser.search + parser.hash,
        };
    }

    /**
     * Match a path against defined routes
     */
    matchRoute(path) {
        for (const route of this.routes) {
            const match = path.match(route.pattern.regex);
            if (match) {
                const params = {};
                route.pattern.params.forEach((param, index) => {
                    params[param] = match[index + 1];
                });
                return { route, params };
            }
        }
        return null;
    }

    /**
     * Destroy the router
     */
    destroy() {
        window.removeEventListener('popstate', this._onPopState);
    }

    // ========================================================================
    // Private Methods
    // ========================================================================

    async _navigate(path, type, options = {}) {
        const fullPath = this.basePath + path;
        const parsed = this.parseUrl(fullPath);
        const matched = this.matchRoute(parsed.path);

        if (!matched) {
            if (this.notFoundHandler) {
                this.notFoundHandler(parsed);
            }
            console.warn(`[ZylixRouter] Route not found: ${path}`);
            return false;
        }

        const { route, params } = matched;
        const from = this.currentRoute;
        const to = { ...route, params, query: parsed.query, path: parsed.path };

        // Run guards
        for (const guard of this.guards) {
            try {
                const result = await guard(to, from);
                if (result === false) {
                    console.log('[ZylixRouter] Navigation blocked by guard');
                    return false;
                }
                if (result && typeof result === 'object' && result.redirect) {
                    return this.replace(result.redirect);
                }
            } catch (error) {
                console.error('[ZylixRouter] Guard error:', error);
                return false;
            }
        }

        // Run route-specific guards
        if (route.guards) {
            for (const guard of route.guards) {
                const result = await guard(to, from);
                if (result === false || (result && result.redirect)) {
                    if (result && result.redirect) {
                        return this.replace(result.redirect);
                    }
                    return false;
                }
            }
        }

        // Update browser history
        const state = { path: parsed.path, params, timestamp: Date.now() };

        if (this.mode === 'hash') {
            if (type === 'push') {
                window.location.hash = path;
            } else {
                window.history.replaceState(state, '', '#' + path);
            }
        } else {
            if (type === 'push') {
                window.history.pushState(state, '', fullPath);
            } else {
                window.history.replaceState(state, '', fullPath);
            }
        }

        // Update current route
        this.currentRoute = to;

        // Notify callbacks
        const event = type === 'push' ? 'push' : 'replace';
        this._notifyCallbacks(event, to, params);

        // Execute component handler
        if (route.component) {
            route.component({ route: to, params, query: parsed.query, router: this });
        }

        return true;
    }

    _onPopState(event) {
        const path = this.currentPath;
        const matched = this.matchRoute(path);

        if (matched) {
            const { route, params } = matched;
            const parsed = this.parseUrl(window.location.href);

            this.currentRoute = { ...route, params, query: parsed.query, path };
            this._notifyCallbacks('popstate', this.currentRoute, params);

            if (route.component) {
                route.component({ route: this.currentRoute, params, query: parsed.query, router: this });
            }
        }
    }

    _handleInitialRoute() {
        const path = this.currentPath;
        const matched = this.matchRoute(path);

        if (matched) {
            const { route, params } = matched;
            const parsed = this.parseUrl(window.location.href);

            this.currentRoute = { ...route, params, query: parsed.query, path };
            this._notifyCallbacks('initial', this.currentRoute, params);

            if (route.component) {
                route.component({ route: this.currentRoute, params, query: parsed.query, router: this });
            }
        } else if (this.notFoundHandler) {
            this.notFoundHandler(this.parseUrl(window.location.href));
        }
    }

    _compilePattern(path) {
        const params = [];
        const regexStr = path
            .replace(/\//g, '\\/')
            .replace(/:(\w+)/g, (_, param) => {
                params.push(param);
                return '([^\\/]+)';
            })
            .replace(/\*/g, '.*');

        return {
            regex: new RegExp(`^${regexStr}$`),
            params,
        };
    }

    _notifyCallbacks(event, route, params) {
        for (const callback of this.callbacks) {
            try {
                callback(event, route, params);
            } catch (error) {
                console.error('[ZylixRouter] Callback error:', error);
            }
        }
    }
}

// ============================================================================
// Link Component Helper
// ============================================================================

/**
 * Create a router-aware link
 * @param {string} path - Path to navigate to
 * @param {Object} options - Link options
 */
function createRouterLink(router, path, options = {}) {
    const link = document.createElement('a');
    link.href = router.basePath + path;
    link.textContent = options.text || path;

    if (options.className) {
        link.className = options.className;
    }

    link.addEventListener('click', (e) => {
        e.preventDefault();
        router.push(path);
    });

    return link;
}

// ============================================================================
// Deep Link Handler
// ============================================================================

/**
 * Handle deep links from external sources
 * @param {ZylixRouter} router - Router instance
 */
function setupDeepLinkHandler(router) {
    // Handle clicks on external links that should be routed
    document.addEventListener('click', (e) => {
        const link = e.target.closest('a[data-router-link]');
        if (link) {
            e.preventDefault();
            const path = link.getAttribute('href');
            router.push(path);
        }
    });

    // Handle custom URL scheme (for PWA/mobile web)
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.addEventListener('message', (event) => {
            if (event.data && event.data.type === 'DEEP_LINK') {
                router.push(event.data.path);
            }
        });
    }
}

// ============================================================================
// Export for different module systems
// ============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ZylixRouter, createRouterLink, setupDeepLinkHandler };
} else if (typeof window !== 'undefined') {
    window.ZylixRouter = ZylixRouter;
    window.createRouterLink = createRouterLink;
    window.setupDeepLinkHandler = setupDeepLinkHandler;
}
