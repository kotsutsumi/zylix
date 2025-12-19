/*
 * Zylix GTK4 Shell
 * Linux platform implementation using GTK4
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include "zylix.h"

/* === Application State === */
typedef struct {
    GtkApplication *app;
    GtkWidget *window;
    GtkWidget *counter_label;
    GtkWidget *status_label;
    bool initialized;
} ZylixApp;

static ZylixApp app_state = {0};

/* === Helper Functions === */

static void update_counter_display(void) {
    const zylix_state_t *state = zylix_get_state();
    if (state && state->view_data) {
        const zylix_app_state_t *app = (const zylix_app_state_t *)state->view_data;
        char buf[32];
        snprintf(buf, sizeof(buf), "%ld", app->counter);
        gtk_label_set_text(GTK_LABEL(app_state.counter_label), buf);
    }
}

/* === Event Handlers === */

static void on_increment_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;

    if (zylix_dispatch(ZYLIX_EVENT_COUNTER_INCREMENT, NULL, 0) == ZYLIX_OK) {
        update_counter_display();
    }
}

static void on_decrement_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;

    if (zylix_dispatch(ZYLIX_EVENT_COUNTER_DECREMENT, NULL, 0) == ZYLIX_OK) {
        update_counter_display();
    }
}

static void on_reset_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)user_data;

    if (zylix_dispatch(ZYLIX_EVENT_COUNTER_RESET, NULL, 0) == ZYLIX_OK) {
        update_counter_display();
    }
}

/* === Window Construction === */

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    /* Initialize Zylix Core */
    if (zylix_init() != ZYLIX_OK) {
        fprintf(stderr, "Failed to initialize Zylix: %s\n", zylix_get_last_error());
        return;
    }
    app_state.initialized = true;
    printf("[Zylix] Core initialized, ABI version: %u\n", zylix_get_abi_version());

    /* Create window */
    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Zylix Counter");
    gtk_window_set_default_size(GTK_WINDOW(window), 400, 400);
    app_state.window = window;

    /* Main container */
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
    gtk_widget_set_margin_top(box, 40);
    gtk_widget_set_margin_bottom(box, 40);
    gtk_widget_set_margin_start(box, 40);
    gtk_widget_set_margin_end(box, 40);
    gtk_widget_set_halign(box, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(box, GTK_ALIGN_CENTER);
    gtk_window_set_child(GTK_WINDOW(window), box);

    /* Title */
    GtkWidget *title = gtk_label_new("Zylix Counter");
    PangoAttrList *title_attrs = pango_attr_list_new();
    pango_attr_list_insert(title_attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
    pango_attr_list_insert(title_attrs, pango_attr_scale_new(2.0));
    gtk_label_set_attributes(GTK_LABEL(title), title_attrs);
    pango_attr_list_unref(title_attrs);
    gtk_box_append(GTK_BOX(box), title);

    /* Subtitle */
    GtkWidget *subtitle = gtk_label_new("Zig Core + GTK4 Shell");
    gtk_widget_add_css_class(subtitle, "dim-label");
    gtk_box_append(GTK_BOX(box), subtitle);

    /* Counter display */
    app_state.counter_label = gtk_label_new("0");
    PangoAttrList *counter_attrs = pango_attr_list_new();
    pango_attr_list_insert(counter_attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
    pango_attr_list_insert(counter_attrs, pango_attr_scale_new(4.0));
    gtk_label_set_attributes(GTK_LABEL(app_state.counter_label), counter_attrs);
    pango_attr_list_unref(counter_attrs);

    GtkWidget *counter_frame = gtk_frame_new(NULL);
    gtk_widget_set_margin_top(counter_frame, 20);
    gtk_widget_set_margin_bottom(counter_frame, 20);
    gtk_frame_set_child(GTK_FRAME(counter_frame), app_state.counter_label);
    gtk_widget_set_size_request(counter_frame, 200, 100);
    gtk_box_append(GTK_BOX(box), counter_frame);

    /* Button container */
    GtkWidget *button_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 16);
    gtk_widget_set_halign(button_box, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(box), button_box);

    /* Decrement button */
    GtkWidget *dec_btn = gtk_button_new_with_label("-");
    gtk_widget_set_size_request(dec_btn, 60, 60);
    g_signal_connect(dec_btn, "clicked", G_CALLBACK(on_decrement_clicked), NULL);
    gtk_box_append(GTK_BOX(button_box), dec_btn);

    /* Reset button */
    GtkWidget *reset_btn = gtk_button_new_with_label("Reset");
    gtk_widget_set_size_request(reset_btn, 80, 60);
    g_signal_connect(reset_btn, "clicked", G_CALLBACK(on_reset_clicked), NULL);
    gtk_box_append(GTK_BOX(button_box), reset_btn);

    /* Increment button */
    GtkWidget *inc_btn = gtk_button_new_with_label("+");
    gtk_widget_set_size_request(inc_btn, 60, 60);
    gtk_widget_add_css_class(inc_btn, "suggested-action");
    g_signal_connect(inc_btn, "clicked", G_CALLBACK(on_increment_clicked), NULL);
    gtk_box_append(GTK_BOX(button_box), inc_btn);

    /* Status */
    app_state.status_label = gtk_label_new("Zylix Core initialized");
    gtk_widget_add_css_class(app_state.status_label, "dim-label");
    gtk_widget_set_margin_top(app_state.status_label, 20);
    gtk_box_append(GTK_BOX(box), app_state.status_label);

    /* Update counter display */
    update_counter_display();

    /* Show window */
    gtk_window_present(GTK_WINDOW(window));
}

static void shutdown_app(GtkApplication *app, gpointer user_data) {
    (void)app;
    (void)user_data;

    if (app_state.initialized) {
        zylix_deinit();
        printf("[Zylix] Core shutdown\n");
    }
}

/* === Main === */

int main(int argc, char *argv[]) {
    GtkApplication *app = gtk_application_new("com.zylix.counter", G_APPLICATION_DEFAULT_FLAGS);
    app_state.app = app;

    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    g_signal_connect(app, "shutdown", G_CALLBACK(shutdown_app), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);

    g_object_unref(app);
    return status;
}
