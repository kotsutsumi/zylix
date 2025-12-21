import { test, describe, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';

// Mock browser environment
const mockHistory = {
    _state: null,
    _stack: [{ path: '/', state: null }],
    _index: 0,
    pushState: mock.fn((state, title, url) => {
        mockHistory._index++;
        mockHistory._stack.push({ path: url, state });
        mockHistory._state = state;
    }),
    replaceState: mock.fn((state, title, url) => {
        mockHistory._stack[mockHistory._index] = { path: url, state };
        mockHistory._state = state;
    }),
    back: mock.fn(() => {
        if (mockHistory._index > 0) {
            mockHistory._index--;
            mockHistory._state = mockHistory._stack[mockHistory._index].state;
        }
    }),
    forward: mock.fn(() => {
        if (mockHistory._index < mockHistory._stack.length - 1) {
            mockHistory._index++;
            mockHistory._state = mockHistory._stack[mockHistory._index].state;
        }
    }),
    go: mock.fn((delta) => {
        const newIndex = mockHistory._index + delta;
        if (newIndex >= 0 && newIndex < mockHistory._stack.length) {
            mockHistory._index = newIndex;
            mockHistory._state = mockHistory._stack[mockHistory._index].state;
        }
    }),
    get state() {
        return mockHistory._state;
    },
    _reset() {
        mockHistory._state = null;
        mockHistory._stack = [{ path: '/', state: null }];
        mockHistory._index = 0;
        mockHistory.pushState.mock.resetCalls();
        mockHistory.replaceState.mock.resetCalls();
        mockHistory.back.mock.resetCalls();
        mockHistory.forward.mock.resetCalls();
        mockHistory.go.mock.resetCalls();
    }
};

let popstateListeners = [];

globalThis.window = {
    history: mockHistory,
    location: {
        pathname: '/',
        search: '',
        hash: '',
        href: 'http://localhost/',
    },
    addEventListener: mock.fn((event, handler) => {
        if (event === 'popstate') {
            popstateListeners.push(handler);
        }
    }),
    removeEventListener: mock.fn((event, handler) => {
        if (event === 'popstate') {
            popstateListeners = popstateListeners.filter(h => h !== handler);
        }
    }),
};

globalThis.document = {
    createElement: (tag) => ({
        tagName: tag.toUpperCase(),
        href: '',
        pathname: '/',
        search: '',
        hash: '',
        textContent: '',
        className: '',
        getAttribute: mock.fn(() => null),
        setAttribute: mock.fn(),
        addEventListener: mock.fn(),
    }),
    addEventListener: mock.fn(),
};

// Mock navigator using Object.defineProperty since it's read-only in Node.js
const mockNavigator = {
    serviceWorker: {
        addEventListener: mock.fn(),
    },
};
Object.defineProperty(globalThis, 'navigator', {
    value: mockNavigator,
    writable: true,
    configurable: true,
});

globalThis.console = {
    log: mock.fn(),
    warn: mock.fn(),
    error: mock.fn(),
};

globalThis.URLSearchParams = class URLSearchParams {
    constructor(search = '') {
        this._params = new Map();
        if (search.startsWith('?')) {
            search = search.slice(1);
        }
        if (search) {
            search.split('&').forEach(pair => {
                const [key, value] = pair.split('=');
                this._params.set(decodeURIComponent(key), decodeURIComponent(value || ''));
            });
        }
    }
    get(key) {
        return this._params.get(key) || null;
    }
    *[Symbol.iterator]() {
        yield* this._params.entries();
    }
};

// Import after mocking
const routerModule = await import('../../platforms/web/zylix-router.js');
const { ZylixRouter, createRouterLink, setupDeepLinkHandler } = routerModule;

describe('ZylixRouter', () => {
    let router;

    beforeEach(() => {
        mockHistory._reset();
        popstateListeners = [];
        window.location.pathname = '/';
        window.location.search = '';
        window.location.hash = '';
        window.location.href = 'http://localhost/';
        window.addEventListener.mock.resetCalls();
        window.removeEventListener.mock.resetCalls();
        console.log.mock.resetCalls();
        console.warn.mock.resetCalls();
        console.error.mock.resetCalls();
    });

    afterEach(() => {
        if (router) {
            router.destroy();
            router = null;
        }
    });

    describe('Constructor', () => {
        test('should create with default options', () => {
            router = new ZylixRouter({ autoStart: false });

            assert.deepStrictEqual(router.routes, []);
            assert.strictEqual(router.currentRoute, null);
            assert.strictEqual(router.basePath, '');
            assert.strictEqual(router.mode, 'history');
        });

        test('should create with custom basePath', () => {
            router = new ZylixRouter({ basePath: '/app', autoStart: false });

            assert.strictEqual(router.basePath, '/app');
        });

        test('should create with hash mode', () => {
            router = new ZylixRouter({ mode: 'hash', autoStart: false });

            assert.strictEqual(router.mode, 'hash');
        });

        test('should register popstate listener', () => {
            router = new ZylixRouter({ autoStart: false });

            assert.ok(window.addEventListener.mock.calls.length > 0);
            const popstateCall = window.addEventListener.mock.calls.find(
                call => call.arguments[0] === 'popstate'
            );
            assert.ok(popstateCall);
        });

        test('should store notFound handler', () => {
            const notFoundHandler = mock.fn();
            router = new ZylixRouter({ notFound: notFoundHandler, autoStart: false });

            assert.strictEqual(router.notFoundHandler, notFoundHandler);
        });
    });

    describe('defineRoutes', () => {
        test('should define routes with compiled patterns', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/', name: 'home' },
                { path: '/about', name: 'about' },
            ]);

            assert.strictEqual(router.routes.length, 2);
            assert.ok(router.routes[0].pattern);
            assert.ok(router.routes[0].pattern.regex);
        });

        test('should return router for chaining', () => {
            router = new ZylixRouter({ autoStart: false });
            const result = router.defineRoutes([{ path: '/' }]);

            assert.strictEqual(result, router);
        });

        test('should handle routes with parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/user/:id', name: 'user' },
                { path: '/post/:id/comment/:commentId', name: 'comment' },
            ]);

            assert.deepStrictEqual(router.routes[0].pattern.params, ['id']);
            assert.deepStrictEqual(router.routes[1].pattern.params, ['id', 'commentId']);
        });
    });

    describe('addGuard', () => {
        test('should add a guard', () => {
            router = new ZylixRouter({ autoStart: false });
            const guard = mock.fn();
            router.addGuard(guard);

            assert.strictEqual(router.guards.length, 1);
            assert.strictEqual(router.guards[0], guard);
        });

        test('should return router for chaining', () => {
            router = new ZylixRouter({ autoStart: false });
            const result = router.addGuard(() => true);

            assert.strictEqual(result, router);
        });

        test('should support multiple guards', () => {
            router = new ZylixRouter({ autoStart: false });
            router.addGuard(() => true);
            router.addGuard(() => true);
            router.addGuard(() => true);

            assert.strictEqual(router.guards.length, 3);
        });
    });

    describe('onNavigate', () => {
        test('should add a callback', () => {
            router = new ZylixRouter({ autoStart: false });
            const callback = mock.fn();
            router.onNavigate(callback);

            assert.strictEqual(router.callbacks.length, 1);
            assert.strictEqual(router.callbacks[0], callback);
        });

        test('should return router for chaining', () => {
            router = new ZylixRouter({ autoStart: false });
            const result = router.onNavigate(() => {});

            assert.strictEqual(result, router);
        });
    });

    describe('matchRoute', () => {
        test('should match exact path', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/', name: 'home' },
                { path: '/about', name: 'about' },
            ]);

            const match = router.matchRoute('/about');
            assert.ok(match);
            assert.strictEqual(match.route.name, 'about');
        });

        test('should extract parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/user/:id', name: 'user' },
            ]);

            const match = router.matchRoute('/user/123');
            assert.ok(match);
            assert.strictEqual(match.params.id, '123');
        });

        test('should extract multiple parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/post/:postId/comment/:commentId', name: 'comment' },
            ]);

            const match = router.matchRoute('/post/42/comment/7');
            assert.ok(match);
            assert.strictEqual(match.params.postId, '42');
            assert.strictEqual(match.params.commentId, '7');
        });

        test('should return null for unmatched path', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/', name: 'home' },
            ]);

            const match = router.matchRoute('/nonexistent');
            assert.strictEqual(match, null);
        });
    });

    describe('parseUrl', () => {
        test('should parse simple path', () => {
            router = new ZylixRouter({ autoStart: false });

            document.createElement = (tag) => {
                const elem = {
                    tagName: tag.toUpperCase(),
                    href: '',
                    pathname: '/about',
                    search: '',
                    hash: '',
                };
                return elem;
            };

            const parsed = router.parseUrl('/about');
            assert.strictEqual(parsed.path, '/about');
        });

        test('should parse query parameters', () => {
            router = new ZylixRouter({ autoStart: false });

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/search',
                search: '?q=test&page=1',
                hash: '',
            });

            const parsed = router.parseUrl('/search?q=test&page=1');
            assert.strictEqual(parsed.query.q, 'test');
            assert.strictEqual(parsed.query.page, '1');
        });

        test('should parse hash', () => {
            router = new ZylixRouter({ autoStart: false });

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/page',
                search: '',
                hash: '#section',
            });

            const parsed = router.parseUrl('/page#section');
            assert.strictEqual(parsed.hash, 'section');
        });
    });

    describe('currentPath', () => {
        test('should return pathname in history mode', () => {
            router = new ZylixRouter({ mode: 'history', autoStart: false });
            window.location.pathname = '/test';

            assert.strictEqual(router.currentPath, '/test');
        });

        test('should return hash in hash mode', () => {
            router = new ZylixRouter({ mode: 'hash', autoStart: false });
            window.location.hash = '#/test';

            assert.strictEqual(router.currentPath, '/test');
        });

        test('should return / for empty hash', () => {
            router = new ZylixRouter({ mode: 'hash', autoStart: false });
            window.location.hash = '';

            assert.strictEqual(router.currentPath, '/');
        });
    });

    describe('query', () => {
        test('should return query parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            window.location.search = '?foo=bar&baz=qux';

            const query = router.query;
            assert.strictEqual(query.foo, 'bar');
            assert.strictEqual(query.baz, 'qux');
        });

        test('should return empty object for no query', () => {
            router = new ZylixRouter({ autoStart: false });
            window.location.search = '';

            const query = router.query;
            assert.deepStrictEqual(query, {});
        });
    });

    describe('push', () => {
        test('should navigate to matched route', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            const result = await router.push('/about');

            assert.strictEqual(result, true);
            assert.ok(router.currentRoute);
            assert.strictEqual(router.currentRoute.name, 'about');
        });

        test('should call pushState', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.push('/about');

            assert.ok(mockHistory.pushState.mock.calls.length > 0);
        });

        test('should return false for unmatched route', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/', name: 'home' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/nonexistent',
                search: '',
                hash: '',
            });

            const result = await router.push('/nonexistent');

            assert.strictEqual(result, false);
            assert.ok(console.warn.mock.calls.length > 0);
        });

        test('should call notFoundHandler for unmatched route', async () => {
            const notFoundHandler = mock.fn();
            router = new ZylixRouter({ notFound: notFoundHandler, autoStart: false });
            router.defineRoutes([
                { path: '/', name: 'home' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/nonexistent',
                search: '',
                hash: '',
            });

            await router.push('/nonexistent');

            assert.ok(notFoundHandler.mock.calls.length > 0);
        });

        test('should notify callbacks', async () => {
            const callback = mock.fn();
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);
            router.onNavigate(callback);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.push('/about');

            assert.ok(callback.mock.calls.length > 0);
            assert.strictEqual(callback.mock.calls[0].arguments[0], 'push');
        });

        test('should execute component handler', async () => {
            const component = mock.fn();
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about', component },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.push('/about');

            assert.ok(component.mock.calls.length > 0);
        });
    });

    describe('replace', () => {
        test('should call replaceState', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.replace('/about');

            assert.ok(mockHistory.replaceState.mock.calls.length > 0);
        });

        test('should notify callbacks with replace event', async () => {
            const callback = mock.fn();
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);
            router.onNavigate(callback);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.replace('/about');

            assert.strictEqual(callback.mock.calls[0].arguments[0], 'replace');
        });
    });

    describe('Navigation guards', () => {
        test('should block navigation when guard returns false', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/protected', name: 'protected' },
            ]);
            router.addGuard(() => false);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/protected',
                search: '',
                hash: '',
            });

            const result = await router.push('/protected');

            assert.strictEqual(result, false);
            assert.strictEqual(router.currentRoute, null);
        });

        test('should allow navigation when guard returns true', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/allowed', name: 'allowed' },
            ]);
            router.addGuard(() => true);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/allowed',
                search: '',
                hash: '',
            });

            const result = await router.push('/allowed');

            assert.strictEqual(result, true);
        });

        test('should support async guards', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/async', name: 'async' },
            ]);
            router.addGuard(async () => {
                await new Promise(resolve => setTimeout(resolve, 10));
                return true;
            });

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/async',
                search: '',
                hash: '',
            });

            const result = await router.push('/async');

            assert.strictEqual(result, true);
        });

        test('should handle guard errors', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/error', name: 'error' },
            ]);
            router.addGuard(() => {
                throw new Error('Guard error');
            });

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/error',
                search: '',
                hash: '',
            });

            const result = await router.push('/error');

            assert.strictEqual(result, false);
            assert.ok(console.error.mock.calls.length > 0);
        });

        test('should handle redirect from guard', async () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/login', name: 'login' },
                { path: '/protected', name: 'protected' },
            ]);
            router.addGuard((to) => {
                if (to.path === '/protected') {
                    return { redirect: '/login' };
                }
                return true;
            });

            let callCount = 0;
            document.createElement = (tag) => {
                callCount++;
                const pathname = callCount === 1 ? '/protected' : '/login';
                return {
                    tagName: tag.toUpperCase(),
                    href: '',
                    pathname,
                    search: '',
                    hash: '',
                };
            };

            await router.push('/protected');

            assert.ok(router.currentRoute);
            assert.strictEqual(router.currentRoute.name, 'login');
        });

        test('should run route-specific guards', async () => {
            const routeGuard = mock.fn(() => true);
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/guarded', name: 'guarded', guards: [routeGuard] },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/guarded',
                search: '',
                hash: '',
            });

            await router.push('/guarded');

            assert.ok(routeGuard.mock.calls.length > 0);
        });
    });

    describe('back, forward, go', () => {
        test('should call history.back', () => {
            router = new ZylixRouter({ autoStart: false });
            router.back();

            assert.ok(mockHistory.back.mock.calls.length > 0);
        });

        test('should call history.forward', () => {
            router = new ZylixRouter({ autoStart: false });
            router.forward();

            assert.ok(mockHistory.forward.mock.calls.length > 0);
        });

        test('should call history.go with delta', () => {
            router = new ZylixRouter({ autoStart: false });
            router.go(-2);

            assert.ok(mockHistory.go.mock.calls.length > 0);
            assert.strictEqual(mockHistory.go.mock.calls[0].arguments[0], -2);
        });
    });

    describe('destroy', () => {
        test('should remove popstate listener', () => {
            router = new ZylixRouter({ autoStart: false });
            router.destroy();

            assert.ok(window.removeEventListener.mock.calls.length > 0);
            const popstateCall = window.removeEventListener.mock.calls.find(
                call => call.arguments[0] === 'popstate'
            );
            assert.ok(popstateCall);
        });
    });

    describe('Hash mode', () => {
        test('should use hash for navigation', async () => {
            router = new ZylixRouter({ mode: 'hash', autoStart: false });
            router.defineRoutes([
                { path: '/about', name: 'about' },
            ]);

            document.createElement = (tag) => ({
                tagName: tag.toUpperCase(),
                href: '',
                pathname: '/about',
                search: '',
                hash: '',
            });

            await router.push('/about');

            assert.ok(router.currentRoute);
        });
    });
});

describe('createRouterLink', () => {
    let router;

    beforeEach(() => {
        mockHistory._reset();
        router = new ZylixRouter({ autoStart: false });
        router.defineRoutes([
            { path: '/about', name: 'about' },
        ]);
    });

    afterEach(() => {
        if (router) {
            router.destroy();
            router = null;
        }
    });

    test('should create an anchor element', () => {
        let createdElement = null;
        document.createElement = (tag) => {
            createdElement = {
                tagName: tag.toUpperCase(),
                href: '',
                textContent: '',
                className: '',
                addEventListener: mock.fn(),
            };
            return createdElement;
        };

        const link = createRouterLink(router, '/about');

        assert.ok(createdElement);
        assert.strictEqual(createdElement.tagName, 'A');
    });

    test('should set href with basePath', () => {
        let createdElement = null;
        document.createElement = (tag) => {
            createdElement = {
                tagName: tag.toUpperCase(),
                href: '',
                textContent: '',
                className: '',
                addEventListener: mock.fn(),
            };
            return createdElement;
        };

        const routerWithBase = new ZylixRouter({ basePath: '/app', autoStart: false });
        const link = createRouterLink(routerWithBase, '/about');

        assert.strictEqual(createdElement.href, '/app/about');
        routerWithBase.destroy();
    });

    test('should set text content', () => {
        let createdElement = null;
        document.createElement = (tag) => {
            createdElement = {
                tagName: tag.toUpperCase(),
                href: '',
                textContent: '',
                className: '',
                addEventListener: mock.fn(),
            };
            return createdElement;
        };

        const link = createRouterLink(router, '/about', { text: 'About Us' });

        assert.strictEqual(createdElement.textContent, 'About Us');
    });

    test('should set className', () => {
        let createdElement = null;
        document.createElement = (tag) => {
            createdElement = {
                tagName: tag.toUpperCase(),
                href: '',
                textContent: '',
                className: '',
                addEventListener: mock.fn(),
            };
            return createdElement;
        };

        const link = createRouterLink(router, '/about', { className: 'nav-link' });

        assert.strictEqual(createdElement.className, 'nav-link');
    });

    test('should add click event listener', () => {
        let createdElement = null;
        document.createElement = (tag) => {
            createdElement = {
                tagName: tag.toUpperCase(),
                href: '',
                textContent: '',
                className: '',
                addEventListener: mock.fn(),
            };
            return createdElement;
        };

        const link = createRouterLink(router, '/about');

        assert.ok(createdElement.addEventListener.mock.calls.length > 0);
        assert.strictEqual(createdElement.addEventListener.mock.calls[0].arguments[0], 'click');
    });
});

describe('setupDeepLinkHandler', () => {
    let router;

    beforeEach(() => {
        mockHistory._reset();
        document.addEventListener.mock.resetCalls();
        navigator.serviceWorker.addEventListener.mock.resetCalls();
        router = new ZylixRouter({ autoStart: false });
    });

    afterEach(() => {
        if (router) {
            router.destroy();
            router = null;
        }
    });

    test('should add click listener to document', () => {
        setupDeepLinkHandler(router);

        assert.ok(document.addEventListener.mock.calls.length > 0);
        const clickCall = document.addEventListener.mock.calls.find(
            call => call.arguments[0] === 'click'
        );
        assert.ok(clickCall);
    });

    test('should add message listener to service worker', () => {
        setupDeepLinkHandler(router);

        assert.ok(navigator.serviceWorker.addEventListener.mock.calls.length > 0);
        const messageCall = navigator.serviceWorker.addEventListener.mock.calls.find(
            call => call.arguments[0] === 'message'
        );
        assert.ok(messageCall);
    });
});

describe('Exports', () => {
    test('should export ZylixRouter', () => {
        assert.ok(ZylixRouter);
        assert.strictEqual(typeof ZylixRouter, 'function');
    });

    test('should export createRouterLink', () => {
        assert.ok(createRouterLink);
        assert.strictEqual(typeof createRouterLink, 'function');
    });

    test('should export setupDeepLinkHandler', () => {
        assert.ok(setupDeepLinkHandler);
        assert.strictEqual(typeof setupDeepLinkHandler, 'function');
    });
});
