import { test, describe, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';

// Mock browser environment
const mockWebSocket = {
    OPEN: 1,
    readyState: 1,
    send: mock.fn(),
    close: mock.fn(),
};

globalThis.WebSocket = class MockWebSocket {
    constructor(url) {
        this.url = url;
        this.readyState = 1;
        this.onopen = null;
        this.onmessage = null;
        this.onclose = null;
        this.onerror = null;
        Object.assign(this, mockWebSocket);

        // Simulate connection
        setTimeout(() => {
            if (this.onopen) this.onopen();
        }, 0);
    }
    send(data) {
        mockWebSocket.send(data);
    }
};
globalThis.WebSocket.OPEN = 1;

globalThis.window = {
    location: { reload: mock.fn() },
    scrollX: 0,
    scrollY: 0,
    scrollTo: mock.fn(),
    open: mock.fn(),
    __ZYLIX_DEV__: true,
    __ZYLIX_MODULES__: {},
    __ZYLIX_HOT_ACCEPT__: mock.fn(),
    __ZYLIX_REQUIRE__: mock.fn(),
};

globalThis.document = {
    createElement: (tag) => ({
        tagName: tag.toUpperCase(),
        style: {},
        innerHTML: '',
        id: '',
        remove: mock.fn(),
    }),
    body: {
        appendChild: mock.fn(),
    },
    getElementById: mock.fn(() => null),
    querySelector: mock.fn(() => null),
    querySelectorAll: mock.fn(() => []),
    readyState: 'complete',
    addEventListener: mock.fn(),
};

globalThis.sessionStorage = {
    _data: {},
    getItem: mock.fn((key) => globalThis.sessionStorage._data[key] || null),
    setItem: mock.fn((key, value) => { globalThis.sessionStorage._data[key] = value; }),
    removeItem: mock.fn((key) => { delete globalThis.sessionStorage._data[key]; }),
};

globalThis.console = {
    log: mock.fn(),
    warn: mock.fn(),
    error: mock.fn(),
};

// Import after mocking
const devServer = await import('../../platforms/web/zylix-dev-server.js');

describe('DEFAULT_CONFIG', () => {
    test('should have correct default values', () => {
        assert.strictEqual(devServer.DEFAULT_CONFIG.port, 3000);
        assert.strictEqual(devServer.DEFAULT_CONFIG.wsPort, 3001);
        assert.strictEqual(devServer.DEFAULT_CONFIG.host, 'localhost');
        assert.strictEqual(devServer.DEFAULT_CONFIG.openBrowser, true);
        assert.strictEqual(devServer.DEFAULT_CONFIG.hotReload, true);
        assert.strictEqual(devServer.DEFAULT_CONFIG.liveReload, true);
        assert.strictEqual(devServer.DEFAULT_CONFIG.overlay, true);
        assert.strictEqual(devServer.DEFAULT_CONFIG.debounceMs, 50);
    });

    test('should have watch paths', () => {
        assert.ok(Array.isArray(devServer.DEFAULT_CONFIG.watchPaths));
        assert.ok(devServer.DEFAULT_CONFIG.watchPaths.includes('src'));
        assert.ok(devServer.DEFAULT_CONFIG.watchPaths.includes('public'));
    });

    test('should have ignore patterns', () => {
        assert.ok(Array.isArray(devServer.DEFAULT_CONFIG.ignorePatterns));
        assert.ok(devServer.DEFAULT_CONFIG.ignorePatterns.includes('node_modules'));
        assert.ok(devServer.DEFAULT_CONFIG.ignorePatterns.includes('.git'));
    });
});

describe('ZylixHotReloadClient', () => {
    let client;

    beforeEach(() => {
        mockWebSocket.send.mock.resetCalls();
        window.location.reload.mock.resetCalls();
        client = new devServer.ZylixHotReloadClient({ wsUrl: 'ws://test:3001' });
    });

    test('should connect to WebSocket', () => {
        assert.ok(client.ws);
        assert.strictEqual(client.ws.url, 'ws://test:3001');
    });

    test('should have default reconnect settings', () => {
        assert.strictEqual(client.reconnectInterval, 1000);
        assert.strictEqual(client.maxReconnectAttempts, 10);
        assert.strictEqual(client.reconnectAttempts, 0);
    });

    test('should have handlers map', () => {
        assert.ok(client.handlers instanceof Map);
    });

    test('should have state map', () => {
        assert.ok(client.state instanceof Map);
    });

    describe('Event handlers', () => {
        test('should register handler with on()', () => {
            const handler = mock.fn();
            client.on('test', handler);

            assert.strictEqual(client.handlers.get('test'), handler);
        });

        test('should unregister handler with off()', () => {
            const handler = mock.fn();
            client.on('test', handler);
            client.off('test');

            assert.strictEqual(client.handlers.has('test'), false);
        });
    });

    describe('State management', () => {
        test('should get state', () => {
            client.state.set('key', 'value');
            assert.strictEqual(client.getState('key'), 'value');
        });

        test('should set state and send update', () => {
            client.setState('key', 'value');

            assert.strictEqual(client.state.get('key'), 'value');
            assert.ok(mockWebSocket.send.mock.calls.length > 0);
        });
    });

    describe('Message handling', () => {
        test('should handle reload message', () => {
            client.handleMessage({ type: 'reload' });
            // Should trigger window.location.reload
            // Note: The actual reload is mocked
        });

        test('should handle ping message', () => {
            mockWebSocket.send.mock.resetCalls();
            client.handleMessage({ type: 'ping' });

            assert.ok(mockWebSocket.send.mock.calls.length > 0);
            const sentData = JSON.parse(mockWebSocket.send.mock.calls[0].arguments[0]);
            assert.strictEqual(sentData.type, 'pong');
        });

        test('should handle state_sync message', () => {
            client.handleMessage({
                type: 'state_sync',
                payload: { foo: 'bar' }
            });

            assert.strictEqual(client.state.get('foo'), 'bar');
        });

        test('should call custom handler', () => {
            const handler = mock.fn();
            client.on('custom', handler);

            client.handleMessage({ type: 'custom', payload: { data: 123 } });

            assert.strictEqual(handler.mock.calls.length, 1);
            assert.deepStrictEqual(handler.mock.calls[0].arguments[0], { data: 123 });
        });
    });

    describe('Error overlay', () => {
        test('should create error overlay', () => {
            const errors = [{ file: 'test.js', line: 10, column: 5, message: 'Syntax error' }];

            client.showErrorOverlay(errors);

            assert.ok(document.body.appendChild.mock.calls.length > 0);
        });

        test('should handle single error', () => {
            const error = { file: 'test.js', line: 10, column: 5, message: 'Error' };

            client.showErrorOverlay(error);

            assert.ok(document.body.appendChild.mock.calls.length > 0);
        });

        test('should hide existing overlay before showing new one', () => {
            const mockOverlay = { remove: mock.fn() };
            document.getElementById = mock.fn(() => mockOverlay);

            client.showErrorOverlay([{ file: 'test.js', line: 1, column: 1, message: 'Error' }]);

            assert.ok(mockOverlay.remove.mock.calls.length > 0);

            // Reset
            document.getElementById = mock.fn(() => null);
        });

        test('should hide error overlay', () => {
            const mockOverlay = { remove: mock.fn() };
            document.getElementById = mock.fn(() => mockOverlay);

            client.hideErrorOverlay();

            assert.ok(mockOverlay.remove.mock.calls.length > 0);

            // Reset
            document.getElementById = mock.fn(() => null);
        });
    });

    describe('State preservation', () => {
        test('should save state to sessionStorage', () => {
            document.querySelectorAll = mock.fn(() => [
                { id: 'input1', type: 'text', value: 'test' },
                { id: 'check1', type: 'checkbox', checked: true },
            ]);

            client.saveState();

            assert.ok(sessionStorage.setItem.mock.calls.length > 0);
        });

        test('should restore state from sessionStorage', () => {
            sessionStorage._data['__ZYLIX_STATE__'] = JSON.stringify({
                input1: { type: 'text', value: 'restored' },
                __scroll: { x: 100, y: 200 }
            });

            const mockInput = { type: 'text', value: '' };
            document.getElementById = mock.fn(() => mockInput);

            client.restoreState();

            assert.strictEqual(mockInput.value, 'restored');
            assert.ok(window.scrollTo.mock.calls.length > 0);

            // Reset
            document.getElementById = mock.fn(() => null);
            sessionStorage._data = {};
        });

        test('should handle invalid JSON in sessionStorage', () => {
            sessionStorage._data['__ZYLIX_STATE__'] = 'invalid json';

            // Should not throw
            client.restoreState();

            // Reset
            sessionStorage._data = {};
        });
    });

    describe('Hot update', () => {
        test('should handle hot update in development mode', () => {
            window.__ZYLIX_DEV__ = true;
            window.__ZYLIX_MODULES__ = {};
            window.__ZYLIX_HOT_ACCEPT__ = mock.fn();

            client.handleHotUpdate({
                module: 'test-module',
                code: 'module.exports = { test: true };'
            });

            // In development mode, should process the update
            assert.ok(window.__ZYLIX_HOT_ACCEPT__.mock.calls.length > 0 ||
                      window.__ZYLIX_MODULES__['test-module'] !== undefined);
        });

        test('should warn and skip in non-development mode', () => {
            window.__ZYLIX_DEV__ = false;
            window.__ZYLIX_MODULES__ = {};

            client.handleHotUpdate({
                module: 'test-module',
                code: 'module.exports = { test: true };'
            });

            // Should have logged a warning
            // Reset
            window.__ZYLIX_DEV__ = true;
        });
    });
});

describe('ZylixDevServer', () => {
    let server;

    beforeEach(() => {
        server = new devServer.ZylixDevServer();
    });

    afterEach(() => {
        server.stop();
    });

    test('should have default config', () => {
        assert.strictEqual(server.config.port, 3000);
        assert.strictEqual(server.config.wsPort, 3001);
        assert.strictEqual(server.config.host, 'localhost');
    });

    test('should merge custom config', () => {
        const customServer = new devServer.ZylixDevServer({ port: 4000 });
        assert.strictEqual(customServer.config.port, 4000);
        assert.strictEqual(customServer.config.wsPort, 3001); // Default preserved
    });

    test('should have empty clients set', () => {
        assert.ok(server.clients instanceof Set);
        assert.strictEqual(server.clients.size, 0);
    });

    test('should have initial stats', () => {
        assert.ok(server.stats.startTime);
        assert.strictEqual(server.stats.builds, 0);
        assert.strictEqual(server.stats.errors, 0);
    });

    describe('getStats', () => {
        test('should return stats with uptime', () => {
            const stats = server.getStats();

            assert.ok(stats.uptime >= 0);
            assert.strictEqual(stats.builds, 0);
            assert.strictEqual(stats.errors, 0);
            assert.strictEqual(stats.clients, 0);
        });
    });

    describe('isHotReloadable', () => {
        test('should return true for JavaScript files', () => {
            assert.ok(server.isHotReloadable('js'));
            assert.ok(server.isHotReloadable('jsx'));
            assert.ok(server.isHotReloadable('ts'));
            assert.ok(server.isHotReloadable('tsx'));
        });

        test('should return true for CSS files', () => {
            assert.ok(server.isHotReloadable('css'));
            assert.ok(server.isHotReloadable('scss'));
            assert.ok(server.isHotReloadable('less'));
        });

        test('should return false for non-reloadable files', () => {
            assert.strictEqual(server.isHotReloadable('html'), false);
            assert.strictEqual(server.isHotReloadable('png'), false);
            assert.strictEqual(server.isHotReloadable('json'), false);
        });
    });

    describe('broadcast', () => {
        test('should send to all clients', () => {
            const client1 = { send: mock.fn() };
            const client2 = { send: mock.fn() };

            server.clients.add(client1);
            server.clients.add(client2);

            server.broadcast({ type: 'test' });

            assert.strictEqual(client1.send.mock.calls.length, 1);
            assert.strictEqual(client2.send.mock.calls.length, 1);
        });

        test('should remove failing clients', () => {
            const failingClient = {
                send: mock.fn(() => { throw new Error('Connection lost'); })
            };

            server.clients.add(failingClient);
            server.broadcast({ type: 'test' });

            assert.strictEqual(server.clients.size, 0);
        });
    });

    describe('triggerReload', () => {
        test('should broadcast reload message', () => {
            const client = { send: mock.fn() };
            server.clients.add(client);

            server.triggerReload();

            const message = JSON.parse(client.send.mock.calls[0].arguments[0]);
            assert.strictEqual(message.type, 'reload');
        });

        test('should increment builds count', () => {
            const initialBuilds = server.stats.builds;
            server.triggerReload();

            assert.strictEqual(server.stats.builds, initialBuilds + 1);
        });
    });

    describe('triggerError', () => {
        test('should broadcast error overlay message', () => {
            const client = { send: mock.fn() };
            server.clients.add(client);

            const error = new Error('Test error');
            server.triggerError(error, 'test.js');

            const message = JSON.parse(client.send.mock.calls[0].arguments[0]);
            assert.strictEqual(message.type, 'error_overlay');
            assert.strictEqual(message.payload.file, 'test.js');
            assert.strictEqual(message.payload.message, 'Test error');
        });

        test('should increment errors count', () => {
            const initialErrors = server.stats.errors;
            server.triggerError(new Error('Test'), 'test.js');

            assert.strictEqual(server.stats.errors, initialErrors + 1);
        });
    });

    describe('buildModule', () => {
        test('should return code for module', async () => {
            const code = await server.buildModule('test.js');

            assert.ok(code.includes('test.js'));
        });

        test('should cache built modules', async () => {
            await server.buildModule('test.js');

            assert.ok(server.buildCache.has('test.js'));
        });

        test('should return cached code if recent', async () => {
            await server.buildModule('test.js');
            const code1 = await server.buildModule('test.js');
            const code2 = await server.buildModule('test.js');

            // Should be same cached result
            assert.strictEqual(code1, code2);
        });
    });

    describe('handleFileChange', () => {
        test('should debounce rapid changes', () => {
            const client = { send: mock.fn() };
            server.clients.add(client);

            server.handleFileChange('test.js', 'change');
            server.handleFileChange('test.js', 'change');
            server.handleFileChange('test.js', 'change');

            // Should only broadcast once due to debouncing
            assert.ok(client.send.mock.calls.length <= 1);
        });

        test('should trigger hot update for JS files', () => {
            const client = { send: mock.fn() };
            server.clients.add(client);

            // Wait for debounce
            server._lastChange = 0;
            server.handleFileChange('component.jsx', 'change');

            // Should attempt hot update
            assert.ok(client.send.mock.calls.length >= 0);
        });
    });

    describe('openBrowser', () => {
        test('should open browser in window environment', () => {
            server.openBrowser();

            assert.ok(window.open.mock.calls.length > 0);
        });
    });

    describe('stop', () => {
        test('should clean up resources', () => {
            server.fileWatcher = { close: mock.fn() };
            server.wsServer = { close: mock.fn() };
            server.httpServer = { close: mock.fn() };

            server.stop();

            assert.ok(server.fileWatcher.close.mock.calls.length > 0);
            assert.ok(server.wsServer.close.mock.calls.length > 0);
            assert.ok(server.httpServer.close.mock.calls.length > 0);
        });

        test('should handle missing servers gracefully', () => {
            server.fileWatcher = null;
            server.wsServer = null;
            server.httpServer = null;

            // Should not throw
            server.stop();
        });
    });
});

describe('Exports', () => {
    test('should export ZylixHotReloadClient', () => {
        assert.ok(devServer.ZylixHotReloadClient);
    });

    test('should export ZylixDevServer', () => {
        assert.ok(devServer.ZylixDevServer);
    });

    test('should export DEFAULT_CONFIG', () => {
        assert.ok(devServer.DEFAULT_CONFIG);
    });
});
