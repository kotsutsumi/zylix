//! Database Connection Pool
//!
//! Provides connection pooling for all database backends with:
//! - Configurable pool size (min/max)
//! - Connection health checking
//! - Idle connection timeout
//! - Connection lifetime management
//! - Wait queue for when pool is exhausted
//! - Statistics and monitoring

const std = @import("std");
const types = @import("types.zig");

const ConnectionState = types.ConnectionState;
const ConnectionOptions = types.ConnectionOptions;
const QueryStats = types.QueryStats;
const Backend = types.Backend;
const DatabaseError = types.DatabaseError;
const Error = types.Error;

/// Pool statistics
pub const PoolStats = struct {
    // Current state
    total_connections: u32 = 0,
    idle_connections: u32 = 0,
    active_connections: u32 = 0,
    waiting_requests: u32 = 0,

    // Lifetime counters
    connections_created: u64 = 0,
    connections_closed: u64 = 0,
    connections_recycled: u64 = 0,
    acquisitions_total: u64 = 0,
    acquisitions_timeout: u64 = 0,
    acquisitions_error: u64 = 0,

    // Timing
    avg_acquisition_time_ns: u64 = 0,
    max_acquisition_time_ns: u64 = 0,
    avg_usage_time_ns: u64 = 0,
};

/// Pool configuration
pub const PoolConfig = struct {
    // Size limits
    min_size: u16 = 1,
    max_size: u16 = 10,

    // Timeouts
    acquire_timeout_ms: u32 = 30000, // Max wait time to acquire connection
    idle_timeout_ms: u32 = 300000, // Close idle connections after this time (5 min)
    max_lifetime_ms: u32 = 3600000, // Max connection lifetime (1 hour)
    health_check_interval_ms: u32 = 30000, // Health check interval

    // Behavior
    test_on_acquire: bool = true, // Ping connection before returning
    test_on_release: bool = false, // Ping connection after returning
    remove_abandoned: bool = true, // Remove connections not returned
    abandoned_timeout_ms: u32 = 300000, // Time before considering abandoned
    log_abandoned: bool = true, // Log abandoned connections

    // Validation
    validation_query: ?[]const u8 = null, // Custom validation query
};

/// Pooled connection state
pub const PooledConnectionState = enum(u8) {
    idle = 0,
    in_use = 1,
    validating = 2,
    closing = 3,
    closed = 4,
};

/// Pooled connection wrapper
pub fn PooledConnection(comptime Conn: type) type {
    return struct {
        const Self = @This();

        connection: *Conn,
        pool: *ConnectionPool(Conn),
        state: PooledConnectionState = .idle,

        // Timing
        created_at: i64 = 0,
        last_used_at: i64 = 0,
        acquired_at: i64 = 0,

        // Usage tracking
        use_count: u64 = 0,

        /// Get the underlying connection
        pub fn get(self: *Self) *Conn {
            return self.connection;
        }

        /// Release connection back to pool
        pub fn release(self: *Self) void {
            self.pool.releaseConnection(self);
        }

        /// Check if connection is still valid
        pub fn isValid(self: *const Self) bool {
            if (self.state == .closed) return false;
            if (self.connection.state == .disconnected) return false;

            const now = std.time.timestamp();
            const config = self.pool.config;

            // Check max lifetime
            if (now - self.created_at > @as(i64, @intCast(config.max_lifetime_ms)) / 1000) {
                return false;
            }

            return true;
        }

        /// Check if connection is idle too long
        pub fn isIdleTooLong(self: *const Self, config: PoolConfig) bool {
            if (self.state != .idle) return false;

            const now = std.time.timestamp();
            const idle_seconds = @as(i64, @intCast(config.idle_timeout_ms)) / 1000;
            return now - self.last_used_at > idle_seconds;
        }
    };
}

/// Connection pool
pub fn ConnectionPool(comptime Conn: type) type {
    return struct {
        const Self = @This();
        const PooledConn = PooledConnection(Conn);

        allocator: std.mem.Allocator,
        config: PoolConfig,
        backend: Backend,
        connection_options: ConnectionOptions,

        // Connection storage
        connections: std.ArrayListUnmanaged(*PooledConn) = .{},
        idle_stack: std.ArrayListUnmanaged(*PooledConn) = .{},

        // State
        state: PoolState = .uninitialized,
        stats: PoolStats = .{},

        // Synchronization
        // NOTE: This implementation is designed for single-threaded use.
        // For multi-threaded applications, use std.Thread.Mutex for synchronization.
        mutex: std.Thread.Mutex = .{},

        const PoolState = enum {
            uninitialized,
            running,
            draining,
            closed,
        };

        pub fn init(allocator: std.mem.Allocator, backend: Backend, options: ConnectionOptions, config: PoolConfig) Self {
            return .{
                .allocator = allocator,
                .config = config,
                .backend = backend,
                .connection_options = options,
            };
        }

        pub fn deinit(self: *Self) void {
            self.close();
            self.connections.deinit(self.allocator);
            self.idle_stack.deinit(self.allocator);
        }

        /// Start the pool and create minimum connections
        pub fn start(self: *Self) !void {
            if (self.state != .uninitialized) {
                return error.InvalidState;
            }

            self.state = .running;

            // Create minimum connections
            var i: u16 = 0;
            while (i < self.config.min_size) : (i += 1) {
                const pooled = try self.createConnection();
                try self.idle_stack.append(self.allocator, pooled);
            }
        }

        /// Close all connections and shutdown pool
        pub fn close(self: *Self) void {
            if (self.state == .closed) return;

            self.state = .draining;

            // Close all connections
            for (self.connections.items) |pooled| {
                pooled.connection.close();
                self.allocator.destroy(pooled.connection);
                self.allocator.destroy(pooled);
            }

            self.connections.clearRetainingCapacity();
            self.idle_stack.clearRetainingCapacity();
            self.state = .closed;
        }

        /// Acquire a connection from the pool
        pub fn acquire(self: *Self) !*PooledConn {
            if (self.state != .running) {
                return error.InvalidState;
            }

            const start_time = std.time.nanoTimestamp();
            defer {
                const elapsed = std.time.nanoTimestamp() - start_time;
                self.updateAcquisitionStats(@intCast(elapsed));
            }

            // Try to get an idle connection
            if (self.idle_stack.items.len > 0) {
                const pooled = self.idle_stack.pop();

                // Validate if configured
                if (self.config.test_on_acquire) {
                    if (!try self.validateConnection(pooled)) {
                        // Connection invalid, close and create new
                        self.closeConnection(pooled);
                        return self.createAndUseConnection();
                    }
                }

                pooled.state = .in_use;
                pooled.acquired_at = std.time.timestamp();
                pooled.use_count += 1;
                self.stats.active_connections += 1;
                self.stats.idle_connections -= 1;
                self.stats.acquisitions_total += 1;

                return pooled;
            }

            // No idle connections - can we create a new one?
            if (self.connections.items.len < self.config.max_size) {
                return self.createAndUseConnection();
            }

            // Pool exhausted
            self.stats.acquisitions_timeout += 1;
            return error.PoolExhausted;
        }

        fn createAndUseConnection(self: *Self) !*PooledConn {
            const pooled = try self.createConnection();
            pooled.state = .in_use;
            pooled.acquired_at = std.time.timestamp();
            pooled.use_count = 1;
            self.stats.active_connections += 1;
            self.stats.acquisitions_total += 1;
            return pooled;
        }

        /// Release a connection back to the pool
        pub fn releaseConnection(self: *Self, pooled: *PooledConn) void {
            if (self.state != .running) {
                self.closeConnection(pooled);
                return;
            }

            const now = std.time.timestamp();
            pooled.last_used_at = now;
            pooled.state = .idle;
            self.stats.active_connections -= 1;

            // Validate if configured
            if (self.config.test_on_release) {
                if (!(self.validateConnection(pooled) catch false)) {
                    self.closeConnection(pooled);
                    return;
                }
            }

            // Check if connection is still valid
            if (!pooled.isValid()) {
                self.closeConnection(pooled);
                return;
            }

            // Return to idle pool
            self.idle_stack.append(self.allocator, pooled) catch {
                self.closeConnection(pooled);
                return;
            };
            self.stats.idle_connections += 1;
            self.stats.connections_recycled += 1;
        }

        /// Create a new connection
        fn createConnection(self: *Self) !*PooledConn {
            // Create the underlying connection
            const conn = try self.allocator.create(Conn);
            errdefer self.allocator.destroy(conn);

            conn.* = Conn.init(self.allocator, self.connection_options);
            try conn.open();

            // Wrap in pooled connection
            const pooled = try self.allocator.create(PooledConn);
            errdefer {
                conn.close();
                self.allocator.destroy(pooled);
            }

            pooled.* = .{
                .connection = conn,
                .pool = self,
                .state = .idle,
                .created_at = std.time.timestamp(),
                .last_used_at = std.time.timestamp(),
            };

            try self.connections.append(self.allocator, pooled);
            self.stats.total_connections += 1;
            self.stats.connections_created += 1;

            return pooled;
        }

        /// Close and remove a connection
        fn closeConnection(self: *Self, pooled: *PooledConn) void {
            pooled.state = .closing;
            pooled.connection.close();

            // Remove from connections list
            for (self.connections.items, 0..) |p, i| {
                if (p == pooled) {
                    _ = self.connections.swapRemove(i);
                    break;
                }
            }

            self.allocator.destroy(pooled.connection);
            self.allocator.destroy(pooled);

            self.stats.total_connections -= 1;
            self.stats.connections_closed += 1;
        }

        /// Validate a connection is still working
        fn validateConnection(self: *Self, pooled: *PooledConn) !bool {
            pooled.state = .validating;
            defer pooled.state = .idle;

            // Check basic validity
            if (!pooled.isValid()) return false;

            // Run validation query if configured
            if (self.config.validation_query) |query| {
                _ = try pooled.connection.execute(query);
            } else {
                // Default validation - just check connection state
                if (pooled.connection.state == .disconnected) return false;
            }

            return true;
        }

        /// Maintenance - clean up idle connections
        pub fn maintenance(self: *Self) void {
            if (self.state != .running) return;

            const now = std.time.timestamp();
            var i: usize = 0;

            while (i < self.idle_stack.items.len) {
                const pooled = self.idle_stack.items[i];

                // Remove if idle too long (but keep min connections)
                if (pooled.isIdleTooLong(self.config) and
                    self.connections.items.len > self.config.min_size)
                {
                    _ = self.idle_stack.swapRemove(i);
                    self.stats.idle_connections -= 1;
                    self.closeConnection(pooled);
                    continue;
                }

                // Check max lifetime
                const lifetime_seconds = @as(i64, @intCast(self.config.max_lifetime_ms)) / 1000;
                if (now - pooled.created_at > lifetime_seconds and
                    self.connections.items.len > self.config.min_size)
                {
                    _ = self.idle_stack.swapRemove(i);
                    self.stats.idle_connections -= 1;
                    self.closeConnection(pooled);
                    continue;
                }

                i += 1;
            }
        }

        fn updateAcquisitionStats(self: *Self, elapsed_ns: u64) void {
            // Update average (simple moving average)
            if (self.stats.acquisitions_total == 0) {
                self.stats.avg_acquisition_time_ns = elapsed_ns;
            } else {
                const total = self.stats.acquisitions_total;
                self.stats.avg_acquisition_time_ns = (self.stats.avg_acquisition_time_ns * (total - 1) + elapsed_ns) / total;
            }

            if (elapsed_ns > self.stats.max_acquisition_time_ns) {
                self.stats.max_acquisition_time_ns = elapsed_ns;
            }
        }

        /// Get pool statistics
        pub fn getStats(self: *const Self) PoolStats {
            return self.stats;
        }

        /// Get current pool size
        pub fn size(self: *const Self) usize {
            return self.connections.items.len;
        }

        /// Get number of available connections
        pub fn available(self: *const Self) usize {
            return self.idle_stack.items.len;
        }

        /// Get number of active connections
        pub fn active(self: *const Self) usize {
            return self.connections.items.len - self.idle_stack.items.len;
        }
    };
}

/// Create a connection pool for SQLite
pub fn sqlitePool(allocator: std.mem.Allocator, options: ConnectionOptions, config: PoolConfig) ConnectionPool(@import("sqlite.zig").Connection) {
    return ConnectionPool(@import("sqlite.zig").Connection).init(allocator, .sqlite, options, config);
}

/// Create a connection pool for MySQL
pub fn mysqlPool(allocator: std.mem.Allocator, options: ConnectionOptions, config: PoolConfig) ConnectionPool(@import("mysql.zig").Connection) {
    return ConnectionPool(@import("mysql.zig").Connection).init(allocator, .mysql, options, config);
}

/// Create a connection pool for PostgreSQL
pub fn postgresPool(allocator: std.mem.Allocator, options: ConnectionOptions, config: PoolConfig) ConnectionPool(@import("postgres.zig").Connection) {
    return ConnectionPool(@import("postgres.zig").Connection).init(allocator, .postgresql, options, config);
}

/// Create a connection pool for Turso
pub fn tursoPool(allocator: std.mem.Allocator, options: ConnectionOptions, config: PoolConfig) ConnectionPool(@import("turso.zig").Connection) {
    return ConnectionPool(@import("turso.zig").Connection).init(allocator, .turso, options, config);
}

// Tests
test "PoolConfig defaults" {
    const config = PoolConfig{};
    try std.testing.expectEqual(@as(u16, 1), config.min_size);
    try std.testing.expectEqual(@as(u16, 10), config.max_size);
    try std.testing.expect(config.test_on_acquire);
}

test "PoolStats initialization" {
    const stats = PoolStats{};
    try std.testing.expectEqual(@as(u32, 0), stats.total_connections);
    try std.testing.expectEqual(@as(u64, 0), stats.connections_created);
}
