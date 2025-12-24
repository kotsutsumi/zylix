//! Bundle Size Optimization
//!
//! Tools for analyzing, optimizing, and reducing bundle sizes
//! including tree shaking, dead code elimination, and compression.

const std = @import("std");

/// Module information for bundle analysis
pub const ModuleInfo = struct {
    name: []const u8,
    size_bytes: usize,
    dependencies: []const []const u8,
    is_used: bool,
    is_entry: bool,
};

/// Bundle analysis result
pub const BundleAnalysis = struct {
    total_size: usize,
    used_size: usize,
    unused_size: usize,
    module_count: usize,
    used_module_count: usize,
    dependency_count: usize,
    compression_ratio: f64,

    pub fn unusedPercentage(self: *const BundleAnalysis) f64 {
        if (self.total_size == 0) return 0.0;
        return @as(f64, @floatFromInt(self.unused_size)) / @as(f64, @floatFromInt(self.total_size)) * 100.0;
    }

    pub fn potentialSavings(self: *const BundleAnalysis) usize {
        return self.unused_size;
    }
};

/// Bundle analyzer for size optimization
pub const BundleAnalyzer = struct {
    allocator: std.mem.Allocator,
    modules: std.StringHashMap(ModuleInfo),
    entry_points: std.ArrayListUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator) !*BundleAnalyzer {
        const analyzer = try allocator.create(BundleAnalyzer);
        analyzer.* = .{
            .allocator = allocator,
            .modules = std.StringHashMap(ModuleInfo).init(allocator),
            .entry_points = .{},
        };
        return analyzer;
    }

    pub fn deinit(self: *BundleAnalyzer) void {
        self.modules.deinit();
        self.entry_points.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Add module to analysis
    pub fn addModule(self: *BundleAnalyzer, info: ModuleInfo) !void {
        try self.modules.put(info.name, info);
        if (info.is_entry) {
            try self.entry_points.append(self.allocator, info.name);
        }
    }

    /// Mark module as used (reachable from entry point)
    pub fn markUsed(self: *BundleAnalyzer, name: []const u8) void {
        if (self.modules.getPtr(name)) |module| {
            if (module.is_used) return; // Already visited
            module.is_used = true;

            // Mark dependencies as used
            for (module.dependencies) |dep| {
                self.markUsed(dep);
            }
        }
    }

    /// Analyze bundle
    pub fn analyze(self: *BundleAnalyzer) BundleAnalysis {
        // Reset usage flags
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.is_used = false;
        }

        // Mark reachable modules from entry points
        for (self.entry_points.items) |entry| {
            self.markUsed(entry);
        }

        // Calculate statistics
        var total_size: usize = 0;
        var used_size: usize = 0;
        var unused_size: usize = 0;
        var used_count: usize = 0;
        var dep_count: usize = 0;

        var it2 = self.modules.iterator();
        while (it2.next()) |entry| {
            total_size += entry.value_ptr.size_bytes;
            dep_count += entry.value_ptr.dependencies.len;

            if (entry.value_ptr.is_used) {
                used_size += entry.value_ptr.size_bytes;
                used_count += 1;
            } else {
                unused_size += entry.value_ptr.size_bytes;
            }
        }

        return .{
            .total_size = total_size,
            .used_size = used_size,
            .unused_size = unused_size,
            .module_count = self.modules.count(),
            .used_module_count = used_count,
            .dependency_count = dep_count,
            .compression_ratio = if (total_size > 0) @as(f64, @floatFromInt(used_size)) / @as(f64, @floatFromInt(total_size)) else 1.0,
        };
    }

    /// Get unused modules
    pub fn getUnusedModules(self: *BundleAnalyzer, allocator: std.mem.Allocator) ![]const []const u8 {
        var unused = std.ArrayList([]const u8).init(allocator);
        errdefer unused.deinit();

        var it = self.modules.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.is_used) {
                try unused.append(entry.key_ptr.*);
            }
        }

        return unused.toOwnedSlice();
    }
};

/// Tree shaker for dead code elimination
pub const TreeShaker = struct {
    allocator: std.mem.Allocator,
    exports: std.StringHashMap(ExportInfo),
    imports: std.ArrayListUnmanaged(ImportInfo),
    side_effects: std.StringHashMap(bool),

    pub const ExportInfo = struct {
        name: []const u8,
        module: []const u8,
        is_used: bool,
    };

    pub const ImportInfo = struct {
        name: []const u8,
        from_module: []const u8,
        to_module: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !*TreeShaker {
        const shaker = try allocator.create(TreeShaker);
        shaker.* = .{
            .allocator = allocator,
            .exports = std.StringHashMap(ExportInfo).init(allocator),
            .imports = .{},
            .side_effects = std.StringHashMap(bool).init(allocator),
        };
        return shaker;
    }

    pub fn deinit(self: *TreeShaker) void {
        self.exports.deinit();
        self.imports.deinit(self.allocator);
        self.side_effects.deinit();
        self.allocator.destroy(self);
    }

    /// Add export
    pub fn addExport(self: *TreeShaker, name: []const u8, module: []const u8) !void {
        try self.exports.put(name, .{
            .name = name,
            .module = module,
            .is_used = false,
        });
    }

    /// Add import
    pub fn addImport(self: *TreeShaker, name: []const u8, from: []const u8, to: []const u8) !void {
        try self.imports.append(self.allocator, .{
            .name = name,
            .from_module = from,
            .to_module = to,
        });
    }

    /// Mark module as having side effects
    pub fn markSideEffects(self: *TreeShaker, module: []const u8) !void {
        try self.side_effects.put(module, true);
    }

    /// Shake tree (mark unused exports)
    pub fn shake(self: *TreeShaker) ShakeResult {
        // Mark used exports based on imports
        for (self.imports.items) |imp| {
            if (self.exports.getPtr(imp.name)) |exp| {
                exp.is_used = true;
            }
        }

        // Count results
        var total_exports: usize = 0;
        var used_exports: usize = 0;
        var unused_exports: usize = 0;

        var it = self.exports.iterator();
        while (it.next()) |entry| {
            total_exports += 1;
            if (entry.value_ptr.is_used or self.side_effects.contains(entry.value_ptr.module)) {
                used_exports += 1;
            } else {
                unused_exports += 1;
            }
        }

        return .{
            .total_exports = total_exports,
            .used_exports = used_exports,
            .unused_exports = unused_exports,
            .side_effect_modules = self.side_effects.count(),
        };
    }

    /// Get removable exports
    pub fn getRemovableExports(self: *TreeShaker, allocator: std.mem.Allocator) ![]const []const u8 {
        var removable = std.ArrayList([]const u8).init(allocator);
        errdefer removable.deinit();

        var it = self.exports.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.is_used and !self.side_effects.contains(entry.value_ptr.module)) {
                try removable.append(entry.key_ptr.*);
            }
        }

        return removable.toOwnedSlice();
    }

    pub const ShakeResult = struct {
        total_exports: usize,
        used_exports: usize,
        unused_exports: usize,
        side_effect_modules: usize,
    };
};

/// Compression estimator
pub const CompressionEstimator = struct {
    /// Estimate gzip compression ratio
    pub fn estimateGzipRatio(data: []const u8) f64 {
        // Simplified estimation based on entropy
        if (data.len == 0) return 1.0;

        var freq: [256]usize = [_]usize{0} ** 256;
        for (data) |byte| {
            freq[byte] += 1;
        }

        var entropy: f64 = 0.0;
        const len_f = @as(f64, @floatFromInt(data.len));

        for (freq) |count| {
            if (count > 0) {
                const p = @as(f64, @floatFromInt(count)) / len_f;
                entropy -= p * @log2(p);
            }
        }

        // Estimate compression ratio (higher entropy = less compressible)
        const max_entropy = 8.0; // Maximum entropy for bytes
        const ratio = entropy / max_entropy;

        // Typical gzip achieves 60-70% compression on text
        return 0.3 + ratio * 0.5;
    }

    /// Estimate brotli compression ratio
    pub fn estimateBrotliRatio(data: []const u8) f64 {
        // Brotli typically achieves 20-30% better than gzip
        return estimateGzipRatio(data) * 0.8;
    }

    /// Calculate actual size after compression
    pub fn estimateCompressedSize(original_size: usize, ratio: f64) usize {
        return @intFromFloat(@as(f64, @floatFromInt(original_size)) * ratio);
    }
};

/// Code splitting suggestion
pub const SplitSuggestion = struct {
    module: []const u8,
    reason: SplitReason,
    estimated_savings: usize,

    pub const SplitReason = enum {
        /// Large module that could be lazy loaded
        large_size,
        /// Module used only in specific routes
        route_specific,
        /// Module with heavy dependencies
        heavy_dependencies,
        /// Rarely used functionality
        low_usage,
    };
};

/// Code splitter analyzer
pub const CodeSplitter = struct {
    allocator: std.mem.Allocator,
    size_threshold: usize,
    suggestions: std.ArrayListUnmanaged(SplitSuggestion),

    pub fn init(allocator: std.mem.Allocator) !*CodeSplitter {
        const splitter = try allocator.create(CodeSplitter);
        splitter.* = .{
            .allocator = allocator,
            .size_threshold = 50 * 1024, // 50KB default
            .suggestions = .{},
        };
        return splitter;
    }

    pub fn deinit(self: *CodeSplitter) void {
        self.suggestions.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Set size threshold for splitting
    pub fn setSizeThreshold(self: *CodeSplitter, threshold: usize) void {
        self.size_threshold = threshold;
    }

    /// Analyze module for splitting
    pub fn analyzeModule(self: *CodeSplitter, name: []const u8, size: usize, dep_count: usize) !void {
        if (size > self.size_threshold) {
            try self.suggestions.append(self.allocator, .{
                .module = name,
                .reason = .large_size,
                .estimated_savings = size,
            });
        }

        if (dep_count > 10) {
            try self.suggestions.append(self.allocator, .{
                .module = name,
                .reason = .heavy_dependencies,
                .estimated_savings = size / 2,
            });
        }
    }

    /// Get split suggestions
    pub fn getSuggestions(self: *const CodeSplitter) []const SplitSuggestion {
        return self.suggestions.items;
    }

    /// Calculate total potential savings
    pub fn totalPotentialSavings(self: *const CodeSplitter) usize {
        var total: usize = 0;
        for (self.suggestions.items) |suggestion| {
            total += suggestion.estimated_savings;
        }
        return total;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "BundleAnalyzer basic analysis" {
    const allocator = std.testing.allocator;

    var analyzer = try BundleAnalyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.addModule(.{
        .name = "main",
        .size_bytes = 1000,
        .dependencies = &.{"utils"},
        .is_used = false,
        .is_entry = true,
    });

    try analyzer.addModule(.{
        .name = "utils",
        .size_bytes = 500,
        .dependencies = &.{},
        .is_used = false,
        .is_entry = false,
    });

    try analyzer.addModule(.{
        .name = "unused",
        .size_bytes = 300,
        .dependencies = &.{},
        .is_used = false,
        .is_entry = false,
    });

    const analysis = analyzer.analyze();

    try std.testing.expectEqual(@as(usize, 1800), analysis.total_size);
    try std.testing.expectEqual(@as(usize, 1500), analysis.used_size);
    try std.testing.expectEqual(@as(usize, 300), analysis.unused_size);
    try std.testing.expectEqual(@as(usize, 2), analysis.used_module_count);
}

test "BundleAnalysis unused percentage" {
    const analysis = BundleAnalysis{
        .total_size = 1000,
        .used_size = 700,
        .unused_size = 300,
        .module_count = 5,
        .used_module_count = 3,
        .dependency_count = 10,
        .compression_ratio = 0.7,
    };

    try std.testing.expect(analysis.unusedPercentage() == 30.0);
    try std.testing.expectEqual(@as(usize, 300), analysis.potentialSavings());
}

test "TreeShaker basic shaking" {
    const allocator = std.testing.allocator;

    var shaker = try TreeShaker.init(allocator);
    defer shaker.deinit();

    try shaker.addExport("funcA", "module1");
    try shaker.addExport("funcB", "module1");
    try shaker.addExport("funcC", "module2");

    try shaker.addImport("funcA", "module1", "main");

    const result = shaker.shake();

    try std.testing.expectEqual(@as(usize, 3), result.total_exports);
    try std.testing.expectEqual(@as(usize, 1), result.used_exports);
    try std.testing.expectEqual(@as(usize, 2), result.unused_exports);
}

test "CompressionEstimator gzip ratio" {
    const data = "Hello, World! This is a test string for compression estimation.";
    const ratio = CompressionEstimator.estimateGzipRatio(data);

    try std.testing.expect(ratio > 0.3);
    try std.testing.expect(ratio < 0.9);
}

test "CompressionEstimator compressed size" {
    const size = CompressionEstimator.estimateCompressedSize(1000, 0.5);
    try std.testing.expectEqual(@as(usize, 500), size);
}

test "CodeSplitter suggestions" {
    const allocator = std.testing.allocator;

    var splitter = try CodeSplitter.init(allocator);
    defer splitter.deinit();

    splitter.setSizeThreshold(1000);

    try splitter.analyzeModule("small", 500, 2);
    try splitter.analyzeModule("large", 5000, 5);
    try splitter.analyzeModule("heavy", 800, 15);

    const suggestions = splitter.getSuggestions();
    try std.testing.expectEqual(@as(usize, 2), suggestions.len);
}
