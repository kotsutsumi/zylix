---
title: Android Tutorial
weight: 3
---

## Overview

Build the Zylix demo app with Jetpack Compose and JNI on Android.

## Prerequisites

- Android Studio
- Android SDK (API 26+)
- Android NDK r25+

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build the Zig Core (Android ABIs)

```bash
cd core
zig build android -Doptimize=ReleaseFast
```

## 3. Copy the Libraries

```bash
cp zig-out/android/arm64-v8a/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/arm64-v8a/
cp zig-out/android/armeabi-v7a/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/armeabi-v7a/
cp zig-out/android/x86_64/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/x86_64/
cp zig-out/android/x86/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/x86/
```

## 4. Build and Run

```bash
cd ../platforms/android
./gradlew installDebug
```

## 5. Confirm State Updates

Open the app and use the counter controls. State updates should be immediate.

Key files:

- `platforms/android/app/src/main/java/com/zylix/app/ZylixBridge.kt` (JNI bridge)
- `platforms/android/app/src/main/java/com/zylix/app/ui/CounterScreen.kt` (Compose UI)

## Troubleshooting

- Missing .so: confirm `core/zig-out/android/` outputs exist.
- NDK not found: set `ANDROID_NDK_HOME` or install via SDK Manager.

## Next Steps

- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
- [ABI Spec](/docs/ABI.md)
