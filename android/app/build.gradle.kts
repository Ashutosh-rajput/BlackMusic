plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.muskmelon.blackmusic"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.muskmelon.blackmusic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    sourceSets {
        getByName("release").jniLibs.srcDir(
            layout.buildDirectory.dir("generated/flutterJniLibs/release").get().asFile,
        )
    }
}

// AGP 9 does not currently pick up Flutter's AOT output automatically. The
// Flutter build writes `app.so` for each ABI, while Android packages native
// libraries only when they are named `lib*.so`. Stage those files alongside
// Flutter's native assets before the release APK is assembled.
val stageFlutterReleaseJniLibs by tasks.registering(Copy::class) {
    dependsOn(tasks.named("compileFlutterBuildRelease"))
    from(layout.buildDirectory.dir("intermediates/flutter/release")) {
        include("*/app.so")
        eachFile {
            name = "libapp.so"
        }
        includeEmptyDirs = false
    }
    into(layout.buildDirectory.dir("generated/flutterJniLibs/release"))
}

tasks.matching {
    it.name == "mergeReleaseJniLibFolders" || it.name == "mergeReleaseNativeLibs"
}.configureEach {
    dependsOn(stageFlutterReleaseJniLibs)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
