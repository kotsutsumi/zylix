# Zylix iOS Makefile
# Build iOS app from command line without opening Xcode

.PHONY: all generate build build-sim run clean help core

# Default target
all: build-sim

# Generate Xcode project from project.yml
generate:
	@echo "Generating Xcode project..."
	@which xcodegen > /dev/null || (echo "Error: xcodegen not found. Install with: brew install xcodegen" && exit 1)
	xcodegen generate
	@echo "Xcode project generated!"

# Build Zylix Core library
core:
	@echo "Building Zylix Core..."
	cd ../../core && zig build ios-sim -Doptimize=ReleaseFast
	mkdir -p Zylix/Libraries
	cp ../../core/zig-out/ios-simulator/libzylix.a Zylix/Libraries/
	@echo "Core library ready!"

core-device:
	@echo "Building Zylix Core for device..."
	cd ../../core && zig build ios -Doptimize=ReleaseFast
	mkdir -p Zylix/Libraries
	cp ../../core/zig-out/ios/libzylix.a Zylix/Libraries/
	@echo "Core library ready!"

# Build for iOS Simulator
build-sim: generate core
	@echo "Building for iOS Simulator..."
	xcodebuild \
		-project Zylix.xcodeproj \
		-scheme Zylix \
		-configuration Debug \
		-sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-derivedDataPath build \
		build
	@echo "Build complete!"

# Build for iOS Device
build-device: generate core-device
	@echo "Building for iOS Device..."
	xcodebuild \
		-project Zylix.xcodeproj \
		-scheme Zylix \
		-configuration Release \
		-sdk iphoneos \
		-destination 'generic/platform=iOS' \
		-derivedDataPath build \
		build
	@echo "Build complete!"

# Alias for device build
build: build-device

# Run on iOS Simulator
run: build-sim
	@echo "Launching on iOS Simulator..."
	@APP_PATH=$$(find build -name "*.app" -type d | head -1); \
	if [ -n "$$APP_PATH" ]; then \
		xcrun simctl boot "iPhone 16" 2>/dev/null || true; \
		xcrun simctl install booted "$$APP_PATH"; \
		xcrun simctl launch booted com.zylix.app; \
		echo "App launched!"; \
	else \
		echo "Error: App not found"; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf build
	rm -rf Zylix/Libraries/libzylix.a
	rm -rf ../../core/zig-out
	rm -rf ../../core/.zig-cache
	@echo "Clean complete!"

# Show help
help:
	@echo "Zylix iOS Build Commands:"
	@echo ""
	@echo "  make generate    - Generate Xcode project from project.yml"
	@echo "  make core        - Build Zylix Core for simulator"
	@echo "  make core-device - Build Zylix Core for device"
	@echo "  make build-sim   - Build for iOS Simulator"
	@echo "  make build       - Build for iOS Device"
	@echo "  make run         - Build and run on iOS Simulator"
	@echo "  make clean       - Remove build artifacts"
	@echo ""
	@echo "Requirements:"
	@echo "  - Xcode Command Line Tools"
	@echo "  - xcodegen (brew install xcodegen)"
	@echo "  - Zig compiler"
