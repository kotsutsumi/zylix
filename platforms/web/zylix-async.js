/**
 * zylix-async.js - Web Platform Async Processing for Zylix v0.4.0
 *
 * Provides Promise/async-await integration for Zylix async system.
 * Features:
 * - Promise integration with Zylix Future pattern
 * - Fetch API wrapper
 * - Background task scheduling (Web Workers)
 * - Cancellation via AbortController
 */

// ============================================================================
// Future/Promise Integration
// ============================================================================

class ZylixFuture {
    constructor() {
        this.state = 'pending';
        this.value = null;
        this.error = null;

        this._promise = new Promise((resolve, reject) => {
            this._resolve = resolve;
            this._reject = reject;
        });

        this._thenCallbacks = [];
        this._catchCallbacks = [];
        this._finallyCallbacks = [];
        this._abortController = new AbortController();
        this._timeout = null;
    }

    /**
     * Resolve the future with a value
     */
    resolve(value) {
        if (this.state !== 'pending') return;
        this.state = 'fulfilled';
        this.value = value;
        this._resolve(value);
        this._thenCallbacks.forEach(cb => cb(value));
        this._finallyCallbacks.forEach(cb => cb());
    }

    /**
     * Reject the future with an error
     */
    reject(error) {
        if (this.state !== 'pending') return;
        this.state = 'rejected';
        this.error = error;
        this._reject(error);
        this._catchCallbacks.forEach(cb => cb(error));
        this._finallyCallbacks.forEach(cb => cb());
    }

    /**
     * Cancel the future
     */
    cancel() {
        if (this.state !== 'pending') return;
        this.state = 'cancelled';
        this._abortController.abort();
        this._finallyCallbacks.forEach(cb => cb());
    }

    /**
     * Add success callback
     */
    then(callback) {
        this._thenCallbacks.push(callback);
        if (this.state === 'fulfilled') {
            callback(this.value);
        }
        return this;
    }

    /**
     * Add error callback
     */
    catch(callback) {
        this._catchCallbacks.push(callback);
        if (this.state === 'rejected') {
            callback(this.error);
        }
        return this;
    }

    /**
     * Add finally callback
     */
    finally(callback) {
        this._finallyCallbacks.push(callback);
        if (this.state !== 'pending') {
            callback();
        }
        return this;
    }

    /**
     * Set timeout
     */
    timeout(ms) {
        this._timeout = setTimeout(() => {
            if (this.state === 'pending') {
                this.reject(new Error('Timeout'));
            }
        }, ms);
        return this;
    }

    /**
     * Get AbortSignal for fetch
     */
    get signal() {
        return this._abortController.signal;
    }

    /**
     * Convert to native Promise
     */
    toPromise() {
        return this._promise;
    }

    /**
     * Create from native Promise
     */
    static from(promise) {
        const future = new ZylixFuture();
        promise
            .then(value => future.resolve(value))
            .catch(error => future.reject(error));
        return future;
    }
}

// ============================================================================
// HTTP Client
// ============================================================================

class ZylixHttpClient {
    constructor(options = {}) {
        this.baseUrl = options.baseUrl || '';
        this.defaultHeaders = {
            'User-Agent': 'Zylix/0.4.0',
            'Accept': 'application/json',
            ...options.headers,
        };
        this.timeout = options.timeout || 30000;
    }

    /**
     * Perform GET request
     */
    get(url, options = {}) {
        return this._request('GET', url, null, options);
    }

    /**
     * Perform POST request
     */
    post(url, body, options = {}) {
        return this._request('POST', url, body, options);
    }

    /**
     * Perform PUT request
     */
    put(url, body, options = {}) {
        return this._request('PUT', url, body, options);
    }

    /**
     * Perform DELETE request
     */
    delete(url, options = {}) {
        return this._request('DELETE', url, null, options);
    }

    /**
     * Perform PATCH request
     */
    patch(url, body, options = {}) {
        return this._request('PATCH', url, body, options);
    }

    /**
     * Internal request method
     */
    _request(method, url, body, options = {}) {
        const future = new ZylixFuture();
        const fullUrl = this.baseUrl + url;
        const timeout = options.timeout || this.timeout;

        future.timeout(timeout);

        const headers = {
            ...this.defaultHeaders,
            ...options.headers,
        };

        if (body && typeof body === 'object') {
            headers['Content-Type'] = 'application/json';
            body = JSON.stringify(body);
        }

        const fetchOptions = {
            method,
            headers,
            body: body || undefined,
            signal: future.signal,
        };

        fetch(fullUrl, fetchOptions)
            .then(async response => {
                const contentType = response.headers.get('content-type');
                let data;

                if (contentType && contentType.includes('application/json')) {
                    data = await response.json();
                } else {
                    data = await response.text();
                }

                const result = {
                    ok: response.ok,
                    status: response.status,
                    statusText: response.statusText,
                    headers: Object.fromEntries(response.headers.entries()),
                    data,
                };

                if (response.ok) {
                    future.resolve(result);
                } else {
                    future.reject(result);
                }
            })
            .catch(error => {
                if (error.name === 'AbortError') {
                    future.reject(new Error('Request cancelled'));
                } else {
                    future.reject(error);
                }
            });

        return future;
    }
}

// ============================================================================
// Task Scheduler
// ============================================================================

const TaskPriority = {
    LOW: 0,
    NORMAL: 1,
    HIGH: 2,
    CRITICAL: 3,
};

const TaskState = {
    QUEUED: 'queued',
    RUNNING: 'running',
    COMPLETED: 'completed',
    FAILED: 'failed',
    CANCELLED: 'cancelled',
};

class ZylixScheduler {
    constructor() {
        this.tasks = [];
        this.running = false;
        this.nextId = 1;
        this._rafId = null;
    }

    /**
     * Start the scheduler
     */
    start() {
        this.running = true;
        this._tick();
    }

    /**
     * Stop the scheduler
     */
    stop() {
        this.running = false;
        if (this._rafId) {
            cancelAnimationFrame(this._rafId);
            this._rafId = null;
        }
    }

    /**
     * Schedule a task
     */
    schedule(fn, options = {}) {
        const task = {
            id: this.nextId++,
            fn,
            priority: options.priority || TaskPriority.NORMAL,
            state: TaskState.QUEUED,
            delay: options.delay || 0,
            scheduledAt: Date.now(),
            cancelled: false,
        };

        // Insert based on priority
        const insertIndex = this.tasks.findIndex(t => t.priority < task.priority);
        if (insertIndex === -1) {
            this.tasks.push(task);
        } else {
            this.tasks.splice(insertIndex, 0, task);
        }

        return {
            id: task.id,
            cancel: () => {
                task.cancelled = true;
                task.state = TaskState.CANCELLED;
            },
            get state() {
                return task.state;
            },
        };
    }

    /**
     * Schedule a delayed task
     */
    scheduleDelayed(fn, delay, options = {}) {
        return this.schedule(fn, { ...options, delay });
    }

    /**
     * Schedule on next frame (requestAnimationFrame)
     */
    scheduleFrame(fn) {
        return this.schedule(fn, { priority: TaskPriority.HIGH });
    }

    /**
     * Schedule on idle (requestIdleCallback)
     */
    scheduleIdle(fn, options = {}) {
        if ('requestIdleCallback' in window) {
            const handle = requestIdleCallback((deadline) => {
                if (!options.cancelled) {
                    fn(deadline);
                }
            }, { timeout: options.timeout || 1000 });

            return {
                id: handle,
                cancel: () => cancelIdleCallback(handle),
                state: TaskState.QUEUED,
            };
        }
        // Fallback to setTimeout
        return this.scheduleDelayed(fn, 0, { priority: TaskPriority.LOW });
    }

    /**
     * Internal tick method
     */
    _tick() {
        if (!this.running) return;

        const now = Date.now();
        const toRun = [];

        // Find tasks ready to run
        for (let i = this.tasks.length - 1; i >= 0; i--) {
            const task = this.tasks[i];
            if (task.cancelled) {
                this.tasks.splice(i, 1);
                continue;
            }
            if (now - task.scheduledAt >= task.delay) {
                toRun.push(task);
                this.tasks.splice(i, 1);
            }
        }

        // Execute tasks (limit per frame to avoid blocking)
        const maxPerFrame = 10;
        for (let i = 0; i < Math.min(toRun.length, maxPerFrame); i++) {
            const task = toRun[i];
            task.state = TaskState.RUNNING;
            try {
                task.fn();
                task.state = TaskState.COMPLETED;
            } catch (error) {
                task.state = TaskState.FAILED;
                console.error('[ZylixScheduler] Task failed:', error);
            }
        }

        // Re-add overflow tasks
        if (toRun.length > maxPerFrame) {
            this.tasks.unshift(...toRun.slice(maxPerFrame));
        }

        this._rafId = requestAnimationFrame(() => this._tick());
    }

    /**
     * Get pending task count
     */
    get pendingCount() {
        return this.tasks.filter(t => t.state === TaskState.QUEUED).length;
    }
}

// ============================================================================
// Async Utilities
// ============================================================================

/**
 * Wait for all futures to complete
 */
function all(futures) {
    const future = new ZylixFuture();

    Promise.all(futures.map(f => f.toPromise()))
        .then(values => future.resolve(values))
        .catch(error => future.reject(error));

    return future;
}

/**
 * Wait for first future to complete
 */
function race(futures) {
    const future = new ZylixFuture();

    Promise.race(futures.map(f => f.toPromise()))
        .then(value => future.resolve(value))
        .catch(error => future.reject(error));

    return future;
}

/**
 * Delay execution
 */
function delay(ms) {
    const future = new ZylixFuture();
    setTimeout(() => future.resolve(), ms);
    return future;
}

/**
 * Retry a function with exponential backoff
 */
async function retry(fn, options = {}) {
    const maxRetries = options.maxRetries || 3;
    const baseDelay = options.baseDelay || 1000;
    const maxDelay = options.maxDelay || 30000;

    let lastError;
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            return await fn();
        } catch (error) {
            lastError = error;
            if (attempt < maxRetries - 1) {
                const delayMs = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
                await new Promise(resolve => setTimeout(resolve, delayMs));
            }
        }
    }
    throw lastError;
}

/**
 * Debounce a function
 */
function debounce(fn, ms) {
    let timeoutId;
    return function (...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => fn.apply(this, args), ms);
    };
}

/**
 * Throttle a function
 */
function throttle(fn, ms) {
    let lastCall = 0;
    return function (...args) {
        const now = Date.now();
        if (now - lastCall >= ms) {
            lastCall = now;
            return fn.apply(this, args);
        }
    };
}

// ============================================================================
// Global Instance
// ============================================================================

const zylixAsync = {
    Future: ZylixFuture,
    HttpClient: ZylixHttpClient,
    Scheduler: ZylixScheduler,
    TaskPriority,
    TaskState,
    all,
    race,
    delay,
    retry,
    debounce,
    throttle,

    // Default instances
    http: new ZylixHttpClient(),
    scheduler: new ZylixScheduler(),

    // Initialize
    init() {
        this.scheduler.start();
        return this;
    },

    // Cleanup
    destroy() {
        this.scheduler.stop();
    },
};

// Auto-start scheduler
if (typeof document !== 'undefined') {
    document.addEventListener('DOMContentLoaded', () => {
        zylixAsync.init();
    });
}

// ============================================================================
// Export
// ============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = zylixAsync;
} else if (typeof window !== 'undefined') {
    window.ZylixAsync = zylixAsync;
    window.ZylixFuture = ZylixFuture;
    window.ZylixHttpClient = ZylixHttpClient;
    window.ZylixScheduler = ZylixScheduler;
}
