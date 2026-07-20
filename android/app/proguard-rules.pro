# Mina IPTV — Release R8. Dart tarafı için ayrıca: flutter build ... --obfuscate --split-debug-info=...
# https://docs.flutter.dev/deployment/android#enabling-proguard-r8

# ─── Crash / Stack Trace Koruması ────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses,AnnotationDefault

# ─── Flutter Engine & Plugins ─────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Kotlin ──────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ─── Media3 / ExoPlayer (Better Player) ──────────────────────────────────────
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ─── Gson ─────────────────────────────────────────────────────────────────────
-keepattributes Signature
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ─── OkHttp / Okio ────────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ─── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── R8 Optimizasyon İpuçları ─────────────────────────────────────────────────
# Gereksiz null kontrolleri ve assertion'ları kaldır (release'de güvenli).
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static void checkNotNull(...);
    public static void checkExpressionValueIsNotNull(...);
    public static void checkFieldIsNotNull(...);
    public static void checkParameterIsNotNull(...);
    public static void checkReturnedValueIsNotNull(...);
    public static void throwNpe(...);
    public static void throwJavaNpe(...);
    public static void throwUninitializedProperty(...);
    public static void throwUninitializedPropertyAccessException(...);
}

# Android Log çağrılarını kaldır (release'de gizlilik + küçük boyut).
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
