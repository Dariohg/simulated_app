import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../../../core/logic/attention_analyzer.dart';
import '../../../core/logic/drowsiness_analyzer.dart';
import '../../../core/logic/emotion_analyzer.dart';
import '../../../core/logic/state_aggregator.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/face_mesh_service.dart';
import '../../../data/services/emotion_service.dart';
import '../../../data/models/calibration_result.dart';

class AnalysisViewModel extends ChangeNotifier {
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final EmotionService _emotionService = EmotionService();

  final DrowsinessAnalyzer _drowsinessAnalyzer = DrowsinessAnalyzer();
  final AttentionAnalyzer _attentionAnalyzer = AttentionAnalyzer();
  final EmotionAnalyzer _emotionAnalyzer = EmotionAnalyzer();
  final StateAggregator _stateAggregator = StateAggregator();

  bool _isInitialized = false;
  CombinedState? _lastState;
  bool _isProcessing = false;

  EmotionResult? _lastEmotionResult;

  DateTime _lastProcessTime = DateTime.now();
  final Duration _processInterval = const Duration(milliseconds: 200);

  bool get isInitialized => _isInitialized;
  CombinedState? get currentState => _lastState;
  CameraController? get cameraController => _cameraService.controller;

  StreamSubscription<bool>? _cameraReadySubscription;

  AnalysisViewModel({
    required CameraService cameraService,
    required FaceMeshService faceMeshService,
  })  : _cameraService = cameraService,
        _faceMeshService = faceMeshService {
    initialize();
  }

  void applyCalibration(CalibrationResult calibration) {
    if (!calibration.isSuccessful) return;
    if (calibration.earThreshold != null) {
      _drowsinessAnalyzer.updateEarThreshold(calibration.earThreshold!);
    }
    if (calibration.baselinePitch != null && calibration.baselineYaw != null) {
      _attentionAnalyzer.applyCalibration(
        baselinePitch: calibration.baselinePitch!,
        baselineYaw: calibration.baselineYaw!,
      );
    }
  }

  Future<void> initialize() async {
    await _emotionService.loadModel();
    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        _cameraService.startImageStream(_processFrame);
        notifyListeners();
      }
    });
    await _cameraService.initializeCamera();
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    if (DateTime.now().difference(_lastProcessTime) < _processInterval) return;

    _isProcessing = true;
    _lastProcessTime = DateTime.now();

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final meshes = await _faceMeshService.processImage(inputImage);

      if (meshes.isEmpty) {
        _lastState = _stateAggregator.aggregate(faceDetected: false);
        notifyListeners();
        return;
      }

      final mesh = meshes.first;
      final points = _preparePoints(mesh);
      final drowsiness = _drowsinessAnalyzer.analyze(points);
      final attention = _attentionAnalyzer.analyze(points);

      if (mesh.boundingBox.width > 30 && mesh.boundingBox.height > 30) {
        final sensorOrientation = _cameraService.cameraDescription?.sensorOrientation ?? 270;

        final modelInput = await ImageUtils.processCameraImageInIsolate(
          image,
          sensorOrientation,
          [
            mesh.boundingBox.left.toInt(),
            mesh.boundingBox.top.toInt(),
            mesh.boundingBox.width.toInt(),
            mesh.boundingBox.height.toInt(),
          ],
        );

        if (modelInput != null) {
          final probabilities = await _emotionService.predict(modelInput);
          if (probabilities.isNotEmpty) {
            _lastEmotionResult = _emotionAnalyzer.analyze(probabilities);
          }
        }
      }

      String cognitiveState = 'concentrado';
      String emotion = 'Neutral';
      double confidence = 0.0;
      Map<String, double>? emotionScores;

      if (_lastEmotionResult != null) {
        cognitiveState = _lastEmotionResult!.cognitiveState;
        emotion = _lastEmotionResult!.emotion;
        confidence = _lastEmotionResult!.confidence;
        emotionScores = _lastEmotionResult!.scores;
      }

      _lastState = _stateAggregator.aggregate(
        faceDetected: true,
        cognitiveState: cognitiveState,
        emotion: emotion,
        confidence: confidence,
        emotionScores: emotionScores,
        drowsiness: drowsiness,
        attention: attention,
        isCalibrating: !_attentionAnalyzer.isCalibrated,
      );

      notifyListeners();

    } catch (e) {
      debugPrint("$e");
    } finally {
      _isProcessing = false;
    }
  }

  List<FaceMeshPoint> _preparePoints(FaceMesh mesh) {
    return List.generate(468, (index) => mesh.points.firstWhere(
            (p) => p.index == index,
        orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0)
    ));
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

      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _cameraReadySubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    _emotionService.dispose();
    super.dispose();
  }
}