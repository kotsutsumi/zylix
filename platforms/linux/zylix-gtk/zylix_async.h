/*
 * zylix_async.h
 * GTK4 Async Processing Header for Zylix v0.4.0
 *
 * Provides GLib async integration for Zylix async system.
 * Features:
 * - GTask-based async pattern
 * - libsoup HTTP client wrapper
 * - GLib main loop task scheduling
 * - GCancellable support
 */

#ifndef ZYLIX_ASYNC_H
#define ZYLIX_ASYNC_H

#include <glib.h>
#include <gio/gio.h>
#include <libsoup/soup.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Future State
 * ============================================================================ */

typedef enum {
    ZYLIX_FUTURE_PENDING,
    ZYLIX_FUTURE_FULFILLED,
    ZYLIX_FUTURE_REJECTED,
    ZYLIX_FUTURE_CANCELLED
} ZylixFutureState;

/* ============================================================================
 * Future Type
 * ============================================================================ */

typedef struct _ZylixFuture ZylixFuture;

typedef void (*ZylixFutureThenCallback)(gpointer value, gpointer user_data);
typedef void (*ZylixFutureCatchCallback)(GError* error, gpointer user_data);
typedef void (*ZylixFutureFinallyCallback)(gpointer user_data);

/**
 * Create a new future
 */
ZylixFuture* zylix_future_new(void);

/**
 * Free a future
 */
void zylix_future_free(ZylixFuture* future);

/**
 * Resolve the future with a value
 */
void zylix_future_resolve(ZylixFuture* future, gpointer value);

/**
 * Reject the future with an error
 */
void zylix_future_reject(ZylixFuture* future, GError* error);

/**
 * Cancel the future
 */
void zylix_future_cancel(ZylixFuture* future);

/**
 * Get future state
 */
ZylixFutureState zylix_future_get_state(ZylixFuture* future);

/**
 * Get future value (if fulfilled)
 */
gpointer zylix_future_get_value(ZylixFuture* future);

/**
 * Get future error (if rejected)
 */
GError* zylix_future_get_error(ZylixFuture* future);

/**
 * Add success callback
 */
ZylixFuture* zylix_future_then(
    ZylixFuture* future,
    ZylixFutureThenCallback callback,
    gpointer user_data
);

/**
 * Add error callback
 */
ZylixFuture* zylix_future_catch(
    ZylixFuture* future,
    ZylixFutureCatchCallback callback,
    gpointer user_data
);

/**
 * Add finally callback
 */
ZylixFuture* zylix_future_finally(
    ZylixFuture* future,
    ZylixFutureFinallyCallback callback,
    gpointer user_data
);

/**
 * Set timeout
 */
ZylixFuture* zylix_future_timeout(ZylixFuture* future, guint milliseconds);

/**
 * Set cancellable
 */
ZylixFuture* zylix_future_with_cancellable(ZylixFuture* future, GCancellable* cancellable);

/* ============================================================================
 * HTTP Client
 * ============================================================================ */

typedef struct _ZylixHttpResponse ZylixHttpResponse;

struct _ZylixHttpResponse {
    guint status_code;
    GHashTable* headers;
    GBytes* body;
};

typedef struct _ZylixHttpClient ZylixHttpClient;

/**
 * Create HTTP client
 */
ZylixHttpClient* zylix_http_client_new(void);

/**
 * Free HTTP client
 */
void zylix_http_client_free(ZylixHttpClient* client);

/**
 * Free HTTP response
 */
void zylix_http_response_free(ZylixHttpResponse* response);

/**
 * Get response body as string
 */
const char* zylix_http_response_get_text(ZylixHttpResponse* response);

/**
 * Check if response is success
 */
gboolean zylix_http_response_is_success(ZylixHttpResponse* response);

/**
 * GET request
 */
ZylixFuture* zylix_http_get(ZylixHttpClient* client, const char* url);

/**
 * POST request
 */
ZylixFuture* zylix_http_post(ZylixHttpClient* client, const char* url, const char* body);

/**
 * PUT request
 */
ZylixFuture* zylix_http_put(ZylixHttpClient* client, const char* url, const char* body);

/**
 * DELETE request
 */
ZylixFuture* zylix_http_delete(ZylixHttpClient* client, const char* url);

/**
 * POST JSON request
 */
ZylixFuture* zylix_http_post_json(ZylixHttpClient* client, const char* url, const char* json);

/* ============================================================================
 * Task Scheduler
 * ============================================================================ */

typedef enum {
    ZYLIX_TASK_PRIORITY_LOW = 0,
    ZYLIX_TASK_PRIORITY_NORMAL = 1,
    ZYLIX_TASK_PRIORITY_HIGH = 2,
    ZYLIX_TASK_PRIORITY_CRITICAL = 3
} ZylixTaskPriority;

typedef enum {
    ZYLIX_TASK_STATE_QUEUED,
    ZYLIX_TASK_STATE_RUNNING,
    ZYLIX_TASK_STATE_COMPLETED,
    ZYLIX_TASK_STATE_FAILED,
    ZYLIX_TASK_STATE_CANCELLED
} ZylixTaskState;

typedef struct _ZylixTaskHandle ZylixTaskHandle;
typedef struct _ZylixScheduler ZylixScheduler;

typedef void (*ZylixTaskCallback)(ZylixTaskHandle* handle, gpointer user_data);

/**
 * Create scheduler
 */
ZylixScheduler* zylix_scheduler_new(void);

/**
 * Free scheduler
 */
void zylix_scheduler_free(ZylixScheduler* scheduler);

/**
 * Start scheduler
 */
void zylix_scheduler_start(ZylixScheduler* scheduler);

/**
 * Stop scheduler
 */
void zylix_scheduler_stop(ZylixScheduler* scheduler);

/**
 * Schedule a task
 */
ZylixTaskHandle* zylix_scheduler_schedule(
    ZylixScheduler* scheduler,
    ZylixTaskCallback callback,
    gpointer user_data,
    ZylixTaskPriority priority
);

/**
 * Schedule a delayed task
 */
ZylixTaskHandle* zylix_scheduler_schedule_delayed(
    ZylixScheduler* scheduler,
    ZylixTaskCallback callback,
    gpointer user_data,
    guint delay_ms,
    ZylixTaskPriority priority
);

/**
 * Get pending task count
 */
guint zylix_scheduler_pending_count(ZylixScheduler* scheduler);

/**
 * Cancel a task
 */
void zylix_task_handle_cancel(ZylixTaskHandle* handle);

/**
 * Check if task is cancelled
 */
gboolean zylix_task_handle_is_cancelled(ZylixTaskHandle* handle);

/**
 * Get task state
 */
ZylixTaskState zylix_task_handle_get_state(ZylixTaskHandle* handle);

/* ============================================================================
 * Async Utilities
 * ============================================================================ */

/**
 * Wait for all futures to complete
 */
ZylixFuture* zylix_async_all(ZylixFuture** futures, guint count);

/**
 * Wait for first future to complete
 */
ZylixFuture* zylix_async_race(ZylixFuture** futures, guint count);

/**
 * Create a delay future
 */
ZylixFuture* zylix_async_delay(guint milliseconds);

/**
 * Retry operation with exponential backoff
 */
typedef ZylixFuture* (*ZylixRetryCallback)(gpointer user_data);

ZylixFuture* zylix_async_retry(
    ZylixRetryCallback callback,
    gpointer user_data,
    guint max_attempts,
    guint initial_delay_ms,
    guint max_delay_ms
);

/* ============================================================================
 * Global Instances
 * ============================================================================ */

/**
 * Get shared HTTP client
 */
ZylixHttpClient* zylix_http_client_shared(void);

/**
 * Get shared scheduler
 */
ZylixScheduler* zylix_scheduler_shared(void);

/**
 * Initialize async system
 */
void zylix_async_init(void);

/**
 * Cleanup async system
 */
void zylix_async_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_ASYNC_H */
