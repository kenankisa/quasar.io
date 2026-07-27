import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

/** Google sample App ID — safe for sideload / internal APKs (not Play Store). */
val googleTestAdMobAppId = "ca-app-pub-3940256099942544~3347511713"

/**
 * Reject placeholders like ca-app-pub-XXXXXXXX… — MobileAdsInitProvider
 * hard-crashes the process on launch when APPLICATION_ID is invalid.
 */
fun isValidAdMobAppId(value: String): Boolean {
    val v = value.trim()
    if (v.isEmpty()) return false
    if (v.contains("XXXXXXXX", ignoreCase = true)) return false
    if (v.contains("YYYYYYYY", ignoreCase = true)) return false
    if (v.contains("YOUR_", ignoreCase = true)) return false
    if (v.contains("placeholder", ignoreCase = true)) return false
    return Regex("""^ca-app-pub-\d{16}~\d{10}$""").matches(v)
}

/** AdMob App ID: env → dart_defines*.json → Google test ID (yalnızca geliştirme). */
fun resolveAdMobAppId(): String {
    System.getenv("ANDROID_ADMOB_APP_ID")?.trim()?.takeIf { isValidAdMobAppId(it) }?.let {
        return it
    }
    (project.findProperty("ANDROID_ADMOB_APP_ID") as String?)
        ?.trim()
        ?.takeIf { isValidAdMobAppId(it) }
        ?.let { return it }

    // Prefer real prod IDs when present; skip invalid placeholders so a
    // half-filled dart_defines.prod.json cannot kill every release APK.
    val defineFiles = listOf(
        rootProject.file("../dart_defines.prod.json"),
        rootProject.file("../dart_defines.dev.json"),
        rootProject.file("../dart_defines.dev.json.example"),
        rootProject.file("../dart_defines.prod.json.example"),
    )
    val keyPattern = Regex("\"ANDROID_ADMOB_APP_ID\"\\s*:\\s*\"([^\"]+)\"")
    for (file in defineFiles) {
        if (!file.exists()) continue
        try {
            val value = keyPattern.find(file.readText())
                ?.groupValues
                ?.getOrNull(1)
                ?.trim()
                .orEmpty()
            if (isValidAdMobAppId(value)) return value
            if (value.isNotEmpty()) {
                logger.warn(
                    "Quasar.io: ignoring invalid ANDROID_ADMOB_APP_ID in ${file.name}: $value",
                )
            }
        } catch (_: Exception) {
            // ignore malformed define files
        }
    }
    return googleTestAdMobAppId
}

val adMobAppId: String = resolveAdMobAppId()

android {
    namespace = "com.example.quasar_io"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.quasar_io"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["adMobAppId"] = adMobAppId
    }

    signingConfigs {
        // Some OEM installers reject v2-only APKs with "file is corrupt / dosyada hata".
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
        }
        create("release") {
            enableV1Signing = true
            enableV2Signing = true
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 minify caused startup crashes on some devices (Google Ads / JNI plugins).
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (adMobAppId.contains("3940256099942544")) {
                logger.warn(
                    "Quasar.io: release build uses AdMob TEST app id. " +
                        "OK for internal APKs — set a real ANDROID_ADMOB_APP_ID in " +
                        "dart_defines.prod.json before Play Store.",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
