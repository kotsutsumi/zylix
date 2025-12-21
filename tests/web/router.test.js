import { test, describe, beforeEach, mock } from 'node:test';
import assert from 'node:assert';

// Mock browser environment
const mockHistory = {
    pushState: mock.fn(),
    replaceState: mock.fn(),
    back: mock.fn(),
    forward: mock.fn(),
    go: mock.fn(),
};

globalThis.window = {
    location: { pathname: '/', search: '', hash: '', href: 'http://localhost/' },
    history: mockHistory,
    addEventListener: mock.fn(),
    removeEventListener: mock.fn(),
};

globalThis.document = {
    createElement: (tag) => ({
        href: '',
        pathname: '',
        search: '',
        hash: '',
        textContent: '',
        className: '',
        getAttribute: mock.fn(),
        setAttribute: mock.fn(),
        addEventListener: mock.fn(),
    }),
    addEventListener: mock.fn(),
};

// Import after mocking
const { ZylixRouter } = await import('../../platforms/web/zylix-router.js');

describe('ZylixRouter', () => {
    let router;

    beforeEach(() => {
        // Reset mocks
        mockHistory.pushState.mock.resetCalls();
        mockHistory.replaceState.mock.resetCalls();
        window.location = { pathname: '/', search: '', hash: '', href: 'http://localhost/' };
    });

    describe('Route Pattern Compilation', () => {
        test('should compile static routes', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([{ path: '/home' }]);

            const match = router.matchRoute('/home');
            assert.ok(match, 'Should match /home');
            assert.deepStrictEqual(match.params, {});
        });

        test('should compile routes with parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([{ path: '/users/:id' }]);

            const match = router.matchRoute('/users/123');
            assert.ok(match, 'Should match /users/123');
            assert.strictEqual(match.params.id, '123');
        });

        test('should compile routes with multiple parameters', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([{ path: '/users/:userId/posts/:postId' }]);

            const match = router.matchRoute('/users/42/posts/99');
            assert.ok(match, 'Should match nested params');
            assert.strictEqual(match.params.userId, '42');
            assert.strictEqual(match.params.postId, '99');
        });

        test('should return null for non-matching routes', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([{ path: '/home' }]);

            const match = router.matchRoute('/about');
            assert.strictEqual(match, null);
        });
    });

    describe('Navigation Guards', () => {
        test('should add global guards', () => {
            router = new ZylixRouter({ autoStart: false });
            const guard = () => true;

            router.addGuard(guard);
            assert.strictEqual(router.guards.length, 1);
        });

        test('should chain addGuard calls', () => {
            router = new ZylixRouter({ autoStart: false });

            const result = router
                .addGuard(() => true)
                .addGuard(() => true);

            assert.strictEqual(result, router);
            assert.strictEqual(router.guards.length, 2);
        });
    });

    describe('Navigation Callbacks', () => {
        test('should add navigation callbacks', () => {
            router = new ZylixRouter({ autoStart: false });
            const callback = () => {};

            router.onNavigate(callback);
            assert.strictEqual(router.callbacks.length, 1);
        });

        test('should chain onNavigate calls', () => {
            router = new ZylixRouter({ autoStart: false });

            const result = router
                .onNavigate(() => {})
                .onNavigate(() => {});

            assert.strictEqual(result, router);
            assert.strictEqual(router.callbacks.length, 2);
        });
    });

    describe('Route Definition', () => {
        test('should chain defineRoutes call', () => {
            router = new ZylixRouter({ autoStart: false });

            const result = router.defineRoutes([{ path: '/' }]);
            assert.strictEqual(result, router);
        });

        test('should compile patterns for all routes', () => {
            router = new ZylixRouter({ autoStart: false });
            router.defineRoutes([
                { path: '/' },
                { path: '/about' },
                { path: '/users/:id' },
            ]);

            assert.strictEqual(router.routes.length, 3);
            assert.ok(router.routes.every(r => r.pattern && r.pattern.regex));
        });
    });

    describe('Configuration', () => {
        test('should accept basePath option', () => {
            router = new ZylixRouter({ autoStart: false, basePath: '/app' });
            assert.strictEqual(router.basePath, '/app');
        });

        test('should default to history mode', () => {
            router = new ZylixRouter({ autoStart: false });
            assert.strictEqual(router.mode, 'history');
        });

        test('should accept hash mode', () => {
            router = new ZylixRouter({ autoStart: false, mode: 'hash' });
            assert.strictEqual(router.mode, 'hash');
        });

        test('should accept notFound handler', () => {
            const notFound = () => {};
            router = new ZylixRouter({ autoStart: false, notFound });
            assert.strictEqual(router.notFoundHandler, notFound);
        });
    });

    describe('Cleanup', () => {
        test('should remove event listener on destroy', () => {
            router = new ZylixRouter({ autoStart: false });
            router.destroy();

            assert.ok(window.removeEventListener.mock.calls.length > 0);
        });
    });
});

describe('Route Matching Edge Cases', () => {
    let router;

    beforeEach(() => {
        router = new ZylixRouter({ autoStart: false });
    });

    test('should handle root path', () => {
        router.defineRoutes([{ path: '/' }]);
        const match = router.matchRoute('/');
        assert.ok(match);
    });

    test('should handle trailing slashes consistently', () => {
        router.defineRoutes([{ path: '/home' }]);

        // Exact match
        const match1 = router.matchRoute('/home');
        assert.ok(match1);

        // With trailing slash should not match (strict)
        const match2 = router.matchRoute('/home/');
        assert.strictEqual(match2, null);
    });

    test('should match first defined route when multiple match', () => {
        router.defineRoutes([
            { path: '/users/:id', name: 'user' },
            { path: '/users/new', name: 'newUser' },
        ]);

        const match = router.matchRoute('/users/new');
        // First matching route wins
        assert.ok(match);
        assert.strictEqual(match.params.id, 'new');
    });

    test('should handle special characters in params', () => {
        router.defineRoutes([{ path: '/files/:filename' }]);

        const match = router.matchRoute('/files/my-file_v2.0');
        assert.ok(match);
        assert.strictEqual(match.params.filename, 'my-file_v2.0');
    });
});
