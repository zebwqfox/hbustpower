import java.util.Properties

// Release signing comes from keystore.properties, which stays out of version control.
// See ../filing/签名与指纹.md for how to create the keystore and read its fingerprints.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// The school app key stays out of version control. scripts/secrets.sh apply writes secrets.properties;
// without it the build still works and the app reports that it is not configured.
val secretProperties = Properties().apply {
    val file = rootProject.file("secrets.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val schoolAppKey: String = secretProperties.getProperty("schoolAppKey") ?: ""

// Where the app looks for the version/notice file, and which hosts it will hand a download link to.
// Both are public values, so they live in gradle.properties and can be overridden per build with -P.
// Leaving cloudConfigUrl empty compiles the whole cloud-config feature out: no requests, no UI.
fun buildValue(name: String): String =
    (providers.gradleProperty(name).orNull ?: secretProperties.getProperty(name) ?: "").trim()

val cloudConfigUrl: String = buildValue("cloudConfigUrl")
val cloudDownloadHosts: String = buildValue("cloudDownloadHosts")
val telemetryUrl: String = buildValue("telemetryUrl")
require(telemetryUrl.isEmpty() || telemetryUrl.startsWith("https://")) {
    "telemetryUrl must be https:// (got: $telemetryUrl)"
}
require(cloudConfigUrl.isEmpty() || cloudConfigUrl.startsWith("https://")) {
    "cloudConfigUrl must be https:// so the config cannot be rewritten in transit (got: $cloudConfigUrl)"
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.zebwqfox.hbustpower"
    compileSdk {
        version = release(37) {
            minorApiLevel = 0
        }
    }

    defaultConfig {
        buildConfigField("String", "SCHOOL_APP_KEY", "\"$schoolAppKey\"")
        buildConfigField("String", "CLOUD_CONFIG_URL", "\"$cloudConfigUrl\"")
        buildConfigField("String", "CLOUD_DOWNLOAD_HOSTS", "\"$cloudDownloadHosts\"")
        buildConfigField("String", "TELEMETRY_URL", "\"$telemetryUrl\"")
        applicationId = "com.zebwqfox.hbustpower"
        if (providers.gradleProperty("isolatedVerification").isPresent) applicationIdSuffix = ".verification"
        minSdk = 23
        targetSdk = 36
        versionCode = 195
        versionName = "1.9.5"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables.useSupportLibrary = true
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            // The production keystore when keystore.properties exists, otherwise a debug-signed
            // staging build that must never be published.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.window:window:1.5.0")
    implementation("androidx.core:core-ktx:1.19.0")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")

    implementation("androidx.compose.ui:ui:1.12.0")
    implementation("androidx.compose.ui:ui-tooling-preview:1.12.0")
    implementation("androidx.compose.foundation:foundation:1.12.0")
    implementation("androidx.compose.animation:animation:1.12.0")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")

    implementation("io.github.kyant0:backdrop:2.0.1")
    implementation("io.github.kyant0:shapes:1.2.1")
    implementation("org.jsoup:jsoup:1.21.2")

    debugImplementation("androidx.compose.ui:ui-tooling:1.12.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest:1.12.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.4.10")
    // android.jar's org.json is stubbed out for JVM tests; this puts the real implementation on the test path.
    testImplementation("org.json:json:20250107")
    // Reads fixtures/expected-1.7.1.json, the parser and insights contract generated from the iOS code.
    testImplementation("com.google.code.gson:gson:2.11.0")
}
