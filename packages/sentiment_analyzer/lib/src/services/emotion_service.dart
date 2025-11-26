import 'dart:typed_data';
import 'dart:math';
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
      final modelPath = 'packages/sentiment_analyzer/assets/emotion_model.tflite';

      // Cargar modelo como bytes
      final modelData = await rootBundle.load(modelPath);
      final buffer = modelData.buffer.asUint8List();

      print('[EmotionService] Modelo leido: ${buffer.length} bytes');

      // Opciones del interprete
      final options = InterpreterOptions()
        ..threads = 4;

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
      print('[EmotionService] ERROR: $e');
    }
  }

  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || !_isModelLoaded || _isBusy) {
      return [];
    }

    _isBusy = true;

    try {
      final expectedSize = 1 * 224 * 224 * 3;
      if (input.length != expectedSize) {
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

      // Aplicar softmax si es necesario
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