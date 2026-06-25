plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cz.syky.redtick.redtick"
    compileSdk = flutter.compileSdkVersion
    // Pinned to match native/android/build-deps.sh and the CI NDK install so the
    // cross-built deps and the core are compiled with the same NDK/libc++.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cz.syky.redtick.redtick"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24) // core deps target API 24+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Build the C++ core (FP-11) per ABI via CMake. The native deps
        // (OpenSSL/Poco/jsoncpp) must be cross-built first with
        // native/android/build-deps.sh into native/android/.deps-prefix/<abi>.
        externalNativeBuild {
            cmake {
                arguments(
                    "-DREDTICK_DEPS_ROOT=${projectDir}/../../native/android/.deps-prefix",
                )
            }
        }
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
