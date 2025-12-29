package com.zylix

import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for ZylixAsync module.
 */
class ZylixAsyncTests {

    // MARK: - Future State Tests

    @Test
    fun `test FutureState values`() {
        assertEquals(FutureState.PENDING.name, "PENDING")
        assertEquals(FutureState.FULFILLED.name, "FULFILLED")
        assertEquals(FutureState.REJECTED.name, "REJECTED")
        assertEquals(FutureState.CANCELLED.name, "CANCELLED")
    }

    // MARK: - ZylixFuture Tests

    @Test
    fun `test future resolves with value`() {
        val future = ZylixFuture<Int>()
        future.resolve(42)

        assertEquals(FutureState.FULFILLED, future.state)
        assertEquals(42, future.value)
        assertNull(future.error)
    }

    @Test
    fun `test future rejects with error`() {
        val future = ZylixFuture<Int>()
        val error = ZylixAsyncException.NetworkError("Test error")
        future.reject(error)

        assertEquals(FutureState.REJECTED, future.state)
        assertNull(future.value)
        assertEquals(error, future.error)
    }

    @Test
    fun `test future can be cancelled`() {
        val future = ZylixFuture<Int>()
        future.cancel()

        assertEquals(FutureState.CANCELLED, future.state)
    }

    @Test
    fun `test resolved static factory`() {
        val future = ZylixFuture.resolved("test")

        assertEquals(FutureState.FULFILLED, future.state)
        assertEquals("test", future.value)
    }

    @Test
    fun `test rejected static factory`() {
        val error = ZylixAsyncException.Timeout()
        val future = ZylixFuture.rejected<String>(error)

        assertEquals(FutureState.REJECTED, future.state)
        assertEquals(error, future.error)
    }

    @Test
    fun `test then callback is called on resolve`() {
        val future = ZylixFuture<Int>()
        var result: Int? = null

        future.then { result = it }
        future.resolve(100)

        assertEquals(100, result)
    }

    @Test
    fun `test catch callback is called on reject`() {
        val future = ZylixFuture<Int>()
        var caughtError: Throwable? = null

        future.catch { caughtError = it }
        future.reject(ZylixAsyncException.NetworkError("Test"))

        assertNotNull(caughtError)
        assertTrue(caughtError is ZylixAsyncException.NetworkError)
    }

    @Test
    fun `test finally callback is called on resolve`() {
        val future = ZylixFuture<Int>()
        var finallyCalled = false

        future.finally { finallyCalled = true }
        future.resolve(1)

        assertTrue(finallyCalled)
    }

    @Test
    fun `test finally callback is called on reject`() {
        val future = ZylixFuture<Int>()
        var finallyCalled = false

        future.finally { finallyCalled = true }
        future.reject(Exception("Test"))

        assertTrue(finallyCalled)
    }

    @Test
    fun `test future does not resolve twice`() {
        val future = ZylixFuture<Int>()
        future.resolve(1)
        future.resolve(2)

        assertEquals(1, future.value)
    }

    // MARK: - ZylixAsyncException Tests

    @Test
    fun `test timeout exception`() {
        val error = ZylixAsyncException.Timeout()
        assertEquals("Operation timed out", error.message)
    }

    @Test
    fun `test timeout exception with custom message`() {
        val error = ZylixAsyncException.Timeout("Custom timeout")
        assertEquals("Custom timeout", error.message)
    }

    @Test
    fun `test cancelled exception`() {
        val error = ZylixAsyncException.Cancelled()
        assertEquals("Operation was cancelled", error.message)
    }

    @Test
    fun `test network error exception`() {
        val error = ZylixAsyncException.NetworkError("Connection failed")
        assertEquals("Connection failed", error.message)
    }

    @Test
    fun `test invalid response exception`() {
        val error = ZylixAsyncException.InvalidResponse()
        assertEquals("Invalid response", error.message)
    }

    // MARK: - HttpResponse Tests

    @Test
    fun `test HttpResponse isSuccess for 2xx codes`() {
        assertTrue(HttpResponse(200, emptyMap(), "").isSuccess)
        assertTrue(HttpResponse(201, emptyMap(), "").isSuccess)
        assertTrue(HttpResponse(299, emptyMap(), "").isSuccess)
    }

    @Test
    fun `test HttpResponse isSuccess for non-2xx codes`() {
        assertFalse(HttpResponse(400, emptyMap(), "").isSuccess)
        assertFalse(HttpResponse(404, emptyMap(), "").isSuccess)
        assertFalse(HttpResponse(500, emptyMap(), "").isSuccess)
    }

    @Test
    fun `test HttpResponse json parsing`() {
        val response = HttpResponse(200, emptyMap(), """{"key": "value"}""")
        val json = response.json()

        assertEquals("value", json.getString("key"))
    }

    // MARK: - TaskPriority Tests

    @Test
    fun `test TaskPriority ordering`() {
        assertTrue(TaskPriority.LOW.value < TaskPriority.NORMAL.value)
        assertTrue(TaskPriority.NORMAL.value < TaskPriority.HIGH.value)
        assertTrue(TaskPriority.HIGH.value < TaskPriority.CRITICAL.value)
    }

    @Test
    fun `test TaskPriority values`() {
        assertEquals(0, TaskPriority.LOW.value)
        assertEquals(1, TaskPriority.NORMAL.value)
        assertEquals(2, TaskPriority.HIGH.value)
        assertEquals(3, TaskPriority.CRITICAL.value)
    }

    // MARK: - TaskState Tests

    @Test
    fun `test TaskState values`() {
        assertEquals("QUEUED", TaskState.QUEUED.name)
        assertEquals("RUNNING", TaskState.RUNNING.name)
        assertEquals("COMPLETED", TaskState.COMPLETED.name)
        assertEquals("FAILED", TaskState.FAILED.name)
        assertEquals("CANCELLED", TaskState.CANCELLED.name)
    }

    // MARK: - ZylixTaskHandle Tests

    @Test
    fun `test TaskHandle initial state`() {
        val handle = ZylixTaskHandle()

        assertEquals(TaskState.QUEUED, handle.state)
        assertEquals(TaskPriority.NORMAL, handle.priority)
        assertFalse(handle.isCancelled())
    }

    @Test
    fun `test TaskHandle with priority`() {
        val handle = ZylixTaskHandle(priority = TaskPriority.HIGH)

        assertEquals(TaskPriority.HIGH, handle.priority)
    }

    @Test
    fun `test TaskHandle cancel`() {
        val handle = ZylixTaskHandle()
        handle.cancel()

        assertTrue(handle.isCancelled())
        assertEquals(TaskState.CANCELLED, handle.state)
    }

    @Test
    fun `test TaskHandle priority comparison`() {
        val lowPriority = ZylixTaskHandle(priority = TaskPriority.LOW)
        val highPriority = ZylixTaskHandle(priority = TaskPriority.HIGH)

        assertTrue(lowPriority < highPriority)
    }
}
