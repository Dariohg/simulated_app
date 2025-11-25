import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionService {
  Interpreter? _interpreter;
  bool _isBusy = false;

  Future<void> loadModel() async {
    try {
      // Asegúrate de poner tu archivo .tflite en assets/
      _interpreter = await Interpreter.fromAsset('assets/emotion_model.tflite');
      print("[INFO] Modelo de emociones cargado correctamente");
    } catch (e) {
      print("[ERROR] Error al cargar modelo de emociones: $e");
    }
  }

  /// Recibe la imagen pre-procesada (224x224) y devuelve las probabilidades
  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || _isBusy) return [];

    _isBusy = true;
    try {
      // Asumiendo output shape [1, 8] (8 emociones)
      var output = List.filled(1 * 8, 0.0).reshape([1, 8]);

      // Ejecutar inferencia
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      // Convertir a lista simple
      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint("Error en inferencia: $e");
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}