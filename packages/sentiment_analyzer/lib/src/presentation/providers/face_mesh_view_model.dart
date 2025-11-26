import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../../services/camera_service.dart';
import '../../services/face_mesh_service.dart';
import '../../services/emotion_service.dart';
import '../../utils/image_utils.dart';

import '../../logic/drowsiness_analyzer.dart';
import '../../logic/attention_analyzer.dart';
import '../../logic/emotion_analyzer.dart';
import '../../logic/state_aggregator.dart';

/// ViewModel principal que coordina el análisis de emociones, somnolencia y atención.
///
/// Pipeline de procesamiento (por frame):
/// 1. Captura de imagen de cámara
/// 2. Detección de face mesh con ML Kit
/// 3. Análisis de somnolencia (EAR/MAR)
/// 4. Análisis de atención (pose de cabeza)
/// 5. Clasificación de emociones (TFLite) - cada N frames
/// 6. Agregación de estados
class FaceMeshViewModel extends ChangeNotifier {
  // Servicios
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final EmotionService _emotionService = EmotionService();

  // Analizadores
  final DrowsinessAnalyzer _drowsinessAnalyzer = DrowsinessAnalyzer();
  final AttentionAnalyzer _attentionAnalyzer = AttentionAnalyzer();
  final EmotionAnalyzer _emotionAnalyzer = EmotionAnalyzer();
  final StateAggregator _stateAggregator = StateAggregator();

  // Estado
  bool _isInitialized = false;
  CombinedState? _lastState;
  EmotionResult? _lastEmotionResult;

  // Getters públicos
  bool get isInitialized => _isInitialized;
  CombinedState? get currentState => _lastState;
  CameraController? get cameraController => _cameraService.controller;

  // Control de procesamiento
  StreamSubscription<bool>? _cameraReadySubscription;
  bool _isProcessing = false;

  // Configuración de frecuencia de procesamiento
  int _frameCount = 0;

  /// Procesar emociones cada N frames (ajustar según rendimiento del dispositivo)
  /// Un valor más alto = menos uso de CPU pero respuesta más lenta
  final int _processEmotionEveryNFrames = 2;  // Reducido de 3 a 2 para mejor respuesta

  // Estadísticas de diagnóstico
  int _totalFrames = 0;
  int _faceDetectedFrames = 0;
  int _emotionProcessedFrames = 0;
  int _emotionSuccessFrames = 0;

  // Contadores de errores detallados
  int _convertImageFail = 0;
  int _processFaceFail = 0;
  int _predictFail = 0;
  int _modelNotLoaded = 0;

  // Timestamp para logs periódicos
  DateTime _lastStatsLog = DateTime.now();

  FaceMeshViewModel({
    required CameraService cameraService,
    required FaceMeshService faceMeshService,
  })  : _cameraService = cameraService,
        _faceMeshService = faceMeshService {
    initialize();
  }

  /// Inicializa todos los componentes del sistema
  Future<void> initialize() async {
    print('[ViewModel] ================================================');
    print('[ViewModel] Inicializando Sistema de Análisis de Emociones');
    print('[ViewModel] ================================================');

    // 1. Cargar modelo de emociones
    await _emotionService.loadModel();
    print('[ViewModel] Modelo de emociones: ${_emotionService.isModelLoaded ? "✓ Cargado" : "✗ No cargado"}');

    // 2. Configurar listener de cámara
    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        _cameraService.startImageStream(_processFrame);
        notifyListeners();
        print('[ViewModel] ✓ Cámara inicializada, stream de video iniciado');
      }
    });

    // 3. Iniciar cámara
    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      print('[ViewModel] ✗ ERROR inicializando cámara: $e');
    }
  }

  /// Procesa cada frame del stream de video
  void _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _frameCount++;
    _totalFrames++;

    try {
      // 1. Convertir imagen de cámara a formato ML Kit
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // 2. Detectar face mesh
      final meshes = await _faceMeshService.processImage(inputImage);

      // 3. Si no hay cara detectada
      if (meshes.isEmpty) {
        _lastState = _stateAggregator.aggregate(faceDetected: false);
        notifyListeners();
        _isProcessing = false;
        return;
      }

      _faceDetectedFrames++;
      final mesh = meshes.first;

      // 4. Preparar puntos del mesh (asegurar que tengamos los 468 puntos)
      final List<FaceMeshPoint> points = _preparePoints(mesh);

      // 5. Análisis de somnolencia (EAR/MAR)
      final drowsiness = _drowsinessAnalyzer.analyze(points);

      // 6. Análisis de atención (pose de cabeza)
      final attention = _attentionAnalyzer.analyze(points);
      final isCalibrating = !_attentionAnalyzer.isCalibrated;

      // 7. Análisis de emociones (solo cada N frames para rendimiento)
      EmotionResult? emotionResult = _lastEmotionResult;

      if (_frameCount % _processEmotionEveryNFrames == 0) {
        _emotionProcessedFrames++;
        // CORRECCIÓN: Llamada asíncrona optimizada
        emotionResult = await _processEmotion(image, mesh.boundingBox);

        if (emotionResult != null) {
          _lastEmotionResult = emotionResult;
          _emotionSuccessFrames++;
        }
      }

      // 8. Extraer datos de emociones
      String cognitiveState = 'concentrado';
      String emotion = 'Neutral';
      double confidence = 0.0;
      Map<String, double>? emotionScores;

      if (emotionResult != null) {
        cognitiveState = emotionResult.cognitiveState;
        emotion = emotionResult.emotion;
        confidence = emotionResult.confidence;
        emotionScores = emotionResult.scores;
      }

      // 9. Agregar todos los estados
      _lastState = _stateAggregator.aggregate(
        faceDetected: true,
        cognitiveState: cognitiveState,
        emotion: emotion,
        confidence: confidence,
        emotionScores: emotionScores,
        drowsiness: drowsiness,
        attention: attention,
        isCalibrating: isCalibrating,
      );

      notifyListeners();

      // 10. Log de estadísticas periódico
      _logPeriodicStats();

    } catch (e, stackTrace) {
      print('[ViewModel] ERROR procesando frame #$_frameCount: $e');
      if (_frameCount <= 5) {
        print('[ViewModel] StackTrace: $stackTrace');
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Prepara la lista de puntos del mesh asegurando los 468 puntos
  List<FaceMeshPoint> _preparePoints(FaceMesh mesh) {
    return List.generate(
      468,
          (index) => mesh.points.firstWhere(
            (p) => p.index == index,
        orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0),
      ),
    );
  }

  /// Procesa las emociones de un frame usando Isolates
  Future<EmotionResult?> _processEmotion(
      CameraImage cameraImage,
      Rect boundingBox,
      ) async {
    try {
      // Validación 1: Modelo cargado
      if (!_emotionService.isModelLoaded) {
        _modelNotLoaded++;
        return null;
      }

      // Validación 2: BoundingBox válido
      if (boundingBox.width < 30 || boundingBox.height < 30) {
        return null;  // Cara demasiado pequeña
      }

      // Obtener rotación del sensor para enderezar la imagen
      // Usualmente 270 para frontal en Android, 90 en otros
      final sensorOrientation = _cameraService.cameraDescription?.sensorOrientation ?? 270;

      // CORRECCIÓN PRINCIPAL:
      // Usar el Isolate para convertir, rotar y recortar sin bloquear la UI
      final modelInput = await ImageUtils.processCameraImageInIsolate(
        cameraImage,
        sensorOrientation,
        [
          boundingBox.left.toInt(),
          boundingBox.top.toInt(),
          boundingBox.width.toInt(),
          boundingBox.height.toInt(),
        ],
      );

      if (modelInput == null) {
        _processFaceFail++;
        return null;
      }

      // Paso 3: Ejecutar inferencia
      final probabilities = await _emotionService.predict(modelInput);
      if (probabilities.isEmpty) {
        _predictFail++;
        return null;
      }

      // Paso 4: Analizar probabilidades con suavizado temporal
      return _emotionAnalyzer.analyze(probabilities);

    } catch (e) {
      print('[ViewModel] ERROR en _processEmotion: $e');
      return null;
    }
  }

  /// Convierte CameraImage a InputImage para ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    try {
      // Concatenar todos los planos de bytes
      final allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Determinar rotación según el sensor de la cámara
      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      // Determinar formato de imagen
      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      print('[ViewModel] ERROR convirtiendo a InputImage: $e');
      return null;
    }
  }

  /// Log de estadísticas periódico (cada 5 segundos)
  void _logPeriodicStats() {
    final now = DateTime.now();
    if (now.difference(_lastStatsLog).inSeconds >= 5) {
      _lastStatsLog = now;

      final faceRate = _totalFrames > 0
          ? (_faceDetectedFrames / _totalFrames * 100).toStringAsFixed(1)
          : '0';
      final emotionRate = _emotionProcessedFrames > 0
          ? (_emotionSuccessFrames / _emotionProcessedFrames * 100).toStringAsFixed(1)
          : '0';

      print('[ViewModel] ═══════════════════════════════════════');
      print('[ViewModel] ESTADÍSTICAS (cada 5s)');
      print('[ViewModel] ───────────────────────────────────────');
      print('[ViewModel] Frames totales: $_totalFrames');
      print('[ViewModel] Cara detectada: $_faceDetectedFrames ($faceRate%)');
      print('[ViewModel] Emociones procesadas: $_emotionProcessedFrames');
      print('[ViewModel] Emociones exitosas: $_emotionSuccessFrames ($emotionRate%)');
      print('[ViewModel] ───────────────────────────────────────');
      print('[ViewModel] Errores detallados:');
      print('[ViewModel]   - Conversión imagen: $_convertImageFail');
      print('[ViewModel]   - Proceso cara: $_processFaceFail');
      print('[ViewModel]   - Predicción: $_predictFail');
      print('[ViewModel]   - Modelo no cargado: $_modelNotLoaded');

      if (_lastState != null && _lastState!.faceDetected) {
        print('[ViewModel] ───────────────────────────────────────');
        print('[ViewModel] Estado actual:');
        print('[ViewModel]   - Final: ${_lastState!.finalState}');
        print('[ViewModel]   - Emoción: ${_lastState!.emotion}');
        print('[ViewModel]   - Confianza: ${(_lastState!.confidence * 100).toStringAsFixed(1)}%');
        print('[ViewModel]   - EAR: ${_lastState!.drowsiness?.ear.toStringAsFixed(3) ?? "N/A"}');
      }
      print('[ViewModel] ═══════════════════════════════════════');
    }
  }

  /// Resetea la calibración y los historiales
  void recalibrate() {
    _attentionAnalyzer.resetCalibration();
    _emotionAnalyzer.reset();
    _drowsinessAnalyzer.reset();
    _lastEmotionResult = null;
    print('[ViewModel] ✓ Recalibración iniciada - mire a la pantalla');
  }

  /// Obtiene estadísticas completas del sistema
  Map<String, dynamic> getFullStats() {
    return {
      'frames': {
        'total': _totalFrames,
        'faceDetected': _faceDetectedFrames,
        'emotionProcessed': _emotionProcessedFrames,
        'emotionSuccess': _emotionSuccessFrames,
      },
      'errors': {
        'convertImage': _convertImageFail,
        'processFace': _processFaceFail,
        'predict': _predictFail,
        'modelNotLoaded': _modelNotLoaded,
      },
      'emotionService': _emotionService.getStats(),
      'emotionAnalyzer': _emotionAnalyzer.getStats(),
      'currentState': _lastState != null ? {
        'finalState': _lastState!.finalState,
        'emotion': _lastState!.emotion,
        'confidence': _lastState!.confidence,
        'faceDetected': _lastState!.faceDetected,
        'isCalibrating': _lastState!.isCalibrating,
      } : null,
    };
  }

  @override
  void dispose() {
    print('[ViewModel] ════════════════════════════════════');
    print('[ViewModel] Liberando recursos...');
    print('[ViewModel] Stats finales: ${getFullStats()}');
    print('[ViewModel] ════════════════════════════════════');

    _cameraReadySubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    _emotionService.dispose();
    super.dispose();
  }
}