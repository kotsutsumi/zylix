// ZylixAsync.cs - Windows Async Processing for Zylix v0.4.0
//
// Provides Task/async-await integration for Zylix async system.
// Features:
// - Task-based async pattern
// - HttpClient wrapper
// - Task scheduling
// - Cancellation support

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Zylix
{
    // ========================================================================
    // Future State
    // ========================================================================

    public enum FutureState
    {
        Pending,
        Fulfilled,
        Rejected,
        Cancelled
    }

    // ========================================================================
    // Zylix Future
    // ========================================================================

    public class ZylixFuture<T>
    {
        private FutureState _state = FutureState.Pending;
        private T? _value;
        private Exception? _error;
        private readonly List<Action<T>> _thenCallbacks = new();
        private readonly List<Action<Exception>> _catchCallbacks = new();
        private readonly List<Action> _finallyCallbacks = new();
        private readonly CancellationTokenSource _cts = new();
        private readonly TaskCompletionSource<T> _tcs = new();

        public FutureState State => _state;
        public T? Value => _value;
        public Exception? Error => _error;
        public CancellationToken CancellationToken => _cts.Token;

        public void Resolve(T value)
        {
            if (_state != FutureState.Pending) return;
            _value = value;
            _state = FutureState.Fulfilled;
            _tcs.TrySetResult(value);
            foreach (var cb in _thenCallbacks) cb(value);
            foreach (var cb in _finallyCallbacks) cb();
        }

        public void Reject(Exception error)
        {
            if (_state != FutureState.Pending) return;
            _error = error;
            _state = FutureState.Rejected;
            _tcs.TrySetException(error);
            foreach (var cb in _catchCallbacks) cb(error);
            foreach (var cb in _finallyCallbacks) cb();
        }

        public void Cancel()
        {
            if (_state != FutureState.Pending) return;
            _state = FutureState.Cancelled;
            _cts.Cancel();
            _tcs.TrySetCanceled();
            foreach (var cb in _finallyCallbacks) cb();
        }

        public ZylixFuture<T> Then(Action<T> callback)
        {
            _thenCallbacks.Add(callback);
            if (_state == FutureState.Fulfilled && _value != null)
                callback(_value);
            return this;
        }

        public ZylixFuture<T> Catch(Action<Exception> callback)
        {
            _catchCallbacks.Add(callback);
            if (_state == FutureState.Rejected && _error != null)
                callback(_error);
            return this;
        }

        public ZylixFuture<T> Finally(Action callback)
        {
            _finallyCallbacks.Add(callback);
            if (_state != FutureState.Pending)
                callback();
            return this;
        }

        public ZylixFuture<T> Timeout(int milliseconds)
        {
            Task.Delay(milliseconds, _cts.Token).ContinueWith(_ =>
            {
                if (_state == FutureState.Pending)
                    Reject(new ZylixTimeoutException());
            }, TaskContinuationOptions.NotOnCanceled);
            return this;
        }

        public async Task<T> AwaitAsync()
        {
            return await _tcs.Task;
        }

        public Task<T> ToTask() => _tcs.Task;

        public static ZylixFuture<T> From(Func<CancellationToken, Task<T>> operation)
        {
            var future = new ZylixFuture<T>();
            Task.Run(async () =>
            {
                try
                {
                    var result = await operation(future.CancellationToken);
                    future.Resolve(result);
                }
                catch (OperationCanceledException)
                {
                    future.Cancel();
                }
                catch (Exception ex)
                {
                    future.Reject(ex);
                }
            });
            return future;
        }

        public static ZylixFuture<T> Resolved(T value)
        {
            var future = new ZylixFuture<T>();
            future.Resolve(value);
            return future;
        }

        public static ZylixFuture<T> Rejected(Exception error)
        {
            var future = new ZylixFuture<T>();
            future.Reject(error);
            return future;
        }
    }

    // ========================================================================
    // Async Exceptions
    // ========================================================================

    public class ZylixTimeoutException : Exception
    {
        public ZylixTimeoutException() : base("Operation timed out") { }
    }

    public class ZylixNetworkException : Exception
    {
        public ZylixNetworkException(string message) : base(message) { }
    }

    // ========================================================================
    // HTTP Client
    // ========================================================================

    public class HttpResponse
    {
        public int StatusCode { get; init; }
        public Dictionary<string, string> Headers { get; init; } = new();
        public string Body { get; init; } = "";

        public bool IsSuccess => StatusCode >= 200 && StatusCode < 300;

        public T? Json<T>() => JsonSerializer.Deserialize<T>(Body);
    }

    public class ZylixHttpClient : IDisposable
    {
        private readonly HttpClient _client;
        private readonly Dictionary<string, string> _defaultHeaders = new()
        {
            { "User-Agent", "Zylix/0.4.0" },
            { "Accept", "application/json" }
        };

        public static ZylixHttpClient Shared { get; } = new();

        public ZylixHttpClient(HttpClient? client = null)
        {
            _client = client ?? new HttpClient();
        }

        public ZylixFuture<HttpResponse> Get(string url, Dictionary<string, string>? headers = null)
        {
            return Request(HttpMethod.Get, url, null, headers);
        }

        public ZylixFuture<HttpResponse> Post(string url, string? body = null, Dictionary<string, string>? headers = null)
        {
            return Request(HttpMethod.Post, url, body, headers);
        }

        public ZylixFuture<HttpResponse> Put(string url, string? body = null, Dictionary<string, string>? headers = null)
        {
            return Request(HttpMethod.Put, url, body, headers);
        }

        public ZylixFuture<HttpResponse> Delete(string url, Dictionary<string, string>? headers = null)
        {
            return Request(HttpMethod.Delete, url, null, headers);
        }

        public ZylixFuture<HttpResponse> PostJson<T>(string url, T body, Dictionary<string, string>? headers = null)
        {
            var allHeaders = new Dictionary<string, string>(headers ?? new());
            allHeaders["Content-Type"] = "application/json";
            return Request(HttpMethod.Post, url, JsonSerializer.Serialize(body), allHeaders);
        }

        private ZylixFuture<HttpResponse> Request(
            HttpMethod method,
            string url,
            string? body,
            Dictionary<string, string>? headers)
        {
            return ZylixFuture<HttpResponse>.From(async ct =>
            {
                var request = new HttpRequestMessage(method, url);

                foreach (var (key, value) in _defaultHeaders)
                    request.Headers.TryAddWithoutValidation(key, value);

                if (headers != null)
                {
                    foreach (var (key, value) in headers)
                        request.Headers.TryAddWithoutValidation(key, value);
                }

                if (body != null)
                    request.Content = new StringContent(body, Encoding.UTF8, "application/json");

                var response = await _client.SendAsync(request, ct);
                var responseBody = await response.Content.ReadAsStringAsync(ct);

                var responseHeaders = new Dictionary<string, string>();
                foreach (var header in response.Headers)
                    responseHeaders[header.Key] = string.Join(", ", header.Value);

                return new HttpResponse
                {
                    StatusCode = (int)response.StatusCode,
                    Headers = responseHeaders,
                    Body = responseBody
                };
            });
        }

        public void Dispose()
        {
            _client.Dispose();
        }
    }

    // ========================================================================
    // Task Scheduler
    // ========================================================================

    public enum TaskPriority
    {
        Low = 0,
        Normal = 1,
        High = 2,
        Critical = 3
    }

    public enum TaskState
    {
        Queued,
        Running,
        Completed,
        Failed,
        Cancelled
    }

    public class ZylixTaskHandle
    {
        public Guid Id { get; } = Guid.NewGuid();
        public TaskPriority Priority { get; }
        public TaskState State { get; internal set; } = TaskState.Queued;

        private CancellationTokenSource _cts = new();

        public ZylixTaskHandle(TaskPriority priority = TaskPriority.Normal)
        {
            Priority = priority;
        }

        public void Cancel()
        {
            _cts.Cancel();
            State = TaskState.Cancelled;
        }

        public bool IsCancelled => _cts.IsCancellationRequested;
        public CancellationToken CancellationToken => _cts.Token;
    }

    public class ZylixScheduler : IDisposable
    {
        private readonly ConcurrentQueue<(ZylixTaskHandle Handle, Func<Task> Work)> _tasks = new();
        private readonly CancellationTokenSource _cts = new();
        private Task? _processingTask;
        private bool _isRunning;

        public static ZylixScheduler Shared { get; } = new();

        public void Start()
        {
            if (_isRunning) return;
            _isRunning = true;
            _processingTask = ProcessLoop();
        }

        public void Stop()
        {
            _isRunning = false;
            _cts.Cancel();
        }

        public ZylixTaskHandle Schedule(Func<Task> work, TaskPriority priority = TaskPriority.Normal)
        {
            var handle = new ZylixTaskHandle(priority);
            _tasks.Enqueue((handle, work));
            return handle;
        }

        public ZylixTaskHandle ScheduleDelayed(
            Func<Task> work,
            int delayMs,
            TaskPriority priority = TaskPriority.Normal)
        {
            var handle = new ZylixTaskHandle(priority);
            Func<Task> wrappedWork = async () =>
            {
                await Task.Delay(delayMs, handle.CancellationToken);
                if (!handle.IsCancelled)
                    await work();
            };
            _tasks.Enqueue((handle, wrappedWork));
            return handle;
        }

        public int PendingCount => _tasks.Count;

        private async Task ProcessLoop()
        {
            while (_isRunning && !_cts.IsCancellationRequested)
            {
                if (_tasks.TryDequeue(out var taskInfo))
                {
                    var (handle, work) = taskInfo;
                    if (!handle.IsCancelled)
                    {
                        handle.State = TaskState.Running;
                        try
                        {
                            await work();
                            handle.State = TaskState.Completed;
                        }
                        catch (OperationCanceledException)
                        {
                            handle.State = TaskState.Cancelled;
                        }
                        catch
                        {
                            handle.State = TaskState.Failed;
                        }
                    }
                }

                await Task.Delay(16, _cts.Token); // ~60fps
            }
        }

        public void Dispose()
        {
            Stop();
            _cts.Dispose();
        }
    }

    // ========================================================================
    // Async Utilities
    // ========================================================================

    public static class ZylixAsyncUtils
    {
        public static async Task<T[]> All<T>(params ZylixFuture<T>[] futures)
        {
            var tasks = new Task<T>[futures.Length];
            for (int i = 0; i < futures.Length; i++)
                tasks[i] = futures[i].AwaitAsync();
            return await Task.WhenAll(tasks);
        }

        public static async Task<T> Race<T>(params ZylixFuture<T>[] futures)
        {
            var tasks = new Task<T>[futures.Length];
            for (int i = 0; i < futures.Length; i++)
                tasks[i] = futures[i].AwaitAsync();
            return await await Task.WhenAny(tasks);
        }

        public static async Task Delay(int milliseconds)
        {
            await Task.Delay(milliseconds);
        }

        public static async Task<T> Retry<T>(
            Func<Task<T>> operation,
            int maxAttempts = 3,
            int initialDelayMs = 1000,
            int maxDelayMs = 30000)
        {
            Exception? lastError = null;
            int currentDelay = initialDelayMs;

            for (int attempt = 0; attempt < maxAttempts; attempt++)
            {
                try
                {
                    return await operation();
                }
                catch (Exception ex)
                {
                    lastError = ex;
                    if (attempt < maxAttempts - 1)
                    {
                        await Task.Delay(currentDelay);
                        currentDelay = Math.Min(currentDelay * 2, maxDelayMs);
                    }
                }
            }

            throw lastError!;
        }
    }
}
