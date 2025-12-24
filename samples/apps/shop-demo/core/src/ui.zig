//! Shop Demo - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, image, spacer };

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
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFFF5F5F5;
    pub const surface: u32 = 0xFFFFFFFF;
    pub const card: u32 = 0xFFFFFFFF;
    pub const text: u32 = 0xFF1C1C1E;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFFFF6B00;
    pub const success: u32 = 0xFF34C759;
    pub const sale: u32 = 0xFFFF3B30;
    pub const star: u32 = 0xFFFFCC00;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
    icon: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

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
fn spacer() VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [3]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildContent(state);
    S.content[2] = buildTabBar(state);

    return column(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var cart_buf: [8]u8 = undefined;
    };

    const cart_count = app.getCartCount();
    const cart_str = std.fmt.bufPrint(&S.cart_buf, "{d}", .{cart_count}) catch "0";

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = row(.{ .style = .{ .gap = 4 } }, &.{
        iconView("cart", .{ .style = .{ .color = Color.text, .font_size = 20 } }),
        text(cart_str, .{ .style = .{ .font_size = 12, .color = Color.primary } }),
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(16, 12),
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .category => buildCategoryScreen(state),
        .product => buildProductScreen(state),
        .cart => buildCartScreen(state),
        .checkout => buildCheckoutScreen(state),
        .orders => buildOrdersScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    const max_display = 4;
    const display_count = @min(state.category_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Categories", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text, .padding = Spacing.all(16) },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildCategoryCard(&state.categories[i]);
    }

    return column(.{ .style = .{ .gap = 8, .flex = 1 } }, S.items[0 .. display_count + 1]);
}

fn buildCategoryCard(category: *const app.Category) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "{d} items", .{category.product_count}) catch "0 items";

    S.items[0] = iconView(category.icon[0..category.icon_len], .{
        .style = .{ .color = Color.primary, .font_size = 24 },
    });
    S.items[1] = text(category.name[0..category.name_len], .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[2] = text(count_str, .{
        .style = .{ .font_size = 12, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildCategoryScreen(state: *const app.AppState) VNode {
    const max_display = 6;
    var display_count: usize = 0;

    const S = struct {
        var items: [max_display]VNode = undefined;
    };

    if (state.selected_category) |cat_id| {
        for (state.products[0..state.product_count]) |*product| {
            if (display_count >= max_display) break;
            if (product.category_id == cat_id) {
                S.items[display_count] = buildProductCard(product, app.isInWishlist(product.id));
                display_count += 1;
            }
        }
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0..display_count]);
}

fn buildProductCard(product: *const app.Product, in_wishlist: bool) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var price_buf: [16]u8 = undefined;
        var rating_buf: [8]u8 = undefined;
    };

    const price_str = std.fmt.bufPrint(&S.price_buf, "${d}.{d:0>2}", .{
        product.price / 100,
        product.price % 100,
    }) catch "$0.00";

    const rating_str = std.fmt.bufPrint(&S.rating_buf, "{d:.1}", .{product.rating}) catch "0.0";

    S.items[0] = row(.{}, &.{
        text(product.name[0..product.name_len], .{
            .style = .{ .font_size = 14, .font_weight = 500, .color = Color.text, .flex = 1 },
        }),
        iconView(if (in_wishlist) "heart.fill" else "heart", .{
            .style = .{ .color = if (in_wishlist) Color.sale else Color.text_secondary },
        }),
    });
    S.items[1] = row(.{ .style = .{ .gap = 4 } }, &.{
        iconView("star.fill", .{ .style = .{ .color = Color.star, .font_size = 12 } }),
        text(rating_str, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });
    S.items[2] = text(price_str, .{
        .style = .{ .font_size = 18, .font_weight = 700, .color = Color.primary },
    });
    S.items[3] = button("Add to Cart", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(12, 8),
            .border_radius = 8,
            .color = 0xFFFFFFFF,
        },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(12),
            .gap = 8,
        },
    }, &S.items);
}

fn buildProductScreen(state: *const app.AppState) VNode {
    if (state.selected_product) |prod_id| {
        if (app.getProduct(prod_id)) |product| {
            return buildProductDetail(product);
        }
    }
    return text("Product not found", .{ .style = .{ .color = Color.text_secondary } });
}

fn buildProductDetail(product: *const app.Product) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var price_buf: [16]u8 = undefined;
    };

    const price_str = std.fmt.bufPrint(&S.price_buf, "${d}.{d:0>2}", .{
        product.price / 100,
        product.price % 100,
    }) catch "$0.00";

    S.items[0] = div(.{ .style = .{ .background = 0xFFE0E0E0, .height = 200, .border_radius = 12 } }, &.{});
    S.items[1] = text(product.name[0..product.name_len], .{
        .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
    });
    S.items[2] = text(price_str, .{
        .style = .{ .font_size = 28, .font_weight = 700, .color = Color.primary },
    });
    S.items[3] = button("Add to Cart", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(24, 14),
            .border_radius = 12,
            .color = 0xFFFFFFFF,
            .font_size = 16,
        },
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildCartScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var total_buf: [24]u8 = undefined;
    };

    const total = app.getCartTotal();
    const total_str = std.fmt.bufPrint(&S.total_buf, "Total: ${d}.{d:0>2}", .{
        total / 100,
        total % 100,
    }) catch "Total: $0.00";

    S.items[0] = buildCartItems(state);
    S.items[1] = text(total_str, .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text, .padding = Spacing.all(16) },
    });
    S.items[2] = button("Checkout", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(24, 14),
            .border_radius = 12,
            .color = 0xFFFFFFFF,
        },
    });

    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 } }, &S.items);
}

fn buildCartItems(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.cart_count, max_display);

    const S = struct {
        var items: [max_display]VNode = undefined;
    };

    for (0..display_count) |i| {
        S.items[i] = buildCartItem(&state.cart[i]);
    }

    return column(.{ .style = .{ .gap = 8 } }, S.items[0..display_count]);
}

fn buildCartItem(item: *const app.CartItem) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var qty_buf: [8]u8 = undefined;
        var price_buf: [16]u8 = undefined;
    };

    const qty_str = std.fmt.bufPrint(&S.qty_buf, "x{d}", .{item.quantity}) catch "x1";

    if (app.getProduct(item.product_id)) |product| {
        const price_str = std.fmt.bufPrint(&S.price_buf, "${d}.{d:0>2}", .{
            (product.price * item.quantity) / 100,
            (product.price * item.quantity) % 100,
        }) catch "$0.00";

        S.items[0] = text(product.name[0..product.name_len], .{
            .style = .{ .font_size = 14, .color = Color.text, .flex = 1 },
        });
        S.items[1] = text(qty_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });
        S.items[2] = text(price_str, .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } });
    } else {
        S.items[0] = text("Unknown", .{ .style = .{ .color = Color.text_secondary } });
        S.items[1] = text(qty_str, .{ .style = .{ .color = Color.text_secondary } });
        S.items[2] = text("$0.00", .{ .style = .{ .color = Color.text_secondary } });
    }

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 8,
            .padding = Spacing.all(12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildCheckoutScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text("Shipping Address", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = div(.{
        .style = .{ .background = Color.surface, .border_radius = 12, .padding = Spacing.all(16), .height = 80 },
    }, &.{});
    S.items[2] = button("Place Order", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(24, 14),
            .border_radius = 12,
            .color = 0xFFFFFFFF,
        },
    });

    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 } }, &S.items);
}

fn buildOrdersScreen(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.order_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Order History", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildOrderItem(&state.orders[i]);
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0 .. display_count + 1]);
}

fn buildOrderItem(order: *const app.Order) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var id_buf: [16]u8 = undefined;
        var total_buf: [16]u8 = undefined;
    };

    const id_str = std.fmt.bufPrint(&S.id_buf, "#{d}", .{order.id}) catch "#0";
    const total_str = std.fmt.bufPrint(&S.total_buf, "${d}.{d:0>2}", .{
        order.total / 100,
        order.total % 100,
    }) catch "$0.00";

    S.items[0] = text(id_str, .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } });
    S.items[1] = text(order.status.name(), .{ .style = .{ .font_size = 12, .color = Color.success } });
    S.items[2] = text(total_str, .{ .style = .{ .font_size = 14, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 8,
            .padding = Spacing.all(12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildTabBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildTabItem("house", "Home", state.current_screen == .home);
    S.items[1] = buildTabItem("heart", "Wishlist", false);
    S.items[2] = buildTabItem("cart", "Cart", state.current_screen == .cart);
    S.items[3] = buildTabItem("person", "Account", false);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(icon_name: []const u8, label: []const u8, selected: bool) VNode {
    const color = if (selected) Color.primary else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 20 } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 10, .color = color } });

    return column(.{ .style = .{ .flex = 1, .gap = 4, .padding = Spacing.symmetric(0, 8) } }, &S.items);
}

// ============================================================================
// C ABI Export
// ============================================================================

pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildApp(app.getState());
    return &S.root;
}

// ============================================================================
// Tests
// ============================================================================

test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
