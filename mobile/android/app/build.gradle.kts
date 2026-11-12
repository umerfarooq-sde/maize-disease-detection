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
val isProductionReleaseRequested = gradle.startParameter.taskNames.any { task ->
    val lower = task.lowercase()
    val isRelease = lower.contains("release")
    val isProduction = lower.contains("production")
    val isGenericRelease = (lower == "assemblerelease" || lower.endsWith(":assemblerelease") ||
                           lower == "bundlerelease" || lower.endsWith(":bundlerelease"))
    isRelease && (isProduction || isGenericRelease)
}
if (isProductionReleaseRequested && !signingAvailable && !verificationOnly) {
    throw GradleException("Release signing is required. Unsigned verification requires the explicit allowUnsignedVerification property and is not distributable.")
}

gradle.taskGraph.whenReady {
    val packagesProductionRelease = allTasks.any { task ->
        val name = task.name
        name.equals("packageProductionRelease", ignoreCase = true) ||
        name.equals("assembleProductionRelease", ignoreCase = true) ||
        name.equals("bundleProductionRelease", ignoreCase = true)
    }
    if (packagesProductionRelease && !signingAvailable && !verificationOnly) {
        throw GradleException("Release signing is required. Unsigned verification requires the explicit allowUnsignedVerification property and is not distributable.")
    }
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

    signingConfigs {
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
        }
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

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "MAIZEDOCTOR Staging")
            signingConfig = signingConfigs.getByName("debug")
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "MAIZEDOCTOR")
            signingConfig = if (signingAvailable) signingConfigs.getByName("externalRelease") else null
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
