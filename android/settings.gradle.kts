pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = file("local.properties")
        var sdkPath: String? = null
        if (propertiesFile.exists()) {
            propertiesFile.inputStream().use { properties.load(it) }
            sdkPath = properties.getProperty("flutter.sdk")
        }
        if (sdkPath == null) {
            sdkPath = System.getenv("FLUTTER_ROOT")
        }
        require(sdkPath != null) { "Flutter SDK not found. Define location with flutter.sdk in local.properties or with FLUTTER_ROOT env variable." }
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
