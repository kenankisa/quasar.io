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

/** AdMob App ID: env → dart_defines*.json → Google test ID (yalnızca geliştirme). */
fun resolveAdMobAppId(): String {
    System.getenv("ANDROID_ADMOB_APP_ID")?.trim()?.takeIf { it.isNotEmpty() }?.let {
        return it
    }
    (project.findProperty("ANDROID_ADMOB_APP_ID") as String?)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.let { return it }

    val defineFiles = listOf(
        rootProject.file("../dart_defines.prod.json"),
        rootProject.file("../dart_defines.dev.json"),
        rootProject.file("../dart_defines.dev.json.example"),
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
            if (value.isNotEmpty()) return value
        } catch (_: Exception) {
            // ignore malformed define files
        }
    }
    return "ca-app-pub-3940256099942544~3347511713"
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
        create("release") {
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
                    "Quasar.io: release build still uses the AdMob TEST app id. " +
                        "Set ANDROID_ADMOB_APP_ID in dart_defines.prod.json before store release.",
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
