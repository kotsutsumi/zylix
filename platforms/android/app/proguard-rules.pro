# Zylix Android ProGuard Rules

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep ZylixBridge
-keep class com.zylix.app.ZylixBridge {
    *;
}

# Keep Compose
-dontwarn androidx.compose.**
