import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img;

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
  final EmotionService _emotionService = EmotionService();

  final DrowsinessAnalyzer _drowsinessAnalyzer = DrowsinessAnalyzer();
  final AttentionAnalyzer _attentionAnalyzer = AttentionAnalyzer();
  final EmotionAnalyzer _emotionAnalyzer = EmotionAnalyzer();
  final StateAggregator _stateAggregator = StateAggregator();

  bool _isInitialized = false;
  CombinedState? _lastState;
  EmotionResult? _lastEmotionResult;

  bool get isInitialized => _isInitialized;
  CombinedState? get currentState => _lastState;
  CameraController? get cameraController => _cameraService.controller;

  StreamSubscription<bool>? _cameraReadySubscription;
  bool _isProcessing = false;

  int _frameCount = 0;
  final int _processEmotionEveryNFrames = 3;

  int _emotionSuccessCount = 0;
  int _emotionFailCount = 0;

  // Contadores de diagnóstico detallado
  int _convertImageFail = 0;
  int _processFaceFail = 0;
  int _predictFail = 0;
  int _modelNotLoaded = 0;

  FaceMeshViewModel({
    required CameraService cameraService,
    required FaceMeshService faceMeshService,
  })  : _cameraService = cameraService,
        _faceMeshService = faceMeshService {
    initialize();
  }

  Future<void> initialize() async {
    print('[ViewModel] === INICIALIZANDO ===');

    await _emotionService.loadModel();

    print('[ViewModel] Modelo cargado: ${_emotionService.isModelLoaded}');

    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        _cameraService.startImageStream(_processFrame);
        notifyListeners();
        print('[ViewModel] Camara lista, stream iniciado');
      }
    });

    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      print('[ViewModel] ERROR inicializando camara: $e');
    }
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _frameCount++;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final meshes = await _faceMeshService.processImage(inputImage);

      if (meshes.isEmpty) {
        _lastState = _stateAggregator.aggregate(faceDetected: false);
        notifyListeners();
        _isProcessing = false;
        return;
      }

      final mesh = meshes.first;

      final List<FaceMeshPoint> points = List.generate(
        468,
            (index) => mesh.points.firstWhere(
              (p) => p.index == index,
          orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0),
        ),
      );

      final drowsiness = _drowsinessAnalyzer.analyze(points);
      final attention = _attentionAnalyzer.analyze(points);
      final isCalibrating = !_attentionAnalyzer.isCalibrated;

      EmotionResult? emotionResult = _lastEmotionResult;

      if (_frameCount % _processEmotionEveryNFrames == 0) {
        emotionResult = await _processEmotion(image, mesh.boundingBox);

        if (emotionResult != null) {
          _lastEmotionResult = emotionResult;
          _emotionSuccessCount++;
        } else {
          _emotionFailCount++;
        }

        // Log detallado cada 30 frames
        if (_frameCount % 30 == 0) {
          print('[ViewModel] Emociones - OK: $_emotionSuccessCount, FAIL: $_emotionFailCount');
          print('[ViewModel] Fallos detalle - convertImg: $_convertImageFail, processFace: $_processFaceFail, predict: $_predictFail, modelNotLoaded: $_modelNotLoaded');
        }
      }

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
    } catch (e) {
      print('[ViewModel] ERROR procesando frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<EmotionResult?> _processEmotion(
      CameraImage cameraImage,
      Rect boundingBox,
      ) async {
    try {
      // Check 1: Modelo cargado
      if (!_emotionService.isModelLoaded) {
        _modelNotLoaded++;
        return null;
      }

      // Check 2: Convertir imagen
      final img.Image? convertedImage = ImageUtils.convertCameraImage(cameraImage);
      if (convertedImage == null) {
        _convertImageFail++;
        return null;
      }

      // Check 3: Procesar cara
      final modelInput = ImageUtils.processFaceForModel(
        convertedImage,
        boundingBox.left.toInt(),
        boundingBox.top.toInt(),
        boundingBox.width.toInt(),
        boundingBox.height.toInt(),
      );
      if (modelInput == null) {
        _processFaceFail++;
        return null;
      }

      // Check 4: Inferencia
      final probabilities = await _emotionService.predict(modelInput);
      if (probabilities.isEmpty) {
        _predictFail++;
        return null;
      }

      return _emotionAnalyzer.analyze(probabilities);
    } catch (e) {
      print('[ViewModel] ERROR en _processEmotion: $e');
      return null;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    try {
      final allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

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

  void recalibrate() {
    _attentionAnalyzer.resetCalibration();
    _emotionAnalyzer.reset();
    _drowsinessAnalyzer.reset();
    _lastEmotionResult = null;
    print('[ViewModel] Recalibracion iniciada');
  }

  @override
  void dispose() {
    print('[ViewModel] Disposing...');
    _cameraReadySubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    _emotionService.dispose();
    super.dispose();
  }
}