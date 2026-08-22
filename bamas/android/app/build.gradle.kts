plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
    id("com.android.application")
    id("com.google.gms.google-services")
    implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
    implementation("com.google.firebase:firebase-analytics")
}

android {
    namespace = "com.example.bamas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (and several other
        // plugins): it uses java.time APIs that don't exist on older
        // Android versions, so they get "desugared" into the APK.
        // Without this the build fails at :app:checkReleaseAarMetadata.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The app's permanent identity on Android. Changed off the default
        // "com.example.*" before first release — this must never change
        // afterwards, and it must match the package name you register in
        // the Firebase console when you run `flutterfire configure`.
        applicationId = "com.bamasburgerbox.app"
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
    // The desugaring support library itself. Version must be 2.1.4+ for
    // flutter_local_notifications 18.x.
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
