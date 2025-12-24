//! Shop Demo - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    category = 1,
    product = 2,
    cart = 3,
    checkout = 4,
    orders = 5,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "Shop",
            .category => "Category",
            .product => "Product",
            .cart => "Cart",
            .checkout => "Checkout",
            .orders => "Orders",
        };
    }
};

pub const Category = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    icon: [32]u8 = [_]u8{0} ** 32,
    icon_len: usize = 0,
    product_count: u32 = 0,
};

pub const Product = struct {
    id: u32 = 0,
    category_id: u32 = 0,
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,
    price: u32 = 0, // cents
    original_price: u32 = 0,
    rating: f32 = 0,
    review_count: u32 = 0,
    in_stock: bool = true,
};

pub const CartItem = struct {
    product_id: u32 = 0,
    quantity: u32 = 0,
};

pub const Order = struct {
    id: u32 = 0,
    total: u32 = 0,
    item_count: u32 = 0,
    status: OrderStatus = .pending,
    created_at: i64 = 0,
};

pub const OrderStatus = enum(u8) {
    pending = 0,
    processing = 1,
    shipped = 2,
    delivered = 3,

    pub fn name(self: OrderStatus) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .processing => "Processing",
            .shipped => "Shipped",
            .delivered => "Delivered",
        };
    }
};

pub const max_categories = 10;
pub const max_products = 50;
pub const max_cart_items = 20;
pub const max_wishlist = 20;
pub const max_orders = 10;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // Catalog
    categories: [max_categories]Category = undefined,
    category_count: usize = 0,
    selected_category: ?u32 = null,

    products: [max_products]Product = undefined,
    product_count: usize = 0,
    selected_product: ?u32 = null,

    // Cart
    cart: [max_cart_items]CartItem = undefined,
    cart_count: usize = 0,

    // Wishlist
    wishlist: [max_wishlist]u32 = [_]u32{0} ** max_wishlist,
    wishlist_count: usize = 0,

    // Orders
    orders: [max_orders]Order = undefined,
    order_count: usize = 0,
    next_order_id: u32 = 1001,

    // Search
    search_query: [64]u8 = [_]u8{0} ** 64,
    search_query_len: usize = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Categories
    _ = addCategory("Electronics", "laptopcomputer");
    _ = addCategory("Clothing", "tshirt");
    _ = addCategory("Home", "house");
    _ = addCategory("Sports", "sportscourt");

    // Products
    _ = addProduct(1, "Wireless Headphones", 7999, 9999, 4.5, 128);
    _ = addProduct(1, "Smart Watch", 19999, 24999, 4.7, 256);
    _ = addProduct(1, "Bluetooth Speaker", 4999, 5999, 4.3, 89);
    _ = addProduct(2, "Cotton T-Shirt", 1999, 2499, 4.2, 45);
    _ = addProduct(2, "Denim Jeans", 4999, 6999, 4.4, 67);
    _ = addProduct(3, "Coffee Maker", 8999, 10999, 4.6, 112);
    _ = addProduct(3, "Desk Lamp", 2999, 3999, 4.1, 34);
    _ = addProduct(4, "Yoga Mat", 2499, 2999, 4.8, 203);
}

fn addCategory(name: []const u8, icon: []const u8) ?u32 {
    if (app_state.category_count >= max_categories) return null;

    var cat = &app_state.categories[app_state.category_count];
    cat.id = @intCast(app_state.category_count + 1);

    const name_len = @min(name.len, cat.name.len);
    @memcpy(cat.name[0..name_len], name[0..name_len]);
    cat.name_len = name_len;

    const icon_len = @min(icon.len, cat.icon.len);
    @memcpy(cat.icon[0..icon_len], icon[0..icon_len]);
    cat.icon_len = icon_len;

    app_state.category_count += 1;
    return cat.id;
}

fn addProduct(category_id: u32, name: []const u8, price: u32, original: u32, rating: f32, reviews: u32) ?u32 {
    if (app_state.product_count >= max_products) return null;

    var prod = &app_state.products[app_state.product_count];
    prod.id = @intCast(app_state.product_count + 1);
    prod.category_id = category_id;

    const name_len = @min(name.len, prod.name.len);
    @memcpy(prod.name[0..name_len], name[0..name_len]);
    prod.name_len = name_len;

    prod.price = price;
    prod.original_price = original;
    prod.rating = rating;
    prod.review_count = reviews;
    prod.in_stock = true;

    // Update category count
    for (app_state.categories[0..app_state.category_count]) |*cat| {
        if (cat.id == category_id) {
            cat.product_count += 1;
            break;
        }
    }

    app_state.product_count += 1;
    return prod.id;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

pub fn selectCategory(id: ?u32) void {
    app_state.selected_category = id;
    if (id != null) {
        app_state.current_screen = .category;
    }
}

pub fn selectProduct(id: ?u32) void {
    app_state.selected_product = id;
    if (id != null) {
        app_state.current_screen = .product;
    }
}

// Cart operations
pub fn addToCart(product_id: u32) bool {
    // Check if already in cart
    for (app_state.cart[0..app_state.cart_count]) |*item| {
        if (item.product_id == product_id) {
            item.quantity += 1;
            return true;
        }
    }

    // Add new item
    if (app_state.cart_count >= max_cart_items) return false;

    app_state.cart[app_state.cart_count] = .{
        .product_id = product_id,
        .quantity = 1,
    };
    app_state.cart_count += 1;
    return true;
}

pub fn removeFromCart(product_id: u32) bool {
    for (app_state.cart[0..app_state.cart_count], 0..) |*item, i| {
        if (item.product_id == product_id) {
            if (i < app_state.cart_count - 1) {
                var j = i;
                while (j < app_state.cart_count - 1) : (j += 1) {
                    app_state.cart[j] = app_state.cart[j + 1];
                }
            }
            app_state.cart_count -= 1;
            return true;
        }
    }
    return false;
}

pub fn updateQuantity(product_id: u32, quantity: u32) bool {
    if (quantity == 0) return removeFromCart(product_id);

    for (app_state.cart[0..app_state.cart_count]) |*item| {
        if (item.product_id == product_id) {
            item.quantity = quantity;
            return true;
        }
    }
    return false;
}

pub fn clearCart() void {
    app_state.cart_count = 0;
}

pub fn getCartCount() u32 {
    var count: u32 = 0;
    for (app_state.cart[0..app_state.cart_count]) |item| {
        count += item.quantity;
    }
    return count;
}

pub fn getCartTotal() u32 {
    var total: u32 = 0;
    for (app_state.cart[0..app_state.cart_count]) |item| {
        if (getProduct(item.product_id)) |product| {
            total += product.price * item.quantity;
        }
    }
    return total;
}

pub fn getProduct(id: u32) ?*const Product {
    for (app_state.products[0..app_state.product_count]) |*product| {
        if (product.id == id) return product;
    }
    return null;
}

// Wishlist
pub fn toggleWishlist(product_id: u32) void {
    // Check if in wishlist
    for (app_state.wishlist[0..app_state.wishlist_count], 0..) |id, i| {
        if (id == product_id) {
            // Remove
            if (i < app_state.wishlist_count - 1) {
                var j = i;
                while (j < app_state.wishlist_count - 1) : (j += 1) {
                    app_state.wishlist[j] = app_state.wishlist[j + 1];
                }
            }
            app_state.wishlist_count -= 1;
            return;
        }
    }

    // Add
    if (app_state.wishlist_count < max_wishlist) {
        app_state.wishlist[app_state.wishlist_count] = product_id;
        app_state.wishlist_count += 1;
    }
}

pub fn isInWishlist(product_id: u32) bool {
    for (app_state.wishlist[0..app_state.wishlist_count]) |id| {
        if (id == product_id) return true;
    }
    return false;
}

// Checkout
pub fn proceedToCheckout() void {
    if (app_state.cart_count > 0) {
        app_state.current_screen = .checkout;
    }
}

pub fn placeOrder() ?u32 {
    if (app_state.cart_count == 0) return null;
    if (app_state.order_count >= max_orders) return null;

    var order = &app_state.orders[app_state.order_count];
    order.id = app_state.next_order_id;
    order.total = getCartTotal();
    order.item_count = getCartCount();
    order.status = .pending;
    order.created_at = 1700000000;

    app_state.next_order_id += 1;
    app_state.order_count += 1;

    clearCart();
    app_state.current_screen = .orders;

    return order.id;
}

// Search
pub fn setSearchQuery(query: []const u8) void {
    const len = @min(query.len, app_state.search_query.len);
    @memcpy(app_state.search_query[0..len], query[0..len]);
    app_state.search_query_len = len;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.category_count > 0);
    try std.testing.expect(app_state.product_count > 0);
}

test "cart operations" {
    init();
    defer deinit();
    try std.testing.expect(addToCart(1));
    try std.testing.expectEqual(@as(usize, 1), app_state.cart_count);
    try std.testing.expectEqual(@as(u32, 1), getCartCount());
    try std.testing.expect(addToCart(1)); // Add again
    try std.testing.expectEqual(@as(u32, 2), getCartCount()); // Quantity increased
    try std.testing.expect(removeFromCart(1));
    try std.testing.expectEqual(@as(usize, 0), app_state.cart_count);
}

test "wishlist" {
    init();
    defer deinit();
    try std.testing.expect(!isInWishlist(1));
    toggleWishlist(1);
    try std.testing.expect(isInWishlist(1));
    toggleWishlist(1);
    try std.testing.expect(!isInWishlist(1));
}

test "cart total" {
    init();
    defer deinit();
    _ = addToCart(1); // Wireless Headphones $79.99
    const total = getCartTotal();
    try std.testing.expectEqual(@as(u32, 7999), total);
}

test "place order" {
    init();
    defer deinit();
    _ = addToCart(1);
    const order_id = placeOrder();
    try std.testing.expect(order_id != null);
    try std.testing.expectEqual(@as(usize, 0), app_state.cart_count);
    try std.testing.expectEqual(@as(usize, 1), app_state.order_count);
}

test "screen navigation" {
    init();
    defer deinit();
    setScreen(.cart);
    try std.testing.expectEqual(Screen.cart, app_state.current_screen);
}
