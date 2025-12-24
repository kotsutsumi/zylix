//! Database Workshop - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum {
    column,
    row,
    div,
    text,
    button,
    scroll,
    icon,
    input,
    spacer,
};

pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around };

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(v: f32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }

    pub fn symmetric(h: f32, v: f32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
    }
};

pub const Style = struct {
    padding: Spacing = .{},
    margin: Spacing = .{},
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    alignment: Alignment = .start,
    justify: Justify = .start,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFF1C1C1E;
    pub const surface: u32 = 0xFF2C2C2E;
    pub const card: u32 = 0xFF3A3A3C;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFF007AFF;
    pub const success: u32 = 0xFF34C759;
    pub const warning: u32 = 0xFFFF9500;
    pub const error_color: u32 = 0xFFFF3B30;
    pub const crud: u32 = 0xFF5856D6;
    pub const query: u32 = 0xFF5AC8FA;
    pub const transaction: u32 = 0xFFFF9500;
    pub const keyvalue: u32 = 0xFFFF2D55;
    pub const import_export: u32 = 0xFF34C759;
};

pub const Props = struct {
    style: Style = .{},
    on_press: ?*const fn () void = null,
    text: []const u8 = "",
    icon: []const u8 = "",
    placeholder: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

// Component constructors
fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

fn text(content: []const u8, props: Props) VNode {
    var p = props;
    p.text = content;
    return .{ .tag = .text, .props = p, .children = &.{} };
}

fn button(label: []const u8, props: Props) VNode {
    var p = props;
    p.text = label;
    return .{ .tag = .button, .props = p, .children = &.{} };
}

fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}

fn scroll(props: Props, children: []const VNode) VNode {
    return .{ .tag = .scroll, .props = props, .children = children };
}

fn spacer() VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

// Main app builder
pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [3]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildModeSelector(state);
    S.content[2] = buildContent(state);

    return column(.{
        .style = .{
            .background = Color.background,
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text("Database Workshop", .{
        .style = .{
            .font_size = 28,
            .font_weight = 700,
            .color = Color.text,
        },
    });
    S.items[1] = text(state.current_mode.description(), .{
        .style = .{
            .font_size = 14,
            .color = Color.text_secondary,
        },
    });

    return column(.{ .style = .{ .gap = 4 } }, &S.items);
}

fn buildModeSelector(state: *const app.AppState) VNode {
    const modes = [_]app.WorkshopMode{ .crud, .query, .transaction, .keyvalue, .import_export };
    const S = struct {
        var items: [5]VNode = undefined;
    };

    for (modes, 0..) |mode, i| {
        S.items[i] = buildModeTab(mode, state.current_mode == mode);
    }

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(4),
            .gap = 4,
        },
    }, &S.items);
}

fn buildModeTab(mode: app.WorkshopMode, selected: bool) VNode {
    const bg = if (selected) getModeColor(mode) else 0;
    const text_color = if (selected) Color.text else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(mode.icon(), .{
        .style = .{ .color = text_color, .font_size = 16 },
    });
    S.items[1] = text(mode.title(), .{
        .style = .{ .font_size = 11, .color = text_color },
    });

    return column(.{
        .style = .{
            .padding = Spacing.symmetric(8, 6),
            .background = bg,
            .border_radius = 8,
            .alignment = .center,
            .gap = 2,
            .flex = 1,
        },
    }, &S.items);
}

fn getModeColor(mode: app.WorkshopMode) u32 {
    return switch (mode) {
        .crud => Color.crud,
        .query => Color.query,
        .transaction => Color.transaction,
        .keyvalue => Color.keyvalue,
        .import_export => Color.import_export,
    };
}

fn buildContent(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = switch (state.current_mode) {
        .crud => buildCRUDPanel(state),
        .query => buildQueryPanel(state),
        .transaction => buildTransactionPanel(state),
        .keyvalue => buildKeyValuePanel(state),
        .import_export => buildImportExportPanel(state),
    };
    S.items[1] = buildStatusBar(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

// CRUD Panel
fn buildCRUDPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildCRUDActions();
    S.items[1] = buildRecordList(state);
    S.items[2] = buildRecordDetail(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

fn buildCRUDActions() VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = button("Create", .{
        .style = .{
            .background = Color.success,
            .padding = Spacing.symmetric(16, 10),
            .border_radius = 8,
        },
    });
    S.items[1] = button("Read", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(16, 10),
            .border_radius = 8,
        },
    });
    S.items[2] = button("Update", .{
        .style = .{
            .background = Color.warning,
            .padding = Spacing.symmetric(16, 10),
            .border_radius = 8,
        },
    });
    S.items[3] = button("Delete", .{
        .style = .{
            .background = Color.error_color,
            .padding = Spacing.symmetric(16, 10),
            .border_radius = 8,
        },
    });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

fn buildRecordList(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.record_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
        var count_buf: [32]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "Records: {d}", .{state.record_count}) catch "Records: 0";

    S.items[0] = text(count_str, .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        const record = &state.records[i];
        const selected = state.selected_record == record.id;
        S.items[i + 1] = buildRecordRow(record, selected);
    }

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(12),
            .gap = 8,
        },
    }, S.items[0 .. display_count + 1]);
}

fn buildRecordRow(record: *const app.Record, selected: bool) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var id_buf: [8]u8 = undefined;
    };

    const id_str = std.fmt.bufPrint(&S.id_buf, "#{d}", .{record.id}) catch "#0";
    const bg = if (selected) Color.primary else Color.card;

    S.items[0] = text(id_str, .{
        .style = .{ .font_size = 12, .color = Color.text_secondary, .width = 30 },
    });
    S.items[1] = text(record.name[0..record.name_len], .{
        .style = .{ .font_size = 14, .color = Color.text, .flex = 1 },
    });
    S.items[2] = iconView(if (record.active) "checkmark.circle.fill" else "xmark.circle", .{
        .style = .{ .color = if (record.active) Color.success else Color.error_color },
    });

    return row(.{
        .style = .{
            .background = bg,
            .border_radius = 8,
            .padding = Spacing.symmetric(12, 8),
            .gap = 8,
            .alignment = .center,
        },
    }, &S.items);
}

fn buildRecordDetail(state: *const app.AppState) VNode {
    if (state.selected_record) |id| {
        for (state.records[0..state.record_count]) |*record| {
            if (record.id == id) {
                return buildRecordCard(record);
            }
        }
    }

    return text("Select a record to view details", .{
        .style = .{
            .font_size = 14,
            .color = Color.text_secondary,
            .alignment = .center,
        },
    });
}

fn buildRecordCard(record: *const app.Record) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var age_buf: [16]u8 = undefined;
    };

    const age_str = std.fmt.bufPrint(&S.age_buf, "{d} years old", .{record.age}) catch "0 years old";

    S.items[0] = buildDetailRow("Name", record.name[0..record.name_len]);
    S.items[1] = buildDetailRow("Email", record.email[0..record.email_len]);
    S.items[2] = buildDetailRow("Age", age_str);
    S.items[3] = buildDetailRow("Status", if (record.active) "Active" else "Inactive");

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildDetailRow(label: []const u8, value: []const u8) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{
        .style = .{ .font_size = 12, .color = Color.text_secondary, .width = 60 },
    });
    S.items[1] = text(value, .{
        .style = .{ .font_size = 14, .color = Color.text },
    });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

// Query Panel
fn buildQueryPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildQueryBuilder(state);
    S.items[1] = buildQueryActions();
    S.items[2] = buildQueryResults(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

fn buildQueryBuilder(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    const filter_value = if (state.filter.value_len > 0)
        state.filter.value[0..state.filter.value_len]
    else
        "No filter";

    S.items[0] = text("Query Builder", .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = buildDetailRow("Filter", filter_value);
    S.items[2] = buildDetailRow("Sort", if (state.sort_field_len > 0)
        state.sort_field[0..state.sort_field_len]
    else
        "None");

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildQueryActions() VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = button("Execute Query", .{
        .style = .{
            .background = Color.query,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });
    S.items[1] = button("Clear", .{
        .style = .{
            .background = Color.card,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

fn buildQueryResults(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var result_buf: [32]u8 = undefined;
    };

    const result_str = if (state.query_executed)
        std.fmt.bufPrint(&S.result_buf, "{d} records found", .{state.query_result_count}) catch "0 records"
    else
        "No query executed";

    S.items[0] = iconView("doc.text.magnifyingglass", .{
        .style = .{ .color = Color.query, .font_size = 32 },
    });
    S.items[1] = text(result_str, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(24),
            .alignment = .center,
            .gap = 12,
        },
    }, &S.items);
}

// Transaction Panel
fn buildTransactionPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildTransactionStatus(state);
    S.items[1] = buildTransactionActions(state);
    S.items[2] = buildTransactionInfo(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

fn buildTransactionStatus(state: *const app.AppState) VNode {
    const status = if (state.in_transaction) "Active Transaction" else "No Transaction";
    const color = if (state.in_transaction) Color.transaction else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(if (state.in_transaction) "arrow.triangle.2.circlepath.circle.fill" else "arrow.triangle.2.circlepath.circle", .{
        .style = .{ .color = color, .font_size = 48 },
    });
    S.items[1] = text(status, .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = color },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(32),
            .alignment = .center,
            .gap = 16,
        },
    }, &S.items);
}

fn buildTransactionActions(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    const begin_enabled = !state.in_transaction;
    const commit_enabled = state.in_transaction;
    const rollback_enabled = state.in_transaction;

    S.items[0] = button("Begin", .{
        .style = .{
            .background = if (begin_enabled) Color.success else Color.card,
            .padding = Spacing.symmetric(20, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });
    S.items[1] = button("Commit", .{
        .style = .{
            .background = if (commit_enabled) Color.primary else Color.card,
            .padding = Spacing.symmetric(20, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });
    S.items[2] = button("Rollback", .{
        .style = .{
            .background = if (rollback_enabled) Color.error_color else Color.card,
            .padding = Spacing.symmetric(20, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

fn buildTransactionInfo(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var ops_buf: [32]u8 = undefined;
    };

    const ops_str = std.fmt.bufPrint(&S.ops_buf, "{d}", .{state.transaction_operations}) catch "0";

    S.items[0] = buildDetailRow("Operations", ops_str);
    S.items[1] = buildDetailRow("Isolation", "Serializable");

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

// Key-Value Panel
fn buildKeyValuePanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildKVActions();
    S.items[1] = buildKVList(state);
    S.items[2] = buildKVStats(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

fn buildKVActions() VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = button("Set", .{
        .style = .{
            .background = Color.success,
            .padding = Spacing.symmetric(20, 10),
            .border_radius = 8,
        },
    });
    S.items[1] = button("Get", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(20, 10),
            .border_radius = 8,
        },
    });
    S.items[2] = button("Delete", .{
        .style = .{
            .background = Color.error_color,
            .padding = Spacing.symmetric(20, 10),
            .border_radius = 8,
        },
    });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

fn buildKVList(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.kv_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
        var count_buf: [32]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "Entries: {d}", .{state.kv_count}) catch "Entries: 0";

    S.items[0] = text(count_str, .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        const entry = &state.kv_entries[i];
        S.items[i + 1] = buildKVRow(entry);
    }

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(12),
            .gap = 8,
        },
    }, S.items[0 .. display_count + 1]);
}

fn buildKVRow(entry: *const app.KVEntry) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView("key.fill", .{
        .style = .{ .color = Color.keyvalue, .font_size = 14 },
    });
    S.items[1] = text(entry.key[0..entry.key_len], .{
        .style = .{ .font_size = 14, .color = Color.text, .flex = 1 },
    });
    S.items[2] = text(entry.value[0..@min(entry.value_len, 20)], .{
        .style = .{ .font_size = 12, .color = Color.text_secondary },
    });

    return row(.{
        .style = .{
            .background = Color.card,
            .border_radius = 8,
            .padding = Spacing.symmetric(12, 8),
            .gap = 8,
            .alignment = .center,
        },
    }, &S.items);
}

fn buildKVStats(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var size_buf: [32]u8 = undefined;
    };

    const estimated_size = state.kv_count * 320; // Approximate bytes per entry
    const size_str = if (estimated_size >= 1024)
        std.fmt.bufPrint(&S.size_buf, "{d} KB", .{estimated_size / 1024}) catch "0 KB"
    else
        std.fmt.bufPrint(&S.size_buf, "{d} B", .{estimated_size}) catch "0 B";

    S.items[0] = buildDetailRow("Total Size", size_str);
    S.items[1] = buildDetailRow("Max Entries", "50");

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

// Import/Export Panel
fn buildImportExportPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildFormatSelector(state);
    S.items[1] = buildExportActions();
    S.items[2] = buildExportStats(state);

    return column(.{ .style = .{ .gap = 12, .flex = 1 } }, &S.items);
}

fn buildFormatSelector(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text("Export Format", .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = button("JSON", .{
        .style = .{
            .background = if (state.export_format == .json) Color.import_export else Color.card,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });
    S.items[2] = button("CSV", .{
        .style = .{
            .background = if (state.export_format == .csv) Color.import_export else Color.card,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildExportActions() VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = button("Export Data", .{
        .style = .{
            .background = Color.import_export,
            .padding = Spacing.symmetric(24, 14),
            .border_radius = 8,
            .flex = 1,
        },
    });
    S.items[1] = button("Import Data", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(24, 14),
            .border_radius = 8,
            .flex = 1,
        },
    });

    return row(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildExportStats(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var size_buf: [32]u8 = undefined;
        var import_buf: [32]u8 = undefined;
    };

    const size_str = if (state.last_export_size > 0)
        std.fmt.bufPrint(&S.size_buf, "{d} bytes", .{state.last_export_size}) catch "0 bytes"
    else
        "No export yet";

    const import_str = if (state.last_import_count > 0)
        std.fmt.bufPrint(&S.import_buf, "{d} records", .{state.last_import_count}) catch "0 records"
    else
        "No import yet";

    S.items[0] = buildDetailRow("Last Export", size_str);
    S.items[1] = buildDetailRow("Last Import", import_str);

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

// Status Bar
fn buildStatusBar(state: *const app.AppState) VNode {
    const color = switch (state.status) {
        .idle => Color.text_secondary,
        .pending => Color.warning,
        .success => Color.success,
        .error_status => Color.error_color,
    };

    const icon_name = switch (state.status) {
        .idle => "circle",
        .pending => "clock",
        .success => "checkmark.circle.fill",
        .error_status => "xmark.circle.fill",
    };

    const message = if (state.status_message_len > 0)
        state.status_message[0..state.status_message_len]
    else
        "Ready";

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{
        .style = .{ .color = color, .font_size = 14 },
    });
    S.items[1] = text(message, .{
        .style = .{ .font_size = 12, .color = color },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 8,
            .padding = Spacing.symmetric(12, 8),
            .gap = 8,
            .alignment = .center,
        },
    }, &S.items);
}

// Tests
test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "mode colors" {
    try std.testing.expectEqual(Color.crud, getModeColor(.crud));
    try std.testing.expectEqual(Color.transaction, getModeColor(.transaction));
}
