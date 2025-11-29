import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionService {
  Interpreter? _interpreter;
  bool _isBusy = false;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  int _inferenceCount = 0;
  int _successCount = 0;
  int _errorCount = 0;
  double _lastInferenceTimeMs = 0;

  List<int> _inputShape = [1, 224, 224, 3];
  List<int> _outputShape = [1, 8];

  static const List<String> LABELS = [
    'Anger', 'Contempt', 'Disgust', 'Fear',
    'Happiness', 'Neutral', 'Sadness', 'Surprise'
  ];

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 2;

      _interpreter = await Interpreter.fromAsset(
        'packages/sentiment_analyzer/assets/emotion_model.tflite',
        options: options,
      );

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      _isModelLoaded = true;
    } catch (e) {
      print('[EmotionService] Error cargando modelo: $e');
      _isModelLoaded = false;
    }
  }

  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || !_isModelLoaded) return [];
    if (_isBusy) return [];

    _isBusy = true;
    _inferenceCount++;
    final stopwatch = Stopwatch()..start();

    try {
      if (input.length != 150528) {
        _errorCount++;
        return [];
      }

      var outputBuffer = List<double>.filled(8, 0).reshape([1, 8]);

      _interpreter!.run(input.reshape([1, 224, 224, 3]), outputBuffer);

      stopwatch.stop();
      _lastInferenceTimeMs = stopwatch.elapsedMicroseconds / 1000.0;

      List<double> rawOutput = List<double>.from(outputBuffer[0]);

      double sum = rawOutput.fold(0.0, (a, b) => a + b);
      List<double> probabilities;

      if (sum < 0.99 || sum > 1.01) {
        probabilities = _softmax(rawOutput);
      } else {
        probabilities = rawOutput;
      }

      _successCount++;
      return probabilities;
    } catch (e) {
      print('[EmotionService] Error en inferencia: $e');
      _errorCount++;
      return [];
    } finally {
      _isBusy = false;
    }
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    double maxVal = logits.reduce(max);
    List<double> expVals = logits.map((x) => exp(x - maxVal)).toList();
    double sumExp = expVals.reduce((a, b) => a + b);
    if (sumExp == 0) return List.filled(logits.length, 1.0 / logits.length);
    return expVals.map((x) => x / sumExp).toList();
  }

  Map<String, dynamic> getStats() {
    return {
      'isLoaded': _isModelLoaded,
      'inferenceCount': _inferenceCount,
      'successCount': _successCount,
      'errorCount': _errorCount,
      'successRate': _inferenceCount > 0
          ? (_successCount / _inferenceCount * 100).toStringAsFixed(1)
          : 'N/A',
      'lastInferenceMs': _lastInferenceTimeMs.toStringAsFixed(2),
      'inputShape': _inputShape.toString(),
      'outputShape': _outputShape.toString(),
    };
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}