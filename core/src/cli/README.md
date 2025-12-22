# Zylix Test CLI

Command-line interface for running E2E tests across all platforms.

## Installation

```bash
cd core
zig build
```

The CLI will be available at `./zig-out/bin/zylix-test`.

## Usage

```bash
zylix-test <command> [options]
```

## Commands

### `run` - Run Tests

Execute E2E tests with various options.

```bash
# Run all tests
zylix-test run

# Run web tests only
zylix-test run --platform web

# Run with specific browser
zylix-test run --platform web --browser firefox

# Run with retries and parallel workers
zylix-test run --parallel 4 --retry 2

# Filter tests by name
zylix-test run --filter "login*"

# Dry run (show tests without running)
zylix-test run --dry-run
```

**Options:**
| Option | Description |
|--------|-------------|
| `--platform <name>` | Target platform (web, ios, android, macos, windows, linux) |
| `--browser <type>` | Browser for web tests (chrome, firefox, safari) |
| `--headless` | Run browser in headless mode |
| `--parallel <n>` | Number of parallel workers |
| `--timeout <ms>` | Test timeout in milliseconds |
| `--retry <n>` | Number of retries for failed tests |
| `--reporter <format>` | Output format (console, junit, json, html) |
| `--filter <pattern>` | Filter tests by name pattern |
| `--shard <n/total>` | Run shard n of total shards (CI mode) |
| `--dry-run` | Show tests without running |

### `init` - Initialize Project

Create a new test project with configuration and example tests.

```bash
# Create new project
zylix-test init my-tests

# Use specific template
zylix-test init my-tests --template mobile

# Overwrite existing
zylix-test init my-tests --force
```

**Options:**
| Option | Description |
|--------|-------------|
| `--template <name>` | Project template (basic, full, mobile, web) |
| `--force` | Overwrite existing files |

### `server` - Manage Bridge Servers

Start, stop, and manage platform bridge servers.

```bash
# Start web bridge server
zylix-test server start --web

# Start multiple servers
zylix-test server start --ios --android

# Stop all servers
zylix-test server stop --all

# Check status
zylix-test server status --all

# Start on custom port
zylix-test server start --web --port=9516
```

**Actions:**
- `start` - Start bridge server(s)
- `stop` - Stop bridge server(s)
- `status` - Show server status
- `restart` - Restart bridge server(s)

**Platform Options:**
| Option | Platform | Default Port |
|--------|----------|--------------|
| `--web` | Web/Playwright | 9515 |
| `--ios` | iOS/XCUITest | 8100 |
| `--android` | Android/UiAutomator2 | 4724 |
| `--macos` | macOS/Accessibility | 8200 |
| `--windows` | Windows/UIAutomation | 4723 |
| `--linux` | Linux/AT-SPI | 8300 |
| `--all` | All platforms | - |

### `list` - List Tests

Display available tests.

```bash
# List all tests
zylix-test list

# Filter by platform
zylix-test list --platform web

# Output as JSON
zylix-test list --json
```

### `report` - Generate Reports

Generate test reports from results.

```bash
# Generate HTML report
zylix-test report --format html

# Generate and open in browser
zylix-test report --format html --open

# Specify input/output directories
zylix-test report --input results/ --output reports/ --format junit
```

**Options:**
| Option | Description |
|--------|-------------|
| `--input <dir>` | Input directory with test results |
| `--output <dir>` | Output directory for reports |
| `--format <type>` | Report format (html, junit, json, markdown) |
| `--open` | Open report in browser (HTML only) |

### `version` - Show Version

```bash
zylix-test version
# Output:
# zylix-test 0.9.0
# Zig 0.15.2
# Platform: macOS (aarch64)
```

### `help` - Get Help

```bash
# General help
zylix-test --help

# Command-specific help
zylix-test help run
zylix-test help server
```

## Configuration

Create `zylix-test.json` in your project root:

```json
{
  "name": "my-tests",
  "version": "0.1.0",
  "testDir": "tests",
  "outputDir": "test-results",
  "timeout": 30000,
  "retries": 0,
  "reporter": "console",
  "platforms": ["web"],
  "web": {
    "browser": "chrome",
    "headless": true,
    "viewport": {
      "width": 1280,
      "height": 720
    }
  }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4
      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
      - name: Build
        run: cd core && zig build
      - name: Run Tests
        run: ./core/zig-out/bin/zylix-test run --shard ${{ matrix.shard }}/4
```

### GitLab CI

```yaml
test:
  parallel: 4
  script:
    - cd core && zig build
    - ./zig-out/bin/zylix-test run --shard $CI_NODE_INDEX/$CI_NODE_TOTAL
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Test failure |
| 2 | Invalid arguments |
| 3 | Configuration error |
| 4 | Runtime error |

## Architecture

```
core/src/cli/
├── main.zig      # Entry point and command routing
├── commands.zig  # Command implementations
├── config.zig    # Configuration loading
├── output.zig    # Terminal output formatting
└── README.md     # This file
```
