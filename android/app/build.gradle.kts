plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.simulated_app"
    // Volvemos a 34 o 35, que son estables. No uses 36 todavía.
    compileSdk = 36

    // Elimina la línea ndkVersion si no tienes la 27 instalada específicamente,
    // o usa la versión por defecto estable de tu Android Studio.
    // ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.simulated_app"
        minSdk = 24
        targetSdk = 35 // Coincide con compileSdk
        versionCode = 1
        versionName = "1.0.0"

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // MANTÉN ESTO: Es vital para que no se eliminen las librerías de TFLite al compilar
    packaging {
        jniLibs {
            pickFirsts += setOf(
                "lib/*/libtensorflowlite_jni.so",
                "lib/*/libtensorflowlite_flex_jni.so"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // MANTÉN ESTO: La librería de operaciones Flex
    //implementation("org.tensorflow:tensorflow-lite-select-tf-ops:2.16.1")
}