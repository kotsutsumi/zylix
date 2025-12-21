/*
 * zylix_router.h
 * GTK4 Router Header for Zylix v0.3.0
 *
 * Provides GTK4 navigation integration for Zylix routing system.
 * Features:
 * - GtkStack-based navigation
 * - Deep link handling (D-Bus activation)
 * - Route parameters and query strings
 * - Navigation guards
 * - History management
 */

#ifndef ZYLIX_ROUTER_H
#define ZYLIX_ROUTER_H

#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Type Definitions
 * ============================================================================ */

typedef struct _ZylixRouter ZylixRouter;
typedef struct _ZylixRoute ZylixRoute;
typedef struct _ZylixRouteContext ZylixRouteContext;
typedef struct _ZylixParsedURL ZylixParsedURL;
typedef struct _ZylixRouteParam ZylixRouteParam;
typedef struct _ZylixQueryParam ZylixQueryParam;

/* ============================================================================
 * Route Parameter Types
 * ============================================================================ */

struct _ZylixRouteParam {
    const char* name;
    const char* value;
};

struct _ZylixQueryParam {
    const char* key;
    const char* value;
};

struct _ZylixParsedURL {
    char* path;
    ZylixRouteParam* params;
    int param_count;
    ZylixQueryParam* query;
    int query_count;
    char* fragment;
};

/* ============================================================================
 * Guard Types
 * ============================================================================ */

typedef enum {
    ZYLIX_GUARD_ALLOW,
    ZYLIX_GUARD_DENY,
    ZYLIX_GUARD_REDIRECT
} ZylixGuardResult;

typedef struct {
    ZylixGuardResult result;
    const char* redirect_to;
    const char* message;
} ZylixGuardResponse;

typedef ZylixGuardResponse (*ZylixGuardFn)(ZylixRouteContext* context);

/* ============================================================================
 * Route Metadata
 * ============================================================================ */

typedef struct {
    const char* title;
    bool requires_auth;
    const char** permissions;
    int permission_count;
    const char* icon;
    bool show_in_sidebar;
} ZylixRouteMeta;

/* ============================================================================
 * Route Definition
 * ============================================================================ */

struct _ZylixRoute {
    const char* path;
    ZylixRouteMeta meta;
    ZylixGuardFn* guards;
    int guard_count;
    ZylixRoute* children;
    int child_count;
    GtkWidget* (*create_widget)(ZylixRouteContext* context);
};

/* ============================================================================
 * Route Context
 * ============================================================================ */

struct _ZylixRouteContext {
    ZylixParsedURL* url;
    ZylixRouter* router;
    bool is_authenticated;
    const char** user_roles;
    int role_count;
    void* user_data;
};

/* ============================================================================
 * Navigation Event
 * ============================================================================ */

typedef enum {
    ZYLIX_NAV_PUSH,
    ZYLIX_NAV_REPLACE,
    ZYLIX_NAV_BACK,
    ZYLIX_NAV_FORWARD,
    ZYLIX_NAV_DEEP_LINK
} ZylixNavigationEvent;

typedef void (*ZylixNavigationCallback)(
    ZylixNavigationEvent event,
    const char* path,
    ZylixRouteContext* context,
    void* user_data
);

/* ============================================================================
 * Router API
 * ============================================================================ */

/**
 * Create a new router instance
 */
ZylixRouter* zylix_router_new(void);

/**
 * Free router resources
 */
void zylix_router_free(ZylixRouter* router);

/**
 * Define routes
 */
void zylix_router_define_routes(ZylixRouter* router, ZylixRoute* routes, int count);

/**
 * Set base path
 */
void zylix_router_set_base_path(ZylixRouter* router, const char* path);

/**
 * Set not found handler
 */
void zylix_router_set_not_found(ZylixRouter* router, void (*handler)(ZylixParsedURL* url));

/**
 * Add navigation callback
 */
void zylix_router_on_navigate(
    ZylixRouter* router,
    ZylixNavigationCallback callback,
    void* user_data
);

/**
 * Set GTK stack for navigation
 */
void zylix_router_set_stack(ZylixRouter* router, GtkStack* stack);

/**
 * Navigate to path (push)
 */
void zylix_router_push(ZylixRouter* router, const char* path);

/**
 * Replace current path
 */
void zylix_router_replace(ZylixRouter* router, const char* path);

/**
 * Go back in history
 */
void zylix_router_back(ZylixRouter* router);

/**
 * Go forward in history
 */
void zylix_router_forward(ZylixRouter* router);

/**
 * Check if can go back
 */
bool zylix_router_can_go_back(ZylixRouter* router);

/**
 * Check if can go forward
 */
bool zylix_router_can_go_forward(ZylixRouter* router);

/**
 * Get current path
 */
const char* zylix_router_get_current_path(ZylixRouter* router);

/**
 * Get current context
 */
ZylixRouteContext* zylix_router_get_context(ZylixRouter* router);

/**
 * Handle deep link
 */
void zylix_router_handle_deep_link(ZylixRouter* router, const char* url);

/* ============================================================================
 * URL Parsing
 * ============================================================================ */

/**
 * Parse URL string
 */
ZylixParsedURL* zylix_parse_url(const char* url);

/**
 * Free parsed URL
 */
void zylix_parsed_url_free(ZylixParsedURL* url);

/**
 * Get param from parsed URL
 */
const char* zylix_parsed_url_get_param(ZylixParsedURL* url, const char* name);

/**
 * Get query param from parsed URL
 */
const char* zylix_parsed_url_get_query(ZylixParsedURL* url, const char* key);

/* ============================================================================
 * Route Context Helpers
 * ============================================================================ */

/**
 * Check if context has role
 */
bool zylix_context_has_role(ZylixRouteContext* context, const char* role);

/**
 * Create new context
 */
ZylixRouteContext* zylix_context_new(ZylixParsedURL* url, ZylixRouter* router);

/**
 * Free context
 */
void zylix_context_free(ZylixRouteContext* context);

/* ============================================================================
 * Common Guards
 * ============================================================================ */

/**
 * Guard that requires authentication
 */
ZylixGuardResponse zylix_guard_require_auth(ZylixRouteContext* context);

/**
 * Create guard that requires a specific role
 */
ZylixGuardFn zylix_guard_require_role(const char* role);

/* ============================================================================
 * GTK Integration
 * ============================================================================ */

/**
 * Create sidebar navigation list
 */
GtkWidget* zylix_router_create_sidebar(ZylixRouter* router);

/**
 * Create navigation header bar
 */
GtkWidget* zylix_router_create_header_bar(ZylixRouter* router);

/**
 * Setup AdwNavigationSplitView with router
 */
void zylix_router_setup_split_view(
    ZylixRouter* router,
    GtkWidget* split_view,
    GtkWidget* sidebar,
    GtkWidget* content
);

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_ROUTER_H */
