package com.example.simulated_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            // ESTA ES LA CLAVE: Cargar las operaciones Flex antes que nada.
            System.loadLibrary("tensorflowlite_flex_jni")
        } catch (e: UnsatisfiedLinkError) {
            println("Error cargando librería Flex nativa: $e")
        }
    }
}