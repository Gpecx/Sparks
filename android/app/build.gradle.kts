import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gpecx.spark"
    // compileSdk 36: os plugins atuais (connectivity_plus, image_picker_android,
    // androidx activity/browser etc.) exigem compilar contra a API 36, senão o
    // checkReleaseAarMetadata falha. compileSdk só afeta a compilação.
    // targetSdk segue em 35 (exigência atual da Play; precisa ser <= compileSdk).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gpecx.spark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val envProperties = Properties()
            val envFile = project.rootProject.file("../.env")
            if (envFile.exists()) {
                envProperties.load(FileInputStream(envFile))
            }

            storeFile = file(envProperties.getProperty("RELEASE_STORE_FILE") ?: "keystore/release.keystore")
            storePassword = envProperties.getProperty("RELEASE_STORE_PASSWORD") ?: ""
            keyAlias = envProperties.getProperty("RELEASE_KEY_ALIAS") ?: ""
            keyPassword = envProperties.getProperty("RELEASE_KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
