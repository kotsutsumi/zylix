//! App Integration APIs Module
//!
//! Unified APIs for common app integration needs:
//! - In-App Purchases (IAP): StoreKit 2, Play Billing
//! - Advertising: Banner, Interstitial, Rewarded ads
//! - Key-Value Store: Persistent storage across platforms
//! - App Lifecycle: Foreground/background, termination, memory warnings
//! - Motion Frame Provider: Camera-based motion tracking
//! - Audio Clip Player: Low-latency audio playback
//!
//! Platform Support:
//! - iOS: Full support via native frameworks
//! - Android: Full support via native APIs
//! - Web: Partial support (KeyValueStore, Lifecycle, Audio)
//! - Desktop: Partial support (KeyValueStore, Lifecycle, Motion, Audio)

const std = @import("std");

// Re-export submodules
pub const iap = @import("iap.zig");
pub const ads = @import("ads.zig");
pub const keyvalue = @import("keyvalue.zig");
pub const lifecycle = @import("lifecycle.zig");
pub const motion = @import("motion.zig");
pub const audioclip = @import("audioclip.zig");

// Re-export common types from IAP
pub const Store = iap.Store;
pub const StoreConfig = iap.StoreConfig;
pub const Product = iap.Product;
pub const ProductType = iap.ProductType;
pub const PurchaseResult = iap.PurchaseResult;
pub const PurchaseState = iap.PurchaseState;
pub const RestoreResult = iap.RestoreResult;
pub const Entitlement = iap.Entitlement;
pub const IapError = iap.IapError;

// Re-export common types from Ads
pub const Ads = ads.Ads;
pub const AdsConfig = ads.AdsConfig;
pub const AdType = ads.AdType;
pub const BannerSize = ads.BannerSize;
pub const BannerPosition = ads.BannerPosition;
pub const AdResult = ads.AdResult;
pub const RewardResult = ads.RewardResult;
pub const ConsentStatus = ads.ConsentStatus;
pub const AdsError = ads.AdsError;

// Re-export common types from KeyValueStore
pub const KeyValueStore = keyvalue.KeyValueStore;
pub const KvConfig = keyvalue.KvConfig;
pub const StoredValue = keyvalue.StoredValue;
pub const ValueType = keyvalue.ValueType;
pub const BatchOperation = keyvalue.BatchOperation;
pub const KvError = keyvalue.KvError;

// Re-export common types from Lifecycle
pub const AppLifecycle = lifecycle.AppLifecycle;
pub const LifecycleConfig = lifecycle.LifecycleConfig;
pub const AppState = lifecycle.AppState;
pub const MemoryPressure = lifecycle.MemoryPressure;
pub const LifecycleEvent = lifecycle.LifecycleEvent;
pub const LaunchInfo = lifecycle.LaunchInfo;
pub const LifecycleError = lifecycle.LifecycleError;

// Re-export common types from Motion
pub const MotionFrameProvider = motion.MotionFrameProvider;
pub const MotionFrameConfig = motion.MotionFrameConfig;
pub const MotionFrame = motion.MotionFrame;
pub const MotionResult = motion.MotionResult;
pub const Resolution = motion.Resolution;
pub const PixelFormat = motion.PixelFormat;
pub const CameraFacing = motion.CameraFacing;
pub const MotionError = motion.MotionError;

// Re-export common types from AudioClip
pub const AudioClipPlayer = audioclip.AudioClipPlayer;
pub const AudioClipConfig = audioclip.AudioClipConfig;
pub const AudioClip = audioclip.AudioClip;
pub const VoiceHandle = audioclip.VoiceHandle;
pub const PlaybackState = audioclip.PlaybackState;
pub const SpatialPosition = audioclip.SpatialPosition;
pub const AudioFormat = audioclip.AudioFormat;
pub const AudioClipError = audioclip.AudioClipError;

/// Platform availability information
pub const PlatformSupport = struct {
    iap: bool,
    ads: bool,
    keyvalue: bool,
    lifecycle: bool,
    motion: bool,
    audioclip: bool,

    pub fn isFullySupported(self: PlatformSupport) bool {
        return self.iap and self.ads and self.keyvalue and
            self.lifecycle and self.motion and self.audioclip;
    }

    pub fn isPartiallySupported(self: PlatformSupport) bool {
        return self.iap or self.ads or self.keyvalue or
            self.lifecycle or self.motion or self.audioclip;
    }
};

/// Get platform support information
pub fn getPlatformSupport() PlatformSupport {
    return .{
        .iap = Store.isAvailable(),
        .ads = Ads.isAvailable(),
        .keyvalue = true, // Always available (file-based fallback)
        .lifecycle = true, // Always available (basic support)
        .motion = MotionFrameProvider.isAvailable(),
        .audioclip = AudioClipPlayer.isAvailable(),
    };
}

/// Integration manager for convenient access to all services
pub const IntegrationManager = struct {
    allocator: std.mem.Allocator,
    store: ?*Store = null,
    ads_manager: ?*Ads = null,
    kv_store: ?*KeyValueStore = null,
    lifecycle_manager: ?*AppLifecycle = null,
    motion_provider: ?*MotionFrameProvider = null,
    audio_player: ?*AudioClipPlayer = null,

    pub fn init(allocator: std.mem.Allocator) IntegrationManager {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IntegrationManager) void {
        if (self.store) |s| {
            s.deinit();
            self.allocator.destroy(s);
        }
        if (self.ads_manager) |a| {
            a.deinit();
            self.allocator.destroy(a);
        }
        if (self.kv_store) |k| {
            k.deinit();
            self.allocator.destroy(k);
        }
        if (self.lifecycle_manager) |l| {
            l.deinit();
            self.allocator.destroy(l);
        }
        if (self.motion_provider) |m| {
            m.deinit();
            self.allocator.destroy(m);
        }
        if (self.audio_player) |a| {
            a.deinit();
            self.allocator.destroy(a);
        }
    }

    /// Get or create IAP store.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getStore(self: *IntegrationManager, config: StoreConfig) !*Store {
        if (self.store) |s| return s;

        const store = try self.allocator.create(Store);
        store.* = iap.createStore(self.allocator, config);
        self.store = store;
        return store;
    }

    /// Get or create ads manager.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getAds(self: *IntegrationManager, config: AdsConfig) !*Ads {
        if (self.ads_manager) |a| return a;

        const ads_mgr = try self.allocator.create(Ads);
        ads_mgr.* = ads.createAds(self.allocator, config);
        self.ads_manager = ads_mgr;
        return ads_mgr;
    }

    /// Get or create key-value store.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getKeyValueStore(self: *IntegrationManager, config: KvConfig) !*KeyValueStore {
        if (self.kv_store) |k| return k;

        const kv = try self.allocator.create(KeyValueStore);
        kv.* = keyvalue.createStore(self.allocator, config);
        self.kv_store = kv;
        return kv;
    }

    /// Get or create lifecycle manager.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getLifecycle(self: *IntegrationManager, config: LifecycleConfig) !*AppLifecycle {
        if (self.lifecycle_manager) |l| return l;

        const lc = try self.allocator.create(AppLifecycle);
        lc.* = lifecycle.createLifecycle(self.allocator, config);
        self.lifecycle_manager = lc;
        return lc;
    }

    /// Get or create motion provider.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getMotionProvider(self: *IntegrationManager, config: MotionFrameConfig) !*MotionFrameProvider {
        if (self.motion_provider) |m| return m;

        const mp = try self.allocator.create(MotionFrameProvider);
        mp.* = motion.createProvider(self.allocator, config);
        self.motion_provider = mp;
        return mp;
    }

    /// Get or create audio player.
    /// NOTE: Config is only used on first creation. Subsequent calls return the cached instance.
    pub fn getAudioPlayer(self: *IntegrationManager, config: AudioClipConfig) !*AudioClipPlayer {
        if (self.audio_player) |a| return a;

        const ap = try self.allocator.create(AudioClipPlayer);
        ap.* = audioclip.createPlayer(self.allocator, config);
        self.audio_player = ap;
        return ap;
    }
};

/// Create an integration manager
pub fn createIntegrationManager(allocator: std.mem.Allocator) IntegrationManager {
    return IntegrationManager.init(allocator);
}

// Convenience functions

/// Create an IAP store with default config
pub fn createStore(allocator: std.mem.Allocator) Store {
    return iap.createDefaultStore(allocator);
}

/// Create an ads manager with default config
pub fn createAdsManager(allocator: std.mem.Allocator) Ads {
    return ads.createDefaultAds(allocator);
}

/// Create a key-value store with default config
pub fn createKeyValueStore(allocator: std.mem.Allocator) KeyValueStore {
    return keyvalue.createDefaultStore(allocator);
}

/// Create a lifecycle manager with default config
pub fn createLifecycleManager(allocator: std.mem.Allocator) AppLifecycle {
    return lifecycle.createDefaultLifecycle(allocator);
}

/// Create a motion frame provider with default config
pub fn createMotionProvider(allocator: std.mem.Allocator) MotionFrameProvider {
    return motion.createDefaultProvider(allocator);
}

/// Create an audio clip player with default config
pub fn createAudioPlayer(allocator: std.mem.Allocator) AudioClipPlayer {
    return audioclip.createDefaultPlayer(allocator);
}

// Tests
test "Integration module imports" {
    // Verify all submodules can be imported
    _ = iap;
    _ = ads;
    _ = keyvalue;
    _ = lifecycle;
    _ = motion;
    _ = audioclip;
}

test "Platform support check" {
    const support = getPlatformSupport();
    // KeyValue and Lifecycle should always be available
    try std.testing.expect(support.keyvalue);
    try std.testing.expect(support.lifecycle);
}

test "IntegrationManager creation" {
    const allocator = std.testing.allocator;
    var manager = createIntegrationManager(allocator);
    defer manager.deinit();

    const kv = try manager.getKeyValueStore(.{});
    // Verify it's a valid instance by calling a method
    try std.testing.expectEqual(@as(usize, 0), kv.count());

    // Second call should return same instance
    const kv2 = try manager.getKeyValueStore(.{});
    try std.testing.expectEqual(kv, kv2);
}

test "Convenience constructors" {
    const allocator = std.testing.allocator;

    var store = createStore(allocator);
    defer store.deinit();

    var ads_mgr = createAdsManager(allocator);
    defer ads_mgr.deinit();

    var kv = createKeyValueStore(allocator);
    defer kv.deinit();

    var lc = createLifecycleManager(allocator);
    defer lc.deinit();

    var mp = createMotionProvider(allocator);
    defer mp.deinit();

    var ap = createAudioPlayer(allocator);
    defer ap.deinit();
}

test "Type re-exports" {
    // Verify types are accessible
    const _product: ?Product = null;
    const _ad_type: AdType = .banner;
    const _app_state: AppState = .foreground;
    const _resolution: Resolution = .low;
    const _audio_format: AudioFormat = .wav;

    _ = _product;
    _ = _ad_type;
    _ = _app_state;
    _ = _resolution;
    _ = _audio_format;
}
