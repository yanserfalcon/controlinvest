plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.invest_tracker"
    compileSdk = flutter.compileSdkVersion // Mantenemos la versión de Flutter
    ndkVersion = flutter.ndkVersion
    // Eliminamos la línea conflictiva 'compileSdkVersion = 34'
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.invest_tracker"
        
        // CORRECCIÓN CLAVE: Usamos la sintaxis de llamada a función para las SDKs
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion 
        
        // También usamos la sintaxis de llamada a función para las versiones
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}