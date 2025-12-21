#!/bin/bash
#
# Build script for Zylix Counter WASM Demo
#
# Usage: ./build.sh [options]
#   --release    Build with ReleaseSmall optimization (default)
#   --debug      Build with Debug mode
#   --serve      Start HTTP server after build
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/../../core"
OPTIMIZE="ReleaseSmall"
SERVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            OPTIMIZE="Debug"
            shift
            ;;
        --release)
            OPTIMIZE="ReleaseSmall"
            shift
            ;;
        --serve)
            SERVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== Zylix Counter WASM Build ==="
echo "Optimization: $OPTIMIZE"
echo ""

# Check for Zig
if ! command -v zig &> /dev/null; then
    echo "Error: Zig is not installed or not in PATH"
    echo "Install from: https://ziglang.org/download/"
    exit 1
fi

echo "Zig version: $(zig version)"
echo ""

# Build WASM
echo "Building WASM module..."
cd "$CORE_DIR"
zig build wasm -Doptimize=$OPTIMIZE

# Copy WASM to sample directory
echo "Copying zylix.wasm..."
cp "$CORE_DIR/zig-out/wasm/zylix.wasm" "$SCRIPT_DIR/"

# Show file size
WASM_SIZE=$(ls -lh "$SCRIPT_DIR/zylix.wasm" | awk '{print $5}')
echo ""
echo "Build complete!"
echo "  WASM size: $WASM_SIZE"
echo "  Output: $SCRIPT_DIR/zylix.wasm"
echo ""

# Optionally start server
if [ "$SERVE" = true ]; then
    echo "Starting HTTP server on http://localhost:8080"
    echo "Press Ctrl+C to stop"
    echo ""
    cd "$SCRIPT_DIR"

    # Try Python 3 first, then Python 2
    if command -v python3 &> /dev/null; then
        python3 -m http.server 8080
    elif command -v python &> /dev/null; then
        python -m SimpleHTTPServer 8080
    else
        echo "Error: Python not found. Install Python or use another HTTP server."
        echo "Example: npx serve ."
        exit 1
    fi
else
    echo "To test the demo:"
    echo "  cd $SCRIPT_DIR"
    echo "  python3 -m http.server 8080"
    echo "  Open http://localhost:8080"
fi
