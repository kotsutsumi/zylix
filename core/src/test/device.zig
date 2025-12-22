// Zylix Test Framework - Device Management
// Device registry, pooling, and health monitoring

const std = @import("std");
const Allocator = std.mem.Allocator;
const driver = @import("driver.zig");
const Platform = driver.Platform;

/// Device status
pub const DeviceStatus = enum {
    available,
    busy,
    offline,
    error,
    maintenance,
};

/// Device capability
pub const DeviceCapability = enum {
    camera,
    gps,
    nfc,
    bluetooth,
    biometrics,
    accelerometer,
    gyroscope,
    network_throttle,
    screen_recording,
    touch,
    keyboard,
    mouse,
};

/// Device information
pub const DeviceInfo = struct {
    id: []const u8,
    name: []const u8,
    platform: Platform,
    os_version: []const u8,
    model: []const u8,
    manufacturer: []const u8,
    screen_width: u32,
    screen_height: u32,
    pixel_density: f32,
    capabilities: []const DeviceCapability,
    status: DeviceStatus,
    last_seen: i64,
    session_id: ?[]const u8,
    tags: []const []const u8,

    pub fn isAvailable(self: DeviceInfo) bool {
        return self.status == .available;
    }

    pub fn hasCapability(self: DeviceInfo, cap: DeviceCapability) bool {
        for (self.capabilities) |c| {
            if (c == cap) return true;
        }
        return false;
    }

    pub fn matchesPlatform(self: DeviceInfo, target: Platform) bool {
        if (target == .auto) return true;
        return self.platform == target;
    }
};

/// Device filter criteria
pub const DeviceFilter = struct {
    platform: ?Platform = null,
    os_version_min: ?[]const u8 = null,
    os_version_max: ?[]const u8 = null,
    capabilities: []const DeviceCapability = &.{},
    tags: []const []const u8 = &.{},
    status: ?DeviceStatus = null,
    model_pattern: ?[]const u8 = null,

    pub fn matches(self: DeviceFilter, device: DeviceInfo) bool {
        // Platform filter
        if (self.platform) |p| {
            if (!device.matchesPlatform(p)) return false;
        }

        // Status filter
        if (self.status) |s| {
            if (device.status != s) return false;
        }

        // Capability filter
        for (self.capabilities) |cap| {
            if (!device.hasCapability(cap)) return false;
        }

        // Tag filter
        for (self.tags) |tag| {
            var found = false;
            for (device.tags) |dt| {
                if (std.mem.eql(u8, tag, dt)) {
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }

        return true;
    }
};

/// Device registry for managing connected devices
pub const DeviceRegistry = struct {
    allocator: Allocator,
    devices: std.StringHashMap(DeviceInfo),
    listeners: std.ArrayList(*const fn (DeviceEvent) void),

    const Self = @This();

    pub const DeviceEvent = struct {
        event_type: EventType,
        device_id: []const u8,
        timestamp: i64,

        pub const EventType = enum {
            connected,
            disconnected,
            status_changed,
            session_started,
            session_ended,
        };
    };

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .devices = std.StringHashMap(DeviceInfo).init(allocator),
            .listeners = std.ArrayList(*const fn (DeviceEvent) void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.devices.deinit();
        self.listeners.deinit();
    }

    /// Register a new device
    pub fn register(self: *Self, device: DeviceInfo) !void {
        try self.devices.put(device.id, device);
        self.notify(.{
            .event_type = .connected,
            .device_id = device.id,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Unregister a device
    pub fn unregister(self: *Self, device_id: []const u8) void {
        if (self.devices.remove(device_id)) {
            self.notify(.{
                .event_type = .disconnected,
                .device_id = device_id,
                .timestamp = std.time.timestamp(),
            });
        }
    }

    /// Get device by ID
    pub fn get(self: *Self, device_id: []const u8) ?DeviceInfo {
        return self.devices.get(device_id);
    }

    /// Update device status
    pub fn updateStatus(self: *Self, device_id: []const u8, status: DeviceStatus) void {
        if (self.devices.getPtr(device_id)) |device| {
            device.status = status;
            device.last_seen = std.time.timestamp();
            self.notify(.{
                .event_type = .status_changed,
                .device_id = device_id,
                .timestamp = std.time.timestamp(),
            });
        }
    }

    /// Find devices matching filter
    pub fn find(self: *Self, filter: DeviceFilter) ![]DeviceInfo {
        var results = std.ArrayList(DeviceInfo).init(self.allocator);

        var iter = self.devices.valueIterator();
        while (iter.next()) |device| {
            if (filter.matches(device.*)) {
                try results.append(device.*);
            }
        }

        return results.toOwnedSlice();
    }

    /// Get all available devices
    pub fn getAvailable(self: *Self) ![]DeviceInfo {
        return self.find(.{ .status = .available });
    }

    /// Count devices by platform
    pub fn countByPlatform(self: *Self) std.AutoHashMap(Platform, u32) {
        var counts = std.AutoHashMap(Platform, u32).init(self.allocator);

        var iter = self.devices.valueIterator();
        while (iter.next()) |device| {
            const entry = counts.getOrPut(device.platform) catch continue;
            if (!entry.found_existing) {
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
        }

        return counts;
    }

    /// Add event listener
    pub fn addListener(self: *Self, listener: *const fn (DeviceEvent) void) !void {
        try self.listeners.append(listener);
    }

    fn notify(self: *Self, event: DeviceEvent) void {
        for (self.listeners.items) |listener| {
            listener(event);
        }
    }
};

/// Device pool for parallel test execution
pub const DevicePool = struct {
    allocator: Allocator,
    registry: *DeviceRegistry,
    allocations: std.StringHashMap(Allocation),
    queue: std.ArrayList(AllocationRequest),
    mutex: std.Thread.Mutex,
    config: PoolConfig,

    const Self = @This();

    pub const PoolConfig = struct {
        /// Maximum wait time for device allocation (ms)
        allocation_timeout_ms: u64 = 300000,
        /// Time between allocation retry attempts (ms)
        retry_interval_ms: u64 = 1000,
        /// Maximum concurrent allocations per device
        max_concurrent: u32 = 1,
        /// Enable device health checks
        health_check_enabled: bool = true,
        /// Health check interval (ms)
        health_check_interval_ms: u64 = 30000,
    };

    pub const Allocation = struct {
        device_id: []const u8,
        session_id: []const u8,
        allocated_at: i64,
        expires_at: ?i64,
        owner: []const u8,
    };

    pub const AllocationRequest = struct {
        id: []const u8,
        filter: DeviceFilter,
        callback: ?*const fn (?DeviceInfo) void,
        requested_at: i64,
        timeout_at: i64,
    };

    pub fn init(allocator: Allocator, registry: *DeviceRegistry, config: PoolConfig) Self {
        return .{
            .allocator = allocator,
            .registry = registry,
            .allocations = std.StringHashMap(Allocation).init(allocator),
            .queue = std.ArrayList(AllocationRequest).init(allocator),
            .mutex = .{},
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocations.deinit();
        self.queue.deinit();
    }

    /// Allocate a device matching the filter
    pub fn allocate(self: *Self, filter: DeviceFilter, owner: []const u8, timeout_ms: ?u64) !?DeviceInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Find available device
        const devices = try self.registry.find(filter);
        defer self.allocator.free(devices);

        for (devices) |device| {
            if (device.status == .available and !self.allocations.contains(device.id)) {
                // Allocate device
                const session_id = try self.generateSessionId();
                try self.allocations.put(device.id, .{
                    .device_id = device.id,
                    .session_id = session_id,
                    .allocated_at = std.time.timestamp(),
                    .expires_at = if (timeout_ms) |t| std.time.timestamp() + @as(i64, @intCast(t / 1000)) else null,
                    .owner = owner,
                });

                self.registry.updateStatus(device.id, .busy);
                return device;
            }
        }

        return null;
    }

    /// Release a device allocation
    pub fn release(self: *Self, device_id: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.allocations.remove(device_id)) {
            self.registry.updateStatus(device_id, .available);
        }
    }

    /// Check if device is allocated
    pub fn isAllocated(self: *Self, device_id: []const u8) bool {
        return self.allocations.contains(device_id);
    }

    /// Get allocation info
    pub fn getAllocation(self: *Self, device_id: []const u8) ?Allocation {
        return self.allocations.get(device_id);
    }

    /// Get pool statistics
    pub fn getStats(self: *Self) PoolStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var available: u32 = 0;
        var allocated: u32 = 0;
        var offline: u32 = 0;

        var iter = self.registry.devices.valueIterator();
        while (iter.next()) |device| {
            switch (device.status) {
                .available => available += 1,
                .busy => allocated += 1,
                .offline, .error => offline += 1,
                .maintenance => {},
            }
        }

        return .{
            .total_devices = @intCast(self.registry.devices.count()),
            .available_devices = available,
            .allocated_devices = allocated,
            .offline_devices = offline,
            .pending_requests = @intCast(self.queue.items.len),
        };
    }

    fn generateSessionId(self: *Self) ![]const u8 {
        var buf: [32]u8 = undefined;
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @intCast(std.time.milliTimestamp());
        };
        const rng = std.Random.DefaultPrng.init(seed).random();

        for (&buf) |*c| {
            const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
            c.* = chars[rng.intRangeAtMost(usize, 0, chars.len - 1)];
        }

        return try self.allocator.dupe(u8, &buf);
    }
};

/// Pool statistics
pub const PoolStats = struct {
    total_devices: u32,
    available_devices: u32,
    allocated_devices: u32,
    offline_devices: u32,
    pending_requests: u32,

    pub fn utilizationPercent(self: PoolStats) f32 {
        if (self.total_devices == 0) return 0;
        return @as(f32, @floatFromInt(self.allocated_devices)) /
            @as(f32, @floatFromInt(self.total_devices)) * 100;
    }
};

/// Device health monitor
pub const HealthMonitor = struct {
    allocator: Allocator,
    registry: *DeviceRegistry,
    checks: std.StringHashMap(HealthCheck),
    running: std.atomic.Value(bool),
    config: HealthConfig,

    const Self = @This();

    pub const HealthConfig = struct {
        check_interval_ms: u64 = 30000,
        timeout_ms: u64 = 5000,
        unhealthy_threshold: u32 = 3,
        healthy_threshold: u32 = 2,
    };

    pub const HealthCheck = struct {
        device_id: []const u8,
        last_check: i64,
        consecutive_failures: u32,
        consecutive_successes: u32,
        is_healthy: bool,
        last_error: ?[]const u8,
    };

    pub const HealthStatus = struct {
        device_id: []const u8,
        is_healthy: bool,
        last_check: i64,
        response_time_ms: ?u64,
        error_message: ?[]const u8,
    };

    pub fn init(allocator: Allocator, registry: *DeviceRegistry, config: HealthConfig) Self {
        return .{
            .allocator = allocator,
            .registry = registry,
            .checks = std.StringHashMap(HealthCheck).init(allocator),
            .running = std.atomic.Value(bool).init(false),
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.checks.deinit();
    }

    /// Start health monitoring
    pub fn start(self: *Self) !void {
        if (self.running.load(.acquire)) return;
        self.running.store(true, .release);

        // Initialize health checks for all devices
        var iter = self.registry.devices.iterator();
        while (iter.next()) |entry| {
            try self.checks.put(entry.key_ptr.*, .{
                .device_id = entry.key_ptr.*,
                .last_check = 0,
                .consecutive_failures = 0,
                .consecutive_successes = 0,
                .is_healthy = true,
                .last_error = null,
            });
        }
    }

    /// Stop health monitoring
    pub fn stop(self: *Self) void {
        self.running.store(false, .release);
    }

    /// Record health check result
    pub fn recordResult(self: *Self, device_id: []const u8, success: bool, error_msg: ?[]const u8) void {
        if (self.checks.getPtr(device_id)) |check| {
            check.last_check = std.time.timestamp();

            if (success) {
                check.consecutive_failures = 0;
                check.consecutive_successes += 1;
                check.last_error = null;

                if (check.consecutive_successes >= self.config.healthy_threshold) {
                    check.is_healthy = true;
                    self.registry.updateStatus(device_id, .available);
                }
            } else {
                check.consecutive_successes = 0;
                check.consecutive_failures += 1;
                check.last_error = error_msg;

                if (check.consecutive_failures >= self.config.unhealthy_threshold) {
                    check.is_healthy = false;
                    self.registry.updateStatus(device_id, .error);
                }
            }
        }
    }

    /// Get health status for device
    pub fn getStatus(self: *Self, device_id: []const u8) ?HealthStatus {
        const check = self.checks.get(device_id) orelse return null;

        return .{
            .device_id = device_id,
            .is_healthy = check.is_healthy,
            .last_check = check.last_check,
            .response_time_ms = null,
            .error_message = check.last_error,
        };
    }

    /// Get all unhealthy devices
    pub fn getUnhealthy(self: *Self) ![]HealthStatus {
        var results = std.ArrayList(HealthStatus).init(self.allocator);

        var iter = self.checks.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.is_healthy) {
                try results.append(.{
                    .device_id = entry.key_ptr.*,
                    .is_healthy = false,
                    .last_check = entry.value_ptr.last_check,
                    .response_time_ms = null,
                    .error_message = entry.value_ptr.last_error,
                });
            }
        }

        return results.toOwnedSlice();
    }

    /// Get health summary
    pub fn getSummary(self: *Self) HealthSummary {
        var healthy: u32 = 0;
        var unhealthy: u32 = 0;

        var iter = self.checks.valueIterator();
        while (iter.next()) |check| {
            if (check.is_healthy) {
                healthy += 1;
            } else {
                unhealthy += 1;
            }
        }

        return .{
            .total_devices = healthy + unhealthy,
            .healthy_devices = healthy,
            .unhealthy_devices = unhealthy,
            .health_percentage = if (healthy + unhealthy > 0)
                @as(f32, @floatFromInt(healthy)) / @as(f32, @floatFromInt(healthy + unhealthy)) * 100
            else
                0,
        };
    }
};

/// Health summary
pub const HealthSummary = struct {
    total_devices: u32,
    healthy_devices: u32,
    unhealthy_devices: u32,
    health_percentage: f32,
};

/// Device farm integration
pub const DeviceFarm = struct {
    allocator: Allocator,
    registry: DeviceRegistry,
    pool: DevicePool,
    monitor: HealthMonitor,
    config: FarmConfig,

    const Self = @This();

    pub const FarmConfig = struct {
        name: []const u8 = "default",
        max_devices: u32 = 100,
        auto_scaling: bool = false,
        cloud_provider: ?CloudProvider = null,
    };

    pub const CloudProvider = enum {
        aws_device_farm,
        browserstack,
        sauce_labs,
        local,
    };

    pub fn init(allocator: Allocator, config: FarmConfig) Self {
        var registry = DeviceRegistry.init(allocator);
        return .{
            .allocator = allocator,
            .registry = registry,
            .pool = DevicePool.init(allocator, &registry, .{}),
            .monitor = HealthMonitor.init(allocator, &registry, .{}),
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.monitor.deinit();
        self.pool.deinit();
        self.registry.deinit();
    }

    /// Start the device farm
    pub fn start(self: *Self) !void {
        try self.monitor.start();
    }

    /// Stop the device farm
    pub fn stop(self: *Self) void {
        self.monitor.stop();
    }

    /// Get farm status
    pub fn getStatus(self: *Self) FarmStatus {
        return .{
            .name = self.config.name,
            .pool_stats = self.pool.getStats(),
            .health_summary = self.monitor.getSummary(),
            .cloud_provider = self.config.cloud_provider,
        };
    }
};

/// Farm status
pub const FarmStatus = struct {
    name: []const u8,
    pool_stats: PoolStats,
    health_summary: HealthSummary,
    cloud_provider: ?DeviceFarm.CloudProvider,
};

// Tests
test "DeviceFilter matching" {
    const device = DeviceInfo{
        .id = "device-1",
        .name = "iPhone 15",
        .platform = .ios,
        .os_version = "17.0",
        .model = "iPhone15,2",
        .manufacturer = "Apple",
        .screen_width = 1179,
        .screen_height = 2556,
        .pixel_density = 3.0,
        .capabilities = &.{ .camera, .gps, .biometrics },
        .status = .available,
        .last_seen = 0,
        .session_id = null,
        .tags = &.{ "premium", "ios17" },
    };

    // Platform filter
    const ios_filter = DeviceFilter{ .platform = .ios };
    try std.testing.expect(ios_filter.matches(device));

    const android_filter = DeviceFilter{ .platform = .android };
    try std.testing.expect(!android_filter.matches(device));

    // Status filter
    const available_filter = DeviceFilter{ .status = .available };
    try std.testing.expect(available_filter.matches(device));

    // Capability filter
    const camera_filter = DeviceFilter{ .capabilities = &.{.camera} };
    try std.testing.expect(camera_filter.matches(device));

    const nfc_filter = DeviceFilter{ .capabilities = &.{.nfc} };
    try std.testing.expect(!nfc_filter.matches(device));
}

test "DeviceRegistry basic operations" {
    const allocator = std.testing.allocator;

    var registry = DeviceRegistry.init(allocator);
    defer registry.deinit();

    const device = DeviceInfo{
        .id = "test-device",
        .name = "Test Device",
        .platform = .android,
        .os_version = "14",
        .model = "Pixel 8",
        .manufacturer = "Google",
        .screen_width = 1080,
        .screen_height = 2400,
        .pixel_density = 2.5,
        .capabilities = &.{},
        .status = .available,
        .last_seen = 0,
        .session_id = null,
        .tags = &.{},
    };

    try registry.register(device);
    try std.testing.expect(registry.get("test-device") != null);

    registry.updateStatus("test-device", .busy);
    try std.testing.expectEqual(DeviceStatus.busy, registry.get("test-device").?.status);

    registry.unregister("test-device");
    try std.testing.expect(registry.get("test-device") == null);
}

test "DevicePool allocation" {
    const allocator = std.testing.allocator;

    var registry = DeviceRegistry.init(allocator);
    defer registry.deinit();

    var pool = DevicePool.init(allocator, &registry, .{});
    defer pool.deinit();

    // Register a device
    try registry.register(.{
        .id = "pool-device",
        .name = "Pool Device",
        .platform = .web,
        .os_version = "latest",
        .model = "Chrome",
        .manufacturer = "Google",
        .screen_width = 1920,
        .screen_height = 1080,
        .pixel_density = 1.0,
        .capabilities = &.{},
        .status = .available,
        .last_seen = 0,
        .session_id = null,
        .tags = &.{},
    });

    // Allocate device
    const device = try pool.allocate(.{ .platform = .web }, "test-owner", null);
    try std.testing.expect(device != null);
    try std.testing.expect(pool.isAllocated("pool-device"));

    // Release device
    pool.release("pool-device");
    try std.testing.expect(!pool.isAllocated("pool-device"));
}

test "HealthMonitor" {
    const allocator = std.testing.allocator;

    var registry = DeviceRegistry.init(allocator);
    defer registry.deinit();

    var monitor = HealthMonitor.init(allocator, &registry, .{
        .unhealthy_threshold = 2,
        .healthy_threshold = 2,
    });
    defer monitor.deinit();

    try registry.register(.{
        .id = "health-device",
        .name = "Health Device",
        .platform = .ios,
        .os_version = "17.0",
        .model = "iPhone",
        .manufacturer = "Apple",
        .screen_width = 1170,
        .screen_height = 2532,
        .pixel_density = 3.0,
        .capabilities = &.{},
        .status = .available,
        .last_seen = 0,
        .session_id = null,
        .tags = &.{},
    });

    try monitor.start();

    // Record failures
    monitor.recordResult("health-device", false, "Connection timeout");
    monitor.recordResult("health-device", false, "Connection timeout");

    const status = monitor.getStatus("health-device");
    try std.testing.expect(status != null);
    try std.testing.expect(!status.?.is_healthy);

    monitor.stop();
}

test "PoolStats utilization" {
    const stats = PoolStats{
        .total_devices = 10,
        .available_devices = 6,
        .allocated_devices = 4,
        .offline_devices = 0,
        .pending_requests = 0,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 40.0), stats.utilizationPercent(), 0.001);
}
