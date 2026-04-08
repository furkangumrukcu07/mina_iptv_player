import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Video: `better_player` → Android’de ExoPlayer2 (texture / SurfaceTexture).
// Gerçek SurfaceView için paket fork veya PlatformView gerekir; bu sürümde yok.

android {
    namespace = "com.mina.iptv.mina_iptv_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    compileOptions {
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        resources {
            pickFirsts.add("lib/**/libc++_shared.so")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // HLS master + WEBVTT altyazı track’leri için Media3 HLS modülü zorunlu.
    // better_player_plus bunu transitif taşır; sürümü hizalayıp APK’da kesin bulunmasını sağlar.
    implementation("androidx.media3:media3-exoplayer-hls:1.8.0")
}
