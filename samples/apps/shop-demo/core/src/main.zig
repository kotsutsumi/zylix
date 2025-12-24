//! Shop Demo - Entry Point and C ABI Exports

const std = @import("std");
pub const app = @import("app.zig");
pub const ui = @import("ui.zig");

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

// Navigation
export fn app_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn app_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

export fn app_select_category(id: u32) void {
    if (id == 0) {
        app.selectCategory(null);
    } else {
        app.selectCategory(id);
    }
}

export fn app_select_product(id: u32) void {
    if (id == 0) {
        app.selectProduct(null);
    } else {
        app.selectProduct(id);
    }
}

// Cart operations
export fn app_add_to_cart(product_id: u32) i32 {
    return if (app.addToCart(product_id)) 1 else 0;
}

export fn app_remove_from_cart(product_id: u32) i32 {
    return if (app.removeFromCart(product_id)) 1 else 0;
}

export fn app_update_quantity(product_id: u32, quantity: u32) i32 {
    return if (app.updateQuantity(product_id, quantity)) 1 else 0;
}

export fn app_clear_cart() void {
    app.clearCart();
}

export fn app_get_cart_count() u32 {
    return app.getCartCount();
}

export fn app_get_cart_total() u32 {
    return app.getCartTotal();
}

// Wishlist
export fn app_toggle_wishlist(product_id: u32) void {
    app.toggleWishlist(product_id);
}

export fn app_is_in_wishlist(product_id: u32) i32 {
    return if (app.isInWishlist(product_id)) 1 else 0;
}

// Checkout
export fn app_proceed_to_checkout() void {
    app.proceedToCheckout();
}

export fn app_place_order() u32 {
    return app.placeOrder() orelse 0;
}

// State queries
export fn app_get_category_count() u32 {
    return @intCast(app.getState().category_count);
}

export fn app_get_product_count() u32 {
    return @intCast(app.getState().product_count);
}

export fn app_get_order_count() u32 {
    return @intCast(app.getState().order_count);
}

export fn app_get_wishlist_count() u32 {
    return @intCast(app.getState().wishlist_count);
}

// Search
export fn app_set_search_query(ptr: [*]const u8, len: usize) void {
    if (len > 0) {
        app.setSearchQuery(ptr[0..len]);
    } else {
        app.setSearchQuery("");
    }
}

// UI rendering
export fn app_render() [*]const ui.VNode {
    return ui.render();
}

// ============================================================================
// Tests
// ============================================================================

test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(app.getState().initialized);
}

test "cart workflow" {
    init();
    defer deinit();

    // Add to cart
    try std.testing.expectEqual(@as(i32, 1), app_add_to_cart(1));
    try std.testing.expectEqual(@as(u32, 1), app_get_cart_count());

    // Add same item again (quantity increases)
    try std.testing.expectEqual(@as(i32, 1), app_add_to_cart(1));
    try std.testing.expectEqual(@as(u32, 2), app_get_cart_count());

    // Check total (Wireless Headphones $79.99 x 2 = $159.98)
    try std.testing.expectEqual(@as(u32, 15998), app_get_cart_total());

    // Update quantity
    try std.testing.expectEqual(@as(i32, 1), app_update_quantity(1, 1));
    try std.testing.expectEqual(@as(u32, 1), app_get_cart_count());

    // Remove from cart
    try std.testing.expectEqual(@as(i32, 1), app_remove_from_cart(1));
    try std.testing.expectEqual(@as(u32, 0), app_get_cart_count());
}

test "wishlist operations" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i32, 0), app_is_in_wishlist(1));
    app_toggle_wishlist(1);
    try std.testing.expectEqual(@as(i32, 1), app_is_in_wishlist(1));
    try std.testing.expectEqual(@as(u32, 1), app_get_wishlist_count());
    app_toggle_wishlist(1);
    try std.testing.expectEqual(@as(i32, 0), app_is_in_wishlist(1));
}

test "checkout flow" {
    init();
    defer deinit();

    // Cannot place order with empty cart
    try std.testing.expectEqual(@as(u32, 0), app_place_order());

    // Add item and place order
    _ = app_add_to_cart(1);
    app_proceed_to_checkout();
    try std.testing.expectEqual(@intFromEnum(app.Screen.checkout), app_get_screen());

    const order_id = app_place_order();
    try std.testing.expect(order_id >= 1001);
    try std.testing.expectEqual(@as(u32, 0), app_get_cart_count());
    try std.testing.expectEqual(@as(u32, 1), app_get_order_count());
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(3); // cart
    try std.testing.expectEqual(@as(u8, 3), app_get_screen());

    app_select_category(1);
    try std.testing.expectEqual(@as(u8, 1), app_get_screen()); // category screen

    app_select_product(1);
    try std.testing.expectEqual(@as(u8, 2), app_get_screen()); // product screen
}

test "data queries" {
    init();
    defer deinit();

    try std.testing.expect(app_get_category_count() > 0);
    try std.testing.expect(app_get_product_count() > 0);
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
