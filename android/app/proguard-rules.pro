# Mina IPTV — Release R8. Dart tarafı için ayrıca: flutter build ... --obfuscate --split-debug-info=...
# https://docs.flutter.dev/deployment/android#enabling-proguard-r8

# Crash / yansıma
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses,AnnotationDefault

# Flutter engine & plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Media3 / ExoPlayer (Better Player)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Gson (bazı bağımlılıklar)
-keepattributes Signature
-keep class com.google.gson.** { *; }

# OkHttp / platform
-dontwarn okhttp3.**
-dontwarn okio.**
