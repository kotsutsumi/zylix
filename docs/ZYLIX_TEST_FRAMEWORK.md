# Zylix Test Framework 設計書

> **バージョン**: v0.8.1
> **ステータス**: 実装済み

---

## 1. 概要

Zylix Test Framework は、全6プラットフォーム（iOS, Android, macOS, Windows, Linux, Web）で統一されたE2Eテストを実行するための独自テストフレームワークである。v0.8.1 で E2E テスト基盤を実装済み。

### 設計原則

1. **Write Once, Run Everywhere** - 1つのテストコードが全プラットフォームで動作
2. **OS Native Testing** - 各プラットフォームのネイティブテストツールを活用
3. **C ABI Integration** - Zylix本体と同じC ABIパターンを採用
4. **Zero Runtime Overhead** - テストコードはプロダクションコードに含まれない

---

## 2. アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                 Zylix Test API (Zig)                    │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │  Selectors  │ │   Actions   │ │  Assertions │       │
│  │  find()     │ │  tap()      │ │  expect()   │       │
│  │  query()    │ │  type()     │ │  assert()   │       │
│  │  waitFor()  │ │  swipe()    │ │  verify()   │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │  Screenshot │ │   Fixtures  │ │  Test Runner│       │
│  │  capture()  │ │  setup()    │ │  run()      │       │
│  │  compare()  │ │  teardown() │ │  report()   │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
└─────────────────────────────────────────────────────────┘
                            │
                        C ABI
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  iOS Driver   │   │Android Driver │   │  Web Driver   │
│               │   │               │   │               │
│  XCUITest     │   │  UiAutomator  │   │  Playwright   │
│  Integration  │   │  Integration  │   │  Integration  │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  macOS Driver │   │ Windows Driver│   │  Linux Driver │
│               │   │               │   │               │
│  XCUITest     │   │  WinAppDriver │   │  AT-SPI/Dogtl │
│  Integration  │   │  Integration  │   │  Integration  │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

## 3. テスト API 設計

### 3.1 Selector API

```zig
// core/src/test/selector.zig

pub const Selector = struct {
    component_type: ?ComponentType = null,
    text: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    test_id: ?[]const u8 = null,
    index: ?usize = null,

    pub fn byType(comptime T: ComponentType) Selector {
        return .{ .component_type = T };
    }

    pub fn byText(text: []const u8) Selector {
        return .{ .text = text };
    }

    pub fn byTestId(id: []const u8) Selector {
        return .{ .test_id = id };
    }

    pub fn byAccessibilityId(id: []const u8) Selector {
        return .{ .accessibility_id = id };
    }
};
```

### 3.2 Element API

```zig
// core/src/test/element.zig

pub const Element = struct {
    driver: *Driver,
    selector: Selector,

    // Actions
    pub fn tap(self: *Element) !void;
    pub fn doubleTap(self: *Element) !void;
    pub fn longPress(self: *Element, duration_ms: u32) !void;
    pub fn type(self: *Element, text: []const u8) !void;
    pub fn clear(self: *Element) !void;
    pub fn swipe(self: *Element, direction: SwipeDirection) !void;
    pub fn scroll(self: *Element, direction: ScrollDirection, amount: f32) !void;

    // Queries
    pub fn exists(self: *Element) bool;
    pub fn isVisible(self: *Element) bool;
    pub fn isEnabled(self: *Element) bool;
    pub fn getText(self: *Element) ![]const u8;
    pub fn getAttribute(self: *Element, name: []const u8) ![]const u8;
    pub fn getRect(self: *Element) !Rect;

    // Chaining
    pub fn find(self: *Element, selector: Selector) Element;
    pub fn findAll(self: *Element, selector: Selector) []Element;
};
```

### 3.3 App API

```zig
// core/src/test/app.zig

pub const App = struct {
    driver: *Driver,
    config: AppConfig,

    pub fn launch(config: AppConfig) !App;
    pub fn terminate(self: *App) !void;
    pub fn reset(self: *App) !void;

    // Navigation
    pub fn find(self: *App, selector: Selector) Element;
    pub fn findAll(self: *App, selector: Selector) []Element;
    pub fn waitFor(self: *App, selector: Selector, timeout_ms: u32) !Element;
    pub fn waitForNot(self: *App, selector: Selector, timeout_ms: u32) !void;

    // Screenshots
    pub fn screenshot(self: *App) !Screenshot;
    pub fn compareScreenshot(self: *App, baseline: []const u8) !CompareResult;

    // State (Zylix-specific)
    pub fn getState(self: *App, comptime T: type) !T;
    pub fn dispatch(self: *App, event: Event) !void;
};
```

### 3.4 Assertion API

```zig
// core/src/test/assert.zig

pub fn expect(value: anytype) Expectation(@TypeOf(value)) {
    return .{ .value = value };
}

pub fn Expectation(comptime T: type) type {
    return struct {
        value: T,

        pub fn toBe(self: @This(), expected: T) !void;
        pub fn toEqual(self: @This(), expected: T) !void;
        pub fn toContain(self: @This(), substring: []const u8) !void;
        pub fn toBeVisible(self: @This()) !void;
        pub fn toExist(self: @This()) !void;
        pub fn toBeEnabled(self: @This()) !void;
        pub fn toHaveText(self: @This(), text: []const u8) !void;
    };
}
```

---

## 4. Platform Driver 設計

### 4.1 Driver Interface

```zig
// core/src/test/driver.zig

pub const Driver = struct {
    vtable: *const VTable,
    context: *anyopaque,

    pub const VTable = struct {
        launch: *const fn (*anyopaque, AppConfig) anyerror!void,
        terminate: *const fn (*anyopaque) anyerror!void,
        findElement: *const fn (*anyopaque, Selector) anyerror!?ElementHandle,
        findElements: *const fn (*anyopaque, Selector) anyerror![]ElementHandle,
        tap: *const fn (*anyopaque, ElementHandle) anyerror!void,
        typeText: *const fn (*anyopaque, ElementHandle, []const u8) anyerror!void,
        getText: *const fn (*anyopaque, ElementHandle) anyerror![]const u8,
        screenshot: *const fn (*anyopaque) anyerror![]const u8,
        // ... more
    };
};
```

### 4.2 Platform-Specific Implementations

| Platform | Driver File | Native Tool | Communication |
|----------|-------------|-------------|---------------|
| iOS | `platforms/ios/ZylixTest/` | XCUITest | XPC / HTTP |
| Android | `platforms/android/zylix-test/` | UiAutomator2 | ADB / HTTP |
| macOS | `platforms/macos/ZylixTest/` | XCUITest | XPC / HTTP |
| Windows | `platforms/windows/ZylixTest/` | WinAppDriver | HTTP |
| Linux | `platforms/linux/zylix-test/` | AT-SPI / Dogtail | D-Bus |
| Web | `platforms/web/zylix-test/` | Playwright | WebSocket |

---

## 5. テスト例

### 5.1 基本的なテスト

```zig
// tests/e2e/login_test.zig

const std = @import("std");
const zylix_test = @import("zylix_test");

test "user can login with valid credentials" {
    var app = try zylix_test.App.launch(.{
        .app_id = "com.example.myapp",
        .platform = .auto,
    });
    defer app.terminate() catch {};

    // Find and interact with elements
    try app.find(.byTestId("email-input")).type("user@example.com");
    try app.find(.byTestId("password-input")).type("password123");
    try app.find(.byTestId("login-button")).tap();

    // Wait for navigation
    const welcome = try app.waitFor(.byText("Welcome"), 5000);

    // Assert
    try zylix_test.expect(welcome.isVisible()).toBe(true);
    try zylix_test.expect(welcome.getText()).toContain("Welcome");
}

test "shows error for invalid credentials" {
    var app = try zylix_test.App.launch(.{ .app_id = "com.example.myapp" });
    defer app.terminate() catch {};

    try app.find(.byTestId("email-input")).type("wrong@example.com");
    try app.find(.byTestId("password-input")).type("wrongpassword");
    try app.find(.byTestId("login-button")).tap();

    const error_msg = try app.waitFor(.byTestId("error-message"), 3000);
    try zylix_test.expect(error_msg.getText()).toContain("Invalid credentials");
}
```

### 5.2 Visual Regression テスト

```zig
test "login screen matches baseline" {
    var app = try zylix_test.App.launch(.{ .app_id = "com.example.myapp" });
    defer app.terminate() catch {};

    const result = try app.compareScreenshot("login-screen-baseline");
    try zylix_test.expect(result.diff_percentage).toBeLessThan(0.01);
}
```

### 5.3 State テスト (Zylix固有)

```zig
test "counter state updates correctly" {
    var app = try zylix_test.App.launch(.{ .app_id = "com.example.counter" });
    defer app.terminate() catch {};

    // Get initial state
    const initial_state = try app.getState(CounterState);
    try zylix_test.expect(initial_state.count).toBe(0);

    // Tap increment
    try app.find(.byTestId("increment-button")).tap();

    // Verify state changed
    const new_state = try app.getState(CounterState);
    try zylix_test.expect(new_state.count).toBe(1);
}
```

---

## 6. ディレクトリ構造

```
zylix/
├── core/
│   └── src/
│       └── test/                    # Test framework core (Zig)
│           ├── app.zig
│           ├── element.zig
│           ├── selector.zig
│           ├── driver.zig
│           ├── assert.zig
│           ├── screenshot.zig
│           └── runner.zig
│
├── platforms/
│   ├── ios/
│   │   └── ZylixTest/               # iOS test driver
│   │       ├── ZylixTestDriver.swift
│   │       └── XCUITestBridge.swift
│   │
│   ├── android/
│   │   └── zylix-test/              # Android test driver
│   │       └── src/main/java/com/zylix/test/
│   │           ├── ZylixTestDriver.kt
│   │           └── UiAutomatorBridge.kt
│   │
│   ├── macos/
│   │   └── ZylixTest/               # macOS test driver
│   │
│   ├── windows/
│   │   └── ZylixTest/               # Windows test driver
│   │       └── WinAppDriverBridge.cs
│   │
│   ├── linux/
│   │   └── zylix-test/              # Linux test driver
│   │       └── atspi_bridge.c
│   │
│   └── web/
│       └── zylix-test/              # Web test driver (Playwright wrapper)
│           └── playwright_bridge.js
│
├── tests/
│   └── e2e/                         # E2E test files (Zig)
│       ├── login_test.zig
│       ├── counter_test.zig
│       └── navigation_test.zig
│
└── tools/
    └── zylix-test-cli/              # Test runner CLI
        └── main.zig
```

---

## 7. 実装フェーズ

### Phase 1: Core API (Week 1-2)
| Task | Description | Priority |
|------|-------------|----------|
| 1.1 | Selector API 実装 | P0 |
| 1.2 | Element API 実装 | P0 |
| 1.3 | App API 実装 | P0 |
| 1.4 | Assertion API 実装 | P0 |
| 1.5 | Driver Interface 定義 | P0 |

### Phase 2: Web Driver (Week 2-3)
| Task | Description | Priority |
|------|-------------|----------|
| 2.1 | Playwright Bridge 実装 | P0 |
| 2.2 | WebSocket 通信層 | P0 |
| 2.3 | Screenshot 機能 | P1 |
| 2.4 | Visual Regression | P1 |

### Phase 3: Mobile Drivers (Week 3-5)
| Task | Description | Priority |
|------|-------------|----------|
| 3.1 | iOS XCUITest Driver | P0 |
| 3.2 | Android UiAutomator Driver | P0 |
| 3.3 | HTTP Server for communication | P0 |

### Phase 4: Desktop Drivers (Week 5-7)
| Task | Description | Priority |
|------|-------------|----------|
| 4.1 | macOS XCUITest Driver | P1 |
| 4.2 | Windows WinAppDriver Bridge | P1 |
| 4.3 | Linux AT-SPI Bridge | P2 |

### Phase 5: CI/CD Integration (Week 7-8)
| Task | Description | Priority |
|------|-------------|----------|
| 5.1 | GitHub Actions workflow | P0 |
| 5.2 | Test report generation | P1 |
| 5.3 | Parallel test execution | P1 |
| 5.4 | Device farm integration | P2 |

---

## 8. 成功基準

- [ ] 統一APIで全6プラットフォームのE2Eテスト実行可能
- [ ] Visual Regression テスト機能
- [ ] CI/CDパイプラインでの自動実行
- [ ] テスト実行時間: 単体テスト < 1分、E2E < 10分
- [ ] ドキュメント完備

---

## 9. 参考

- [XCUITest Documentation](https://developer.apple.com/documentation/xctest)
- [UiAutomator2](https://developer.android.com/training/testing/other-components/ui-automator)
- [WinAppDriver](https://github.com/microsoft/WinAppDriver)
- [AT-SPI](https://www.freedesktop.org/wiki/Accessibility/AT-SPI2/)
- [Playwright](https://playwright.dev/)
