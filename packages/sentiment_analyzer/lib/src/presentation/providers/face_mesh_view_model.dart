import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img; // Para procesar recorte

import '../../services/camera_service.dart';
import '../../services/face_mesh_service.dart';
import '../../services/emotion_service.dart';
import '../../utils/image_utils.dart';

import '../../logic/drowsiness_analyzer.dart';
import '../../logic/attention_analyzer.dart';
import '../../logic/emotion_analyzer.dart';
import '../../logic/state_aggregator.dart';

class FaceMeshViewModel extends ChangeNotifier {
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final EmotionService _emotionService = EmotionService(); // Nuevo servicio

  final DrowsinessAnalyzer _drowsinessAnalyzer = DrowsinessAnalyzer();
  final AttentionAnalyzer _attentionAnalyzer = AttentionAnalyzer();
  final EmotionAnalyzer _emotionAnalyzer = EmotionAnalyzer();
  final StateAggregator _stateAggregator = StateAggregator();

  bool _isInitialized = false;
  CombinedState? _lastState;

  bool get isInitialized => _isInitialized;
  CombinedState? get currentState => _lastState;
  CameraController? get cameraController => _cameraService.controller;

  StreamSubscription<bool>? _cameraReadySubscription;
  bool _isProcessing = false;

  // Control de frames para no saturar el modelo de emociones
  int _frameCount = 0;
  final int _processEmotionEveryNFrames = 5; // Simular config Python

  FaceMeshViewModel({
    required CameraService cameraService,
    required FaceMeshService faceMeshService,
  })  : _cameraService = cameraService,
        _faceMeshService = faceMeshService {
    initialize();
  }

  Future<void> initialize() async {
    print("[INFO] Inicializando componentes...");

    // Cargar modelo TFLite
    await _emotionService.loadModel();

    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        _cameraService.startImageStream(_processFrame);
        notifyListeners();
        print("[INFO] Sistema iniciado correctamente");
      }
    });

    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      print("[ERROR] No se pudo acceder a la camara: $e");
    }
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _frameCount++;

    final inputImage = _convertCameraImageToInputImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    // 1. Detectar Malla Facial (Rápido)
    final meshes = await _faceMeshService.processImage(inputImage);

    if (meshes.isNotEmpty) {
      final mesh = meshes.first;
      List<FaceMeshPoint> points = List.generate(468, (index) =>
          mesh.points.firstWhere((p) => p.index == index, orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0))
      );

      // 2. Analizar Geometría (Somnolencia y Atención)
      final drowsiness = _drowsinessAnalyzer.analyze(points);
      final attention = _attentionAnalyzer.analyze(points);

      // 3. Analizar Emociones (Más lento, solo cada N frames)
      EmotionResult? emotionResult = _lastState?.emotion;

      if (_frameCount % _processEmotionEveryNFrames == 0) {
        // Convertir YUV a RGB para el modelo
        img.Image? convertedImage = ImageUtils.convertCameraImage(image);

        if (convertedImage != null) {
          // Obtener Bounding Box de la cara desde la malla
          final rect = mesh.boundingBox;

          // Pre-procesar (Recortar y Resize)
          final modelInput = ImageUtils.processFaceForModel(
              convertedImage,
              rect.left.toInt(),
              rect.top.toInt(),
              rect.width.toInt(),
              rect.height.toInt()
          );

          if (modelInput != null) {
            // Inferencia TFLite
            final probabilities = await _emotionService.predict(modelInput);
            if (probabilities.isNotEmpty) {
              emotionResult = _emotionAnalyzer.analyze(probabilities);
            }
          }
        }
      }

      // 4. Agregar Estado Final
      _lastState = _stateAggregator.aggregate(
        drowsiness: drowsiness,
        attention: attention,
        emotion: emotionResult,
        isCalibrating: !_attentionAnalyzer.isCalibrated,
      );

      notifyListeners();
    }

    _isProcessing = false;
  }

  // Método auxiliar interno para ML Kit (InputImage)
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
        ?? InputImageRotation.rotation0deg;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw)
        ?? InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void recalibrate() {
    _attentionAnalyzer.resetCalibration();
    _emotionAnalyzer.reset();
    print("[INFO] Recalibrando... mire a la pantalla");
  }

  @override
  void dispose() {
    print("[INFO] Cerrando sistema...");
    _cameraReadySubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    _emotionService.dispose();
    super.dispose();
  }
}