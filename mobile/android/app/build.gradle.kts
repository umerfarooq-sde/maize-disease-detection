plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyNames = listOf("MAIZEDOCTOR_KEYSTORE_FILE", "MAIZEDOCTOR_KEYSTORE_PASSWORD", "MAIZEDOCTOR_KEY_ALIAS", "MAIZEDOCTOR_KEY_PASSWORD")
val releaseKeys = releaseKeyNames.map { System.getenv(it)?.takeIf(String::isNotBlank) }
val signingAvailable = releaseKeys.all { it != null }
if (releaseKeys.any { it != null } && !signingAvailable) {
    throw GradleException("Supply all four external release signing settings together.")
}
val verificationOnly = providers.gradleProperty("allowUnsignedVerification").orNull == "true" || System.getenv("MAIZEDOCTOR_UNSIGNED_VERIFICATION") == "true"
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !signingAvailable && !verificationOnly) {
    throw GradleException("Release signing is required. Unsigned verification requires the explicit allowUnsignedVerification property and is not distributable.")
}

android {
    namespace = "com.maizedoctor.maizedoctor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.maizedoctor.maizedoctor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "MAIZEDOCTOR Staging")
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "MAIZEDOCTOR")
        }
    }
    signingConfigs {
        if (signingAvailable) {
            create("externalRelease") {
                storeFile = file(releaseKeys[0]!!)
                storePassword = releaseKeys[1]
                keyAlias = releaseKeys[2]
                keyPassword = releaseKeys[3]
                enableV1Signing = false
                enableV2Signing = true
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (signingAvailable) signingConfigs.getByName("externalRelease") else null
        }
    }
}

flutter {
    source = "../.."
}
