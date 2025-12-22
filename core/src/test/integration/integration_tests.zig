//! Zylix Test Framework - Integration Tests
//!
//! Main entry point for integration tests between Zig drivers and bridge servers.
//! Tests HTTP protocol communication and JSON message formats.
//!
//! Compatible with Zig 0.15.
//!
//! ## Test Coverage
//! - Web: Playwright bridge protocol
//! - iOS: XCUITest/WDA bridge protocol
//! - watchOS: XCUITest/WDA bridge protocol (Digital Crown, Side Button)
//! - Android: UIAutomator2 bridge protocol
//! - macOS: Accessibility bridge protocol
//! - Linux: AT-SPI bridge protocol
//!
//! ## Running Tests
//! ```bash
//! cd core
//! zig build test
//! ```

const std = @import("std");

// Import all integration test modules
pub const mock_server = @import("mock_server.zig");

// Platform-specific integration tests
pub const web = @import("web_integration_test.zig");
pub const ios = @import("ios_integration_test.zig");
pub const watchos = @import("watchos_integration_test.zig");
pub const android = @import("android_integration_test.zig");
pub const desktop = @import("desktop_integration_test.zig");

// Re-export test utilities
pub const MockServer = mock_server.MockServer;
pub const MockResponse = mock_server.MockResponse;
pub const PlatformMocks = mock_server.PlatformMocks;

/// Integration test configuration
pub const IntegrationTestConfig = struct {
    /// Enable verbose logging
    verbose: bool = false,
    /// Mock server startup delay (ms)
    server_startup_delay_ms: u32 = 100,
    /// Default test timeout (ms)
    test_timeout_ms: u32 = 5000,
    /// Skip platform tests (useful for CI)
    skip_web: bool = false,
    skip_ios: bool = false,
    skip_watchos: bool = false,
    skip_android: bool = false,
    skip_macos: bool = false,
    skip_linux: bool = false,
};

/// Default test ports (offset from production to avoid conflicts)
pub const TestPorts = struct {
    pub const web: u16 = 19515; // Production: 9515
    pub const ios: u16 = 18100; // Production: 8100
    pub const watchos: u16 = 18101; // Same as iOS but different port
    pub const android: u16 = 16790; // Production: 6790
    pub const macos: u16 = 18200; // Production: 8200
    pub const linux: u16 = 18300; // Production: 8300
};

/// Test helper: Wait for server to start
pub fn waitForServer(delay_ms: u32) void {
    std.Thread.sleep(delay_ms * std.time.ns_per_ms);
}

/// Test helper: Create mock server with platform handler
pub fn createPlatformMockServer(allocator: std.mem.Allocator, platform: Platform) MockServer {
    const port = switch (platform) {
        .web => TestPorts.web,
        .ios => TestPorts.ios,
        .watchos => TestPorts.watchos,
        .android => TestPorts.android,
        .macos => TestPorts.macos,
        .linux => TestPorts.linux,
    };

    var server = MockServer.init(allocator, port);

    switch (platform) {
        .web => server.setHandler(PlatformMocks.webHandler),
        .ios => server.setHandler(PlatformMocks.iosHandler),
        .watchos => server.setHandler(PlatformMocks.iosHandler), // watchOS uses same handler as iOS
        .android => server.setHandler(PlatformMocks.androidHandler),
        .macos => server.setHandler(PlatformMocks.macosHandler),
        .linux => server.setHandler(PlatformMocks.linuxHandler),
    }

    return server;
}

/// Platform enum for test configuration
pub const Platform = enum {
    web,
    ios,
    watchos,
    android,
    macos,
    linux,
};

// Compile-time test aggregation
comptime {
    // This ensures all test modules are compiled
    _ = mock_server;
    _ = web;
    _ = ios;
    _ = watchos;
    _ = android;
    _ = desktop;
}

// Module-level tests
test "integration test module loads" {
    // Verify all modules compile and load correctly
    try std.testing.expect(@TypeOf(MockServer) != void);
    try std.testing.expect(@TypeOf(MockResponse) != void);
}

test "test ports are unique" {
    try std.testing.expect(TestPorts.web != TestPorts.ios);
    try std.testing.expect(TestPorts.ios != TestPorts.watchos);
    try std.testing.expect(TestPorts.watchos != TestPorts.android);
    try std.testing.expect(TestPorts.android != TestPorts.macos);
    try std.testing.expect(TestPorts.macos != TestPorts.linux);

    // Verify they're offset from production
    try std.testing.expect(TestPorts.web > 9515);
    try std.testing.expect(TestPorts.ios > 8100);
    try std.testing.expect(TestPorts.watchos > 8100);
}
