// zylix-dev-server.js - Web Development Server for Zylix v0.5.0
//
// Provides hot reload and development server functionality for web platform.
// Features:
// - WebSocket-based hot reload
// - File watching with debouncing
// - State preservation
// - Error overlay

// ============================================================================
// Configuration
// ============================================================================

const DEFAULT_CONFIG = {
    port: 3000,
    wsPort: 3001,
    host: 'localhost',
    openBrowser: true,
    hotReload: true,
    liveReload: true,
    overlay: true,
    debounceMs: 50,
    watchPaths: ['src', 'public'],
    ignorePatterns: ['node_modules', '.git', '*.log']
};

// ============================================================================
// WebSocket Client (Browser Side)
// ============================================================================

class ZylixHotReloadClient {
    constructor(options = {}) {
        this.wsUrl = options.wsUrl || `ws://localhost:${DEFAULT_CONFIG.wsPort}`;
        this.ws = null;
        this.reconnectInterval = 1000;
        this.maxReconnectAttempts = 10;
        this.reconnectAttempts = 0;
        this.handlers = new Map();
        this.state = new Map();

        this.connect();
    }

    connect() {
        try {
            this.ws = new WebSocket(this.wsUrl);

            this.ws.onopen = () => {
                console.log('[Zylix HMR] Connected');
                this.reconnectAttempts = 0;
                this.sendStateSync();
            };

            this.ws.onmessage = (event) => {
                this.handleMessage(JSON.parse(event.data));
            };

            this.ws.onclose = () => {
                console.log('[Zylix HMR] Disconnected');
                this.scheduleReconnect();
            };

            this.ws.onerror = (error) => {
                console.error('[Zylix HMR] Error:', error);
            };
        } catch (error) {
            console.error('[Zylix HMR] Connection failed:', error);
            this.scheduleReconnect();
        }
    }

    scheduleReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
            console.log(`[Zylix HMR] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
            setTimeout(() => this.connect(), delay);
        }
    }

    handleMessage(message) {
        switch (message.type) {
            case 'reload':
                this.handleReload();
                break;
            case 'hot_update':
                this.handleHotUpdate(message.payload);
                break;
            case 'error_overlay':
                this.showErrorOverlay(message.payload);
                break;
            case 'state_sync':
                this.handleStateSync(message.payload);
                break;
            case 'ping':
                this.send({ type: 'pong' });
                break;
        }

        const handler = this.handlers.get(message.type);
        if (handler) {
            handler(message.payload);
        }
    }

    handleReload() {
        console.log('[Zylix HMR] Full reload triggered');
        this.saveState();
        window.location.reload();
    }

    handleHotUpdate(payload) {
        const { module, code } = payload;
        console.log(`[Zylix HMR] Hot update for module: ${module}`);

        try {
            // Dynamic module replacement
            if (window.__ZYLIX_MODULES__) {
                const moduleFactory = new Function('module', 'exports', 'require', code);
                const moduleObj = { exports: {} };
                moduleFactory(moduleObj, moduleObj.exports, window.__ZYLIX_REQUIRE__);
                window.__ZYLIX_MODULES__[module] = moduleObj.exports;
            }

            // Trigger component re-render if React/Vue
            if (window.__ZYLIX_HOT_ACCEPT__) {
                window.__ZYLIX_HOT_ACCEPT__(module);
            }
        } catch (error) {
            console.error('[Zylix HMR] Hot update failed:', error);
            this.handleReload();
        }
    }

    showErrorOverlay(errors) {
        this.hideErrorOverlay();

        const overlay = document.createElement('div');
        overlay.id = 'zylix-error-overlay';
        overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.9);
            color: #fff;
            font-family: 'SF Mono', Monaco, monospace;
            padding: 20px;
            overflow: auto;
            z-index: 99999;
        `;

        let html = `
            <div style="max-width: 800px; margin: 0 auto;">
                <h1 style="color: #ff6b6b; margin-bottom: 20px;">
                    ⚠️ Build Error
                </h1>
        `;

        const errorList = Array.isArray(errors) ? errors : [errors];
        for (const error of errorList) {
            html += `
                <div style="background: #2d2d2d; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                    <div style="color: #888; margin-bottom: 5px;">
                        ${error.file}:${error.line}:${error.column}
                    </div>
                    <div style="color: #ff6b6b; font-weight: bold;">
                        ${error.message}
                    </div>
                </div>
            `;
        }

        html += `
                <button onclick="document.getElementById('zylix-error-overlay').remove()"
                        style="background: #4a90d9; color: white; border: none; padding: 10px 20px;
                               border-radius: 4px; cursor: pointer; margin-top: 10px;">
                    Dismiss
                </button>
            </div>
        `;

        overlay.innerHTML = html;
        document.body.appendChild(overlay);
    }

    hideErrorOverlay() {
        const existing = document.getElementById('zylix-error-overlay');
        if (existing) {
            existing.remove();
        }
    }

    // State Preservation
    saveState() {
        const state = {};

        // Save form values
        document.querySelectorAll('input, textarea, select').forEach(el => {
            if (el.id || el.name) {
                state[el.id || el.name] = {
                    type: el.type,
                    value: el.type === 'checkbox' ? el.checked : el.value
                };
            }
        });

        // Save scroll position
        state.__scroll = {
            x: window.scrollX,
            y: window.scrollY
        };

        // Save to sessionStorage
        sessionStorage.setItem('__ZYLIX_STATE__', JSON.stringify(state));
    }

    restoreState() {
        const stateStr = sessionStorage.getItem('__ZYLIX_STATE__');
        if (!stateStr) return;

        try {
            const state = JSON.parse(stateStr);

            // Restore form values
            for (const [key, data] of Object.entries(state)) {
                if (key.startsWith('__')) continue;

                const el = document.getElementById(key) || document.querySelector(`[name="${key}"]`);
                if (el) {
                    if (data.type === 'checkbox') {
                        el.checked = data.value;
                    } else {
                        el.value = data.value;
                    }
                }
            }

            // Restore scroll position
            if (state.__scroll) {
                window.scrollTo(state.__scroll.x, state.__scroll.y);
            }

            // Clear stored state
            sessionStorage.removeItem('__ZYLIX_STATE__');
        } catch (error) {
            console.error('[Zylix HMR] State restoration failed:', error);
        }
    }

    handleStateSync(state) {
        for (const [key, value] of Object.entries(state)) {
            this.state.set(key, value);
        }
    }

    sendStateSync() {
        const state = Object.fromEntries(this.state);
        this.send({ type: 'state_sync', payload: state });
    }

    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(data));
        }
    }

    on(event, handler) {
        this.handlers.set(event, handler);
    }

    off(event) {
        this.handlers.delete(event);
    }

    getState(key) {
        return this.state.get(key);
    }

    setState(key, value) {
        this.state.set(key, value);
        this.send({ type: 'state_update', payload: { key, value } });
    }
}

// ============================================================================
// Development Server (Node.js Side)
// ============================================================================

class ZylixDevServer {
    constructor(config = {}) {
        this.config = { ...DEFAULT_CONFIG, ...config };
        this.clients = new Set();
        this.fileWatcher = null;
        this.httpServer = null;
        this.wsServer = null;
        this.buildCache = new Map();
        this.stats = {
            startTime: Date.now(),
            builds: 0,
            errors: 0
        };
    }

    async start() {
        console.log(`\n🚀 Zylix Dev Server v0.5.0\n`);

        await this.startHttpServer();
        await this.startWebSocketServer();
        await this.startFileWatcher();

        if (this.config.openBrowser) {
            this.openBrowser();
        }

        console.log(`\n📦 Ready at http://${this.config.host}:${this.config.port}`);
        console.log(`🔌 WebSocket at ws://${this.config.host}:${this.config.wsPort}`);
        console.log(`\nWatching for changes...\n`);
    }

    async startHttpServer() {
        // In browser environment, this would be a service worker
        // In Node.js, this would use http module
        if (typeof window !== 'undefined') {
            console.log('[Dev Server] Running in browser mode');
            return;
        }

        // Node.js server implementation would go here
    }

    async startWebSocketServer() {
        if (typeof window !== 'undefined') {
            // Browser-side: connect as client
            return;
        }

        // Node.js WebSocket server implementation would go here
    }

    async startFileWatcher() {
        if (typeof window !== 'undefined') return;

        // Node.js file watcher implementation would go here
    }

    handleFileChange(path, changeType) {
        console.log(`[Watch] ${changeType}: ${path}`);

        const ext = path.split('.').pop();
        const now = Date.now();

        // Debounce
        if (this._lastChange && now - this._lastChange < this.config.debounceMs) {
            return;
        }
        this._lastChange = now;

        // Determine reload type
        if (this.config.hotReload && this.isHotReloadable(ext)) {
            this.triggerHotUpdate(path);
        } else if (this.config.liveReload) {
            this.triggerReload();
        }
    }

    isHotReloadable(ext) {
        return ['js', 'jsx', 'ts', 'tsx', 'css', 'scss', 'less'].includes(ext);
    }

    async triggerHotUpdate(path) {
        try {
            const code = await this.buildModule(path);
            this.broadcast({
                type: 'hot_update',
                payload: {
                    module: path,
                    code: code
                }
            });
            this.stats.builds++;
        } catch (error) {
            this.triggerError(error, path);
        }
    }

    triggerReload() {
        this.broadcast({ type: 'reload' });
        this.stats.builds++;
    }

    triggerError(error, file) {
        const errorInfo = {
            file: file || 'unknown',
            line: error.line || 1,
            column: error.column || 1,
            message: error.message
        };
        this.broadcast({ type: 'error_overlay', payload: errorInfo });
        this.stats.errors++;
    }

    async buildModule(path) {
        // Check cache
        const cached = this.buildCache.get(path);
        if (cached && cached.timestamp > Date.now() - 1000) {
            return cached.code;
        }

        // Build module (simplified - real implementation would use esbuild/swc)
        const code = `// Hot updated module: ${path}\n`;

        this.buildCache.set(path, {
            code,
            timestamp: Date.now()
        });

        return code;
    }

    broadcast(message) {
        const data = JSON.stringify(message);
        for (const client of this.clients) {
            try {
                client.send(data);
            } catch (error) {
                this.clients.delete(client);
            }
        }
    }

    openBrowser() {
        const url = `http://${this.config.host}:${this.config.port}`;

        if (typeof window !== 'undefined') {
            window.open(url, '_blank');
            return;
        }

        // Node.js open implementation
        const { platform } = process || {};
        const command = platform === 'darwin' ? 'open' :
                       platform === 'win32' ? 'start' : 'xdg-open';

        if (typeof require !== 'undefined') {
            require('child_process').exec(`${command} ${url}`);
        }
    }

    getStats() {
        return {
            ...this.stats,
            uptime: Date.now() - this.stats.startTime,
            clients: this.clients.size
        };
    }

    stop() {
        if (this.fileWatcher) {
            this.fileWatcher.close();
        }
        if (this.wsServer) {
            this.wsServer.close();
        }
        if (this.httpServer) {
            this.httpServer.close();
        }
        console.log('\n👋 Dev server stopped\n');
    }
}

// ============================================================================
// Exports
// ============================================================================

if (typeof window !== 'undefined') {
    // Browser
    window.ZylixHotReloadClient = ZylixHotReloadClient;
    window.ZylixDevServer = ZylixDevServer;

    // Auto-initialize HMR client
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.__ZYLIX_HMR__ = new ZylixHotReloadClient();
            window.__ZYLIX_HMR__.restoreState();
        });
    } else {
        window.__ZYLIX_HMR__ = new ZylixHotReloadClient();
        window.__ZYLIX_HMR__.restoreState();
    }
}

if (typeof module !== 'undefined' && module.exports) {
    // Node.js
    module.exports = {
        ZylixHotReloadClient,
        ZylixDevServer,
        DEFAULT_CONFIG
    };
}

// ES Modules
export { ZylixHotReloadClient, ZylixDevServer, DEFAULT_CONFIG };
