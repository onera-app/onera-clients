import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

// Load local.properties for secrets (Supabase keys, API URL, keystore)
val localProperties = Properties().apply {
    val localPropsFile = rootProject.file("local.properties")
    if (localPropsFile.exists()) {
        FileInputStream(localPropsFile).use { load(it) }
    }
}

// Version management: read from environment (CI) or default
val appVersionCode = System.getenv("VERSION_CODE")?.toIntOrNull()
    ?: localProperties.getProperty("VERSION_CODE")?.toIntOrNull()
    ?: 1
val appVersionName = System.getenv("VERSION_NAME")
    ?: localProperties.getProperty("VERSION_NAME")
    ?: "1.0.0"

android {
    namespace = "chat.onera.mobile"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    defaultConfig {
        applicationId = "chat.onera.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = appVersionCode
        versionName = appVersionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        // Build config for API URLs and auth
        buildConfigField("String", "API_BASE_URL", "\"${localProperties.getProperty("API_BASE_URL") ?: System.getenv("API_BASE_URL") ?: "https://api.onera.chat/"}\"")
        buildConfigField("String", "SUPABASE_URL", "\"${localProperties.getProperty("SUPABASE_URL") ?: System.getenv("SUPABASE_URL") ?: "MISSING_URL"}\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"${localProperties.getProperty("SUPABASE_PUBLISHABLE_KEY") ?: System.getenv("SUPABASE_PUBLISHABLE_KEY") ?: "MISSING_KEY"}\"")
    }

    signingConfigs {
        // Release signing: reads from environment (CI) or local.properties (dev)
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_FILE")
                ?: localProperties.getProperty("KEYSTORE_FILE")
            val keystorePass = System.getenv("KEYSTORE_PASSWORD")
                ?: localProperties.getProperty("KEYSTORE_PASSWORD")
            val keyAliasName = System.getenv("KEY_ALIAS")
                ?: localProperties.getProperty("KEY_ALIAS")
                ?: "onera-upload"
            val keyPass = System.getenv("KEY_PASSWORD")
                ?: localProperties.getProperty("KEY_PASSWORD")

            if (keystorePath != null && keystorePass != null && keyPass != null) {
                storeFile = file(keystorePath)
                storePassword = keystorePass
                keyAlias = keyAliasName
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        debug {
            // Debug uses staging API by default (override in local.properties)
            buildConfigField("String", "API_BASE_URL", "\"${localProperties.getProperty("API_BASE_URL") ?: System.getenv("API_BASE_URL") ?: "https://api-stage.onera.chat/"}\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Production API for release builds
            buildConfigField("String", "API_BASE_URL", "\"${System.getenv("API_BASE_URL") ?: "https://api.onera.chat/"}\"")
            buildConfigField("String", "SUPABASE_URL", "\"${System.getenv("SUPABASE_URL_PROD") ?: localProperties.getProperty("SUPABASE_URL_PROD") ?: localProperties.getProperty("SUPABASE_URL") ?: "MISSING_URL"}\"")
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"${System.getenv("SUPABASE_PUBLISHABLE_KEY_PROD") ?: localProperties.getProperty("SUPABASE_PUBLISHABLE_KEY_PROD") ?: localProperties.getProperty("SUPABASE_PUBLISHABLE_KEY") ?: "MISSING_KEY"}\"")

            // Use release signing if available, otherwise fall back to debug
            signingConfig = try {
                val releaseSigning = signingConfigs.getByName("release")
                if (releaseSigning.storeFile != null) releaseSigning else signingConfigs.getByName("debug")
            } catch (_: Exception) {
                signingConfigs.getByName("debug")
            }
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = "17"
    }
    
    buildFeatures {
        compose = true
        buildConfig = true
    }
    
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
    }
}

dependencies {
    // Core
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.appcompat)
    
    // Compose
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    
    // Navigation
    implementation(libs.androidx.navigation.compose)
    
    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    
    // Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.kotlinx)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    
    // Crypto - libsodium for XSalsa20-Poly1305 (compatible with web)
    implementation("com.goterl:lazysodium-android:5.1.0@aar")
    implementation("net.java.dev.jna:jna:5.14.0@aar")
    
    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    
    // DataStore & Security
    implementation(libs.datastore.preferences)
    implementation(libs.security.crypto)
    implementation(libs.biometric)
    
    // Credentials (Passkeys)
    implementation(libs.credentials)
    implementation(libs.credentials.play.services)
    
    // Coroutines
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.coroutines.core)
    
    // Serialization
    implementation(libs.kotlinx.serialization.json)
    
    // Supabase Authentication
    implementation(libs.supabase.auth)
    implementation(libs.supabase.compose.auth)
    implementation(libs.ktor.client.android)
    
    // Image Loading
    implementation(libs.coil.compose)
    
    // Markdown Rendering
    implementation(libs.markdown.renderer)
    implementation(libs.markdown.renderer.coil)
    
    // Logging
    implementation(libs.timber)
    
    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
