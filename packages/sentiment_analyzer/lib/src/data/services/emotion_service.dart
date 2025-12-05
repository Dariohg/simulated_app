import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionService {
  static final EmotionService _instance = EmotionService._internal();
  factory EmotionService() => _instance;
  EmotionService._internal();

  Interpreter? _interpreter;
  bool _isBusy = false;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    if (_isModelLoaded) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'packages/sentiment_analyzer/assets/emotion_model.tflite',
        options: options,
      );
      _isModelLoaded = true;
    } catch (e) {
      debugPrint('[EmotionService] Error cargando modelo: $e');
      _isModelLoaded = false;
    }
  }

  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || !_isModelLoaded) return [];
    if (_isBusy) return [];

    _isBusy = true;
    try {
      // El modelo espera 224x224x3 = 150528 floats
      if (input.length != 150528) {
        debugPrint('[EmotionService] Tamaño de entrada incorrecto: ${input.length}');
        return [];
      }

      // Buffer de salida: [1, 8]
      var outputBuffer = List.filled(1 * 8, 0.0).reshape([1, 8]);

      // Reshape de entrada
      var inputBuffer = input.reshape([1, 224, 224, 3]);

      _interpreter!.run(inputBuffer, outputBuffer);

      List<double> rawOutput = List<double>.from(outputBuffer[0]);

      // Aplicar Softmax para obtener probabilidades limpias (0.0 a 1.0)
      return _softmax(rawOutput);
    } catch (e) {
      debugPrint('[EmotionService] Error en inferencia: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    double maxVal = logits.reduce(max);
    // Calcular exponenciales restando el máximo para estabilidad numérica
    List<double> expVals = logits.map((x) => exp(x - maxVal)).toList();
    double sumExp = expVals.reduce((a, b) => a + b);

    if (sumExp == 0) return List.filled(logits.length, 1.0 / logits.length);

    return expVals.map((x) => x / sumExp).toList();
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}