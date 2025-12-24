//! Advertising Module
//!
//! Unified advertising abstraction with support for:
//! - Banner ads (show/hide by placement)
//! - Interstitial ads
//! - Rewarded video ads
//! - GDPR/privacy compliance helpers
//!
//! Platform implementations:
//! - iOS: AdMob / AppLovin
//! - Android: AdMob / AppLovin
//! - Web/Desktop: Not supported (stub implementation)
//!
//! IMPORTANT: String lifetimes
//! - placement_id strings are stored by reference, not copied.
//! - Callers must ensure placement_id strings outlive their use in the Ads manager.
//! - For long-lived placements, use string literals or allocator-owned strings.

const std = @import("std");

/// Ads error types
pub const AdsError = error{
    NotAvailable,
    NotInitialized,
    AdNotLoaded,
    AdLoadFailed,
    AdShowFailed,
    NetworkError,
    InvalidPlacement,
    ConsentRequired,
    RateLimited,
    OutOfMemory,
};

/// Ad type
pub const AdType = enum(u8) {
    banner = 0,
    interstitial = 1,
    rewarded = 2,
    native = 3,
    app_open = 4,
};

/// Banner size
pub const BannerSize = enum(u8) {
    standard = 0, // 320x50
    large = 1, // 320x100
    medium_rectangle = 2, // 300x250
    full_banner = 3, // 468x60
    leaderboard = 4, // 728x90
    adaptive = 5, // Adaptive to screen width
};

/// Banner position
pub const BannerPosition = enum(u8) {
    top = 0,
    bottom = 1,
    top_left = 2,
    top_right = 3,
    bottom_left = 4,
    bottom_right = 5,
};

/// Ad result for interstitial ads
pub const AdResult = struct {
    placement_id: []const u8,
    shown: bool,
    clicked: bool = false,
    error_message: ?[]const u8 = null,

    pub fn isSuccessful(self: *const AdResult) bool {
        return self.shown and self.error_message == null;
    }
};

/// Reward result for rewarded video ads
pub const RewardResult = struct {
    placement_id: []const u8,
    earned: bool,
    reward_type: []const u8,
    reward_amount: u32,
    error_message: ?[]const u8 = null,

    pub fn isSuccessful(self: *const RewardResult) bool {
        return self.earned and self.error_message == null;
    }
};

/// Consent status for GDPR/privacy compliance
pub const ConsentStatus = enum(u8) {
    unknown = 0,
    not_required = 1,
    required = 2,
    obtained = 3,
    personalized = 4,
    non_personalized = 5,
};

/// Consent configuration
pub const ConsentConfig = struct {
    /// Privacy policy URL
    privacy_policy_url: ?[]const u8 = null,
    /// Enable GDPR consent flow
    gdpr_enabled: bool = true,
    /// Enable CCPA consent flow
    ccpa_enabled: bool = true,
    /// Enable ATT (App Tracking Transparency) on iOS
    att_enabled: bool = true,
    /// Tag for under age of consent
    tag_for_under_age_of_consent: bool = false,
};

/// Ad provider type
pub const AdProvider = enum(u8) {
    admob = 0,
    applovin = 1,
    unity_ads = 2,
    ironsource = 3,
    custom = 255,
};

/// Ads configuration
pub const AdsConfig = struct {
    /// Primary ad provider
    provider: AdProvider = .admob,
    /// App ID for the ad provider
    app_id: ?[]const u8 = null,
    /// Enable test ads
    test_mode: bool = false,
    /// Test device IDs
    test_device_ids: []const []const u8 = &.{},
    /// Consent configuration
    consent: ConsentConfig = .{},
    /// Enable debug logging
    debug: bool = false,
};

/// Banner ad state
pub const BannerState = struct {
    placement_id: []const u8,
    size: BannerSize,
    position: BannerPosition,
    is_visible: bool = false,
    is_loaded: bool = false,
};

/// Future result wrapper for async operations
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?AdsError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?AdsError) void = null,

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

        pub fn fail(self: *Self, err: AdsError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) AdsError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return AdsError.NotInitialized;
        }

        pub fn onComplete(self: *Self, callback: *const fn (?T, ?AdsError) void) void {
            self.callback = callback;
            if (self.completed) {
                callback(self.result, self.err);
            }
        }
    };
}

/// Ad event callback
pub const AdEventCallback = *const fn (AdEvent) void;

/// Ad events
pub const AdEvent = union(enum) {
    banner_loaded: []const u8, // placement_id
    banner_failed: struct { placement_id: []const u8, err_msg: []const u8 },
    banner_clicked: []const u8,
    banner_impression: []const u8,
    interstitial_loaded: []const u8,
    interstitial_failed: struct { placement_id: []const u8, err_msg: []const u8 },
    interstitial_shown: []const u8,
    interstitial_closed: []const u8,
    interstitial_clicked: []const u8,
    rewarded_loaded: []const u8,
    rewarded_failed: struct { placement_id: []const u8, err_msg: []const u8 },
    rewarded_shown: []const u8,
    rewarded_closed: []const u8,
    rewarded_earned: struct { placement_id: []const u8, reward_type: []const u8, amount: u32 },
};

/// Advertising Manager
pub const Ads = struct {
    allocator: std.mem.Allocator,
    config: AdsConfig,
    initialized: bool = false,
    consent_status: ConsentStatus = .unknown,
    banners: std.StringHashMapUnmanaged(BannerState) = .{},
    event_callback: ?AdEventCallback = null,

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: AdsConfig) Ads {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Ads) void {
        self.banners.deinit(self.allocator);
        self.initialized = false;
    }

    /// Initialize the ads SDK
    pub fn initialize(self: *Ads) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        // Platform-specific initialization would happen here
        self.initialized = true;
        future.complete({});

        return future;
    }

    /// Set event callback for ad events
    pub fn setEventCallback(self: *Ads, callback: AdEventCallback) void {
        self.event_callback = callback;
    }

    /// Load a banner ad
    pub fn loadBanner(self: *Ads, placement_id: []const u8, size: BannerSize) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (!self.initialized) {
            future.fail(AdsError.NotInitialized);
            return future;
        }

        // Store banner state
        self.banners.put(self.allocator, placement_id, .{
            .placement_id = placement_id,
            .size = size,
            .position = .bottom,
            .is_visible = false,
            .is_loaded = false,
        }) catch {
            future.fail(AdsError.OutOfMemory);
            return future;
        };

        // Platform-specific banner load would happen here
        future.complete({});
        return future;
    }

    /// Show a banner ad at specified position
    pub fn showBanner(self: *Ads, placement_id: []const u8, position: BannerPosition) void {
        if (!self.initialized) return;

        if (self.banners.getPtr(placement_id)) |banner| {
            banner.position = position;
            banner.is_visible = true;
            // Platform-specific banner show would happen here
        }
    }

    /// Hide a banner ad
    pub fn hideBanner(self: *Ads, placement_id: []const u8) void {
        if (!self.initialized) return;

        if (self.banners.getPtr(placement_id)) |banner| {
            banner.is_visible = false;
            // Platform-specific banner hide would happen here
        }
    }

    /// Destroy a banner ad
    pub fn destroyBanner(self: *Ads, placement_id: []const u8) void {
        _ = self.banners.remove(placement_id);
        // Platform-specific banner destroy would happen here
    }

    /// Load an interstitial ad
    pub fn loadInterstitial(self: *Ads, placement_id: []const u8) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (!self.initialized) {
            future.fail(AdsError.NotInitialized);
            return future;
        }

        // Platform-specific interstitial load would happen here
        _ = placement_id;
        future.complete({});
        return future;
    }

    /// Show an interstitial ad
    pub fn showInterstitial(self: *Ads, placement_id: []const u8) *Future(AdResult) {
        const future = self.allocator.create(Future(AdResult)) catch {
            const err_future = self.allocator.create(Future(AdResult)) catch unreachable;
            err_future.* = Future(AdResult).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(AdResult).init();

        if (!self.initialized) {
            future.fail(AdsError.NotInitialized);
            return future;
        }

        // Platform-specific interstitial show would happen here
        future.complete(.{
            .placement_id = placement_id,
            .shown = false,
            .error_message = "Ads not available on this platform",
        });

        return future;
    }

    /// Load a rewarded video ad
    pub fn loadRewarded(self: *Ads, placement_id: []const u8) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (!self.initialized) {
            future.fail(AdsError.NotInitialized);
            return future;
        }

        // Platform-specific rewarded load would happen here
        _ = placement_id;
        future.complete({});
        return future;
    }

    /// Show a rewarded video ad
    pub fn showRewarded(self: *Ads, placement_id: []const u8) *Future(RewardResult) {
        const future = self.allocator.create(Future(RewardResult)) catch {
            const err_future = self.allocator.create(Future(RewardResult)) catch unreachable;
            err_future.* = Future(RewardResult).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(RewardResult).init();

        if (!self.initialized) {
            future.fail(AdsError.NotInitialized);
            return future;
        }

        // Platform-specific rewarded show would happen here
        future.complete(.{
            .placement_id = placement_id,
            .earned = false,
            .reward_type = "",
            .reward_amount = 0,
            .error_message = "Ads not available on this platform",
        });

        return future;
    }

    /// Request consent from user (GDPR/CCPA)
    pub fn requestConsent(self: *Ads) *Future(ConsentStatus) {
        const future = self.allocator.create(Future(ConsentStatus)) catch {
            const err_future = self.allocator.create(Future(ConsentStatus)) catch unreachable;
            err_future.* = Future(ConsentStatus).init();
            err_future.fail(AdsError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ConsentStatus).init();

        // Platform-specific consent request would happen here
        self.consent_status = .not_required;
        future.complete(.not_required);

        return future;
    }

    /// Get current consent status
    pub fn getConsentStatus(self: *const Ads) ConsentStatus {
        return self.consent_status;
    }

    /// Update consent status
    pub fn setConsentStatus(self: *Ads, status: ConsentStatus) void {
        self.consent_status = status;
    }

    /// Check if ads are available on this platform
    pub fn isAvailable() bool {
        // Platform detection would happen here
        return false;
    }

    /// Check if a specific ad type is supported
    pub fn isAdTypeSupported(ad_type: AdType) bool {
        _ = ad_type;
        // Platform-specific support check
        return false;
    }

    /// Enable or disable test mode
    pub fn setTestMode(self: *Ads, enabled: bool) void {
        self.config.test_mode = enabled;
    }
};

/// Convenience function to create an ads manager
pub fn createAds(allocator: std.mem.Allocator, config: AdsConfig) Ads {
    return Ads.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultAds(allocator: std.mem.Allocator) Ads {
    return Ads.init(allocator, .{});
}

// Tests
test "Ads initialization" {
    const allocator = std.testing.allocator;
    var ads = createDefaultAds(allocator);
    defer ads.deinit();

    const future = ads.initialize();
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());
    try std.testing.expect(ads.initialized);
}

test "Ads availability check" {
    try std.testing.expect(!Ads.isAvailable());
}

test "AdResult success check" {
    const success = AdResult{
        .placement_id = "interstitial_1",
        .shown = true,
    };
    try std.testing.expect(success.isSuccessful());

    const failed = AdResult{
        .placement_id = "interstitial_1",
        .shown = false,
        .error_message = "Ad not loaded",
    };
    try std.testing.expect(!failed.isSuccessful());
}

test "RewardResult success check" {
    const success = RewardResult{
        .placement_id = "rewarded_1",
        .earned = true,
        .reward_type = "coins",
        .reward_amount = 100,
    };
    try std.testing.expect(success.isSuccessful());

    const failed = RewardResult{
        .placement_id = "rewarded_1",
        .earned = false,
        .reward_type = "",
        .reward_amount = 0,
        .error_message = "User cancelled",
    };
    try std.testing.expect(!failed.isSuccessful());
}

test "Banner management" {
    const allocator = std.testing.allocator;
    var ads = createDefaultAds(allocator);
    defer ads.deinit();

    const init_future = ads.initialize();
    defer allocator.destroy(init_future);

    const load_future = ads.loadBanner("banner_1", .standard);
    defer allocator.destroy(load_future);
    try std.testing.expect(load_future.isCompleted());

    ads.showBanner("banner_1", .bottom);
    if (ads.banners.get("banner_1")) |banner| {
        try std.testing.expect(banner.is_visible);
        try std.testing.expectEqual(BannerPosition.bottom, banner.position);
    }

    ads.hideBanner("banner_1");
    if (ads.banners.get("banner_1")) |banner| {
        try std.testing.expect(!banner.is_visible);
    }

    ads.destroyBanner("banner_1");
    try std.testing.expect(ads.banners.get("banner_1") == null);
}

test "Consent status" {
    const allocator = std.testing.allocator;
    var ads = createDefaultAds(allocator);
    defer ads.deinit();

    try std.testing.expectEqual(ConsentStatus.unknown, ads.getConsentStatus());

    ads.setConsentStatus(.obtained);
    try std.testing.expectEqual(ConsentStatus.obtained, ads.getConsentStatus());
}

test "Test mode" {
    const allocator = std.testing.allocator;
    var ads = createDefaultAds(allocator);
    defer ads.deinit();

    try std.testing.expect(!ads.config.test_mode);
    ads.setTestMode(true);
    try std.testing.expect(ads.config.test_mode);
}
