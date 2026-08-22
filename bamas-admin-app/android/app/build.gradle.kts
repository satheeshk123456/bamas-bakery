plugins {
   id("com.google.gms.google-services") version "4.5.0" apply false
   id("com.android.application")
   id("com.google.gms.google-services")
   implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
   implementation("com.google.firebase:firebase-analytics")
}

android {
    namespace = "com.bamasburgerbox.admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (and several other
        // plugins): it uses java.time APIs that don't exist on older
        // Android versions, so they get "desugared" into the APK.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The admin app's permanent identity on Android — deliberately
        // different from the customer app's applicationId
        // (com.bamasburgerbox.app) so both can be installed on the same
        // phone/tablet at the same time. Must match the Android app you
        // register for "Bamas Admin" in the Firebase console.
        applicationId = "com.bamasburgerbox.admin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
