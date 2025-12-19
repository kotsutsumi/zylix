# Zylix Android Build Commands
# CLI builds without Android Studio

.PHONY: all clean build build-debug build-release install setup core

# Default target
all: build-debug

# Setup Gradle wrapper (run once)
setup:
	@echo "Setting up Gradle wrapper..."
	gradle wrapper --gradle-version 8.5

# Build Zylix Core for Android targets
core:
	@echo "Building Zylix Core for Android..."
	cd ../../core && zig build android-arm64 -Doptimize=ReleaseFast
	cd ../../core && zig build android-x64 -Doptimize=ReleaseFast
	@echo "Copying libraries..."
	mkdir -p app/src/main/jniLibs/arm64-v8a
	mkdir -p app/src/main/jniLibs/x86_64
	cp ../../core/zig-out/android-arm64/libzylix.a app/src/main/jniLibs/arm64-v8a/
	cp ../../core/zig-out/android-x64/libzylix.a app/src/main/jniLibs/x86_64/
	@echo "Done!"

# Debug build
build-debug: core
	@echo "Building debug APK..."
	./gradlew assembleDebug
	@echo "APK: app/build/outputs/apk/debug/app-debug.apk"

# Release build
build-release: core
	@echo "Building release APK..."
	./gradlew assembleRelease
	@echo "APK: app/build/outputs/apk/release/app-release-unsigned.apk"

# Shorthand
build: build-debug

# Install on connected device
install: build-debug
	@echo "Installing on device..."
	./gradlew installDebug
	@echo "Done! Launch Zylix on your device."

# Clean build artifacts
clean:
	@echo "Cleaning..."
	./gradlew clean
	rm -rf app/src/main/jniLibs/arm64-v8a/libzylix.a
	rm -rf app/src/main/jniLibs/x86_64/libzylix.a
	@echo "Clean complete."

# Run tests
test:
	./gradlew test

# Lint check
lint:
	./gradlew lint
