import java.io.File
import java.io.FileInputStream
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase: google-services.json'dan kaynak (ör. default_web_client_id) üretir.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/// Flutter’ın beklediği biçim: her `--dart-define` UTF-8 + Base64, virgülle birleşik.
fun encodeDartDefineSegment(def: String): String =
    Base64.getEncoder().encodeToString(def.toByteArray(StandardCharsets.UTF_8))

/// `tool/secrets/play_integrity.env` → [IntegrityService] için derleme zamanı define’ları.
fun readPlayIntegrityDartDefineSegments(repoRoot: File): List<String> {
    val env = File(repoRoot, "tool/secrets/play_integrity.env")
    if (!env.isFile) return emptyList()
    val segments = mutableListOf<String>()
    env.readLines().forEach { line ->
        val t = line.trim()
        if (t.isEmpty() || t.startsWith("#")) return@forEach
        val eq = t.indexOf('=')
        if (eq <= 0) return@forEach
        val k = t.substring(0, eq).trim()
        var v = t.substring(eq + 1).trim()
        if (v.length >= 2) {
            val a = v.first()
            val b = v.last()
            if ((a == '"' && b == '"') || (a == '\'' && b == '\'')) {
                v = v.substring(1, v.length - 1)
            }
        }
        val pair = when (k) {
            "PLAY_INTEGRITY_API_KEY", "INTEGRITY_CLOUD_PROJECT_NUMBER", "INTEGRITY_DEBUG_LOG" ->
                if (v.isNotEmpty()) "$k=$v" else null
            else -> null
        } ?: return@forEach
        segments.add(encodeDartDefineSegment(pair))
    }
    return segments
}

val repoRootForSecrets = rootProject.projectDir.parentFile
val playIntegrityDartSegments = readPlayIntegrityDartDefineSegments(repoRootForSecrets)
if (playIntegrityDartSegments.isNotEmpty()) {
    val existingDartDefines = findProperty("dart-defines")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
    val mergedDartDefines = buildString {
        if (!existingDartDefines.isNullOrEmpty()) {
            append(existingDartDefines)
            append(",")
        }
        append(playIntegrityDartSegments.joinToString(","))
    }
    extra["dart-defines"] = mergedDartDefines
    logger.lifecycle(
        "Mina IPTV: Play Integrity — ${playIntegrityDartSegments.size} dart-define play_integrity.env üzerinden derlemeye eklendi.",
    )
} else {
    val envFile = File(repoRootForSecrets, "tool/secrets/play_integrity.env")
    if (envFile.isFile) {
        logger.warn(
            "Mina IPTV: tool/secrets/play_integrity.env var ama kullanılabilir anahtar yok (PLAY_INTEGRITY_API_KEY boş olabilir).",
        )
    }
}

// Video: `better_player` → Android’de ExoPlayer2 (texture / SurfaceTexture).
// Gerçek SurfaceView için paket fork veya PlatformView gerekir; bu sürümde yok.

android {
    namespace = "com.mina.iptv.mina_iptv_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseKeystore = keystorePropertiesFile.exists()
    if (hasReleaseKeystore) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mina.iptv.mina_iptv_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth / Firestore en az API 23 (Android 6) gerektirir, ancak uygulama en az API 26 (Android 8) destekler.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8: Kotlin/Java sınıf isimleri küçültülür. Dart obfuscation ayrıca flutter build ile.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        resources {
            pickFirsts.add("lib/**/libc++_shared.so")
        }
        jniLibs {
            // androidx/media3 decoder_ffmpeg AAR eklendiğinde çakışmayı önler.
            pickFirsts.add("lib/**/libffmpegJNI.so")
            // x86 / x86_64 yalnızca emülatörler içindir; gerçek telefon ve TV
            // box'ların tamamı ARM. Flutter'ın `ndk.abiFilters`'ı evrensel APK
            // paketlemesinde dikkate almadığı eklenti native kütüphanelerini
            // (ör. x86_64 libmpv ~15.8 MB) burada paketleme aşamasında zorla
            // dışlıyoruz. Hem APK hem AAB için, derleme bayrağından bağımsız.
            excludes += listOf("**/x86/**", "**/x86_64/**")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Android 15 edge-to-edge: MainActivity’de [enableEdgeToEdge].
    implementation("androidx.activity:activity-ktx:1.10.1")
    // HLS master + WEBVTT altyazı track’leri için Media3 HLS modülü zorunlu.
    // better_player_plus bunu transitif taşır; sürümü hizalayıp APK’da kesin bulunmasını sağlar.
    implementation("androidx.media3:media3-exoplayer-hls:1.8.0")
    // Media3 FFmpeg uzantısı (Maven’da yok). Plugin library’de local AAR AGP’yi
    // kırdığı için APK runtime’ına burada eklenir.
    listOf(
        file("../../packages/better_player_plus/android/third_party/decoder_ffmpeg/lib-decoder-ffmpeg-release.aar"),
        file("../../packages/better_player_plus/android/third_party/decoder_ffmpeg/decoder-ffmpeg-release.aar"),
    ).firstOrNull { it.isFile }?.let { aar ->
        implementation(files(aar))
    }
}
