plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Meta SDK client token: root .env (META_CLIENT_TOKEN=...), then
// android/local.properties (meta.clientToken), then the environment (CI).
// Never committed, never logged.
val metaClientToken: String = run {
    val envFile = rootProject.file("../.env")
    val fromEnvFile = if (envFile.exists()) {
        envFile.readLines()
            .firstOrNull { it.startsWith("META_CLIENT_TOKEN=") }
            ?.substringAfter("=")?.trim()?.trim('"', '\'')
    } else null
    val localProps = Properties()
    val localFile = rootProject.file("local.properties")
    if (localFile.exists()) FileInputStream(localFile).use { localProps.load(it) }
    listOf(fromEnvFile, localProps.getProperty("meta.clientToken"), System.getenv("META_CLIENT_TOKEN"))
        .firstOrNull { !it.isNullOrBlank() } ?: ""
}

android {
    namespace = "com.finaltable.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.finaltable.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // purchases_flutter 9.x (Play Billing 8) requires API 23+;
        // flutter.minSdkVersion is 24 on Flutter 3.38, so delegation is safe.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "facebook_client_token", metaClientToken)
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Release builds must carry the Meta client token; debug only warns.
gradle.taskGraph.whenReady {
    val isRelease = allTasks.any { it.name.contains("Release", ignoreCase = true) && it.project == project }
    if (metaClientToken.isEmpty()) {
        if (isRelease) {
            throw GradleException(
                "META_CLIENT_TOKEN is missing. Add META_CLIENT_TOKEN=... to the repo-root .env " +
                    "(or meta.clientToken to android/local.properties) before building a release."
            )
        } else {
            logger.warn("WARNING: META_CLIENT_TOKEN missing; Meta SDK client token is empty (debug build).")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
