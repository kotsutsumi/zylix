#!/bin/bash
#
# Zylix macOS Build Script
# Builds Zylix Core and macOS app from command line
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
MACOS_DIR="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}==>${NC} $1"; }
print_warning() { echo -e "${YELLOW}Warning:${NC} $1"; }
print_error() { echo -e "${RED}Error:${NC} $1"; }

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."

    if ! command -v zig &> /dev/null; then
        print_error "Zig not found. Install with: brew install zig"
        exit 1
    fi

    if ! command -v xcodegen &> /dev/null; then
        print_error "XcodeGen not found. Install with: brew install xcodegen"
        exit 1
    fi

    print_status "Dependencies OK"
}

# Build Zylix Core for macOS
build_core() {
    print_status "Building Zylix Core for macOS (aarch64)..."

    cd "$CORE_DIR"

    mkdir -p zig-out/macos/lib

    zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast

    # Copy to macos output
    cp zig-out/lib/libzylix.a zig-out/macos/lib/

    print_status "Core built: $(ls -lh zig-out/macos/lib/libzylix.a | awk '{print $5}')"
}

# Generate Xcode project
generate_project() {
    print_status "Generating Xcode project..."

    cd "$MACOS_DIR"
    xcodegen generate

    print_status "Project generated: Zylix.xcodeproj"
}

# Build macOS app
build_app() {
    local config="${1:-Debug}"

    print_status "Building macOS app ($config)..."

    cd "$MACOS_DIR"

    xcodebuild -project Zylix.xcodeproj \
        -scheme Zylix \
        -configuration "$config" \
        -derivedDataPath build \
        build

    print_status "Build completed"
}

# Run app
run_app() {
    print_status "Running Zylix..."

    local app_path="$MACOS_DIR/build/Build/Products/Debug/Zylix.app"

    if [ -d "$app_path" ]; then
        open "$app_path"
    else
        print_error "App not found. Run 'build' first."
        exit 1
    fi
}

# Clean build artifacts
clean() {
    print_status "Cleaning build artifacts..."

    rm -rf "$MACOS_DIR/build"
    rm -rf "$MACOS_DIR/Zylix.xcodeproj"
    rm -rf "$CORE_DIR/zig-out/macos"

    print_status "Clean completed"
}

# Show help
show_help() {
    echo "Zylix macOS Build Script"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  build       Build everything (core + app)"
    echo "  core        Build Zylix Core only"
    echo "  app         Build macOS app only"
    echo "  run         Run the app"
    echo "  clean       Clean build artifacts"
    echo "  help        Show this help"
}

# Main
case "${1:-build}" in
    build)
        check_dependencies
        build_core
        generate_project
        build_app Debug
        ;;
    core)
        check_dependencies
        build_core
        ;;
    app)
        check_dependencies
        generate_project
        build_app Debug
        ;;
    run)
        run_app
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
