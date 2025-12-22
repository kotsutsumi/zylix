// ZylixAsync.kt - Android Async Processing for Zylix v0.4.0
//
// Provides Kotlin Coroutines integration for Zylix async system.
// Features:
// - Coroutines/Flow integration
// - OkHttp/Retrofit wrapper
// - Task scheduling
// - Cancellation support

package com.zylix

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.UUID
import java.util.concurrent.PriorityBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

// ============================================================================
// Future State
// ============================================================================

enum class FutureState {
    PENDING,
    FULFILLED,
    REJECTED,
    CANCELLED
}

// ============================================================================
// Zylix Future
// ============================================================================

class ZylixFuture<T> {
    private var _state = FutureState.PENDING
    val state: FutureState get() = _state

    private var _value: T? = null
    val value: T? get() = _value

    private var _error: Throwable? = null
    val error: Throwable? get() = _error

    private val thenCallbacks = mutableListOf<(T) -> Unit>()
    private val catchCallbacks = mutableListOf<(Throwable) -> Unit>()
    private val finallyCallbacks = mutableListOf<() -> Unit>()

    private var job: Job? = null
    private var timeoutJob: Job? = null

    fun resolve(value: T) {
        if (_state != FutureState.PENDING) return
        _value = value
        _state = FutureState.FULFILLED
        thenCallbacks.forEach { it(value) }
        finallyCallbacks.forEach { it() }
        timeoutJob?.cancel()
    }

    fun reject(error: Throwable) {
        if (_state != FutureState.PENDING) return
        _error = error
        _state = FutureState.REJECTED
        catchCallbacks.forEach { it(error) }
        finallyCallbacks.forEach { it() }
        timeoutJob?.cancel()
    }

    fun cancel() {
        if (_state != FutureState.PENDING) return
        _state = FutureState.CANCELLED
        job?.cancel()
        timeoutJob?.cancel()
        finallyCallbacks.forEach { it() }
    }

    fun then(callback: (T) -> Unit): ZylixFuture<T> {
        thenCallbacks.add(callback)
        if (_state == FutureState.FULFILLED) {
            _value?.let { callback(it) }
        }
        return this
    }

    fun catch(callback: (Throwable) -> Unit): ZylixFuture<T> {
        catchCallbacks.add(callback)
        if (_state == FutureState.REJECTED) {
            _error?.let { callback(it) }
        }
        return this
    }

    fun finally(callback: () -> Unit): ZylixFuture<T> {
        finallyCallbacks.add(callback)
        if (_state != FutureState.PENDING) {
            callback()
        }
        return this
    }

    /**
     * Sets a timeout for this future.
     * @param millis Timeout duration in milliseconds
     * @param scope CoroutineScope for the timeout job - required to ensure proper lifecycle management
     */
    fun timeout(millis: Long, scope: CoroutineScope): ZylixFuture<T> {
        timeoutJob = scope.launch {
            delay(millis)
            if (_state == FutureState.PENDING) {
                reject(ZylixAsyncException.Timeout())
            }
        }
        return this
    }

    suspend fun await(): T {
        return when (_state) {
            FutureState.FULFILLED -> _value!!
            FutureState.REJECTED -> throw _error!!
            FutureState.CANCELLED -> throw ZylixAsyncException.Cancelled()
            FutureState.PENDING -> suspendCancellableCoroutine { cont ->
                then { value -> cont.resume(value) }
                catch { error -> cont.resumeWithException(error) }
            }
        }
    }

    fun toFlow(): Flow<T> = flow {
        emit(await())
    }

    companion object {
        /**
         * Creates a ZylixFuture from a suspend block.
         * @param scope CoroutineScope for the async operation - required to ensure proper lifecycle management
         * @param block The suspend block to execute
         */
        fun <T> from(
            scope: CoroutineScope,
            block: suspend () -> T
        ): ZylixFuture<T> {
            val future = ZylixFuture<T>()
            future.job = scope.launch {
                try {
                    val result = block()
                    future.resolve(result)
                } catch (e: CancellationException) {
                    future.cancel()
                } catch (e: Throwable) {
                    future.reject(e)
                }
            }
            return future
        }

        fun <T> resolved(value: T): ZylixFuture<T> {
            return ZylixFuture<T>().also { it.resolve(value) }
        }

        fun <T> rejected(error: Throwable): ZylixFuture<T> {
            return ZylixFuture<T>().also { it.reject(error) }
        }
    }
}

// ============================================================================
// Async Exceptions
// ============================================================================

sealed class ZylixAsyncException(message: String) : Exception(message) {
    class Timeout(message: String = "Operation timed out") : ZylixAsyncException(message)
    class Cancelled(message: String = "Operation was cancelled") : ZylixAsyncException(message)
    class NetworkError(message: String) : ZylixAsyncException(message)
    class InvalidResponse(message: String = "Invalid response") : ZylixAsyncException(message)
}

// ============================================================================
// HTTP Client
// ============================================================================

data class HttpResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: String
) {
    val isSuccess: Boolean get() = statusCode in 200..299

    fun json(): JSONObject = JSONObject(body)

    inline fun <reified T> json(parser: (JSONObject) -> T): T = parser(json())
}

class ZylixHttpClient(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
) {
    private val defaultHeaders = mutableMapOf(
        "User-Agent" to "Zylix/0.4.0",
        "Accept" to "application/json"
    )

    fun get(url: String, headers: Map<String, String> = emptyMap()): ZylixFuture<HttpResponse> {
        return request("GET", url, null, headers)
    }

    fun post(url: String, body: String? = null, headers: Map<String, String> = emptyMap()): ZylixFuture<HttpResponse> {
        return request("POST", url, body, headers)
    }

    fun put(url: String, body: String? = null, headers: Map<String, String> = emptyMap()): ZylixFuture<HttpResponse> {
        return request("PUT", url, body, headers)
    }

    fun delete(url: String, headers: Map<String, String> = emptyMap()): ZylixFuture<HttpResponse> {
        return request("DELETE", url, null, headers)
    }

    fun postJson(url: String, json: JSONObject, headers: Map<String, String> = emptyMap()): ZylixFuture<HttpResponse> {
        val allHeaders = headers.toMutableMap()
        allHeaders["Content-Type"] = "application/json"
        return request("POST", url, json.toString(), allHeaders)
    }

    private fun request(
        method: String,
        url: String,
        body: String?,
        headers: Map<String, String>
    ): ZylixFuture<HttpResponse> {
        val future = ZylixFuture<HttpResponse>()

        val requestBuilder = Request.Builder().url(url)

        (defaultHeaders + headers).forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val requestBody = body?.toRequestBody("application/json".toMediaType())
        requestBuilder.method(method, requestBody)

        client.newCall(requestBuilder.build()).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                future.reject(ZylixAsyncException.NetworkError(e.message ?: "Unknown error"))
            }

            override fun onResponse(call: Call, response: Response) {
                val responseHeaders = response.headers.toMultimap()
                    .mapValues { it.value.firstOrNull() ?: "" }

                future.resolve(
                    HttpResponse(
                        statusCode = response.code,
                        headers = responseHeaders,
                        body = response.body?.string() ?: ""
                    )
                )
            }
        })

        return future
    }

    companion object {
        val shared = ZylixHttpClient()
    }
}

// ============================================================================
// Task Scheduler
// ============================================================================

enum class TaskPriority(val value: Int) {
    LOW(0),
    NORMAL(1),
    HIGH(2),
    CRITICAL(3)
}

enum class TaskState {
    QUEUED,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED
}

class ZylixTaskHandle(
    val id: UUID = UUID.randomUUID(),
    val priority: TaskPriority = TaskPriority.NORMAL
) : Comparable<ZylixTaskHandle> {
    @Volatile
    var state: TaskState = TaskState.QUEUED
        internal set

    @Volatile
    private var cancelled = false

    private var job: Job? = null

    fun cancel() {
        cancelled = true
        state = TaskState.CANCELLED
        job?.cancel()
    }

    fun isCancelled(): Boolean = cancelled

    internal fun setJob(job: Job) {
        this.job = job
    }

    override fun compareTo(other: ZylixTaskHandle): Int {
        return other.priority.value - priority.value // Higher priority first
    }
}

class ZylixScheduler(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
) {
    private val tasks = PriorityBlockingQueue<Pair<ZylixTaskHandle, suspend () -> Unit>>()
    private var isRunning = false
    private var processingJob: Job? = null

    fun start() {
        if (isRunning) return
        isRunning = true
        processingJob = scope.launch { processLoop() }
    }

    fun stop() {
        isRunning = false
        processingJob?.cancel()
    }

    fun schedule(
        priority: TaskPriority = TaskPriority.NORMAL,
        work: suspend () -> Unit
    ): ZylixTaskHandle {
        val handle = ZylixTaskHandle(priority = priority)
        tasks.add(handle to work)
        return handle
    }

    fun scheduleDelayed(
        delayMillis: Long,
        priority: TaskPriority = TaskPriority.NORMAL,
        work: suspend () -> Unit
    ): ZylixTaskHandle {
        val handle = ZylixTaskHandle(priority = priority)
        val wrappedWork: suspend () -> Unit = {
            delay(delayMillis)
            if (!handle.isCancelled()) {
                work()
            }
        }
        tasks.add(handle to wrappedWork)
        return handle
    }

    val pendingCount: Int
        get() = tasks.count { it.first.state == TaskState.QUEUED }

    private suspend fun processLoop() {
        while (isRunning) {
            val taskPair = tasks.poll()
            if (taskPair != null) {
                val (handle, work) = taskPair
                if (!handle.isCancelled()) {
                    handle.state = TaskState.RUNNING
                    try {
                        work()
                        handle.state = TaskState.COMPLETED
                    } catch (e: CancellationException) {
                        handle.state = TaskState.CANCELLED
                    } catch (e: Throwable) {
                        handle.state = TaskState.FAILED
                    }
                }
            }
            delay(16) // ~60fps
        }
    }

    companion object {
        val shared = ZylixScheduler().also { it.start() }
    }
}

// ============================================================================
// Async Utilities
// ============================================================================

suspend fun <T> all(futures: List<ZylixFuture<T>>): List<T> {
    return coroutineScope {
        futures.map { async { it.await() } }.awaitAll()
    }
}

suspend fun <T> race(futures: List<ZylixFuture<T>>): T {
    return coroutineScope {
        kotlinx.coroutines.selects.select {
            futures.forEach { future ->
                async { future.await() }.onAwait { it }
            }
        }
    }
}

suspend fun delay(millis: Long) {
    kotlinx.coroutines.delay(millis)
}

suspend fun <T> retry(
    maxAttempts: Int = 3,
    initialDelay: Long = 1000,
    maxDelay: Long = 30000,
    block: suspend () -> T
): T {
    var currentDelay = initialDelay
    var lastError: Throwable? = null

    repeat(maxAttempts) { attempt ->
        try {
            return block()
        } catch (e: Throwable) {
            lastError = e
            if (attempt < maxAttempts - 1) {
                delay(currentDelay)
                currentDelay = (currentDelay * 2).coerceAtMost(maxDelay)
            }
        }
    }

    throw lastError!!
}
