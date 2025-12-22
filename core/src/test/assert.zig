// Zylix Test Framework - Assertion API
// Provides fluent assertion interface for test validation

const std = @import("std");
const element_mod = @import("element.zig");

pub const Element = element_mod.Element;

/// Assertion error with detailed context
pub const AssertionError = error{
    ExpectationFailed,
    TypeMismatch,
    ValueMismatch,
    TextMismatch,
    VisibilityMismatch,
    EnabledMismatch,
    ExistenceMismatch,
    ContainsMismatch,
    RangeMismatch,
    LengthMismatch,
    NullMismatch,
};

/// Assertion result with context
pub const AssertionResult = struct {
    passed: bool,
    message: []const u8,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
    location: ?std.builtin.SourceLocation = null,

    pub fn pass() AssertionResult {
        return .{ .passed = true, .message = "" };
    }

    pub fn fail(message: []const u8) AssertionResult {
        return .{ .passed = false, .message = message };
    }

    pub fn failWithValues(message: []const u8, expected: []const u8, actual: []const u8) AssertionResult {
        return .{
            .passed = false,
            .message = message,
            .expected = expected,
            .actual = actual,
        };
    }
};

/// Create expectation for any value
pub fn expect(value: anytype) Expectation(@TypeOf(value)) {
    return Expectation(@TypeOf(value)).init(value);
}

/// Generic expectation type
pub fn Expectation(comptime T: type) type {
    return struct {
        value: T,
        negated: bool = false,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        /// Negate the expectation
        pub fn not(self: Self) Self {
            return .{
                .value = self.value,
                .negated = !self.negated,
            };
        }

        /// Assert exact equality
        pub fn toBe(self: Self, expected: T) AssertionError!void {
            const equal = if (comptime isComparable(T))
                self.value == expected
            else if (comptime isSlice(T))
                std.mem.eql(std.meta.Child(T), self.value, expected)
            else
                @compileError("Type cannot be compared with toBe");

            const result = if (self.negated) !equal else equal;
            if (!result) {
                return AssertionError.ValueMismatch;
            }
        }

        /// Assert deep equality (for structs and complex types)
        pub fn toEqual(self: Self, expected: T) AssertionError!void {
            const equal = deepEqual(self.value, expected);
            const result = if (self.negated) !equal else equal;
            if (!result) {
                return AssertionError.ValueMismatch;
            }
        }

        /// Assert value is truthy
        pub fn toBeTruthy(self: Self) AssertionError!void {
            const truthy = if (comptime @typeInfo(T) == .bool)
                self.value
            else if (comptime @typeInfo(T) == .optional)
                self.value != null
            else if (comptime isNumeric(T))
                self.value != 0
            else
                true;

            const result = if (self.negated) !truthy else truthy;
            if (!result) {
                return AssertionError.ExpectationFailed;
            }
        }

        /// Assert value is falsy
        pub fn toBeFalsy(self: Self) AssertionError!void {
            return self.not().toBeTruthy();
        }

        /// Assert value is null
        pub fn toBeNull(self: Self) AssertionError!void {
            if (comptime @typeInfo(T) != .optional) {
                @compileError("toBeNull requires optional type");
            }
            const is_null = self.value == null;
            const result = if (self.negated) !is_null else is_null;
            if (!result) {
                return AssertionError.NullMismatch;
            }
        }

        /// Assert value is greater than expected
        pub fn toBeGreaterThan(self: Self, expected: T) AssertionError!void {
            if (comptime !isNumeric(T)) {
                @compileError("toBeGreaterThan requires numeric type");
            }
            const greater = self.value > expected;
            const result = if (self.negated) !greater else greater;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }

        /// Assert value is greater than or equal to expected
        pub fn toBeGreaterThanOrEqual(self: Self, expected: T) AssertionError!void {
            if (comptime !isNumeric(T)) {
                @compileError("toBeGreaterThanOrEqual requires numeric type");
            }
            const gte = self.value >= expected;
            const result = if (self.negated) !gte else gte;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }

        /// Assert value is less than expected
        pub fn toBeLessThan(self: Self, expected: T) AssertionError!void {
            if (comptime !isNumeric(T)) {
                @compileError("toBeLessThan requires numeric type");
            }
            const less = self.value < expected;
            const result = if (self.negated) !less else less;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }

        /// Assert value is less than or equal to expected
        pub fn toBeLessThanOrEqual(self: Self, expected: T) AssertionError!void {
            if (comptime !isNumeric(T)) {
                @compileError("toBeLessThanOrEqual requires numeric type");
            }
            const lte = self.value <= expected;
            const result = if (self.negated) !lte else lte;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }

        /// Assert value is within range (inclusive)
        pub fn toBeInRange(self: Self, min: T, max: T) AssertionError!void {
            if (comptime !isNumeric(T)) {
                @compileError("toBeInRange requires numeric type");
            }
            const in_range = self.value >= min and self.value <= max;
            const result = if (self.negated) !in_range else in_range;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }

        /// Assert approximately equal (for floats)
        pub fn toBeCloseTo(self: Self, expected: T, tolerance: T) AssertionError!void {
            if (comptime !isFloat(T)) {
                @compileError("toBeCloseTo requires float type");
            }
            const diff = @abs(self.value - expected);
            const close = diff <= tolerance;
            const result = if (self.negated) !close else close;
            if (!result) {
                return AssertionError.RangeMismatch;
            }
        }
    };
}

/// String-specific expectations
pub fn expectString(value: []const u8) StringExpectation {
    return StringExpectation.init(value);
}

pub const StringExpectation = struct {
    value: []const u8,
    negated: bool = false,

    const Self = @This();

    pub fn init(value: []const u8) Self {
        return .{ .value = value };
    }

    pub fn not(self: Self) Self {
        return .{ .value = self.value, .negated = !self.negated };
    }

    /// Assert exact match
    pub fn toBe(self: Self, expected: []const u8) AssertionError!void {
        const equal = std.mem.eql(u8, self.value, expected);
        const result = if (self.negated) !equal else equal;
        if (!result) {
            return AssertionError.TextMismatch;
        }
    }

    /// Assert contains substring
    pub fn toContain(self: Self, substring: []const u8) AssertionError!void {
        const contains = std.mem.indexOf(u8, self.value, substring) != null;
        const result = if (self.negated) !contains else contains;
        if (!result) {
            return AssertionError.ContainsMismatch;
        }
    }

    /// Assert starts with prefix
    pub fn toStartWith(self: Self, prefix: []const u8) AssertionError!void {
        const starts = std.mem.startsWith(u8, self.value, prefix);
        const result = if (self.negated) !starts else starts;
        if (!result) {
            return AssertionError.TextMismatch;
        }
    }

    /// Assert ends with suffix
    pub fn toEndWith(self: Self, suffix: []const u8) AssertionError!void {
        const ends = std.mem.endsWith(u8, self.value, suffix);
        const result = if (self.negated) !ends else ends;
        if (!result) {
            return AssertionError.TextMismatch;
        }
    }

    /// Assert string length
    pub fn toHaveLength(self: Self, length: usize) AssertionError!void {
        const has_length = self.value.len == length;
        const result = if (self.negated) !has_length else has_length;
        if (!result) {
            return AssertionError.LengthMismatch;
        }
    }

    /// Assert string is empty
    pub fn toBeEmpty(self: Self) AssertionError!void {
        const empty = self.value.len == 0;
        const result = if (self.negated) !empty else empty;
        if (!result) {
            return AssertionError.LengthMismatch;
        }
    }

    /// Assert matches pattern (simple wildcard)
    pub fn toMatch(self: Self, pattern: []const u8) AssertionError!void {
        const matches = matchPattern(self.value, pattern);
        const result = if (self.negated) !matches else matches;
        if (!result) {
            return AssertionError.TextMismatch;
        }
    }
};

/// Element-specific expectations
pub fn expectElement(element: *Element) ElementExpectation {
    return ElementExpectation.init(element);
}

pub const ElementExpectation = struct {
    element: *Element,
    negated: bool = false,

    const Self = @This();

    pub fn init(element: *Element) Self {
        return .{ .element = element };
    }

    pub fn not(self: Self) Self {
        return .{ .element = self.element, .negated = !self.negated };
    }

    /// Assert element is visible
    pub fn toBeVisible(self: Self) AssertionError!void {
        const visible = self.element.isVisible();
        const result = if (self.negated) !visible else visible;
        if (!result) {
            return AssertionError.VisibilityMismatch;
        }
    }

    /// Assert element is enabled
    pub fn toBeEnabled(self: Self) AssertionError!void {
        const enabled = self.element.isEnabled();
        const result = if (self.negated) !enabled else enabled;
        if (!result) {
            return AssertionError.EnabledMismatch;
        }
    }

    /// Assert element exists
    pub fn toExist(self: Self) AssertionError!void {
        const exists = self.element.exists();
        const result = if (self.negated) !exists else exists;
        if (!result) {
            return AssertionError.ExistenceMismatch;
        }
    }

    /// Assert element has text
    pub fn toHaveText(self: Self, expected: []const u8) AssertionError!void {
        const text = self.element.getText() catch return AssertionError.ExpectationFailed;
        const equal = std.mem.eql(u8, text, expected);
        const result = if (self.negated) !equal else equal;
        if (!result) {
            return AssertionError.TextMismatch;
        }
    }

    /// Assert element contains text
    pub fn toContainText(self: Self, substring: []const u8) AssertionError!void {
        const text = self.element.getText() catch return AssertionError.ExpectationFailed;
        const contains = std.mem.indexOf(u8, text, substring) != null;
        const result = if (self.negated) !contains else contains;
        if (!result) {
            return AssertionError.ContainsMismatch;
        }
    }

    /// Assert element has attribute
    pub fn toHaveAttribute(self: Self, name: []const u8, expected: ?[]const u8) AssertionError!void {
        const attr = self.element.getAttribute(name) catch return AssertionError.ExpectationFailed;
        if (expected) |exp| {
            if (attr) |a| {
                const equal = std.mem.eql(u8, a, exp);
                const result = if (self.negated) !equal else equal;
                if (!result) {
                    return AssertionError.ValueMismatch;
                }
            } else {
                if (!self.negated) {
                    return AssertionError.ValueMismatch;
                }
            }
        } else {
            const has_attr = attr != null;
            const result = if (self.negated) !has_attr else has_attr;
            if (!result) {
                return AssertionError.ExistenceMismatch;
            }
        }
    }
};

// Helper functions

fn isComparable(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .bool, .@"enum", .pointer => true,
        else => false,
    };
}

fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .Slice,
        else => false,
    };
}

fn isNumeric(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => true,
        else => false,
    };
}

fn isFloat(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .float, .comptime_float => true,
        else => false,
    };
}

fn deepEqual(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    return switch (@typeInfo(T)) {
        .@"struct" => |info| {
            inline for (info.fields) |field| {
                if (!deepEqual(@field(a, field.name), @field(b, field.name))) {
                    return false;
                }
            }
            return true;
        },
        .array => |info| {
            for (a, b) |a_item, b_item| {
                if (!deepEqual(a_item, b_item)) {
                    return false;
                }
            }
            _ = info;
            return true;
        },
        .pointer => |ptr| {
            if (ptr.size == .Slice) {
                if (a.len != b.len) return false;
                for (a, b) |a_item, b_item| {
                    if (!deepEqual(a_item, b_item)) {
                        return false;
                    }
                }
                return true;
            }
            return a == b;
        },
        else => a == b,
    };
}

fn matchPattern(text: []const u8, pattern: []const u8) bool {
    var t: usize = 0;
    var p: usize = 0;
    var star_idx: ?usize = null;
    var match_idx: usize = 0;

    while (t < text.len) {
        if (p < pattern.len and (pattern[p] == '?' or pattern[p] == text[t])) {
            t += 1;
            p += 1;
        } else if (p < pattern.len and pattern[p] == '*') {
            star_idx = p;
            match_idx = t;
            p += 1;
        } else if (star_idx != null) {
            p = star_idx.? + 1;
            match_idx += 1;
            t = match_idx;
        } else {
            return false;
        }
    }

    while (p < pattern.len and pattern[p] == '*') {
        p += 1;
    }

    return p == pattern.len;
}

// Tests
test "basic expectations" {
    try expect(@as(i32, 5)).toBe(5);
    try expect(@as(i32, 5)).not().toBe(10);
    try expect(@as(i32, 5)).toBeGreaterThan(3);
    try expect(@as(i32, 5)).toBeLessThan(10);
}

test "string expectations" {
    try expectString("Hello World").toContain("World");
    try expectString("Hello World").toStartWith("Hello");
    try expectString("Hello World").toEndWith("World");
    try expectString("Hello World").not().toContain("Goodbye");
}

test "pattern matching" {
    try std.testing.expect(matchPattern("hello", "hello"));
    try std.testing.expect(matchPattern("hello", "h*o"));
    try std.testing.expect(matchPattern("hello", "h?llo"));
    try std.testing.expect(!matchPattern("hello", "world"));
}
