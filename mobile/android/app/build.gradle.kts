import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from a properties file that lives OUTSIDE Git
// (default: ~/.ternava/release-signing.properties, override with
// TERNAVA_SIGNING_PROPERTIES). The file holds the keystore path and the four
// credential keys; none of them are ever committed. When the file is absent the
// release build still assembles but stays UNSIGNED, so CI can compile without
// the secret and only the release job (which injects the file) produces a
// signed artifact. This is why ops/release.sh verifies the signature: an
// unsigned APK must never be published.
val signingPropertiesFile: File? = run {
    val explicit = System.getenv("TERNAVA_SIGNING_PROPERTIES")
    val candidates = listOfNotNull(
        explicit?.let { File(it) },
        File(System.getProperty("user.home"), ".ternava/release-signing.properties"),
    )
    candidates.firstOrNull { it.isFile }
}

val signingProperties = Properties().apply {
    signingPropertiesFile?.inputStream()?.use { load(it) }
}

val hasReleaseSigning = signingPropertiesFile != null &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !signingProperties.getProperty(it).isNullOrBlank()
    }

android {
    namespace = "com.ternava.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ternava.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = File(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Only attach a signing config when real release credentials exist.
            // Otherwise the APK is built unsigned and ops/release.sh refuses to
            // publish it (AC-42: no debug key may sign a release).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
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
