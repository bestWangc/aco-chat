import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val androidApplicationId = providers.gradleProperty("acoApplicationId").orNull
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?: "com.kzparty.chat.aca.cac"

val aliyunLicenseProperties = Properties()
val aliyunLicensePropertiesFile = rootProject.file("../aliyun_license/android/android.properties")
if (aliyunLicensePropertiesFile.exists()) {
    aliyunLicensePropertiesFile.inputStream().use(aliyunLicenseProperties::load)
}
val aliyunLicenseKey = aliyunLicenseProperties.getProperty("licenseKey", "").trim()
val aliyunLicenseDirectory = rootProject.file("../aliyun_license/android")
val generatedAliyunLicenseAssets = layout.buildDirectory.dir("generated/aliyunLicenseAssets")
val copyAliyunLicense = tasks.register<Copy>("copyAliyunLicense") {
    val certificates = aliyunLicenseDirectory.listFiles()
        ?.filter { it.isFile && it.name.startsWith("AliVideoCert-") && it.extension == "crt" }
        .orEmpty()
    if (certificates.size == 1) {
        from(certificates.single())
        into(generatedAliyunLicenseAssets.map { it.dir("cert") })
        rename { "AliVideoCert.crt" }
    }
}

android {
    namespace = "com.aco.aco_chat"
    // Keep the app aligned with the newest Android API required by plugins.
    compileSdk = 37
    buildToolsVersion = "36.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = androidApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["aliyunLicenseKey"] = aliyunLicenseKey
    }

    sourceSets.getByName("main").assets.srcDir(generatedAliyunLicenseAssets)

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug").apply {
                isV1SigningEnabled = true
                isV2SigningEnabled = true
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(copyAliyunLicense)
}

kotlin {
  compilerOptions {
    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
  }
}

dependencies {
    implementation("androidx.biometric:biometric:1.1.0")
}

flutter {
    source = "../.."
}
