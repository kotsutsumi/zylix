/*
 * Zylix GTK4 Todo App
 * Linux platform Todo demo using GTK4
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include "zylix.h"

/* === Todo Item === */
typedef struct {
    uint32_t id;
    char text[256];
    gboolean completed;
} TodoItem;

/* === Application State === */
typedef struct {
    GtkApplication *app;
    GtkWidget *window;
    GtkWidget *entry;
    GtkWidget *list_box;
    GtkWidget *filter_all;
    GtkWidget *filter_active;
    GtkWidget *filter_completed;
    GtkWidget *items_left_label;
    GtkWidget *clear_btn;
    GtkWidget *stats_label;

    TodoItem items[100];
    int item_count;
    uint32_t next_id;
    int current_filter;
    int render_count;
    double last_render_time;
} TodoApp;

static TodoApp app_state = {0};

/* === Timing === */
static double get_time_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

/* === Forward Declarations === */
static void refresh_list(void);
static void update_footer(void);

/* === Todo Operations === */

static void add_todo(const char *text) {
    if (app_state.item_count >= 100) return;
    if (strlen(text) == 0) return;

    double start = get_time_ms();

    TodoItem *item = &app_state.items[app_state.item_count++];
    item->id = app_state.next_id++;
    strncpy(item->text, text, sizeof(item->text) - 1);
    item->text[sizeof(item->text) - 1] = '\0';
    item->completed = FALSE;

    app_state.last_render_time = get_time_ms() - start;
    app_state.render_count++;

    refresh_list();
    update_footer();
}

static void remove_todo(uint32_t id) {
    double start = get_time_ms();

    for (int i = 0; i < app_state.item_count; i++) {
        if (app_state.items[i].id == id) {
            memmove(&app_state.items[i], &app_state.items[i + 1],
                    (app_state.item_count - i - 1) * sizeof(TodoItem));
            app_state.item_count--;
            break;
        }
    }

    app_state.last_render_time = get_time_ms() - start;
    app_state.render_count++;

    refresh_list();
    update_footer();
}

static void toggle_todo(uint32_t id) {
    double start = get_time_ms();

    for (int i = 0; i < app_state.item_count; i++) {
        if (app_state.items[i].id == id) {
            app_state.items[i].completed = !app_state.items[i].completed;
            break;
        }
    }

    app_state.last_render_time = get_time_ms() - start;
    app_state.render_count++;

    refresh_list();
    update_footer();
}

static void toggle_all(void) {
    double start = get_time_ms();

    gboolean all_completed = TRUE;
    for (int i = 0; i < app_state.item_count; i++) {
        if (!app_state.items[i].completed) {
            all_completed = FALSE;
            break;
        }
    }

    for (int i = 0; i < app_state.item_count; i++) {
        app_state.items[i].completed = !all_completed;
    }

    app_state.last_render_time = get_time_ms() - start;
    app_state.render_count++;

    refresh_list();
    update_footer();
}

static void clear_completed(void) {
    double start = get_time_ms();

    int write_idx = 0;
    for (int read_idx = 0; read_idx < app_state.item_count; read_idx++) {
        if (!app_state.items[read_idx].completed) {
            if (write_idx != read_idx) {
                app_state.items[write_idx] = app_state.items[read_idx];
            }
            write_idx++;
        }
    }
    app_state.item_count = write_idx;

    app_state.last_render_time = get_time_ms() - start;
    app_state.render_count++;

    refresh_list();
    update_footer();
}

static int count_active(void) {
    int count = 0;
    for (int i = 0; i < app_state.item_count; i++) {
        if (!app_state.items[i].completed) count++;
    }
    return count;
}

static int count_completed(void) {
    int count = 0;
    for (int i = 0; i < app_state.item_count; i++) {
        if (app_state.items[i].completed) count++;
    }
    return count;
}

/* === Event Handlers === */

static void on_entry_activate(GtkEntry *entry, gpointer user_data) {
    (void)user_data;
    GtkEntryBuffer *buffer = gtk_entry_get_buffer(entry);
    const char *text = gtk_entry_buffer_get_text(buffer);

    if (strlen(text) > 0) {
        add_todo(text);
        gtk_entry_buffer_set_text(buffer, "", 0);
    }
}

static void on_add_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;
    on_entry_activate(GTK_ENTRY(app_state.entry), NULL);
}

static void on_toggle_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    uint32_t id = GPOINTER_TO_UINT(user_data);
    toggle_todo(id);
}

static void on_delete_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    uint32_t id = GPOINTER_TO_UINT(user_data);
    remove_todo(id);
}

static void on_toggle_all_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;
    toggle_all();
}

static void on_clear_completed_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;
    clear_completed();
}

static void on_filter_changed(GtkToggleButton *button, gpointer user_data) {
    if (!gtk_toggle_button_get_active(button)) return;

    int filter = GPOINTER_TO_INT(user_data);
    app_state.current_filter = filter;

    refresh_list();
}

/* === UI Update === */

static GtkWidget* create_todo_row(TodoItem *item) {
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_widget_set_margin_start(row, 12);
    gtk_widget_set_margin_end(row, 12);
    gtk_widget_set_margin_top(row, 8);
    gtk_widget_set_margin_bottom(row, 8);

    /* Checkbox */
    GtkWidget *check = gtk_check_button_new();
    gtk_check_button_set_active(GTK_CHECK_BUTTON(check), item->completed);
    g_signal_connect(check, "toggled", G_CALLBACK(on_toggle_clicked), GUINT_TO_POINTER(item->id));
    gtk_box_append(GTK_BOX(row), check);

    /* Label */
    GtkWidget *label = gtk_label_new(item->text);
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_widget_set_hexpand(label, TRUE);
    if (item->completed) {
        PangoAttrList *attrs = pango_attr_list_new();
        pango_attr_list_insert(attrs, pango_attr_strikethrough_new(TRUE));
        pango_attr_list_insert(attrs, pango_attr_foreground_alpha_new(32768));
        gtk_label_set_attributes(GTK_LABEL(label), attrs);
        pango_attr_list_unref(attrs);
    }
    gtk_box_append(GTK_BOX(row), label);

    /* Delete button */
    GtkWidget *delete_btn = gtk_button_new_from_icon_name("user-trash-symbolic");
    gtk_widget_add_css_class(delete_btn, "flat");
    gtk_widget_add_css_class(delete_btn, "circular");
    g_signal_connect(delete_btn, "clicked", G_CALLBACK(on_delete_clicked), GUINT_TO_POINTER(item->id));
    gtk_box_append(GTK_BOX(row), delete_btn);

    return row;
}

static void refresh_list(void) {
    /* Clear existing items */
    GtkWidget *child;
    while ((child = gtk_widget_get_first_child(app_state.list_box)) != NULL) {
        gtk_list_box_remove(GTK_LIST_BOX(app_state.list_box), child);
    }

    /* Add filtered items */
    for (int i = 0; i < app_state.item_count; i++) {
        TodoItem *item = &app_state.items[i];

        gboolean show = FALSE;
        switch (app_state.current_filter) {
            case ZYLIX_FILTER_ALL:
                show = TRUE;
                break;
            case ZYLIX_FILTER_ACTIVE:
                show = !item->completed;
                break;
            case ZYLIX_FILTER_COMPLETED:
                show = item->completed;
                break;
        }

        if (show) {
            GtkWidget *row = create_todo_row(item);
            gtk_list_box_append(GTK_LIST_BOX(app_state.list_box), row);
        }
    }
}

static void update_footer(void) {
    int active = count_active();
    char buf[64];
    snprintf(buf, sizeof(buf), "%d item%s left", active, active == 1 ? "" : "s");
    gtk_label_set_text(GTK_LABEL(app_state.items_left_label), buf);

    int completed = count_completed();
    gtk_widget_set_visible(app_state.clear_btn, completed > 0);

    snprintf(buf, sizeof(buf), "%d Todos  |  %d Renders  |  %.2f ms",
             app_state.item_count, app_state.render_count, app_state.last_render_time);
    gtk_label_set_text(GTK_LABEL(app_state.stats_label), buf);
}

/* === Window Construction === */

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    app_state.next_id = 1;
    app_state.current_filter = ZYLIX_FILTER_ALL;

    /* Create window */
    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Zylix Todo");
    gtk_window_set_default_size(GTK_WINDOW(window), 500, 600);
    app_state.window = window;

    /* Main container */
    GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_window_set_child(GTK_WINDOW(window), main_box);

    /* Header */
    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_margin_top(header, 20);
    gtk_widget_set_margin_bottom(header, 10);
    gtk_box_append(GTK_BOX(main_box), header);

    GtkWidget *title = gtk_label_new("Zylix Todo");
    PangoAttrList *title_attrs = pango_attr_list_new();
    pango_attr_list_insert(title_attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
    pango_attr_list_insert(title_attrs, pango_attr_scale_new(1.8));
    gtk_label_set_attributes(GTK_LABEL(title), title_attrs);
    pango_attr_list_unref(title_attrs);
    gtk_box_append(GTK_BOX(header), title);

    GtkWidget *subtitle = gtk_label_new("ZigDom + GTK4 (Linux)");
    gtk_widget_add_css_class(subtitle, "dim-label");
    gtk_box_append(GTK_BOX(header), subtitle);

    /* Input area */
    GtkWidget *input_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(input_box, 16);
    gtk_widget_set_margin_end(input_box, 16);
    gtk_widget_set_margin_top(input_box, 8);
    gtk_widget_set_margin_bottom(input_box, 8);
    gtk_box_append(GTK_BOX(main_box), input_box);

    /* Toggle all button */
    GtkWidget *toggle_all_btn = gtk_button_new_from_icon_name("object-select-symbolic");
    gtk_widget_add_css_class(toggle_all_btn, "flat");
    g_signal_connect(toggle_all_btn, "clicked", G_CALLBACK(on_toggle_all_clicked), NULL);
    gtk_box_append(GTK_BOX(input_box), toggle_all_btn);

    /* Entry */
    app_state.entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(app_state.entry), "What needs to be done?");
    gtk_widget_set_hexpand(app_state.entry, TRUE);
    g_signal_connect(app_state.entry, "activate", G_CALLBACK(on_entry_activate), NULL);
    gtk_box_append(GTK_BOX(input_box), app_state.entry);

    /* Add button */
    GtkWidget *add_btn = gtk_button_new_from_icon_name("list-add-symbolic");
    gtk_widget_add_css_class(add_btn, "suggested-action");
    g_signal_connect(add_btn, "clicked", G_CALLBACK(on_add_clicked), NULL);
    gtk_box_append(GTK_BOX(input_box), add_btn);

    /* Filter tabs */
    GtkWidget *filter_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_halign(filter_box, GTK_ALIGN_CENTER);
    gtk_widget_set_margin_top(filter_box, 8);
    gtk_widget_set_margin_bottom(filter_box, 8);
    gtk_widget_add_css_class(filter_box, "linked");
    gtk_box_append(GTK_BOX(main_box), filter_box);

    app_state.filter_all = gtk_toggle_button_new_with_label("All");
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(app_state.filter_all), TRUE);
    g_signal_connect(app_state.filter_all, "toggled", G_CALLBACK(on_filter_changed), GINT_TO_POINTER(ZYLIX_FILTER_ALL));
    gtk_box_append(GTK_BOX(filter_box), app_state.filter_all);

    app_state.filter_active = gtk_toggle_button_new_with_label("Active");
    gtk_toggle_button_set_group(GTK_TOGGLE_BUTTON(app_state.filter_active), GTK_TOGGLE_BUTTON(app_state.filter_all));
    g_signal_connect(app_state.filter_active, "toggled", G_CALLBACK(on_filter_changed), GINT_TO_POINTER(ZYLIX_FILTER_ACTIVE));
    gtk_box_append(GTK_BOX(filter_box), app_state.filter_active);

    app_state.filter_completed = gtk_toggle_button_new_with_label("Completed");
    gtk_toggle_button_set_group(GTK_TOGGLE_BUTTON(app_state.filter_completed), GTK_TOGGLE_BUTTON(app_state.filter_all));
    g_signal_connect(app_state.filter_completed, "toggled", G_CALLBACK(on_filter_changed), GINT_TO_POINTER(ZYLIX_FILTER_COMPLETED));
    gtk_box_append(GTK_BOX(filter_box), app_state.filter_completed);

    /* Scrolled list */
    GtkWidget *scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_box_append(GTK_BOX(main_box), scrolled);

    app_state.list_box = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(app_state.list_box), GTK_SELECTION_NONE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), app_state.list_box);

    /* Footer */
    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(footer, 16);
    gtk_widget_set_margin_end(footer, 16);
    gtk_widget_set_margin_top(footer, 8);
    gtk_widget_set_margin_bottom(footer, 8);
    gtk_box_append(GTK_BOX(main_box), footer);

    app_state.items_left_label = gtk_label_new("0 items left");
    gtk_widget_add_css_class(app_state.items_left_label, "dim-label");
    gtk_box_append(GTK_BOX(footer), app_state.items_left_label);

    GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand(spacer, TRUE);
    gtk_box_append(GTK_BOX(footer), spacer);

    app_state.clear_btn = gtk_button_new_with_label("Clear Completed");
    gtk_widget_add_css_class(app_state.clear_btn, "flat");
    gtk_widget_add_css_class(app_state.clear_btn, "destructive-action");
    gtk_widget_set_visible(app_state.clear_btn, FALSE);
    g_signal_connect(app_state.clear_btn, "clicked", G_CALLBACK(on_clear_completed_clicked), NULL);
    gtk_box_append(GTK_BOX(footer), app_state.clear_btn);

    /* Stats */
    GtkWidget *stats_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_halign(stats_box, GTK_ALIGN_CENTER);
    gtk_widget_set_margin_top(stats_box, 4);
    gtk_widget_set_margin_bottom(stats_box, 12);
    gtk_box_append(GTK_BOX(main_box), stats_box);

    app_state.stats_label = gtk_label_new("0 Todos  |  0 Renders  |  0.00 ms");
    gtk_widget_add_css_class(app_state.stats_label, "dim-label");
    gtk_box_append(GTK_BOX(stats_box), app_state.stats_label);

    /* Add sample todos */
    add_todo("Learn Zig");
    add_todo("Build VDOM");
    add_todo("Create Linux bindings");

    /* Show window */
    gtk_window_present(GTK_WINDOW(window));
}

/* === Main === */

int main(int argc, char *argv[]) {
    GtkApplication *app = gtk_application_new("com.zylix.todo", G_APPLICATION_DEFAULT_FLAGS);
    app_state.app = app;

    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);

    g_object_unref(app);
    return status;
}
