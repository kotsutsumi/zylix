/*
 * zylix_router.c
 * GTK4 Router Implementation for Zylix v0.3.0
 */

#include "zylix_router.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ============================================================================
 * Router Internal Structure
 * ============================================================================ */

struct _ZylixRouter {
    ZylixRoute* routes;
    int route_count;
    char* base_path;
    char* current_path;
    ZylixRouteContext* current_context;
    GtkStack* stack;

    /* History */
    char** history;
    int history_count;
    int history_index;
    int history_capacity;

    /* Callbacks */
    struct {
        ZylixNavigationCallback callback;
        void* user_data;
    }* nav_callbacks;
    int callback_count;
    int callback_capacity;

    /* Not found handler */
    void (*not_found_handler)(ZylixParsedURL* url);
};

/* ============================================================================
 * Router Creation and Destruction
 * ============================================================================ */

ZylixRouter* zylix_router_new(void) {
    ZylixRouter* router = calloc(1, sizeof(ZylixRouter));
    if (!router) return NULL;

    router->history_capacity = 100;
    router->history = calloc(router->history_capacity, sizeof(char*));
    router->history_index = -1;

    router->callback_capacity = 10;
    router->nav_callbacks = calloc(router->callback_capacity, sizeof(*router->nav_callbacks));

    return router;
}

void zylix_router_free(ZylixRouter* router) {
    if (!router) return;

    free(router->base_path);
    free(router->current_path);

    for (int i = 0; i < router->history_count; i++) {
        free(router->history[i]);
    }
    free(router->history);
    free(router->nav_callbacks);

    if (router->current_context) {
        zylix_context_free(router->current_context);
    }

    free(router);
}

/* ============================================================================
 * Router Configuration
 * ============================================================================ */

void zylix_router_define_routes(ZylixRouter* router, ZylixRoute* routes, int count) {
    router->routes = routes;
    router->route_count = count;
}

void zylix_router_set_base_path(ZylixRouter* router, const char* path) {
    free(router->base_path);
    router->base_path = path ? strdup(path) : NULL;
}

void zylix_router_set_not_found(ZylixRouter* router, void (*handler)(ZylixParsedURL* url)) {
    router->not_found_handler = handler;
}

void zylix_router_on_navigate(
    ZylixRouter* router,
    ZylixNavigationCallback callback,
    void* user_data
) {
    if (router->callback_count >= router->callback_capacity) {
        router->callback_capacity *= 2;
        router->nav_callbacks = realloc(
            router->nav_callbacks,
            router->callback_capacity * sizeof(*router->nav_callbacks)
        );
    }

    router->nav_callbacks[router->callback_count].callback = callback;
    router->nav_callbacks[router->callback_count].user_data = user_data;
    router->callback_count++;
}

void zylix_router_set_stack(ZylixRouter* router, GtkStack* stack) {
    router->stack = stack;
}

/* ============================================================================
 * URL Parsing
 * ============================================================================ */

ZylixParsedURL* zylix_parse_url(const char* url) {
    ZylixParsedURL* parsed = calloc(1, sizeof(ZylixParsedURL));
    if (!parsed) return NULL;

    char* url_copy = strdup(url);
    char* path = url_copy;

    /* Extract fragment */
    char* hash = strchr(path, '#');
    if (hash) {
        parsed->fragment = strdup(hash + 1);
        *hash = '\0';
    }

    /* Extract query string */
    char* query = strchr(path, '?');
    char* query_string = NULL;
    if (query) {
        query_string = strdup(query + 1);
        *query = '\0';
    }

    parsed->path = strdup(path);

    /* Parse query parameters */
    if (query_string) {
        /* Count parameters */
        int count = 1;
        for (char* p = query_string; *p; p++) {
            if (*p == '&') count++;
        }

        parsed->query = calloc(count, sizeof(ZylixQueryParam));
        parsed->query_count = 0;

        char* pair = strtok(query_string, "&");
        while (pair && parsed->query_count < count) {
            char* eq = strchr(pair, '=');
            if (eq) {
                *eq = '\0';
                parsed->query[parsed->query_count].key = strdup(pair);
                parsed->query[parsed->query_count].value = strdup(eq + 1);
                parsed->query_count++;
            }
            pair = strtok(NULL, "&");
        }
        free(query_string);
    }

    free(url_copy);
    return parsed;
}

void zylix_parsed_url_free(ZylixParsedURL* url) {
    if (!url) return;

    free(url->path);
    free(url->fragment);

    for (int i = 0; i < url->param_count; i++) {
        free((void*)url->params[i].name);
        free((void*)url->params[i].value);
    }
    free(url->params);

    for (int i = 0; i < url->query_count; i++) {
        free((void*)url->query[i].key);
        free((void*)url->query[i].value);
    }
    free(url->query);

    free(url);
}

const char* zylix_parsed_url_get_param(ZylixParsedURL* url, const char* name) {
    for (int i = 0; i < url->param_count; i++) {
        if (strcmp(url->params[i].name, name) == 0) {
            return url->params[i].value;
        }
    }
    return NULL;
}

const char* zylix_parsed_url_get_query(ZylixParsedURL* url, const char* key) {
    for (int i = 0; i < url->query_count; i++) {
        if (strcmp(url->query[i].key, key) == 0) {
            return url->query[i].value;
        }
    }
    return NULL;
}

/* ============================================================================
 * Route Matching
 * ============================================================================ */

static ZylixRouteParam* match_pattern(
    const char* pattern,
    const char* path,
    int* param_count
) {
    *param_count = 0;

    /* Split pattern and path */
    char* pattern_copy = strdup(pattern);
    char* path_copy = strdup(path);

    /* Count segments */
    int pattern_segs = 0, path_segs = 0;
    for (char* p = pattern_copy; *p; p++) if (*p == '/') pattern_segs++;
    for (char* p = path_copy; *p; p++) if (*p == '/') path_segs++;

    if (pattern_segs != path_segs) {
        free(pattern_copy);
        free(path_copy);
        return NULL;
    }

    /* Allocate params (max possible = number of segments) */
    ZylixRouteParam* params = calloc(pattern_segs + 1, sizeof(ZylixRouteParam));

    char* pattern_token = strtok(pattern_copy, "/");
    char* path_token = strtok(path_copy, "/");

    while (pattern_token && path_token) {
        if (pattern_token[0] == ':') {
            /* Parameter */
            params[*param_count].name = strdup(pattern_token + 1);
            params[*param_count].value = strdup(path_token);
            (*param_count)++;
        } else if (pattern_token[0] == '*') {
            /* Wildcard */
            params[*param_count].name = strdup("wildcard");
            params[*param_count].value = strdup(path_token);
            (*param_count)++;
        } else if (strcmp(pattern_token, path_token) != 0) {
            /* No match */
            for (int i = 0; i < *param_count; i++) {
                free((void*)params[i].name);
                free((void*)params[i].value);
            }
            free(params);
            free(pattern_copy);
            free(path_copy);
            return NULL;
        }

        pattern_token = strtok(NULL, "/");
        path_token = strtok(NULL, "/");
    }

    free(pattern_copy);
    free(path_copy);
    return params;
}

static ZylixRoute* find_route(ZylixRouter* router, const char* path, int* param_count, ZylixRouteParam** params) {
    for (int i = 0; i < router->route_count; i++) {
        ZylixRoute* route = &router->routes[i];
        *params = match_pattern(route->path, path, param_count);
        if (*params) {
            return route;
        }

        /* Check children */
        for (int j = 0; j < route->child_count; j++) {
            ZylixRoute* child = &route->children[j];
            char full_path[512];
            snprintf(full_path, sizeof(full_path), "%s%s", route->path, child->path);
            *params = match_pattern(full_path, path, param_count);
            if (*params) {
                return child;
            }
        }
    }
    return NULL;
}

/* ============================================================================
 * Navigation
 * ============================================================================ */

static void navigate_internal(
    ZylixRouter* router,
    const char* path,
    ZylixNavigationEvent event,
    bool update_history
) {
    /* Build full path */
    char full_path[512];
    if (router->base_path) {
        snprintf(full_path, sizeof(full_path), "%s%s", router->base_path, path);
    } else {
        strncpy(full_path, path, sizeof(full_path) - 1);
    }

    /* Parse URL */
    ZylixParsedURL* parsed = zylix_parse_url(full_path);
    if (!parsed) return;

    /* Find route */
    int param_count = 0;
    ZylixRouteParam* params = NULL;
    ZylixRoute* route = find_route(router, parsed->path, &param_count, &params);

    if (!route) {
        if (router->not_found_handler) {
            router->not_found_handler(parsed);
        }
        zylix_parsed_url_free(parsed);
        return;
    }

    /* Update parsed URL with params */
    parsed->params = params;
    parsed->param_count = param_count;

    /* Create context */
    ZylixRouteContext* context = zylix_context_new(parsed, router);

    /* Check guards */
    for (int i = 0; i < route->guard_count; i++) {
        ZylixGuardResponse response = route->guards[i](context);
        switch (response.result) {
            case ZYLIX_GUARD_ALLOW:
                continue;
            case ZYLIX_GUARD_DENY:
                printf("[ZylixRouter] Navigation denied: %s\n", response.message ? response.message : "");
                zylix_context_free(context);
                return;
            case ZYLIX_GUARD_REDIRECT:
                zylix_context_free(context);
                zylix_router_replace(router, response.redirect_to);
                return;
        }
    }

    /* Update history */
    if (update_history && (event == ZYLIX_NAV_PUSH || event == ZYLIX_NAV_DEEP_LINK)) {
        /* Remove forward history */
        for (int i = router->history_index + 1; i < router->history_count; i++) {
            free(router->history[i]);
        }
        router->history_count = router->history_index + 1;

        /* Add new entry */
        if (router->history_count >= router->history_capacity) {
            /* Remove oldest */
            free(router->history[0]);
            memmove(router->history, router->history + 1, (router->history_count - 1) * sizeof(char*));
            router->history_count--;
        }

        router->history[router->history_count] = strdup(path);
        router->history_count++;
        router->history_index = router->history_count - 1;
    }

    /* Update state */
    free(router->current_path);
    router->current_path = strdup(path);

    if (router->current_context) {
        zylix_context_free(router->current_context);
    }
    router->current_context = context;

    /* Update stack if available */
    if (router->stack && route->create_widget) {
        GtkWidget* widget = route->create_widget(context);
        if (widget) {
            gtk_stack_add_named(router->stack, widget, path);
            gtk_stack_set_visible_child(router->stack, widget);
        }
    }

    /* Notify callbacks */
    for (int i = 0; i < router->callback_count; i++) {
        router->nav_callbacks[i].callback(
            event, path, context,
            router->nav_callbacks[i].user_data
        );
    }
}

void zylix_router_push(ZylixRouter* router, const char* path) {
    navigate_internal(router, path, ZYLIX_NAV_PUSH, true);
}

void zylix_router_replace(ZylixRouter* router, const char* path) {
    navigate_internal(router, path, ZYLIX_NAV_REPLACE, false);
}

void zylix_router_back(ZylixRouter* router) {
    if (!zylix_router_can_go_back(router)) return;
    router->history_index--;
    navigate_internal(router, router->history[router->history_index], ZYLIX_NAV_BACK, false);
}

void zylix_router_forward(ZylixRouter* router) {
    if (!zylix_router_can_go_forward(router)) return;
    router->history_index++;
    navigate_internal(router, router->history[router->history_index], ZYLIX_NAV_FORWARD, false);
}

bool zylix_router_can_go_back(ZylixRouter* router) {
    return router->history_index > 0;
}

bool zylix_router_can_go_forward(ZylixRouter* router) {
    return router->history_index < router->history_count - 1;
}

const char* zylix_router_get_current_path(ZylixRouter* router) {
    return router->current_path;
}

ZylixRouteContext* zylix_router_get_context(ZylixRouter* router) {
    return router->current_context;
}

void zylix_router_handle_deep_link(ZylixRouter* router, const char* url) {
    navigate_internal(router, url, ZYLIX_NAV_DEEP_LINK, true);
}

/* ============================================================================
 * Context Helpers
 * ============================================================================ */

bool zylix_context_has_role(ZylixRouteContext* context, const char* role) {
    for (int i = 0; i < context->role_count; i++) {
        if (strcmp(context->user_roles[i], role) == 0) {
            return true;
        }
    }
    return false;
}

ZylixRouteContext* zylix_context_new(ZylixParsedURL* url, ZylixRouter* router) {
    ZylixRouteContext* context = calloc(1, sizeof(ZylixRouteContext));
    context->url = url;
    context->router = router;
    return context;
}

void zylix_context_free(ZylixRouteContext* context) {
    if (!context) return;
    if (context->url) {
        zylix_parsed_url_free(context->url);
    }
    free(context);
}

/* ============================================================================
 * Common Guards
 * ============================================================================ */

ZylixGuardResponse zylix_guard_require_auth(ZylixRouteContext* context) {
    if (context->is_authenticated) {
        return (ZylixGuardResponse){ .result = ZYLIX_GUARD_ALLOW };
    }
    return (ZylixGuardResponse){
        .result = ZYLIX_GUARD_REDIRECT,
        .redirect_to = "/login"
    };
}

/* Role guard storage */
static const char* _role_guard_role = NULL;

static ZylixGuardResponse _role_guard_fn(ZylixRouteContext* context) {
    if (zylix_context_has_role(context, _role_guard_role)) {
        return (ZylixGuardResponse){ .result = ZYLIX_GUARD_ALLOW };
    }
    return (ZylixGuardResponse){
        .result = ZYLIX_GUARD_DENY,
        .message = "Insufficient permissions"
    };
}

ZylixGuardFn zylix_guard_require_role(const char* role) {
    _role_guard_role = role;
    return _role_guard_fn;
}

/* ============================================================================
 * GTK Integration
 * ============================================================================ */

static void on_sidebar_row_activated(GtkListBox* box, GtkListBoxRow* row, gpointer user_data) {
    ZylixRouter* router = (ZylixRouter*)user_data;
    const char* path = g_object_get_data(G_OBJECT(row), "path");
    if (path) {
        zylix_router_push(router, path);
    }
}

GtkWidget* zylix_router_create_sidebar(ZylixRouter* router) {
    GtkWidget* list = gtk_list_box_new();

    for (int i = 0; i < router->route_count; i++) {
        ZylixRoute* route = &router->routes[i];
        if (!route->meta.show_in_sidebar) continue;

        GtkWidget* row = gtk_list_box_row_new();
        GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);

        if (route->meta.icon) {
            GtkWidget* icon = gtk_image_new_from_icon_name(route->meta.icon);
            gtk_box_append(GTK_BOX(box), icon);
        }

        const char* title = route->meta.title ? route->meta.title : route->path;
        GtkWidget* label = gtk_label_new(title);
        gtk_box_append(GTK_BOX(box), label);

        gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row), box);
        g_object_set_data(G_OBJECT(row), "path", (gpointer)route->path);
        gtk_list_box_append(GTK_LIST_BOX(list), row);
    }

    g_signal_connect(list, "row-activated", G_CALLBACK(on_sidebar_row_activated), router);

    return list;
}

GtkWidget* zylix_router_create_header_bar(ZylixRouter* router) {
    GtkWidget* header = gtk_header_bar_new();

    GtkWidget* back_btn = gtk_button_new_from_icon_name("go-previous-symbolic");
    gtk_widget_set_sensitive(back_btn, zylix_router_can_go_back(router));
    g_signal_connect_swapped(back_btn, "clicked", G_CALLBACK(zylix_router_back), router);
    gtk_header_bar_pack_start(GTK_HEADER_BAR(header), back_btn);

    GtkWidget* forward_btn = gtk_button_new_from_icon_name("go-next-symbolic");
    gtk_widget_set_sensitive(forward_btn, zylix_router_can_go_forward(router));
    g_signal_connect_swapped(forward_btn, "clicked", G_CALLBACK(zylix_router_forward), router);
    gtk_header_bar_pack_start(GTK_HEADER_BAR(header), forward_btn);

    return header;
}
