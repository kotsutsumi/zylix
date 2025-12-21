/*
 * zylix_hot_reload.h
 * GTK4 Hot Reload Header for Zylix v0.5.0
 *
 * Provides hot reload functionality for Linux development.
 * Features:
 * - inotify-based file watching
 * - State preservation
 * - Error overlay
 * - WebSocket communication
 */

#ifndef ZYLIX_HOT_RELOAD_H
#define ZYLIX_HOT_RELOAD_H

#include <glib.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <libsoup/soup.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Hot Reload State
 * ============================================================================ */

typedef enum {
    ZYLIX_HOT_RELOAD_STATE_DISCONNECTED,
    ZYLIX_HOT_RELOAD_STATE_CONNECTING,
    ZYLIX_HOT_RELOAD_STATE_CONNECTED,
    ZYLIX_HOT_RELOAD_STATE_RELOADING,
    ZYLIX_HOT_RELOAD_STATE_ERROR
} ZylixHotReloadState;

/* ============================================================================
 * File Change Type
 * ============================================================================ */

typedef enum {
    ZYLIX_FILE_CHANGE_CREATED,
    ZYLIX_FILE_CHANGE_MODIFIED,
    ZYLIX_FILE_CHANGE_DELETED,
    ZYLIX_FILE_CHANGE_RENAMED
} ZylixFileChangeType;

/* ============================================================================
 * Build Error
 * ============================================================================ */

typedef struct _ZylixBuildError ZylixBuildError;

struct _ZylixBuildError {
    char* file;
    int line;
    int column;
    char* message;
    char* severity;
};

/**
 * Create a new build error
 */
ZylixBuildError* zylix_build_error_new(
    const char* file,
    int line,
    int column,
    const char* message,
    const char* severity
);

/**
 * Free a build error
 */
void zylix_build_error_free(ZylixBuildError* error);

/* ============================================================================
 * File Watcher
 * ============================================================================ */

typedef struct _ZylixFileWatcher ZylixFileWatcher;

typedef void (*ZylixFileWatcherCallback)(
    const char* path,
    ZylixFileChangeType change_type,
    gpointer user_data
);

/**
 * Create a new file watcher
 */
ZylixFileWatcher* zylix_file_watcher_new(void);

/**
 * Free a file watcher
 */
void zylix_file_watcher_free(ZylixFileWatcher* watcher);

/**
 * Add a path to watch
 */
void zylix_file_watcher_add_path(ZylixFileWatcher* watcher, const char* path);

/**
 * Add an ignore pattern
 */
void zylix_file_watcher_add_ignore(ZylixFileWatcher* watcher, const char* pattern);

/**
 * Set the callback
 */
void zylix_file_watcher_set_callback(
    ZylixFileWatcher* watcher,
    ZylixFileWatcherCallback callback,
    gpointer user_data
);

/**
 * Start watching
 */
void zylix_file_watcher_start(ZylixFileWatcher* watcher);

/**
 * Stop watching
 */
void zylix_file_watcher_stop(ZylixFileWatcher* watcher);

/* ============================================================================
 * Hot Reload Client
 * ============================================================================ */

typedef struct _ZylixHotReloadClient ZylixHotReloadClient;

typedef void (*ZylixHotReloadCallback)(gpointer user_data);
typedef void (*ZylixHotUpdateCallback)(const char* module, gpointer user_data);
typedef void (*ZylixErrorCallback)(ZylixBuildError* error, gpointer user_data);

/**
 * Get the shared hot reload client
 */
ZylixHotReloadClient* zylix_hot_reload_client_shared(void);

/**
 * Create a new hot reload client
 */
ZylixHotReloadClient* zylix_hot_reload_client_new(void);

/**
 * Free a hot reload client
 */
void zylix_hot_reload_client_free(ZylixHotReloadClient* client);

/**
 * Set the server URL
 */
void zylix_hot_reload_client_set_url(ZylixHotReloadClient* client, const char* url);

/**
 * Connect to the server
 */
void zylix_hot_reload_client_connect(ZylixHotReloadClient* client);

/**
 * Disconnect from the server
 */
void zylix_hot_reload_client_disconnect(ZylixHotReloadClient* client);

/**
 * Get the current state
 */
ZylixHotReloadState zylix_hot_reload_client_get_state(ZylixHotReloadClient* client);

/**
 * Set reload callback
 */
void zylix_hot_reload_client_on_reload(
    ZylixHotReloadClient* client,
    ZylixHotReloadCallback callback,
    gpointer user_data
);

/**
 * Set hot update callback
 */
void zylix_hot_reload_client_on_hot_update(
    ZylixHotReloadClient* client,
    ZylixHotUpdateCallback callback,
    gpointer user_data
);

/**
 * Set error callback
 */
void zylix_hot_reload_client_on_error(
    ZylixHotReloadClient* client,
    ZylixErrorCallback callback,
    gpointer user_data
);

/* ============================================================================
 * State Preservation
 * ============================================================================ */

typedef struct _ZylixStateManager ZylixStateManager;

/**
 * Get the shared state manager
 */
ZylixStateManager* zylix_state_manager_shared(void);

/**
 * Create a new state manager
 */
ZylixStateManager* zylix_state_manager_new(void);

/**
 * Free a state manager
 */
void zylix_state_manager_free(ZylixStateManager* manager);

/**
 * Set a string value
 */
void zylix_state_manager_set_string(
    ZylixStateManager* manager,
    const char* key,
    const char* value
);

/**
 * Get a string value
 */
const char* zylix_state_manager_get_string(
    ZylixStateManager* manager,
    const char* key
);

/**
 * Set an integer value
 */
void zylix_state_manager_set_int(
    ZylixStateManager* manager,
    const char* key,
    int value
);

/**
 * Get an integer value
 */
int zylix_state_manager_get_int(
    ZylixStateManager* manager,
    const char* key
);

/**
 * Save state to disk
 */
void zylix_state_manager_save(ZylixStateManager* manager);

/**
 * Restore state from disk
 */
void zylix_state_manager_restore(ZylixStateManager* manager);

/**
 * Clear all state
 */
void zylix_state_manager_clear(ZylixStateManager* manager);

/* ============================================================================
 * Error Overlay
 * ============================================================================ */

typedef struct _ZylixErrorOverlay ZylixErrorOverlay;

/**
 * Create a new error overlay
 */
ZylixErrorOverlay* zylix_error_overlay_new(GtkWindow* parent);

/**
 * Free an error overlay
 */
void zylix_error_overlay_free(ZylixErrorOverlay* overlay);

/**
 * Show the overlay with an error
 */
void zylix_error_overlay_show(ZylixErrorOverlay* overlay, ZylixBuildError* error);

/**
 * Hide the overlay
 */
void zylix_error_overlay_hide(ZylixErrorOverlay* overlay);

/**
 * Check if overlay is visible
 */
gboolean zylix_error_overlay_is_visible(ZylixErrorOverlay* overlay);

/* ============================================================================
 * Development Server
 * ============================================================================ */

typedef struct _ZylixDevServer ZylixDevServer;

/**
 * Get the shared dev server
 */
ZylixDevServer* zylix_dev_server_shared(void);

/**
 * Create a new dev server
 */
ZylixDevServer* zylix_dev_server_new(void);

/**
 * Free a dev server
 */
void zylix_dev_server_free(ZylixDevServer* server);

/**
 * Set the port
 */
void zylix_dev_server_set_port(ZylixDevServer* server, int port);

/**
 * Add a watch path
 */
void zylix_dev_server_add_watch_path(ZylixDevServer* server, const char* path);

/**
 * Start the server
 */
void zylix_dev_server_start(ZylixDevServer* server);

/**
 * Stop the server
 */
void zylix_dev_server_stop(ZylixDevServer* server);

/**
 * Check if server is running
 */
gboolean zylix_dev_server_is_running(ZylixDevServer* server);

/**
 * Get connected client count
 */
int zylix_dev_server_get_client_count(ZylixDevServer* server);

/* ============================================================================
 * GTK Widget Integration
 * ============================================================================ */

/**
 * Enable hot reload for a window
 */
void zylix_gtk_window_enable_hot_reload(GtkWindow* window);

/**
 * Disable hot reload for a window
 */
void zylix_gtk_window_disable_hot_reload(GtkWindow* window);

/**
 * Create an error overlay widget
 */
GtkWidget* zylix_gtk_create_error_overlay_widget(ZylixBuildError* error);

/* ============================================================================
 * Global Initialization
 * ============================================================================ */

/**
 * Initialize hot reload system
 */
void zylix_hot_reload_init(void);

/**
 * Cleanup hot reload system
 */
void zylix_hot_reload_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_HOT_RELOAD_H */
