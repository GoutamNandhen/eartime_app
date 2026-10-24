plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = listOf("EARTIME_KEYSTORE_PATH", "EARTIME_KEYSTORE_PASSWORD", "EARTIME_KEY_ALIAS", "EARTIME_KEY_PASSWORD")
    .associateWith { providers.environmentVariable(it).orNull }
val releaseSigningAvailable = signingValues.values.all { !it.isNullOrBlank() }
val checkReleaseSigning by tasks.registering {
    doLast {
        check(releaseSigningAvailable) { "Release signing is not configured. Supply the four EARTIME signing environment variables; debug signing is never used for release." }
        check(file(signingValues.getValue("EARTIME_KEYSTORE_PATH")!!).isFile) { "The configured release keystore is unavailable." }
    }
}

android {
    namespace = "com.eartime.eartime_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
    sourceSets.getByName("test").resources.srcDir("../../test/fixtures")

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eartime.eartime_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningAvailable) create("production") {
            storeFile = file(signingValues.getValue("EARTIME_KEYSTORE_PATH")!!)
            storePassword = signingValues.getValue("EARTIME_KEYSTORE_PASSWORD")
            keyAlias = signingValues.getValue("EARTIME_KEY_ALIAS")
            keyPassword = signingValues.getValue("EARTIME_KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("production")
        }
    }
}

tasks.configureEach {
    if (name in setOf("packageRelease", "bundleRelease", "signReleaseBundle")) dependsOn(checkReleaseSigning)
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}
