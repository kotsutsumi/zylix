---
title: Android チュートリアル
weight: 3
---

## 概要

Jetpack Compose と JNI で Zylix デモアプリを Android で動かします。

## 前提条件

- Android Studio
- Android SDK (API 26+)
- Android NDK r25+

## 1. リポジトリを取得

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Zig コアをビルド（Android ABIs）

```bash
cd core
zig build android -Doptimize=ReleaseFast
```

## 3. ライブラリをコピー

```bash
cp zig-out/android/arm64-v8a/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/arm64-v8a/
cp zig-out/android/armeabi-v7a/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/armeabi-v7a/
cp zig-out/android/x86_64/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/x86_64/
cp zig-out/android/x86/libzylix.so ../platforms/android/zylix-android/src/main/jniLibs/x86/
```

## 4. ビルド＆実行

```bash
cd ../platforms/android
./gradlew installDebug
```

## 5. 状態更新を確認

アプリを開き、カウンター操作で即時に更新されることを確認します。

主なファイル:

- `platforms/android/app/src/main/java/com/zylix/app/ZylixBridge.kt`（JNI ブリッジ）
- `platforms/android/app/src/main/java/com/zylix/app/ui/CounterScreen.kt`（Compose UI）

## トラブルシューティング

- .so が無い: `core/zig-out/android/` を確認。
- NDK が見つからない: SDK Manager で導入、または `ANDROID_NDK_HOME` を設定。

## 次のステップ

- [状態管理](/docs/core-concepts/state-management/)
- [イベント](/docs/core-concepts/events/)
- [ABI 仕様](/docs/ABI.md)
