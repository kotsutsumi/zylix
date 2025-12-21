/*
 * zylix_components.h
 * GTK4 Component Types and Factory for Zylix v0.2.0
 *
 * This file defines the component type enumeration and factory functions
 * for creating GTK4 widgets from Zylix component specifications.
 * Component type values must stay in sync with core/src/component.zig
 */

#ifndef ZYLIX_COMPONENTS_H
#define ZYLIX_COMPONENTS_H

#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Component Type Enumeration
 * Values must match core/src/component.zig exactly
 * ============================================================================ */

typedef enum {
    /* Basic Components (0-9) */
    ZYLIX_COMPONENT_CONTAINER   = 0,
    ZYLIX_COMPONENT_TEXT        = 1,
    ZYLIX_COMPONENT_BUTTON      = 2,
    ZYLIX_COMPONENT_INPUT       = 3,
    ZYLIX_COMPONENT_IMAGE       = 4,
    ZYLIX_COMPONENT_LINK        = 5,
    ZYLIX_COMPONENT_LIST        = 6,
    ZYLIX_COMPONENT_LIST_ITEM   = 7,
    ZYLIX_COMPONENT_HEADING     = 8,
    ZYLIX_COMPONENT_PARAGRAPH   = 9,

    /* Form Components (10-20) */
    ZYLIX_COMPONENT_SELECT        = 10,
    ZYLIX_COMPONENT_CHECKBOX      = 11,
    ZYLIX_COMPONENT_RADIO         = 12,
    ZYLIX_COMPONENT_TEXTAREA      = 13,
    ZYLIX_COMPONENT_TOGGLE_SWITCH = 14,
    ZYLIX_COMPONENT_SLIDER        = 15,
    ZYLIX_COMPONENT_DATE_PICKER   = 16,
    ZYLIX_COMPONENT_TIME_PICKER   = 17,
    ZYLIX_COMPONENT_FILE_INPUT    = 18,
    ZYLIX_COMPONENT_COLOR_PICKER  = 19,
    ZYLIX_COMPONENT_FORM          = 20,

    /* Layout Components (21-28) */
    ZYLIX_COMPONENT_STACK        = 21,
    ZYLIX_COMPONENT_GRID         = 22,
    ZYLIX_COMPONENT_SCROLL_VIEW  = 23,
    ZYLIX_COMPONENT_SPACER       = 24,
    ZYLIX_COMPONENT_DIVIDER      = 25,
    ZYLIX_COMPONENT_CARD         = 26,
    ZYLIX_COMPONENT_ASPECT_RATIO = 27,
    ZYLIX_COMPONENT_SAFE_AREA    = 28,

    /* Navigation Components (30-34) */
    ZYLIX_COMPONENT_NAV_BAR    = 30,
    ZYLIX_COMPONENT_TAB_BAR    = 31,
    ZYLIX_COMPONENT_DRAWER     = 32,
    ZYLIX_COMPONENT_BREADCRUMB = 33,
    ZYLIX_COMPONENT_PAGINATION = 34,

    /* Feedback Components (40-46) */
    ZYLIX_COMPONENT_ALERT    = 40,
    ZYLIX_COMPONENT_TOAST    = 41,
    ZYLIX_COMPONENT_MODAL    = 42,
    ZYLIX_COMPONENT_PROGRESS = 43,
    ZYLIX_COMPONENT_SPINNER  = 44,
    ZYLIX_COMPONENT_SKELETON = 45,
    ZYLIX_COMPONENT_BADGE    = 46,

    /* Data Display Components (50-56) */
    ZYLIX_COMPONENT_TABLE     = 50,
    ZYLIX_COMPONENT_AVATAR    = 51,
    ZYLIX_COMPONENT_ICON      = 52,
    ZYLIX_COMPONENT_TAG       = 53,
    ZYLIX_COMPONENT_TOOLTIP   = 54,
    ZYLIX_COMPONENT_ACCORDION = 55,
    ZYLIX_COMPONENT_CAROUSEL  = 56,

    /* Custom Component */
    ZYLIX_COMPONENT_CUSTOM = 255
} ZylixComponentType;

/* ============================================================================
 * Supporting Enumerations
 * ============================================================================ */

typedef enum {
    ZYLIX_STACK_HORIZONTAL = 0,
    ZYLIX_STACK_VERTICAL   = 1
} ZylixStackDirection;

typedef enum {
    ZYLIX_ALIGN_START  = 0,
    ZYLIX_ALIGN_CENTER = 1,
    ZYLIX_ALIGN_END    = 2,
    ZYLIX_ALIGN_FILL   = 3
} ZylixAlignment;

typedef enum {
    ZYLIX_PROGRESS_LINEAR   = 0,
    ZYLIX_PROGRESS_CIRCULAR = 1
} ZylixProgressStyle;

typedef enum {
    ZYLIX_ALERT_INFO    = 0,
    ZYLIX_ALERT_SUCCESS = 1,
    ZYLIX_ALERT_WARNING = 2,
    ZYLIX_ALERT_ERROR   = 3
} ZylixAlertStyle;

typedef enum {
    ZYLIX_TOAST_TOP    = 0,
    ZYLIX_TOAST_BOTTOM = 1
} ZylixToastPosition;

typedef enum {
    ZYLIX_HEADING_1 = 1,
    ZYLIX_HEADING_2 = 2,
    ZYLIX_HEADING_3 = 3,
    ZYLIX_HEADING_4 = 4,
    ZYLIX_HEADING_5 = 5,
    ZYLIX_HEADING_6 = 6
} ZylixHeadingLevel;

/* ============================================================================
 * Component Properties Structure
 * ============================================================================ */

typedef struct {
    /* Common properties */
    const char* id;
    const char* text;
    const char* placeholder;
    const char* src;
    const char* href;
    const char* icon_name;
    bool        disabled;
    bool        checked;
    bool        expanded;

    /* Numeric properties */
    double      value;
    double      min_value;
    double      max_value;
    double      step;
    int         columns;
    int         rows;
    int         spacing;
    int         current_page;
    int         total_pages;
    int         current_tab;

    /* Style properties */
    ZylixStackDirection  direction;
    ZylixAlignment       alignment;
    ZylixProgressStyle   progress_style;
    ZylixAlertStyle      alert_style;
    ZylixToastPosition   toast_position;
    ZylixHeadingLevel    heading_level;

    /* Size properties */
    int         width;
    int         height;
    double      aspect_ratio;

    /* Callbacks */
    void       (*on_click)(void* user_data);
    void       (*on_change)(const char* value, void* user_data);
    void       (*on_toggle)(bool checked, void* user_data);
    void       (*on_page_change)(int page, void* user_data);
    void       (*on_tab_change)(int tab, void* user_data);
    void*       user_data;

    /* Options for select/dropdown */
    const char** options;
    int          option_count;
    int          selected_index;

    /* Table data */
    const char** table_headers;
    int          header_count;
    const char** table_data;
    int          row_count;
    int          col_count;

    /* Accordion/Carousel items */
    const char** item_titles;
    const char** item_contents;
    int          item_count;

    /* Breadcrumb items */
    const char** breadcrumb_items;
    int          breadcrumb_count;

    /* Tab bar items */
    const char** tab_titles;
    int          tab_count;
} ZylixComponentProps;

/* ============================================================================
 * Component Factory Functions
 * ============================================================================ */

/**
 * Create a GTK4 widget from component type and properties
 * @param type The component type
 * @param props Component properties (can be NULL for defaults)
 * @return GtkWidget* or NULL on error
 */
GtkWidget* zylix_component_create(ZylixComponentType type, const ZylixComponentProps* props);

/**
 * Get component type name as string
 * @param type The component type
 * @return Static string name
 */
const char* zylix_component_type_name(ZylixComponentType type);

/**
 * Initialize default component properties
 * @param props Pointer to props structure to initialize
 */
void zylix_component_props_init(ZylixComponentProps* props);

/**
 * Free any allocated resources in component properties
 * @param props Pointer to props structure
 */
void zylix_component_props_free(ZylixComponentProps* props);

/* ============================================================================
 * Component Category Helpers
 * ============================================================================ */

/**
 * Check if component type is a basic component (0-9)
 */
static inline bool zylix_component_is_basic(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_CONTAINER && type <= ZYLIX_COMPONENT_PARAGRAPH;
}

/**
 * Check if component type is a form component (10-20)
 */
static inline bool zylix_component_is_form(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_SELECT && type <= ZYLIX_COMPONENT_FORM;
}

/**
 * Check if component type is a layout component (21-28)
 */
static inline bool zylix_component_is_layout(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_STACK && type <= ZYLIX_COMPONENT_SAFE_AREA;
}

/**
 * Check if component type is a navigation component (30-34)
 */
static inline bool zylix_component_is_navigation(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_NAV_BAR && type <= ZYLIX_COMPONENT_PAGINATION;
}

/**
 * Check if component type is a feedback component (40-46)
 */
static inline bool zylix_component_is_feedback(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_ALERT && type <= ZYLIX_COMPONENT_BADGE;
}

/**
 * Check if component type is a data display component (50-56)
 */
static inline bool zylix_component_is_data_display(ZylixComponentType type) {
    return type >= ZYLIX_COMPONENT_TABLE && type <= ZYLIX_COMPONENT_CAROUSEL;
}

#ifdef __cplusplus
}
#endif

#endif /* ZYLIX_COMPONENTS_H */
