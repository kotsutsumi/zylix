import { test, describe, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';

// Mock browser environment
globalThis.window = {
    requestIdleCallback: (cb, options) => {
        const id = setTimeout(() => cb({ timeRemaining: () => 50 }), 0);
        return id;
    },
    cancelIdleCallback: (id) => clearTimeout(id),
};

globalThis.document = {
    addEventListener: mock.fn(),
};

globalThis.AbortController = class {
    constructor() {
        this.signal = { aborted: false };
    }
    abort() {
        this.signal.aborted = true;
    }
};

globalThis.fetch = mock.fn();
globalThis.requestAnimationFrame = (cb) => setTimeout(cb, 16);
globalThis.cancelAnimationFrame = (id) => clearTimeout(id);

// Import after mocking
const zylixAsyncModule = await import('../../platforms/web/zylix-async.js');
const zylixAsync = zylixAsyncModule.default || zylixAsyncModule;

describe('ZylixFuture', () => {
    test('should start in pending state', () => {
        const future = new zylixAsync.Future();
        assert.strictEqual(future.state, 'pending');
        assert.strictEqual(future.value, null);
        assert.strictEqual(future.error, null);
    });

    test('should resolve with value', () => {
        const future = new zylixAsync.Future();
        future.resolve('test-value');

        assert.strictEqual(future.state, 'fulfilled');
        assert.strictEqual(future.value, 'test-value');
    });

    test('should reject with error', () => {
        const future = new zylixAsync.Future();
        const error = new Error('test-error');
        // Prevent unhandled rejection
        future.toPromise().catch(() => {});
        future.reject(error);

        assert.strictEqual(future.state, 'rejected');
        assert.strictEqual(future.error, error);
    });

    test('should not change state after resolved', () => {
        const future = new zylixAsync.Future();
        future.resolve('first');
        future.resolve('second');
        future.reject(new Error('nope'));

        assert.strictEqual(future.state, 'fulfilled');
        assert.strictEqual(future.value, 'first');
    });

    test('should not change state after rejected', () => {
        const future = new zylixAsync.Future();
        const error = new Error('first');
        // Prevent unhandled rejection
        future.toPromise().catch(() => {});
        future.reject(error);
        future.resolve('nope');

        assert.strictEqual(future.state, 'rejected');
        assert.strictEqual(future.error, error);
    });

    test('should call then callbacks on resolve', () => {
        const future = new zylixAsync.Future();
        let result = null;

        future.then((value) => {
            result = value;
        });

        future.resolve('test');
        assert.strictEqual(result, 'test');
    });

    test('should call then callback immediately if already resolved', () => {
        const future = new zylixAsync.Future();
        future.resolve('test');

        let result = null;
        future.then((value) => {
            result = value;
        });

        assert.strictEqual(result, 'test');
    });

    test('should call catch callbacks on reject', () => {
        const future = new zylixAsync.Future();
        let result = null;

        // Prevent unhandled rejection
        future.toPromise().catch(() => {});

        future.catch((error) => {
            result = error.message;
        });

        future.reject(new Error('test-error'));
        assert.strictEqual(result, 'test-error');
    });

    test('should call catch callback immediately if already rejected', () => {
        const future = new zylixAsync.Future();
        // Prevent unhandled rejection
        future.toPromise().catch(() => {});
        future.reject(new Error('test-error'));

        let result = null;
        future.catch((error) => {
            result = error.message;
        });

        assert.strictEqual(result, 'test-error');
    });

    test('should call finally callbacks on resolve', () => {
        const future = new zylixAsync.Future();
        let called = false;

        future.finally(() => {
            called = true;
        });

        future.resolve('test');
        assert.ok(called);
    });

    test('should call finally callbacks on reject', () => {
        const future = new zylixAsync.Future();
        let called = false;

        // Prevent unhandled rejection
        future.toPromise().catch(() => {});

        future.finally(() => {
            called = true;
        });

        future.reject(new Error('test'));
        assert.ok(called);
    });

    test('should call finally callback immediately if already settled', () => {
        const future = new zylixAsync.Future();
        future.resolve('test');

        let called = false;
        future.finally(() => {
            called = true;
        });

        assert.ok(called);
    });

    test('should support method chaining', () => {
        const future = new zylixAsync.Future();

        const result = future
            .then(() => {})
            .catch(() => {})
            .finally(() => {});

        assert.strictEqual(result, future);
    });

    test('should cancel pending future', () => {
        const future = new zylixAsync.Future();
        future.cancel();

        assert.strictEqual(future.state, 'cancelled');
    });

    test('should call finally on cancel', () => {
        const future = new zylixAsync.Future();
        let called = false;

        future.finally(() => {
            called = true;
        });

        future.cancel();
        assert.ok(called);
    });

    test('should not cancel if already resolved', () => {
        const future = new zylixAsync.Future();
        future.resolve('test');
        future.cancel();

        assert.strictEqual(future.state, 'fulfilled');
    });

    test('should convert to native Promise', async () => {
        const future = new zylixAsync.Future();
        const promise = future.toPromise();

        assert.ok(promise instanceof Promise);

        future.resolve('test');
        const result = await promise;
        assert.strictEqual(result, 'test');
    });

    test('should create from native Promise (resolve)', async () => {
        const promise = Promise.resolve('test-value');
        const future = zylixAsync.Future.from(promise);

        await new Promise(resolve => setTimeout(resolve, 0));

        assert.strictEqual(future.state, 'fulfilled');
        assert.strictEqual(future.value, 'test-value');
    });

    test('should create from native Promise (reject)', async () => {
        const error = new Error('test-error');
        // Need to handle the rejection to prevent unhandled rejection
        const promise = Promise.reject(error);
        promise.catch(() => {}); // Prevent unhandled rejection

        const future = zylixAsync.Future.from(promise);
        // Also prevent unhandled rejection on the future
        future.toPromise().catch(() => {});

        await new Promise(resolve => setTimeout(resolve, 10));

        assert.strictEqual(future.state, 'rejected');
        assert.strictEqual(future.error, error);
    });

    test('should provide abort signal', () => {
        const future = new zylixAsync.Future();
        assert.ok(future.signal);
        assert.strictEqual(future.signal.aborted, false);
    });

    test('should abort signal on cancel', () => {
        const future = new zylixAsync.Future();
        future.cancel();
        assert.strictEqual(future.signal.aborted, true);
    });
});

describe('ZylixScheduler', () => {
    let scheduler;

    beforeEach(() => {
        scheduler = new zylixAsync.Scheduler();
    });

    afterEach(() => {
        scheduler.stop();
    });

    test('should start and stop', () => {
        assert.strictEqual(scheduler.running, false);

        scheduler.start();
        assert.strictEqual(scheduler.running, true);

        scheduler.stop();
        assert.strictEqual(scheduler.running, false);
    });

    test('should schedule a task', () => {
        const handle = scheduler.schedule(() => {});

        assert.ok(handle.id);
        assert.strictEqual(handle.state, 'queued');
    });

    test('should cancel a scheduled task', () => {
        const handle = scheduler.schedule(() => {});
        handle.cancel();

        assert.strictEqual(handle.state, 'cancelled');
    });

    test('should track pending count', () => {
        assert.strictEqual(scheduler.pendingCount, 0);

        scheduler.schedule(() => {});
        scheduler.schedule(() => {});

        assert.strictEqual(scheduler.pendingCount, 2);
    });

    test('should schedule with delay', () => {
        const handle = scheduler.scheduleDelayed(() => {}, 100);

        assert.ok(handle.id);
        assert.strictEqual(handle.state, 'queued');
    });

    test('should schedule frame task with high priority', () => {
        const handle = scheduler.scheduleFrame(() => {});

        assert.ok(handle.id);
    });

    test('should assign incremental IDs', () => {
        const handle1 = scheduler.schedule(() => {});
        const handle2 = scheduler.schedule(() => {});
        const handle3 = scheduler.schedule(() => {});

        assert.strictEqual(handle2.id, handle1.id + 1);
        assert.strictEqual(handle3.id, handle2.id + 1);
    });
});

describe('TaskPriority', () => {
    test('should have correct priority values', () => {
        assert.strictEqual(zylixAsync.TaskPriority.LOW, 0);
        assert.strictEqual(zylixAsync.TaskPriority.NORMAL, 1);
        assert.strictEqual(zylixAsync.TaskPriority.HIGH, 2);
        assert.strictEqual(zylixAsync.TaskPriority.CRITICAL, 3);
    });
});

describe('TaskState', () => {
    test('should have correct state values', () => {
        assert.strictEqual(zylixAsync.TaskState.QUEUED, 'queued');
        assert.strictEqual(zylixAsync.TaskState.RUNNING, 'running');
        assert.strictEqual(zylixAsync.TaskState.COMPLETED, 'completed');
        assert.strictEqual(zylixAsync.TaskState.FAILED, 'failed');
        assert.strictEqual(zylixAsync.TaskState.CANCELLED, 'cancelled');
    });
});

describe('Async Utilities', () => {
    describe('delay', () => {
        test('should return a future', () => {
            const result = zylixAsync.delay(10);
            assert.ok(result instanceof zylixAsync.Future);
        });

        test('should resolve after delay', async () => {
            const start = Date.now();
            const future = zylixAsync.delay(50);

            await future.toPromise();
            const elapsed = Date.now() - start;

            assert.ok(elapsed >= 45); // Allow some tolerance
        });
    });

    describe('all', () => {
        test('should resolve when all futures resolve', async () => {
            const f1 = new zylixAsync.Future();
            const f2 = new zylixAsync.Future();

            const combined = zylixAsync.all([f1, f2]);

            f1.resolve('a');
            f2.resolve('b');

            const result = await combined.toPromise();
            assert.deepStrictEqual(result, ['a', 'b']);
        });

        test('should reject if any future rejects', async () => {
            const f1 = new zylixAsync.Future();
            const f2 = new zylixAsync.Future();

            const combined = zylixAsync.all([f1, f2]);

            f1.resolve('a');
            f2.reject(new Error('fail'));

            try {
                await combined.toPromise();
                assert.fail('Should have rejected');
            } catch (error) {
                assert.strictEqual(error.message, 'fail');
            }
        });
    });

    describe('race', () => {
        test('should resolve with first resolved value', async () => {
            const f1 = new zylixAsync.Future();
            const f2 = new zylixAsync.Future();

            const raced = zylixAsync.race([f1, f2]);

            f1.resolve('first');

            const result = await raced.toPromise();
            assert.strictEqual(result, 'first');
        });

        test('should reject with first rejected error', async () => {
            const f1 = new zylixAsync.Future();
            const f2 = new zylixAsync.Future();

            const raced = zylixAsync.race([f1, f2]);

            f1.reject(new Error('first-error'));

            try {
                await raced.toPromise();
                assert.fail('Should have rejected');
            } catch (error) {
                assert.strictEqual(error.message, 'first-error');
            }
        });
    });

    describe('debounce', () => {
        test('should debounce function calls', async () => {
            let callCount = 0;
            const fn = () => callCount++;
            const debounced = zylixAsync.debounce(fn, 50);

            debounced();
            debounced();
            debounced();

            assert.strictEqual(callCount, 0);

            await new Promise(resolve => setTimeout(resolve, 100));

            assert.strictEqual(callCount, 1);
        });
    });

    describe('throttle', () => {
        test('should throttle function calls', async () => {
            let callCount = 0;
            const fn = () => callCount++;
            const throttled = zylixAsync.throttle(fn, 50);

            throttled();
            throttled();
            throttled();

            assert.strictEqual(callCount, 1);

            await new Promise(resolve => setTimeout(resolve, 60));

            throttled();
            assert.strictEqual(callCount, 2);
        });
    });
});

describe('ZylixHttpClient', () => {
    let client;

    beforeEach(() => {
        client = new zylixAsync.HttpClient({ baseUrl: 'https://api.example.com' });
        globalThis.fetch.mock.resetCalls();
    });

    test('should create with default options', () => {
        const defaultClient = new zylixAsync.HttpClient();
        assert.strictEqual(defaultClient.baseUrl, '');
        assert.strictEqual(defaultClient.timeout, 30000);
    });

    test('should create with custom options', () => {
        assert.strictEqual(client.baseUrl, 'https://api.example.com');
    });

    test('should set default headers', () => {
        assert.ok(client.defaultHeaders['User-Agent'].includes('Zylix'));
        assert.strictEqual(client.defaultHeaders['Accept'], 'application/json');
    });

    test('should merge custom headers', () => {
        const customClient = new zylixAsync.HttpClient({
            headers: { 'X-Custom': 'value' },
        });

        assert.strictEqual(customClient.defaultHeaders['X-Custom'], 'value');
    });

    test('get should return a future', () => {
        globalThis.fetch.mock.mockImplementation(() =>
            Promise.resolve({
                ok: true,
                status: 200,
                statusText: 'OK',
                headers: new Map([['content-type', 'application/json']]),
                json: () => Promise.resolve({ data: 'test' }),
            })
        );

        const result = client.get('/test');
        assert.ok(result instanceof zylixAsync.Future);
    });

    test('should have post, put, delete, patch methods', () => {
        assert.strictEqual(typeof client.post, 'function');
        assert.strictEqual(typeof client.put, 'function');
        assert.strictEqual(typeof client.delete, 'function');
        assert.strictEqual(typeof client.patch, 'function');
    });
});

describe('zylixAsync global object', () => {
    test('should export all classes', () => {
        assert.ok(zylixAsync.Future);
        assert.ok(zylixAsync.HttpClient);
        assert.ok(zylixAsync.Scheduler);
    });

    test('should export utilities', () => {
        assert.strictEqual(typeof zylixAsync.all, 'function');
        assert.strictEqual(typeof zylixAsync.race, 'function');
        assert.strictEqual(typeof zylixAsync.delay, 'function');
        assert.strictEqual(typeof zylixAsync.retry, 'function');
        assert.strictEqual(typeof zylixAsync.debounce, 'function');
        assert.strictEqual(typeof zylixAsync.throttle, 'function');
    });

    test('should have default instances', () => {
        assert.ok(zylixAsync.http);
        assert.ok(zylixAsync.scheduler);
    });

    test('should have init and destroy methods', () => {
        assert.strictEqual(typeof zylixAsync.init, 'function');
        assert.strictEqual(typeof zylixAsync.destroy, 'function');
    });
});
