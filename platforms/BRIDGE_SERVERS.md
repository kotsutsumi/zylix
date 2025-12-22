# Zylix Test Framework - Bridge Servers

Platform-specific bridge servers that enable communication between Zig-based test drivers and native automation APIs.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Zylix Test Framework (Zig)                      │
├─────────────────────────────────────────────────────────────────────┤
│  web_driver.zig │ ios_driver.zig │ android_driver.zig │ ...        │
└────────┬────────┴───────┬────────┴─────────┬──────────┴─────────────┘
         │ HTTP           │ HTTP             │ HTTP
         ▼                ▼                  ▼
┌─────────────────┐┌─────────────────┐┌─────────────────┐
│   Web Bridge    ││   iOS Bridge    ││ Android Bridge  │
│  (Playwright)   ││   (XCUITest)    ││ (UiAutomator2)  │
└────────┬────────┘└────────┬────────┘└────────┬────────┘
         │                  │                  │
         ▼                  ▼                  ▼
     Browsers           iOS Device       Android Device
```

## Supported Platforms

| Platform | Language | Automation API | Default Port |
|----------|----------|----------------|--------------|
| Web | JavaScript | Playwright | 9515 |
| iOS | Swift | XCUITest | 8100 |
| Android | Kotlin | UiAutomator2 | 4724 |
| macOS | Swift | Accessibility API | 8200 |
| Windows | C# | UI Automation | 4723 |
| Linux | Python | AT-SPI2 | 8300 |

## Web Bridge (Playwright)

**Location:** `platforms/web/zylix-test/`

Cross-browser automation using Playwright.

### Installation

```bash
cd platforms/web/zylix-test
npm install
npx playwright install
```

### Usage

```bash
# Start server (default port: 9515)
npm start

# With custom port
ZYLIX_TEST_PORT=9516 npm start
```

### Supported Browsers

- Chromium (Chrome, Edge)
- Firefox
- WebKit (Safari)

### Commands

| Command | Description |
|---------|-------------|
| `launch` | Create new browser session |
| `close` | Close session |
| `navigate` | Navigate to URL |
| `findElement` | Find element by selector |
| `findElements` | Find multiple elements |
| `waitForSelector` | Wait for element to appear |
| `click`, `dblclick`, `longPress` | Click interactions |
| `type`, `clear` | Text input |
| `swipe`, `scroll` | Gesture actions |
| `screenshot` | Capture screenshot |

---

## iOS Bridge (XCUITest)

**Location:** `platforms/ios/zylix-test/`

Native iOS automation using XCUITest framework.

### Prerequisites

- Xcode 15+
- iOS Simulator or physical device
- Swift 5.9+

### Build

```bash
cd platforms/ios/zylix-test
swift build
```

### Usage

```bash
# Start server (default port: 8100)
.build/debug/ZylixTest

# With custom port
ZYLIX_TEST_PORT=8101 .build/debug/ZylixTest
```

### Element Finding Strategies

- `accessibilityId` - Accessibility identifier
- `name` - Element label
- `predicate` - NSPredicate string
- `classChain` - XCUITest class chain

---

## Android Bridge (UiAutomator2)

**Location:** `platforms/android/zylix-test/`

Native Android automation using UiAutomator2 framework.

### Prerequisites

- Android SDK
- Kotlin 1.9+
- ADB configured

### Build

```bash
cd platforms/android/zylix-test
./gradlew build
```

### Usage

```bash
# Start server (default port: 4724)
./gradlew run

# With custom port
ZYLIX_TEST_PORT=4725 ./gradlew run
```

### Element Finding Strategies

- `accessibilityId` - Content description
- `resourceId` - Android resource ID
- `className` - Widget class name
- `uiSelector` - UiAutomator selector string
- `xpath` - XPath expression

---

## macOS Bridge (Accessibility API)

**Location:** `platforms/macos/zylix-test/`

Native macOS automation using Accessibility API.

### Prerequisites

- macOS 14+
- Xcode 15+
- Accessibility permissions enabled

### Build

```bash
cd platforms/macos/zylix-test
swift build
```

### Usage

```bash
# Start server (default port: 8200)
.build/debug/ZylixTest

# With custom port
ZYLIX_TEST_PORT=8201 .build/debug/ZylixTest
```

### Element Finding Strategies

- `identifier` - Accessibility identifier
- `title` - Window/element title
- `role` - Accessibility role (button, textfield, etc.)
- `predicate` - NSPredicate expression

### Permissions

Enable accessibility in System Settings:
`System Settings > Privacy & Security > Accessibility`

---

## Windows Bridge (UI Automation)

**Location:** `platforms/windows/zylix-test/`

Native Windows automation using UI Automation API.

### Prerequisites

- .NET 8.0 SDK
- Windows 10/11

### Build

```bash
cd platforms/windows/zylix-test
dotnet build
```

### Usage

```bash
# Start server (default port: 4723)
dotnet run

# With custom port
set ZYLIX_TEST_PORT=4724
dotnet run
```

### Element Finding Strategies

- `automationId` - Automation ID property
- `name` - Element name
- `className` - Control class name
- `controlType` - Control type (Button, Edit, etc.)
- `xpath` - XPath-like expression

---

## Linux Bridge (AT-SPI2)

**Location:** `platforms/linux/zylix-test/`

Native Linux automation using AT-SPI2 (Assistive Technology Service Provider Interface).

### Prerequisites

- Python 3.10+
- AT-SPI2 libraries
- pyatspi2

### Installation

```bash
cd platforms/linux/zylix-test
pip install -r requirements.txt

# Ubuntu/Debian
sudo apt install python3-pyatspi at-spi2-core

# Fedora
sudo dnf install python3-pyatspi at-spi2-core
```

### Usage

```bash
# Start server (default port: 8300)
python zylix_test_server.py

# With custom port
ZYLIX_TEST_PORT=8301 python zylix_test_server.py
```

### Element Finding Strategies

- `role` - AT-SPI role (push button, text, etc.)
- `name` - Element name/label
- `description` - Accessibility description
- `state` - Element state (visible, enabled, etc.)

---

## Protocol Specification

All bridges implement a common HTTP/JSON protocol.

### Request Format

```
POST /session/{sessionId}/{command}
Content-Type: application/json

{
  "param1": "value1",
  "param2": "value2"
}
```

### Response Format

```json
{
  "result": "value",
  "elementId": "123",
  "error": null
}
```

### Common Commands

| Command | Method | Path | Description |
|---------|--------|------|-------------|
| Launch | POST | `/session/new/launch` | Create session |
| Close | POST | `/session/{id}/close` | Close session |
| Find | POST | `/session/{id}/findElement` | Find element |
| Click | POST | `/session/{id}/click` | Click element |
| Type | POST | `/session/{id}/type` | Enter text |
| Screenshot | POST | `/session/{id}/screenshot` | Capture screen |

### Error Handling

```json
{
  "error": "element not found",
  "code": "NO_SUCH_ELEMENT"
}
```

Common error codes:
- `NO_SUCH_ELEMENT` - Element not found
- `ELEMENT_NOT_VISIBLE` - Element not visible
- `TIMEOUT` - Operation timed out
- `SESSION_NOT_FOUND` - Invalid session ID

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ZYLIX_TEST_PORT` | Server port | Platform-specific |
| `ZYLIX_TEST_HOST` | Server host | `127.0.0.1` |
| `ZYLIX_TEST_TIMEOUT` | Default timeout (ms) | `30000` |
| `ZYLIX_TEST_DEBUG` | Enable debug logging | `false` |

---

## Integration with Zig Drivers

The Zig drivers in `core/src/test/` communicate with these bridges:

```zig
// Example: Web driver connecting to Playwright bridge
const config = WebDriverConfig{
    .browser = .chrome,
    .headless = true,
};

var driver = try web_driver.createWebDriver(config, allocator);
defer driver.deinit();

// Driver sends HTTP requests to bridge server
try driver.launch(.{ .url = "https://example.com" });
```

Each platform driver handles:
- Connection management
- Command serialization/deserialization
- Error handling and retries
- Session lifecycle

---

## Development

### Adding a New Bridge

1. Create directory: `platforms/{platform}/zylix-test/`
2. Implement HTTP server with JSON protocol
3. Support standard commands (launch, find, click, type, screenshot)
4. Add platform-specific element finding strategies
5. Document in this file

### Testing Bridges

```bash
# Test with curl
curl -X POST http://localhost:9515/session/new/launch \
  -H "Content-Type: application/json" \
  -d '{"browser": "chromium", "headless": true}'

# Response
{"sessionId": "1"}
```

---

## License

MIT License - See [LICENSE](../LICENSE) for details.
