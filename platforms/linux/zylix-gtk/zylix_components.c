/*
 * zylix_components.c
 * GTK4 Component Factory Implementation for Zylix v0.2.0
 *
 * This file implements the component factory functions for creating
 * GTK4 widgets from Zylix component specifications.
 */

#include "zylix_components.h"
#include <string.h>
#include <stdlib.h>

/* ============================================================================
 * Internal Helper Functions
 * ============================================================================ */

static void on_button_clicked(GtkButton* button, gpointer user_data) {
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_click) {
        props->on_click(props->user_data);
    }
}

static void on_entry_changed(GtkEditable* editable, gpointer user_data) {
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_change) {
        const char* text = gtk_editable_get_text(editable);
        props->on_change(text, props->user_data);
    }
}

static void on_check_toggled(GtkCheckButton* check, gpointer user_data) {
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_toggle) {
        gboolean active = gtk_check_button_get_active(check);
        props->on_toggle(active, props->user_data);
    }
}

static void on_switch_toggled(GtkSwitch* sw, GParamSpec* pspec, gpointer user_data) {
    (void)pspec;
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_toggle) {
        gboolean active = gtk_switch_get_active(sw);
        props->on_toggle(active, props->user_data);
    }
}

static void on_scale_changed(GtkRange* range, gpointer user_data) {
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_change) {
        double value = gtk_range_get_value(range);
        char buf[32];
        snprintf(buf, sizeof(buf), "%.2f", value);
        props->on_change(buf, props->user_data);
    }
}

static void on_dropdown_changed(GtkDropDown* dropdown, GParamSpec* pspec, gpointer user_data) {
    (void)pspec;
    ZylixComponentProps* props = (ZylixComponentProps*)user_data;
    if (props && props->on_change) {
        guint selected = gtk_drop_down_get_selected(dropdown);
        char buf[16];
        snprintf(buf, sizeof(buf), "%u", selected);
        props->on_change(buf, props->user_data);
    }
}

/* ============================================================================
 * Basic Components (0-9)
 * ============================================================================ */

static GtkWidget* create_container(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, props ? props->spacing : 0);
    return box;
}

static GtkWidget* create_text(const ZylixComponentProps* props) {
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "");
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    return label;
}

static GtkWidget* create_button(const ZylixComponentProps* props) {
    GtkWidget* button = gtk_button_new_with_label(props && props->text ? props->text : "Button");
    if (props && props->disabled) {
        gtk_widget_set_sensitive(button, FALSE);
    }
    if (props && props->on_click) {
        g_signal_connect(button, "clicked", G_CALLBACK(on_button_clicked), (gpointer)props);
    }
    return button;
}

static GtkWidget* create_input(const ZylixComponentProps* props) {
    GtkWidget* entry = gtk_entry_new();
    if (props) {
        if (props->text) {
            gtk_editable_set_text(GTK_EDITABLE(entry), props->text);
        }
        if (props->placeholder) {
            gtk_entry_set_placeholder_text(GTK_ENTRY(entry), props->placeholder);
        }
        if (props->disabled) {
            gtk_widget_set_sensitive(entry, FALSE);
        }
        if (props->on_change) {
            g_signal_connect(entry, "changed", G_CALLBACK(on_entry_changed), (gpointer)props);
        }
    }
    return entry;
}

static GtkWidget* create_image(const ZylixComponentProps* props) {
    GtkWidget* image;
    if (props && props->src) {
        image = gtk_image_new_from_file(props->src);
    } else {
        image = gtk_image_new();
    }
    if (props && props->width > 0 && props->height > 0) {
        gtk_widget_set_size_request(image, props->width, props->height);
    }
    return image;
}

static GtkWidget* create_link(const ZylixComponentProps* props) {
    GtkWidget* link = gtk_link_button_new_with_label(
        props && props->href ? props->href : "",
        props && props->text ? props->text : "Link"
    );
    return link;
}

static GtkWidget* create_list(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, props ? props->spacing : 4);
    return box;
}

static GtkWidget* create_list_item(const ZylixComponentProps* props) {
    GtkWidget* row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    if (props && props->text) {
        GtkWidget* label = gtk_label_new(props->text);
        gtk_box_append(GTK_BOX(row), label);
    }
    return row;
}

static GtkWidget* create_heading(const ZylixComponentProps* props) {
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "");

    int level = props ? props->heading_level : ZYLIX_HEADING_1;
    if (level < 1 || level > 6) level = 1;

    /* Apply heading style via CSS class */
    char css_class[16];
    snprintf(css_class, sizeof(css_class), "heading%d", level);
    gtk_widget_add_css_class(label, css_class);
    gtk_widget_add_css_class(label, "heading");

    /* Make text larger based on heading level */
    PangoAttrList* attrs = pango_attr_list_new();
    int font_sizes[] = {24, 20, 18, 16, 14, 12};
    pango_attr_list_insert(attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
    pango_attr_list_insert(attrs, pango_attr_size_new(font_sizes[level-1] * PANGO_SCALE));
    gtk_label_set_attributes(GTK_LABEL(label), attrs);
    pango_attr_list_unref(attrs);

    gtk_label_set_xalign(GTK_LABEL(label), 0.0);
    return label;
}

static GtkWidget* create_paragraph(const ZylixComponentProps* props) {
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "");
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0);
    return label;
}

/* ============================================================================
 * Form Components (10-20)
 * ============================================================================ */

static GtkWidget* create_select(const ZylixComponentProps* props) {
    GtkStringList* model = gtk_string_list_new(NULL);

    if (props && props->options) {
        for (int i = 0; i < props->option_count; i++) {
            gtk_string_list_append(model, props->options[i]);
        }
    }

    GtkWidget* dropdown = gtk_drop_down_new(G_LIST_MODEL(model), NULL);
    if (props && props->selected_index >= 0) {
        gtk_drop_down_set_selected(GTK_DROP_DOWN(dropdown), props->selected_index);
    }
    if (props && props->on_change) {
        g_signal_connect(dropdown, "notify::selected", G_CALLBACK(on_dropdown_changed), (gpointer)props);
    }
    return dropdown;
}

static GtkWidget* create_checkbox(const ZylixComponentProps* props) {
    GtkWidget* check = gtk_check_button_new_with_label(props && props->text ? props->text : "");
    if (props) {
        gtk_check_button_set_active(GTK_CHECK_BUTTON(check), props->checked);
        if (props->disabled) {
            gtk_widget_set_sensitive(check, FALSE);
        }
        if (props->on_toggle) {
            g_signal_connect(check, "toggled", G_CALLBACK(on_check_toggled), (gpointer)props);
        }
    }
    return check;
}

static GtkWidget* create_radio(const ZylixComponentProps* props) {
    GtkWidget* radio = gtk_check_button_new_with_label(props && props->text ? props->text : "");
    /* Note: For radio groups, you would set the group using gtk_check_button_set_group() */
    if (props) {
        gtk_check_button_set_active(GTK_CHECK_BUTTON(radio), props->checked);
        if (props->disabled) {
            gtk_widget_set_sensitive(radio, FALSE);
        }
    }
    return radio;
}

static GtkWidget* create_textarea(const ZylixComponentProps* props) {
    GtkWidget* scroll = gtk_scrolled_window_new();
    GtkWidget* text_view = gtk_text_view_new();

    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(text_view), GTK_WRAP_WORD);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll), text_view);

    if (props) {
        if (props->text) {
            GtkTextBuffer* buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
            gtk_text_buffer_set_text(buffer, props->text, -1);
        }
        if (props->rows > 0) {
            gtk_widget_set_size_request(scroll, -1, props->rows * 20);
        } else {
            gtk_widget_set_size_request(scroll, -1, 100);
        }
        if (props->disabled) {
            gtk_text_view_set_editable(GTK_TEXT_VIEW(text_view), FALSE);
        }
    }

    return scroll;
}

static GtkWidget* create_toggle_switch(const ZylixComponentProps* props) {
    GtkWidget* sw = gtk_switch_new();
    if (props) {
        gtk_switch_set_active(GTK_SWITCH(sw), props->checked);
        if (props->disabled) {
            gtk_widget_set_sensitive(sw, FALSE);
        }
        if (props->on_toggle) {
            g_signal_connect(sw, "notify::active", G_CALLBACK(on_switch_toggled), (gpointer)props);
        }
    }
    return sw;
}

static GtkWidget* create_slider(const ZylixComponentProps* props) {
    double min = props ? props->min_value : 0.0;
    double max = props ? props->max_value : 100.0;
    double step = props && props->step > 0 ? props->step : 1.0;

    GtkWidget* scale = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, min, max, step);
    if (props) {
        gtk_range_set_value(GTK_RANGE(scale), props->value);
        if (props->disabled) {
            gtk_widget_set_sensitive(scale, FALSE);
        }
        if (props->on_change) {
            g_signal_connect(scale, "value-changed", G_CALLBACK(on_scale_changed), (gpointer)props);
        }
    }
    gtk_widget_set_size_request(scale, 200, -1);
    return scale;
}

static GtkWidget* create_date_picker(const ZylixComponentProps* props) {
    GtkWidget* calendar = gtk_calendar_new();
    if (props && props->disabled) {
        gtk_widget_set_sensitive(calendar, FALSE);
    }
    return calendar;
}

static GtkWidget* create_time_picker(const ZylixComponentProps* props) {
    /* GTK4 doesn't have a native time picker, create a simple spin button combo */
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);

    GtkWidget* hour_spin = gtk_spin_button_new_with_range(0, 23, 1);
    GtkWidget* sep = gtk_label_new(":");
    GtkWidget* min_spin = gtk_spin_button_new_with_range(0, 59, 1);

    gtk_box_append(GTK_BOX(box), hour_spin);
    gtk_box_append(GTK_BOX(box), sep);
    gtk_box_append(GTK_BOX(box), min_spin);

    if (props && props->disabled) {
        gtk_widget_set_sensitive(box, FALSE);
    }

    return box;
}

static GtkWidget* create_file_input(const ZylixComponentProps* props) {
    /* Create a simple file chooser button (GTK4 style) */
    GtkWidget* button = gtk_button_new_with_label(props && props->text ? props->text : "Choose File...");
    /* Note: Actual file dialog would be opened via a callback */
    if (props && props->disabled) {
        gtk_widget_set_sensitive(button, FALSE);
    }
    return button;
}

static GtkWidget* create_color_picker(const ZylixComponentProps* props) {
    GtkWidget* button = gtk_color_button_new();
    if (props && props->disabled) {
        gtk_widget_set_sensitive(button, FALSE);
    }
    return button;
}

static GtkWidget* create_form(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, props ? props->spacing : 12);
    gtk_widget_add_css_class(box, "form");
    return box;
}

/* ============================================================================
 * Layout Components (21-28)
 * ============================================================================ */

static GtkWidget* create_stack(const ZylixComponentProps* props) {
    GtkOrientation orientation = GTK_ORIENTATION_VERTICAL;
    if (props && props->direction == ZYLIX_STACK_HORIZONTAL) {
        orientation = GTK_ORIENTATION_HORIZONTAL;
    }

    GtkWidget* box = gtk_box_new(orientation, props ? props->spacing : 0);

    if (props) {
        switch (props->alignment) {
            case ZYLIX_ALIGN_START:
                gtk_widget_set_halign(box, GTK_ALIGN_START);
                break;
            case ZYLIX_ALIGN_CENTER:
                gtk_widget_set_halign(box, GTK_ALIGN_CENTER);
                break;
            case ZYLIX_ALIGN_END:
                gtk_widget_set_halign(box, GTK_ALIGN_END);
                break;
            case ZYLIX_ALIGN_FILL:
                gtk_widget_set_halign(box, GTK_ALIGN_FILL);
                break;
        }
    }

    return box;
}

static GtkWidget* create_grid(const ZylixComponentProps* props) {
    GtkWidget* grid = gtk_grid_new();
    if (props && props->spacing > 0) {
        gtk_grid_set_row_spacing(GTK_GRID(grid), props->spacing);
        gtk_grid_set_column_spacing(GTK_GRID(grid), props->spacing);
    }
    return grid;
}

static GtkWidget* create_scroll_view(const ZylixComponentProps* props) {
    GtkWidget* scroll = gtk_scrolled_window_new();
    if (props) {
        if (props->width > 0) {
            gtk_scrolled_window_set_min_content_width(GTK_SCROLLED_WINDOW(scroll), props->width);
        }
        if (props->height > 0) {
            gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scroll), props->height);
        }
    }
    return scroll;
}

static GtkWidget* create_spacer(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    int size = (props && props->height > 0) ? props->height : 16;
    gtk_widget_set_size_request(box, -1, size);
    gtk_widget_set_hexpand(box, TRUE);
    gtk_widget_set_vexpand(box, TRUE);
    return box;
}

static GtkWidget* create_divider(const ZylixComponentProps* props) {
    GtkOrientation orientation = GTK_ORIENTATION_HORIZONTAL;
    if (props && props->direction == ZYLIX_STACK_VERTICAL) {
        orientation = GTK_ORIENTATION_VERTICAL;
    }
    GtkWidget* sep = gtk_separator_new(orientation);
    return sep;
}

static GtkWidget* create_card(const ZylixComponentProps* props) {
    GtkWidget* frame = gtk_frame_new(NULL);
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, props ? props->spacing : 8);
    gtk_frame_set_child(GTK_FRAME(frame), box);
    gtk_widget_add_css_class(frame, "card");
    return frame;
}

static GtkWidget* create_aspect_ratio(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    double ratio = (props && props->aspect_ratio > 0) ? props->aspect_ratio : 1.0;
    int width = (props && props->width > 0) ? props->width : 100;
    int height = (int)(width / ratio);
    gtk_widget_set_size_request(box, width, height);
    return box;
}

static GtkWidget* create_safe_area(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    /* Add some padding for safe area simulation */
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_bottom(box, 16);
    gtk_widget_set_margin_start(box, 16);
    gtk_widget_set_margin_end(box, 16);
    (void)props;
    return box;
}

/* ============================================================================
 * Navigation Components (30-34)
 * ============================================================================ */

static GtkWidget* create_nav_bar(const ZylixComponentProps* props) {
    GtkWidget* header = gtk_header_bar_new();
    if (props && props->text) {
        GtkWidget* title = gtk_label_new(props->text);
        gtk_header_bar_set_title_widget(GTK_HEADER_BAR(header), title);
    }
    return header;
}

static GtkWidget* create_tab_bar(const ZylixComponentProps* props) {
    GtkWidget* notebook = gtk_notebook_new();
    if (props && props->tab_titles) {
        for (int i = 0; i < props->tab_count; i++) {
            GtkWidget* page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
            GtkWidget* label = gtk_label_new(props->tab_titles[i]);
            gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page, label);
        }
        if (props->current_tab >= 0 && props->current_tab < props->tab_count) {
            gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), props->current_tab);
        }
    }
    return notebook;
}

static GtkWidget* create_drawer(const ZylixComponentProps* props) {
    /* Create a simple sidebar-like container */
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_size_request(box, props && props->width > 0 ? props->width : 250, -1);
    gtk_widget_add_css_class(box, "drawer");
    return box;
}

static GtkWidget* create_breadcrumb(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);

    if (props && props->breadcrumb_items) {
        for (int i = 0; i < props->breadcrumb_count; i++) {
            if (i > 0) {
                GtkWidget* sep = gtk_label_new(">");
                gtk_box_append(GTK_BOX(box), sep);
            }

            GtkWidget* item;
            if (i == props->breadcrumb_count - 1) {
                /* Last item is current, not a link */
                item = gtk_label_new(props->breadcrumb_items[i]);
            } else {
                item = gtk_button_new_with_label(props->breadcrumb_items[i]);
                gtk_button_set_has_frame(GTK_BUTTON(item), FALSE);
            }
            gtk_box_append(GTK_BOX(box), item);
        }
    }

    return box;
}

static GtkWidget* create_pagination(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);

    int current = props ? props->current_page : 1;
    int total = props ? props->total_pages : 1;

    GtkWidget* prev = gtk_button_new_with_label("<");
    gtk_widget_set_sensitive(prev, current > 1);
    gtk_box_append(GTK_BOX(box), prev);

    char page_text[32];
    snprintf(page_text, sizeof(page_text), "%d / %d", current, total);
    GtkWidget* label = gtk_label_new(page_text);
    gtk_box_append(GTK_BOX(box), label);

    GtkWidget* next = gtk_button_new_with_label(">");
    gtk_widget_set_sensitive(next, current < total);
    gtk_box_append(GTK_BOX(box), next);

    return box;
}

/* ============================================================================
 * Feedback Components (40-46)
 * ============================================================================ */

static GtkWidget* create_alert(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);

    const char* icon_name = "dialog-information";
    const char* css_class = "info";

    if (props) {
        switch (props->alert_style) {
            case ZYLIX_ALERT_SUCCESS:
                icon_name = "emblem-ok-symbolic";
                css_class = "success";
                break;
            case ZYLIX_ALERT_WARNING:
                icon_name = "dialog-warning-symbolic";
                css_class = "warning";
                break;
            case ZYLIX_ALERT_ERROR:
                icon_name = "dialog-error-symbolic";
                css_class = "error";
                break;
            default:
                icon_name = "dialog-information-symbolic";
                css_class = "info";
                break;
        }
    }

    GtkWidget* icon = gtk_image_new_from_icon_name(icon_name);
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "Alert");

    gtk_box_append(GTK_BOX(box), icon);
    gtk_box_append(GTK_BOX(box), label);

    gtk_widget_add_css_class(box, "alert");
    gtk_widget_add_css_class(box, css_class);

    return box;
}

static GtkWidget* create_toast(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "Toast message");
    gtk_box_append(GTK_BOX(box), label);
    gtk_widget_add_css_class(box, "toast");
    return box;
}

static GtkWidget* create_modal(const ZylixComponentProps* props) {
    /* Note: Actual modal would be a GtkWindow or GtkDialog */
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);

    if (props && props->text) {
        GtkWidget* title = gtk_label_new(props->text);
        PangoAttrList* attrs = pango_attr_list_new();
        pango_attr_list_insert(attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
        pango_attr_list_insert(attrs, pango_attr_size_new(16 * PANGO_SCALE));
        gtk_label_set_attributes(GTK_LABEL(title), attrs);
        pango_attr_list_unref(attrs);
        gtk_box_append(GTK_BOX(box), title);
    }

    gtk_widget_add_css_class(box, "modal");
    return box;
}

static GtkWidget* create_progress(const ZylixComponentProps* props) {
    GtkWidget* progress = gtk_progress_bar_new();
    double value = props ? props->value : 0.0;
    double max = props && props->max_value > 0 ? props->max_value : 100.0;
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(progress), value / max);
    return progress;
}

static GtkWidget* create_spinner(const ZylixComponentProps* props) {
    GtkWidget* spinner = gtk_spinner_new();
    if (!props || !props->disabled) {
        gtk_spinner_start(GTK_SPINNER(spinner));
    }
    return spinner;
}

static GtkWidget* create_skeleton(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    int width = (props && props->width > 0) ? props->width : 200;
    int height = (props && props->height > 0) ? props->height : 20;
    gtk_widget_set_size_request(box, width, height);
    gtk_widget_add_css_class(box, "skeleton");
    return box;
}

static GtkWidget* create_badge(const ZylixComponentProps* props) {
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "0");
    gtk_widget_add_css_class(label, "badge");
    return label;
}

/* ============================================================================
 * Data Display Components (50-56)
 * ============================================================================ */

static GtkWidget* create_table(const ZylixComponentProps* props) {
    GtkWidget* scroll = gtk_scrolled_window_new();
    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 4);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 8);

    if (props && props->table_headers) {
        for (int col = 0; col < props->header_count; col++) {
            GtkWidget* header = gtk_label_new(props->table_headers[col]);
            PangoAttrList* attrs = pango_attr_list_new();
            pango_attr_list_insert(attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
            gtk_label_set_attributes(GTK_LABEL(header), attrs);
            pango_attr_list_unref(attrs);
            gtk_grid_attach(GTK_GRID(grid), header, col, 0, 1, 1);
        }
    }

    if (props && props->table_data) {
        int data_idx = 0;
        for (int row = 0; row < props->row_count; row++) {
            for (int col = 0; col < props->col_count; col++) {
                GtkWidget* cell = gtk_label_new(props->table_data[data_idx++]);
                gtk_grid_attach(GTK_GRID(grid), cell, col, row + 1, 1, 1);
            }
        }
    }

    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll), grid);
    return scroll;
}

static GtkWidget* create_avatar(const ZylixComponentProps* props) {
    GtkWidget* image;
    int size = (props && props->width > 0) ? props->width : 40;

    if (props && props->src) {
        image = gtk_image_new_from_file(props->src);
    } else if (props && props->icon_name) {
        image = gtk_image_new_from_icon_name(props->icon_name);
    } else {
        image = gtk_image_new_from_icon_name("avatar-default-symbolic");
    }

    gtk_widget_set_size_request(image, size, size);
    gtk_widget_add_css_class(image, "avatar");
    return image;
}

static GtkWidget* create_icon(const ZylixComponentProps* props) {
    const char* name = props && props->icon_name ? props->icon_name : "image-missing";
    GtkWidget* icon = gtk_image_new_from_icon_name(name);
    if (props && props->width > 0) {
        gtk_image_set_pixel_size(GTK_IMAGE(icon), props->width);
    }
    return icon;
}

static GtkWidget* create_tag(const ZylixComponentProps* props) {
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "Tag");
    gtk_widget_add_css_class(label, "tag");
    return label;
}

static GtkWidget* create_tooltip(const ZylixComponentProps* props) {
    /* Tooltip is typically attached to another widget, return a label for now */
    GtkWidget* label = gtk_label_new(props && props->text ? props->text : "");
    if (props && props->placeholder) {
        gtk_widget_set_tooltip_text(label, props->placeholder);
    }
    return label;
}

static GtkWidget* create_accordion(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

    if (props && props->item_titles) {
        for (int i = 0; i < props->item_count; i++) {
            GtkWidget* expander = gtk_expander_new(props->item_titles[i]);
            if (props->item_contents && props->item_contents[i]) {
                GtkWidget* content = gtk_label_new(props->item_contents[i]);
                gtk_label_set_wrap(GTK_LABEL(content), TRUE);
                gtk_expander_set_child(GTK_EXPANDER(expander), content);
            }
            if (i == 0 && props->expanded) {
                gtk_expander_set_expanded(GTK_EXPANDER(expander), TRUE);
            }
            gtk_box_append(GTK_BOX(box), expander);
        }
    }

    return box;
}

static GtkWidget* create_carousel(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);

    /* Simple carousel with stack and navigation */
    GtkWidget* stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(stack), GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT);

    if (props && props->item_contents) {
        for (int i = 0; i < props->item_count; i++) {
            GtkWidget* page = gtk_label_new(props->item_contents[i]);
            char name[16];
            snprintf(name, sizeof(name), "page%d", i);
            gtk_stack_add_named(GTK_STACK(stack), page, name);
        }
    }

    gtk_box_append(GTK_BOX(box), stack);

    /* Navigation buttons */
    GtkWidget* nav = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_halign(nav, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(nav), gtk_button_new_with_label("<"));
    gtk_box_append(GTK_BOX(nav), gtk_button_new_with_label(">"));
    gtk_box_append(GTK_BOX(box), nav);

    return box;
}

static GtkWidget* create_custom(const ZylixComponentProps* props) {
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    if (props && props->text) {
        GtkWidget* label = gtk_label_new(props->text);
        gtk_box_append(GTK_BOX(box), label);
    }
    gtk_widget_add_css_class(box, "custom");
    return box;
}

/* ============================================================================
 * Public API Implementation
 * ============================================================================ */

GtkWidget* zylix_component_create(ZylixComponentType type, const ZylixComponentProps* props) {
    switch (type) {
        /* Basic Components */
        case ZYLIX_COMPONENT_CONTAINER:   return create_container(props);
        case ZYLIX_COMPONENT_TEXT:        return create_text(props);
        case ZYLIX_COMPONENT_BUTTON:      return create_button(props);
        case ZYLIX_COMPONENT_INPUT:       return create_input(props);
        case ZYLIX_COMPONENT_IMAGE:       return create_image(props);
        case ZYLIX_COMPONENT_LINK:        return create_link(props);
        case ZYLIX_COMPONENT_LIST:        return create_list(props);
        case ZYLIX_COMPONENT_LIST_ITEM:   return create_list_item(props);
        case ZYLIX_COMPONENT_HEADING:     return create_heading(props);
        case ZYLIX_COMPONENT_PARAGRAPH:   return create_paragraph(props);

        /* Form Components */
        case ZYLIX_COMPONENT_SELECT:        return create_select(props);
        case ZYLIX_COMPONENT_CHECKBOX:      return create_checkbox(props);
        case ZYLIX_COMPONENT_RADIO:         return create_radio(props);
        case ZYLIX_COMPONENT_TEXTAREA:      return create_textarea(props);
        case ZYLIX_COMPONENT_TOGGLE_SWITCH: return create_toggle_switch(props);
        case ZYLIX_COMPONENT_SLIDER:        return create_slider(props);
        case ZYLIX_COMPONENT_DATE_PICKER:   return create_date_picker(props);
        case ZYLIX_COMPONENT_TIME_PICKER:   return create_time_picker(props);
        case ZYLIX_COMPONENT_FILE_INPUT:    return create_file_input(props);
        case ZYLIX_COMPONENT_COLOR_PICKER:  return create_color_picker(props);
        case ZYLIX_COMPONENT_FORM:          return create_form(props);

        /* Layout Components */
        case ZYLIX_COMPONENT_STACK:        return create_stack(props);
        case ZYLIX_COMPONENT_GRID:         return create_grid(props);
        case ZYLIX_COMPONENT_SCROLL_VIEW:  return create_scroll_view(props);
        case ZYLIX_COMPONENT_SPACER:       return create_spacer(props);
        case ZYLIX_COMPONENT_DIVIDER:      return create_divider(props);
        case ZYLIX_COMPONENT_CARD:         return create_card(props);
        case ZYLIX_COMPONENT_ASPECT_RATIO: return create_aspect_ratio(props);
        case ZYLIX_COMPONENT_SAFE_AREA:    return create_safe_area(props);

        /* Navigation Components */
        case ZYLIX_COMPONENT_NAV_BAR:    return create_nav_bar(props);
        case ZYLIX_COMPONENT_TAB_BAR:    return create_tab_bar(props);
        case ZYLIX_COMPONENT_DRAWER:     return create_drawer(props);
        case ZYLIX_COMPONENT_BREADCRUMB: return create_breadcrumb(props);
        case ZYLIX_COMPONENT_PAGINATION: return create_pagination(props);

        /* Feedback Components */
        case ZYLIX_COMPONENT_ALERT:    return create_alert(props);
        case ZYLIX_COMPONENT_TOAST:    return create_toast(props);
        case ZYLIX_COMPONENT_MODAL:    return create_modal(props);
        case ZYLIX_COMPONENT_PROGRESS: return create_progress(props);
        case ZYLIX_COMPONENT_SPINNER:  return create_spinner(props);
        case ZYLIX_COMPONENT_SKELETON: return create_skeleton(props);
        case ZYLIX_COMPONENT_BADGE:    return create_badge(props);

        /* Data Display Components */
        case ZYLIX_COMPONENT_TABLE:     return create_table(props);
        case ZYLIX_COMPONENT_AVATAR:    return create_avatar(props);
        case ZYLIX_COMPONENT_ICON:      return create_icon(props);
        case ZYLIX_COMPONENT_TAG:       return create_tag(props);
        case ZYLIX_COMPONENT_TOOLTIP:   return create_tooltip(props);
        case ZYLIX_COMPONENT_ACCORDION: return create_accordion(props);
        case ZYLIX_COMPONENT_CAROUSEL:  return create_carousel(props);

        /* Custom Component */
        case ZYLIX_COMPONENT_CUSTOM: return create_custom(props);

        default:
            return NULL;
    }
}

const char* zylix_component_type_name(ZylixComponentType type) {
    switch (type) {
        case ZYLIX_COMPONENT_CONTAINER:     return "container";
        case ZYLIX_COMPONENT_TEXT:          return "text";
        case ZYLIX_COMPONENT_BUTTON:        return "button";
        case ZYLIX_COMPONENT_INPUT:         return "input";
        case ZYLIX_COMPONENT_IMAGE:         return "image";
        case ZYLIX_COMPONENT_LINK:          return "link";
        case ZYLIX_COMPONENT_LIST:          return "list";
        case ZYLIX_COMPONENT_LIST_ITEM:     return "list_item";
        case ZYLIX_COMPONENT_HEADING:       return "heading";
        case ZYLIX_COMPONENT_PARAGRAPH:     return "paragraph";
        case ZYLIX_COMPONENT_SELECT:        return "select";
        case ZYLIX_COMPONENT_CHECKBOX:      return "checkbox";
        case ZYLIX_COMPONENT_RADIO:         return "radio";
        case ZYLIX_COMPONENT_TEXTAREA:      return "textarea";
        case ZYLIX_COMPONENT_TOGGLE_SWITCH: return "toggle_switch";
        case ZYLIX_COMPONENT_SLIDER:        return "slider";
        case ZYLIX_COMPONENT_DATE_PICKER:   return "date_picker";
        case ZYLIX_COMPONENT_TIME_PICKER:   return "time_picker";
        case ZYLIX_COMPONENT_FILE_INPUT:    return "file_input";
        case ZYLIX_COMPONENT_COLOR_PICKER:  return "color_picker";
        case ZYLIX_COMPONENT_FORM:          return "form";
        case ZYLIX_COMPONENT_STACK:         return "stack";
        case ZYLIX_COMPONENT_GRID:          return "grid";
        case ZYLIX_COMPONENT_SCROLL_VIEW:   return "scroll_view";
        case ZYLIX_COMPONENT_SPACER:        return "spacer";
        case ZYLIX_COMPONENT_DIVIDER:       return "divider";
        case ZYLIX_COMPONENT_CARD:          return "card";
        case ZYLIX_COMPONENT_ASPECT_RATIO:  return "aspect_ratio";
        case ZYLIX_COMPONENT_SAFE_AREA:     return "safe_area";
        case ZYLIX_COMPONENT_NAV_BAR:       return "nav_bar";
        case ZYLIX_COMPONENT_TAB_BAR:       return "tab_bar";
        case ZYLIX_COMPONENT_DRAWER:        return "drawer";
        case ZYLIX_COMPONENT_BREADCRUMB:    return "breadcrumb";
        case ZYLIX_COMPONENT_PAGINATION:    return "pagination";
        case ZYLIX_COMPONENT_ALERT:         return "alert";
        case ZYLIX_COMPONENT_TOAST:         return "toast";
        case ZYLIX_COMPONENT_MODAL:         return "modal";
        case ZYLIX_COMPONENT_PROGRESS:      return "progress";
        case ZYLIX_COMPONENT_SPINNER:       return "spinner";
        case ZYLIX_COMPONENT_SKELETON:      return "skeleton";
        case ZYLIX_COMPONENT_BADGE:         return "badge";
        case ZYLIX_COMPONENT_TABLE:         return "table";
        case ZYLIX_COMPONENT_AVATAR:        return "avatar";
        case ZYLIX_COMPONENT_ICON:          return "icon";
        case ZYLIX_COMPONENT_TAG:           return "tag";
        case ZYLIX_COMPONENT_TOOLTIP:       return "tooltip";
        case ZYLIX_COMPONENT_ACCORDION:     return "accordion";
        case ZYLIX_COMPONENT_CAROUSEL:      return "carousel";
        case ZYLIX_COMPONENT_CUSTOM:        return "custom";
        default:                            return "unknown";
    }
}

void zylix_component_props_init(ZylixComponentProps* props) {
    if (!props) return;
    memset(props, 0, sizeof(ZylixComponentProps));
    props->max_value = 100.0;
    props->step = 1.0;
    props->heading_level = ZYLIX_HEADING_1;
    props->aspect_ratio = 1.0;
    props->current_page = 1;
    props->total_pages = 1;
}

void zylix_component_props_free(ZylixComponentProps* props) {
    /* Currently no dynamic allocations in props structure */
    (void)props;
}
