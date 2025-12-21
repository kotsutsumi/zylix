#!/bin/bash
# Build Zylix Core for iOS/macOS platforms
# Produces static libraries for Simulator and Device

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
OUTPUT_DIR="$SCRIPT_DIR/lib"

# Clean output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Building Zylix Core for iOS/macOS ==="
echo "Project root: $PROJECT_ROOT"
echo "Core directory: $CORE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check Zig version
ZIG_VERSION=$(zig version)
echo "Using Zig version: $ZIG_VERSION"
echo ""

cd "$CORE_DIR"

# Build for macOS (arm64) - used by iOS Simulator on Apple Silicon
echo "=== Building for macOS (arm64) ==="
zig build-lib \
    -target aarch64-macos \
    -O ReleaseFast \
    --name zylix \
    src/abi.zig \
    -femit-bin="$OUTPUT_DIR/libzylix-macos-arm64.a"

echo "Built: $OUTPUT_DIR/libzylix-macos-arm64.a"

# Build for macOS (x86_64) - used by iOS Simulator on Intel Macs
echo "=== Building for macOS (x86_64) ==="
zig build-lib \
    -target x86_64-macos \
    -O ReleaseFast \
    --name zylix \
    src/abi.zig \
    -femit-bin="$OUTPUT_DIR/libzylix-macos-x64.a"

echo "Built: $OUTPUT_DIR/libzylix-macos-x64.a"

# Create universal library for macOS/Simulator
echo "=== Creating Universal Library ==="
lipo -create \
    "$OUTPUT_DIR/libzylix-macos-arm64.a" \
    "$OUTPUT_DIR/libzylix-macos-x64.a" \
    -output "$OUTPUT_DIR/libzylix.a"

echo "Built: $OUTPUT_DIR/libzylix.a"

# Note: For actual iOS device builds, we would need:
# -target aarch64-ios (but Zig needs iOS SDK paths configured)
# For now, macOS libraries work for Simulator development

# Summary
echo ""
echo "=== Build Complete ==="
echo "Libraries:"
ls -lh "$OUTPUT_DIR"/*.a 2>/dev/null || true
echo ""
echo "To use in Xcode:"
echo "1. Copy libzylix.a to your project"
echo "2. Add to 'Link Binary With Libraries' in Build Phases"
echo "3. Add library search path to Build Settings"
echo "4. Import ZylixSwift package or use bridging header"
echo ""
echo "Library location: $OUTPUT_DIR/libzylix.a"
