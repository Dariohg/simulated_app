import 'dart:typed_data';
import 'dart:math';
import 'dart:ffi'; // [Nuevo] Necesario para cargar librerías dinámicas
import 'dart:io';  // [Nuevo] Necesario para detectar la plataforma (Android)
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionService {
  Interpreter? _interpreter;
  bool _isBusy = false;
  bool _isModelLoaded = false;

  List<int>? _inputShape;
  List<int>? _outputShape;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    print('[EmotionService] === CARGANDO MODELO ===');

    try {
      // [CORRECCIÓN CRÍTICA] Cargar manualmente la librería Flex en Android
      // Esto soluciona el error: "Select TensorFlow op(s)... failed to prepare"
      if (Platform.isAndroid) {
        try {
          DynamicLibrary.open('libtensorflowlite_flex_jni.so');
          print('[EmotionService] Libreria Flex cargada correctamente (JNI)');
        } catch (e) {
          print('[EmotionService] ADVERTENCIA: No se pudo cargar libtensorflowlite_flex_jni.so. '
              'Si el modelo usa Flex Ops, fallará. Error: $e');
        }
      }

      final modelPath = 'packages/sentiment_analyzer/assets/emotion_model.tflite';

      // Cargar modelo como bytes
      final modelData = await rootBundle.load(modelPath);
      final buffer = modelData.buffer.asUint8List();

      print('[EmotionService] Modelo leido: ${buffer.length} bytes');

      // Opciones del interprete
      final options = InterpreterOptions()
        ..threads = 4;
      // Nota: Si sigues teniendo problemas, podrías intentar agregar:
      // ..useNnApiForAndroid = true;
      // pero prueba primero solo con la carga de la librería Flex.

      // Crear interprete desde buffer
      _interpreter = Interpreter.fromBuffer(buffer, options: options);

      if (_interpreter != null) {
        _isModelLoaded = true;

        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();

        _inputShape = inputTensors.first.shape;
        _outputShape = outputTensors.first.shape;

        print('[EmotionService] EXITO: Modelo cargado');
        print('[EmotionService] Input shape: $_inputShape');
        print('[EmotionService] Output shape: $_outputShape');
      }
    } catch (e) {
      _isModelLoaded = false;
      print('[EmotionService] ERROR FATAL al cargar modelo: $e');
    }
  }

  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || !_isModelLoaded || _isBusy) {
      return [];
    }

    _isBusy = true;

    try {
      // Validar tamaño de entrada (ajustar según tu modelo real si varía)
      // 1 * 224 * 224 * 3 = 150528 floats
      final expectedSize = 1 * 224 * 224 * 3;
      if (input.length != expectedSize) {
        print('[EmotionService] Error: Tamaño de entrada incorrecto. Esperado $expectedSize, recibido ${input.length}');
        return [];
      }

      int outputSize = _outputShape?.last ?? 8;
      var outputBuffer = List<List<double>>.generate(
        1,
            (_) => List<double>.filled(outputSize, 0.0),
      );

      var inputReshaped = _reshapeInput(input);
      _interpreter!.run(inputReshaped, outputBuffer);

      List<double> rawOutput = List<double>.from(outputBuffer[0]);

      // Aplicar softmax si la suma no es ~1.0 (el modelo podría devolver logits crudos)
      double sum = rawOutput.fold(0.0, (a, b) => a + b);
      if (sum.abs() < 0.99 || sum.abs() > 1.01) {
        return _softmax(rawOutput);
      }

      return rawOutput;
    } catch (e) {
      print('[EmotionService] ERROR predict: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  List _reshapeInput(Float32List flat) {
    // Reconstruir tensor [1, 224, 224, 3] desde la lista plana
    return List.generate(1, (b) {
      return List.generate(224, (h) {
        return List.generate(224, (w) {
          return List.generate(3, (c) {
            int index = h * 224 * 3 + w * 3 + c;
            return flat[index];
          });
        });
      });
    });
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    double maxVal = logits.reduce((a, b) => a > b ? a : b);
    List<double> expVals = logits.map((x) => exp(x - maxVal)).toList();
    double sumExp = expVals.reduce((a, b) => a + b);
    return expVals.map((x) => x / sumExp).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}