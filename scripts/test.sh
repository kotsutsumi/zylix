#!/usr/bin/env bash
#
# Zylix Cross-Platform Test Orchestration Script
#
# Usage:
#   ./scripts/test.sh [options]
#
# Options:
#   --all         Run all tests across all platforms
#   --core        Run Zig core unit tests
#   --ios         Run iOS E2E tests on simulator
#   --android     Run Android E2E tests on emulator
#   --web         Run Web/WASM tests
#   --report      Generate unified test report
#   --help        Show this help message
#
# Examples:
#   ./scripts/test.sh --all
#   ./scripts/test.sh --core --ios
#   ./scripts/test.sh --android --report
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test results directory
RESULTS_DIR="$PROJECT_ROOT/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default options
RUN_CORE=false
RUN_IOS=false
RUN_ANDROID=false
RUN_WEB=false
GENERATE_REPORT=false

# Test results tracking
CORE_RESULT=""
IOS_RESULT=""
ANDROID_RESULT=""
WEB_RESULT=""

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_help() {
    head -n 25 "$0" | tail -n +2 | sed 's/^#//'
    exit 0
}

setup_results_dir() {
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR/core"
    mkdir -p "$RESULTS_DIR/ios"
    mkdir -p "$RESULTS_DIR/android"
    mkdir -p "$RESULTS_DIR/web"
    mkdir -p "$RESULTS_DIR/reports"
}

# ============================================================================
# Core Zig Tests
# ============================================================================

run_core_tests() {
    print_header "Running Zylix Core (Zig) Tests"

    cd "$PROJECT_ROOT/core"

    # Check if Zig is available
    if ! command -v zig &> /dev/null; then
        print_error "Zig is not installed. Please install Zig 0.15.x"
        CORE_RESULT="SKIPPED"
        return 1
    fi

    print_info "Zig version: $(zig version)"

    # Build first
    print_info "Building Zylix core..."
    if zig build 2>&1 | tee "$RESULTS_DIR/core/build_$TIMESTAMP.log"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        CORE_RESULT="FAILED"
        return 1
    fi

    # Run tests
    print_info "Running unit tests..."
    if zig build test --summary all 2>&1 | tee "$RESULTS_DIR/core/test_$TIMESTAMP.log"; then
        print_success "Core tests passed"
        CORE_RESULT="PASSED"
    else
        print_error "Core tests failed"
        CORE_RESULT="FAILED"
        return 1
    fi

    cd "$PROJECT_ROOT"
}

# ============================================================================
# iOS Tests
# ============================================================================

run_ios_tests() {
    print_header "Running iOS E2E Tests"

    # Check if we're on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_warning "iOS tests can only run on macOS"
        IOS_RESULT="SKIPPED"
        return 0
    fi

    # Check if xcodebuild is available
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed"
        IOS_RESULT="SKIPPED"
        return 1
    fi

    cd "$PROJECT_ROOT/platforms/ios"

    # Check for Xcode project
    if [[ ! -d "Zylix.xcodeproj" ]]; then
        print_warning "Zylix.xcodeproj not found. Run 'xcodegen generate' first."

        # Try to generate project
        if command -v xcodegen &> /dev/null; then
            print_info "Generating Xcode project..."
            xcodegen generate
        else
            IOS_RESULT="SKIPPED"
            return 0
        fi
    fi

    # Find available simulator
    SIMULATOR="iPhone 15"
    IOS_VERSION=$(xcrun simctl list devices available | grep -oE 'iOS [0-9]+\.[0-9]+' | head -1 | sed 's/iOS //')

    if [[ -z "$IOS_VERSION" ]]; then
        IOS_VERSION="17.5"
    fi

    print_info "Using simulator: $SIMULATOR (iOS $IOS_VERSION)"

    # Build for testing
    print_info "Building for testing..."
    if xcodebuild build-for-testing \
        -project Zylix.xcodeproj \
        -scheme Zylix \
        -destination "platform=iOS Simulator,name=$SIMULATOR,OS=$IOS_VERSION" \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee "$RESULTS_DIR/ios/build_$TIMESTAMP.log"; then
        print_success "iOS build completed"
    else
        print_error "iOS build failed"
        IOS_RESULT="FAILED"
        return 1
    fi

    # Run UI tests
    print_info "Running XCUITest E2E tests..."
    if xcodebuild test-without-building \
        -project Zylix.xcodeproj \
        -scheme ZylixUITests \
        -destination "platform=iOS Simulator,name=$SIMULATOR,OS=$IOS_VERSION" \
        -derivedDataPath build \
        -resultBundlePath "$RESULTS_DIR/ios/TestResults_$TIMESTAMP.xcresult" \
        2>&1 | tee "$RESULTS_DIR/ios/test_$TIMESTAMP.log"; then
        print_success "iOS E2E tests passed"
        IOS_RESULT="PASSED"
    else
        print_error "iOS E2E tests failed"
        IOS_RESULT="FAILED"

        # Capture screenshot on failure
        xcrun simctl io booted screenshot "$RESULTS_DIR/ios/failure_$TIMESTAMP.png" 2>/dev/null || true
        return 1
    fi

    cd "$PROJECT_ROOT"
}

# ============================================================================
# Android Tests
# ============================================================================

run_android_tests() {
    print_header "Running Android E2E Tests"

    cd "$PROJECT_ROOT/platforms/android"

    # Check for gradlew
    if [[ ! -f "gradlew" ]]; then
        print_error "gradlew not found"
        ANDROID_RESULT="SKIPPED"
        return 1
    fi

    chmod +x gradlew

    # Check for connected devices/emulators
    if command -v adb &> /dev/null; then
        DEVICES=$(adb devices | grep -v "List" | grep -v "^$" | wc -l)
        if [[ "$DEVICES" -eq 0 ]]; then
            print_warning "No Android devices/emulators connected"
            print_info "Start an emulator with: emulator -avd <avd_name>"

            # Try to find and start an emulator
            if command -v emulator &> /dev/null; then
                AVD=$(emulator -list-avds 2>/dev/null | head -1)
                if [[ -n "$AVD" ]]; then
                    print_info "Starting emulator: $AVD"
                    emulator -avd "$AVD" -no-audio -no-window &

                    # Wait for emulator to boot
                    print_info "Waiting for emulator to boot..."
                    adb wait-for-device

                    # Wait for boot completion
                    for i in {1..60}; do
                        BOOT_COMPLETED=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
                        if [[ "$BOOT_COMPLETED" == "1" ]]; then
                            print_success "Emulator booted"
                            break
                        fi
                        sleep 2
                    done
                else
                    print_warning "No AVDs available"
                    ANDROID_RESULT="SKIPPED"
                    return 0
                fi
            else
                ANDROID_RESULT="SKIPPED"
                return 0
            fi
        fi
    else
        print_warning "adb not found in PATH"
        ANDROID_RESULT="SKIPPED"
        return 0
    fi

    # Build library
    print_info "Building Android library..."
    if ./gradlew :zylix-android:assembleDebug 2>&1 | tee "$RESULTS_DIR/android/build_$TIMESTAMP.log"; then
        print_success "Android build completed"
    else
        print_error "Android build failed"
        ANDROID_RESULT="FAILED"
        return 1
    fi

    # Run unit tests
    print_info "Running unit tests..."
    if ./gradlew test 2>&1 | tee "$RESULTS_DIR/android/unit_test_$TIMESTAMP.log"; then
        print_success "Unit tests passed"
    else
        print_warning "Unit tests failed (continuing with E2E tests)"
    fi

    # Run instrumented tests
    print_info "Running Espresso E2E tests..."
    if ./gradlew :zylix-android:connectedDebugAndroidTest \
        2>&1 | tee "$RESULTS_DIR/android/e2e_test_$TIMESTAMP.log"; then
        print_success "Android E2E tests passed"
        ANDROID_RESULT="PASSED"
    else
        print_error "Android E2E tests failed"
        ANDROID_RESULT="FAILED"

        # Capture screenshot on failure
        adb exec-out screencap -p > "$RESULTS_DIR/android/failure_$TIMESTAMP.png" 2>/dev/null || true
        return 1
    fi

    # Copy test results
    cp -r zylix-android/build/reports "$RESULTS_DIR/android/reports_$TIMESTAMP" 2>/dev/null || true

    cd "$PROJECT_ROOT"
}

# ============================================================================
# Web Tests
# ============================================================================

run_web_tests() {
    print_header "Running Web/WASM Tests"

    cd "$PROJECT_ROOT"

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed"
        WEB_RESULT="SKIPPED"
        return 0
    fi

    # Check for test directory
    if [[ ! -d "tests" ]]; then
        print_warning "tests/ directory not found"
        WEB_RESULT="SKIPPED"
        return 0
    fi

    cd tests

    # Install dependencies if needed
    if [[ -f "package.json" ]] && [[ ! -d "node_modules" ]]; then
        print_info "Installing dependencies..."
        npm install
    fi

    # Run tests
    print_info "Running web tests..."
    if npm test 2>&1 | tee "$RESULTS_DIR/web/test_$TIMESTAMP.log"; then
        print_success "Web tests passed"
        WEB_RESULT="PASSED"
    else
        print_error "Web tests failed"
        WEB_RESULT="FAILED"
        return 1
    fi

    cd "$PROJECT_ROOT"
}

# ============================================================================
# Report Generation
# ============================================================================

generate_report() {
    print_header "Generating Test Report"

    REPORT_FILE="$RESULTS_DIR/reports/summary_$TIMESTAMP.md"

    cat > "$REPORT_FILE" << EOF
# Zylix Test Report

**Generated:** $(date)
**Commit:** $(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
**Branch:** $(git branch --show-current 2>/dev/null || echo "N/A")

## Summary

| Platform | Status |
|----------|--------|
| Core (Zig) | ${CORE_RESULT:-NOT RUN} |
| iOS | ${IOS_RESULT:-NOT RUN} |
| Android | ${ANDROID_RESULT:-NOT RUN} |
| Web | ${WEB_RESULT:-NOT RUN} |

## Results

EOF

    # Add detailed results for each platform
    for platform in core ios android web; do
        if [[ -f "$RESULTS_DIR/$platform/test_$TIMESTAMP.log" ]]; then
            echo "### ${platform^} Test Output" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            tail -50 "$RESULTS_DIR/$platform/test_$TIMESTAMP.log" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done

    # Generate JSON summary
    JSON_FILE="$RESULTS_DIR/reports/summary_$TIMESTAMP.json"
    cat > "$JSON_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "commit": "$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")",
  "branch": "$(git branch --show-current 2>/dev/null || echo "N/A")",
  "results": {
    "core": "${CORE_RESULT:-NOT_RUN}",
    "ios": "${IOS_RESULT:-NOT_RUN}",
    "android": "${ANDROID_RESULT:-NOT_RUN}",
    "web": "${WEB_RESULT:-NOT_RUN}"
  }
}
EOF

    print_success "Report generated: $REPORT_FILE"
    print_success "JSON summary: $JSON_FILE"

    # Print summary to console
    echo ""
    print_header "Test Summary"
    echo "Core (Zig):   ${CORE_RESULT:-NOT RUN}"
    echo "iOS:          ${IOS_RESULT:-NOT RUN}"
    echo "Android:      ${ANDROID_RESULT:-NOT RUN}"
    echo "Web:          ${WEB_RESULT:-NOT RUN}"
    echo ""

    # Determine overall result
    OVERALL="PASSED"
    for result in "$CORE_RESULT" "$IOS_RESULT" "$ANDROID_RESULT" "$WEB_RESULT"; do
        if [[ "$result" == "FAILED" ]]; then
            OVERALL="FAILED"
            break
        fi
    done

    if [[ "$OVERALL" == "PASSED" ]]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed!"
        return 1
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_help
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                RUN_CORE=true
                RUN_IOS=true
                RUN_ANDROID=true
                RUN_WEB=true
                GENERATE_REPORT=true
                shift
                ;;
            --core)
                RUN_CORE=true
                shift
                ;;
            --ios)
                RUN_IOS=true
                shift
                ;;
            --android)
                RUN_ANDROID=true
                shift
                ;;
            --web)
                RUN_WEB=true
                shift
                ;;
            --report)
                GENERATE_REPORT=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    # Setup results directory
    setup_results_dir

    print_header "Zylix Cross-Platform Test Orchestration"
    print_info "Results directory: $RESULTS_DIR"
    echo ""

    # Run requested tests
    if [[ "$RUN_CORE" == true ]]; then
        run_core_tests || true
    fi

    if [[ "$RUN_IOS" == true ]]; then
        run_ios_tests || true
    fi

    if [[ "$RUN_ANDROID" == true ]]; then
        run_android_tests || true
    fi

    if [[ "$RUN_WEB" == true ]]; then
        run_web_tests || true
    fi

    # Generate report
    if [[ "$GENERATE_REPORT" == true ]]; then
        generate_report
    else
        # Print quick summary
        echo ""
        print_header "Quick Summary"
        [[ -n "$CORE_RESULT" ]] && echo "Core: $CORE_RESULT"
        [[ -n "$IOS_RESULT" ]] && echo "iOS: $IOS_RESULT"
        [[ -n "$ANDROID_RESULT" ]] && echo "Android: $ANDROID_RESULT"
        [[ -n "$WEB_RESULT" ]] && echo "Web: $WEB_RESULT"
    fi
}

# Run main function
main "$@"
