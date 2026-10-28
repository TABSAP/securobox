import java.util.Properties
import java.io.FileInputStream

val releaseKeyPropertiesFile = rootProject.file("key.properties")
val validateProductionSigning = tasks.register("validateProductionSigning") {
    doLast {
        if (!releaseKeyPropertiesFile.isFile) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties from android/key.properties.example and add the upload keystore before building a release."
            )
        }
        val properties = Properties().apply {
            load(FileInputStream(releaseKeyPropertiesFile))
        }
        val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
        val missingKeys = requiredKeys.filter { properties.getProperty(it).isNullOrBlank() }
        if (missingKeys.isNotEmpty()) {
            throw GradleException(
                "Release signing is incomplete. Missing key properties: ${missingKeys.joinToString()}."
            )
        }
        if (!file(properties.getProperty("storeFile")).isFile) {
            throw GradleException("The release upload keystore file does not exist.")
        }
        val adMobAppId = properties.getProperty("admobAppId")
            ?: project.findProperty("ADMOB_APP_ID")?.toString()
        if (adMobAppId.isNullOrBlank() || adMobAppId.contains("3940256099942544")) {
            throw GradleException(
                "Production AdMob is not configured. Set admobAppId in android/key.properties to your production AdMob app ID."
            )
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease") {
        dependsOn(validateProductionSigning)
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.securobox.vault"
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
        applicationId = "app.securobox.vault"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = project.findProperty("ADMOB_APP_ID")
            ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("release") {
            if (releaseKeyPropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(releaseKeyPropertiesFile))
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            if (releaseKeyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(releaseKeyPropertiesFile))
                manifestPlaceholders["admobAppId"] = keystoreProperties.getProperty("admobAppId")
                    ?: project.findProperty("ADMOB_APP_ID")
                    ?: ""
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
