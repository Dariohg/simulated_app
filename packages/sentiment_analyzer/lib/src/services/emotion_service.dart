import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Servicio para inferencia del modelo de emociones TFLite.
///
/// El modelo es HSEmotion (EfficientNet-B0) entrenado en AffectNet.
/// - Input: [1, 224, 224, 3] - imagen RGB normalizada con ImageNet stats
/// - Output: [1, 8] - probabilidades de 8 emociones
///
/// Orden de salida: Anger, Contempt, Disgust, Fear, Happiness, Neutral, Sadness, Surprise
class EmotionService {
  Interpreter? _interpreter;
  bool _isBusy = false;
  bool _isModelLoaded = false;

  List<int>? _inputShape;
  List<int>? _outputShape;

  // Estadísticas para debug
  int _inferenceCount = 0;
  int _successCount = 0;
  int _errorCount = 0;
  double _lastInferenceTimeMs = 0;

  bool get isModelLoaded => _isModelLoaded;
  double get lastInferenceTimeMs => _lastInferenceTimeMs;

  /// Carga el modelo TFLite desde los assets
  Future<void> loadModel() async {
    print('[EmotionService] ========================================');
    print('[EmotionService] Iniciando carga del modelo de emociones');
    print('[EmotionService] ========================================');

    try {
      // Intentar cargar librería Flex en Android (para operaciones especiales)
      if (Platform.isAndroid) {
        _tryLoadFlexLibrary();
      }

      // Ruta del modelo en assets
      final modelPath = 'packages/sentiment_analyzer/assets/emotion_model.tflite';

      print('[EmotionService] Cargando modelo desde: $modelPath');

      // Cargar modelo como bytes
      final modelData = await rootBundle.load(modelPath);
      final buffer = modelData.buffer.asUint8List();

      print('[EmotionService] Modelo leído: ${buffer.length} bytes '
          '(${(buffer.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      // Configurar opciones del intérprete
      final options = InterpreterOptions()
        ..threads = 4;  // Usar 4 hilos para mejor rendimiento

      // Crear intérprete desde buffer
      _interpreter = Interpreter.fromBuffer(buffer, options: options);

      if (_interpreter != null) {
        _isModelLoaded = true;

        // Obtener información de tensores
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();

        _inputShape = inputTensors.first.shape;
        _outputShape = outputTensors.first.shape;

        print('[EmotionService] ✓ Modelo cargado exitosamente');
        print('[EmotionService] Input tensor:');
        print('[EmotionService]   - Shape: $_inputShape');
        print('[EmotionService]   - Type: ${inputTensors.first.type}');
        print('[EmotionService] Output tensor:');
        print('[EmotionService]   - Shape: $_outputShape');
        print('[EmotionService]   - Type: ${outputTensors.first.type}');

        // Validar shapes esperados
        _validateModelShapes();
      }
    } catch (e, stackTrace) {
      _isModelLoaded = false;
      print('[EmotionService] ✗ ERROR FATAL al cargar modelo:');
      print('[EmotionService] Error: $e');
      print('[EmotionService] StackTrace: $stackTrace');
    }
  }

  /// Intenta cargar la librería TensorFlow Flex para operaciones especiales
  void _tryLoadFlexLibrary() {
    try {
      // La librería Flex permite operaciones de TF que no están en TFLite estándar
      // Nota: Esto puede no ser necesario si el modelo fue convertido correctamente
      print('[EmotionService] Plataforma Android detectada');
      // DynamicLibrary.open('libtensorflowlite_flex_jni.so');
      // print('[EmotionService] ✓ Librería Flex cargada');
    } catch (e) {
      print('[EmotionService] Nota: No se cargó librería Flex (puede no ser necesaria): $e');
    }
  }

  /// Valida que los shapes del modelo sean los esperados
  void _validateModelShapes() {
    // Input esperado: [1, 224, 224, 3]
    if (_inputShape != null) {
      if (_inputShape!.length != 4 ||
          _inputShape![0] != 1 ||
          _inputShape![1] != 224 ||
          _inputShape![2] != 224 ||
          _inputShape![3] != 3) {
        print('[EmotionService] ⚠ ADVERTENCIA: Input shape inesperado');
        print('[EmotionService] Esperado: [1, 224, 224, 3]');
        print('[EmotionService] Actual: $_inputShape');
      }
    }

    // Output esperado: [1, 8]
    if (_outputShape != null) {
      if (_outputShape!.length != 2 ||
          _outputShape![0] != 1 ||
          _outputShape![1] != 8) {
        print('[EmotionService] ⚠ ADVERTENCIA: Output shape inesperado');
        print('[EmotionService] Esperado: [1, 8]');
        print('[EmotionService] Actual: $_outputShape');
      }
    }
  }

  /// Ejecuta inferencia sobre una imagen preprocesada
  ///
  /// [input] debe ser Float32List de tamaño 1*224*224*3 = 150528
  /// con valores normalizados usando estadísticas ImageNet
  ///
  /// Retorna lista de 8 probabilidades (una por emoción)
  Future<List<double>> predict(Float32List input) async {
    if (_interpreter == null || !_isModelLoaded) {
      print('[EmotionService] Modelo no cargado, ignorando predicción');
      return [];
    }

    if (_isBusy) {
      // No loguear esto ya que puede ser muy frecuente
      return [];
    }

    _isBusy = true;
    _inferenceCount++;
    final stopwatch = Stopwatch()..start();

    try {
      // Validar tamaño de entrada
      final expectedSize = 1 * 224 * 224 * 3; // 150528
      if (input.length != expectedSize) {
        print('[EmotionService] Error: Tamaño de entrada incorrecto');
        print('[EmotionService] Esperado: $expectedSize, Recibido: ${input.length}');
        _errorCount++;
        return [];
      }

      // Crear buffer de salida
      int outputSize = _outputShape?.last ?? 8;
      var outputBuffer = List<List<double>>.generate(
        1,
            (_) => List<double>.filled(outputSize, 0.0),
      );

      // Reshape input de [150528] a [1, 224, 224, 3]
      var inputReshaped = _reshapeInput(input);

      // Ejecutar inferencia
      _interpreter!.run(inputReshaped, outputBuffer);

      stopwatch.stop();
      _lastInferenceTimeMs = stopwatch.elapsedMicroseconds / 1000.0;

      // Extraer resultados
      List<double> rawOutput = List<double>.from(outputBuffer[0]);

      // Verificar si necesitamos aplicar softmax
      // (el modelo puede devolver logits o probabilidades)
      double sum = rawOutput.fold(0.0, (a, b) => a + b);

      List<double> probabilities;
      if (sum.abs() < 0.99 || sum.abs() > 1.01) {
        // Los valores no suman 1, probablemente son logits -> aplicar softmax
        probabilities = _softmax(rawOutput);
      } else {
        // Ya son probabilidades
        probabilities = rawOutput;
      }

      _successCount++;

      // Log de debug periódico
      if (_inferenceCount % 30 == 0) {
        print('[EmotionService] Inferencia #$_inferenceCount');
        print('[EmotionService] Tiempo: ${_lastInferenceTimeMs.toStringAsFixed(2)}ms');
        print('[EmotionService] Éxitos: $_successCount, Errores: $_errorCount');
        _logProbabilities(probabilities);
      }

      return probabilities;
    } catch (e, stackTrace) {
      _errorCount++;
      print('[EmotionService] ERROR en inferencia #$_inferenceCount: $e');
      if (_errorCount <= 3) {
        print('[EmotionService] StackTrace: $stackTrace');
      }
      return [];
    } finally {
      _isBusy = false;
    }
  }

  /// Reshape de Float32List plano a tensor [1, 224, 224, 3]
  List<List<List<List<double>>>> _reshapeInput(Float32List flat) {
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

  /// Aplica softmax a una lista de logits
  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];

    // Restar el máximo para estabilidad numérica
    double maxVal = logits.reduce((a, b) => a > b ? a : b);
    List<double> expVals = logits.map((x) => exp(x - maxVal)).toList();
    double sumExp = expVals.reduce((a, b) => a + b);

    if (sumExp == 0) return List.filled(logits.length, 1.0 / logits.length);

    return expVals.map((x) => x / sumExp).toList();
  }

  /// Log de probabilidades para debug
  void _logProbabilities(List<double> probs) {
    const labels = ['Anger', 'Contempt', 'Disgust', 'Fear',
      'Happiness', 'Neutral', 'Sadness', 'Surprise'];

    // Crear lista de pares (label, prob) y ordenar por probabilidad
    var pairs = <MapEntry<String, double>>[];
    for (int i = 0; i < probs.length && i < labels.length; i++) {
      pairs.add(MapEntry(labels[i], probs[i] * 100));
    }
    pairs.sort((a, b) => b.value.compareTo(a.value));

    print('[EmotionService] Probabilidades:');
    for (int i = 0; i < min(3, pairs.length); i++) {
      print('[EmotionService]   ${pairs[i].key}: ${pairs[i].value.toStringAsFixed(1)}%');
    }
  }

  /// Obtiene estadísticas del servicio
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
      'inputShape': _inputShape?.toString() ?? 'N/A',
      'outputShape': _outputShape?.toString() ?? 'N/A',
    };
  }

  /// Libera recursos del intérprete
  void dispose() {
    print('[EmotionService] Liberando recursos...');
    print('[EmotionService] Stats finales: ${getStats()}');
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}