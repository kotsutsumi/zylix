//! In-App Purchase (IAP) Module
//!
//! Unified purchase flow across platforms with support for:
//! - Product catalog query
//! - Purchase and restore functionality
//! - Entitlement verification
//! - Receipt validation
//!
//! Platform implementations:
//! - iOS: StoreKit 2
//! - Android: Play Billing
//! - Web/Desktop: Not supported (stub implementation)

const std = @import("std");

/// IAP error types
pub const IapError = error{
    NotAvailable,
    NotInitialized,
    ProductNotFound,
    PurchaseCancelled,
    PurchaseFailed,
    PurchasePending,
    RestoreFailed,
    ReceiptValidationFailed,
    NetworkError,
    UserNotAuthenticated,
    DeferredPayment,
    InvalidProduct,
    StoreError,
    OutOfMemory,
};

/// Product type
pub const ProductType = enum(u8) {
    consumable = 0,
    non_consumable = 1,
    auto_renewable_subscription = 2,
    non_renewing_subscription = 3,
};

/// Product information
pub const Product = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    price: f64,
    price_locale: []const u8,
    currency_code: []const u8,
    product_type: ProductType,

    /// Format price with currency symbol
    pub fn formattedPrice(self: *const Product, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}{d:.2}", .{ self.price_locale, self.price });
    }
};

/// Purchase state
pub const PurchaseState = enum(u8) {
    pending = 0,
    purchased = 1,
    failed = 2,
    cancelled = 3,
    deferred = 4,
    restored = 5,
};

/// Purchase result
pub const PurchaseResult = struct {
    product_id: []const u8,
    transaction_id: []const u8,
    state: PurchaseState,
    purchase_date: i64, // Unix timestamp in milliseconds
    receipt_data: ?[]const u8 = null,
    error_message: ?[]const u8 = null,

    pub fn isSuccessful(self: *const PurchaseResult) bool {
        return self.state == .purchased or self.state == .restored;
    }
};

/// Restore result
pub const RestoreResult = struct {
    restored_products: []const []const u8,
    failed_count: u32 = 0,
    error_message: ?[]const u8 = null,

    pub fn isSuccessful(self: *const RestoreResult) bool {
        return self.failed_count == 0 and self.error_message == null;
    }
};

/// Entitlement information
pub const Entitlement = struct {
    product_id: []const u8,
    is_active: bool,
    expiration_date: ?i64 = null, // For subscriptions
    purchase_date: i64,
    original_transaction_id: []const u8,

    pub fn isExpired(self: *const Entitlement) bool {
        if (self.expiration_date) |exp| {
            return std.time.milliTimestamp() > exp;
        }
        return false;
    }
};

/// Receipt validation result
pub const ValidationResult = struct {
    is_valid: bool,
    environment: Environment,
    entitlements: []const Entitlement,
    error_message: ?[]const u8 = null,
};

/// Store environment
pub const Environment = enum(u8) {
    sandbox = 0,
    production = 1,
    unknown = 255,
};

/// Store configuration
pub const StoreConfig = struct {
    /// Enable debug logging
    debug: bool = false,
    /// Auto-finish transactions (set to false for server-side validation)
    auto_finish_transactions: bool = true,
    /// Receipt validation URL (for server-side validation)
    validation_url: ?[]const u8 = null,
    /// Shared secret for App Store validation
    shared_secret: ?[]const u8 = null,
};

/// Future result wrapper for async operations
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?IapError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?IapError) void = null,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
            if (self.callback) |cb| {
                cb(value, null);
            }
        }

        pub fn fail(self: *Self, err: IapError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) IapError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return IapError.NotInitialized;
        }

        pub fn onComplete(self: *Self, callback: *const fn (?T, ?IapError) void) void {
            self.callback = callback;
            if (self.completed) {
                callback(self.result, self.err);
            }
        }
    };
}

/// In-App Purchase Store
pub const Store = struct {
    allocator: std.mem.Allocator,
    config: StoreConfig,
    initialized: bool = false,
    products: std.StringHashMapUnmanaged(Product) = .{},
    entitlements: std.StringHashMapUnmanaged(Entitlement) = .{},

    // Platform-specific handle (opaque pointer)
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: StoreConfig) Store {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Store) void {
        self.products.deinit(self.allocator);
        self.entitlements.deinit(self.allocator);
        self.initialized = false;
    }

    /// Initialize the store connection
    pub fn initialize(self: *Store) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(IapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        // Platform-specific initialization would happen here
        // For now, mark as initialized (stub implementation)
        self.initialized = true;
        future.complete({});

        return future;
    }

    /// Get product information for given product IDs
    pub fn getProducts(self: *Store, product_ids: []const []const u8) *Future([]Product) {
        const future = self.allocator.create(Future([]Product)) catch {
            const err_future = self.allocator.create(Future([]Product)) catch unreachable;
            err_future.* = Future([]Product).init();
            err_future.fail(IapError.OutOfMemory);
            return err_future;
        };
        future.* = Future([]Product).init();

        if (!self.initialized) {
            future.fail(IapError.NotInitialized);
            return future;
        }

        // Platform-specific product fetch would happen here
        // For now, return empty array (stub implementation)
        _ = product_ids;
        const empty: []Product = &.{};
        future.complete(empty);

        return future;
    }

    /// Purchase a product
    pub fn purchase(self: *Store, product_id: []const u8) *Future(PurchaseResult) {
        const future = self.allocator.create(Future(PurchaseResult)) catch {
            const err_future = self.allocator.create(Future(PurchaseResult)) catch unreachable;
            err_future.* = Future(PurchaseResult).init();
            err_future.fail(IapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(PurchaseResult).init();

        if (!self.initialized) {
            future.fail(IapError.NotInitialized);
            return future;
        }

        // Platform-specific purchase would happen here
        // For now, return stub result
        future.complete(.{
            .product_id = product_id,
            .transaction_id = "stub_transaction",
            .state = .failed,
            .purchase_date = std.time.milliTimestamp(),
            .error_message = "IAP not available on this platform",
        });

        return future;
    }

    /// Restore previous purchases
    pub fn restore(self: *Store) *Future(RestoreResult) {
        const future = self.allocator.create(Future(RestoreResult)) catch {
            const err_future = self.allocator.create(Future(RestoreResult)) catch unreachable;
            err_future.* = Future(RestoreResult).init();
            err_future.fail(IapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(RestoreResult).init();

        if (!self.initialized) {
            future.fail(IapError.NotInitialized);
            return future;
        }

        // Platform-specific restore would happen here
        // For now, return empty result
        const empty: []const []const u8 = &.{};
        future.complete(.{
            .restored_products = empty,
        });

        return future;
    }

    /// Check if user has entitlement for a product
    pub fn hasEntitlement(self: *const Store, product_id: []const u8) bool {
        if (self.entitlements.get(product_id)) |ent| {
            return ent.is_active and !ent.isExpired();
        }
        return false;
    }

    /// Get all active entitlements
    pub fn getEntitlements(self: *const Store, allocator: std.mem.Allocator) ![]Entitlement {
        var list = std.ArrayList(Entitlement).init(allocator);
        errdefer list.deinit();

        var iter = self.entitlements.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.is_active and !entry.value_ptr.isExpired()) {
                try list.append(entry.value_ptr.*);
            }
        }

        return list.toOwnedSlice();
    }

    /// Validate a receipt (for server-side validation)
    pub fn validateReceipt(self: *Store, receipt_data: []const u8) *Future(ValidationResult) {
        const future = self.allocator.create(Future(ValidationResult)) catch {
            const err_future = self.allocator.create(Future(ValidationResult)) catch unreachable;
            err_future.* = Future(ValidationResult).init();
            err_future.fail(IapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ValidationResult).init();

        if (!self.initialized) {
            future.fail(IapError.NotInitialized);
            return future;
        }

        // Server-side validation would happen here
        _ = receipt_data;
        const empty: []const Entitlement = &.{};
        future.complete(.{
            .is_valid = false,
            .environment = .unknown,
            .entitlements = empty,
            .error_message = "Receipt validation not implemented",
        });

        return future;
    }

    /// Finish a transaction (required when auto_finish_transactions is false)
    pub fn finishTransaction(self: *Store, transaction_id: []const u8) void {
        if (!self.initialized) return;
        // Platform-specific transaction finish would happen here
        _ = transaction_id;
    }

    /// Check if store is available on this platform
    pub fn isAvailable() bool {
        // Platform detection would happen here
        // For now, return false (not available)
        return false;
    }

    /// Get the current store environment
    pub fn getEnvironment(self: *const Store) Environment {
        _ = self;
        // Platform-specific environment detection
        return .unknown;
    }
};

/// Convenience function to create a store instance
pub fn createStore(allocator: std.mem.Allocator, config: StoreConfig) Store {
    return Store.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultStore(allocator: std.mem.Allocator) Store {
    return Store.init(allocator, .{});
}

// Tests
test "Store initialization" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    const future = store.initialize();
    try std.testing.expect(future.isCompleted());
    try std.testing.expect(store.initialized);
}

test "Store availability check" {
    try std.testing.expect(!Store.isAvailable());
}

test "Product struct" {
    const product = Product{
        .id = "com.example.premium",
        .title = "Premium",
        .description = "Unlock all features",
        .price = 9.99,
        .price_locale = "$",
        .currency_code = "USD",
        .product_type = .non_consumable,
    };

    try std.testing.expect(std.mem.eql(u8, product.id, "com.example.premium"));
    try std.testing.expectEqual(ProductType.non_consumable, product.product_type);
}

test "PurchaseResult success check" {
    const success = PurchaseResult{
        .product_id = "test",
        .transaction_id = "tx123",
        .state = .purchased,
        .purchase_date = 0,
    };
    try std.testing.expect(success.isSuccessful());

    const failed = PurchaseResult{
        .product_id = "test",
        .transaction_id = "tx456",
        .state = .failed,
        .purchase_date = 0,
    };
    try std.testing.expect(!failed.isSuccessful());
}

test "Entitlement expiration check" {
    const active = Entitlement{
        .product_id = "sub_monthly",
        .is_active = true,
        .expiration_date = std.time.milliTimestamp() + 86400000, // +1 day
        .purchase_date = std.time.milliTimestamp() - 86400000,
        .original_transaction_id = "orig_tx",
    };
    try std.testing.expect(!active.isExpired());

    const expired = Entitlement{
        .product_id = "sub_monthly",
        .is_active = true,
        .expiration_date = std.time.milliTimestamp() - 86400000, // -1 day
        .purchase_date = std.time.milliTimestamp() - 172800000,
        .original_transaction_id = "orig_tx2",
    };
    try std.testing.expect(expired.isExpired());
}

test "hasEntitlement" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    try std.testing.expect(!store.hasEntitlement("non_existent"));
}

test "Future completion" {
    var future = Future(i32).init();
    try std.testing.expect(!future.isCompleted());

    future.complete(42);
    try std.testing.expect(future.isCompleted());
    try std.testing.expectEqual(@as(i32, 42), try future.get());
}

test "Future failure" {
    var future = Future(i32).init();
    future.fail(IapError.NotAvailable);
    try std.testing.expect(future.isCompleted());
    try std.testing.expectError(IapError.NotAvailable, future.get());
}
