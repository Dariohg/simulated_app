plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.simulated_app"
    compileSdk = 34
    ndkVersion = "26.1.10909125"

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
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        // Solo arquitecturas ARM (reduce tamaño del APK)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Resolver conflictos de librerías nativas
    packaging {
        jniLibs {
            pickFirsts += setOf(
                "lib/*/libtensorflowlite_jni.so",
                "lib/*/libtensorflowlite_flex_jni.so",
                "lib/*/libtensorflowlite_gpu_jni.so"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TensorFlow Lite base
    implementation("org.tensorflow:tensorflow-lite:2.14.0")

    // TensorFlow Lite Flex Ops - REQUERIDO para el modelo HSEmotion
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:2.14.0")
}