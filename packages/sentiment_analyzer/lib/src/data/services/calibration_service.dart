import 'dart:async';
import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

// RUTAS CORREGIDAS:
import '../../core/utils/landmark_indices.dart';
import '../models/calibration_result.dart';

enum CalibrationStep { faceDetection, lighting, eyeBaseline, completed }

class CalibrationProgress {
  final CalibrationStep step;
  final double stepProgress;
  final String message;
  final bool shouldVibrate;
  final bool requiresAction;
  final String? actionMessage;

  CalibrationProgress({
    required this.step,
    required this.stepProgress,
    required this.message,
    this.shouldVibrate = false,
    this.requiresAction = false,
    this.actionMessage,
  });
}

class CalibrationService {
  final _progressController = StreamController<CalibrationProgress>.broadcast();
  Stream<CalibrationProgress> get progressStream => _progressController.stream;

  CalibrationStep _currentStep = CalibrationStep.faceDetection;
  CalibrationStep get currentStep => _currentStep;

  bool _isCalibrating = false;
  bool get isCalibrating => _isCalibrating;
  bool _isCalibrated = false;
  bool get isCalibrated => _isCalibrated;

  final List<double> _openEyesEARs = [];
  CalibrationResult? _lastResult;
  CalibrationResult? get lastResult => _lastResult;

  void startCalibration() {
    _isCalibrating = true;
    _isCalibrated = false;
    _currentStep = CalibrationStep.faceDetection;
    _resetData();
    _emitProgress(0.0, 'Centra tu rostro en la cámara');
  }

  void resetCalibration() {
    _isCalibrating = false;
    _isCalibrated = false;
    _resetData();
    _currentStep = CalibrationStep.faceDetection;
  }

  void processFrame({List<FaceMeshPoint>? points, double brightness = 0.5}) {
    if (!_isCalibrating) return;

    if (points == null || points.isEmpty) {
      if (_currentStep != CalibrationStep.completed) {
        _emitProgress(0.0, 'No se detecta rostro', requiresAction: true);
      }
      return;
    }

    switch (_currentStep) {
      case CalibrationStep.faceDetection:
        _handleFaceDetection(points);
        break;
      case CalibrationStep.lighting:
        _handleLighting(brightness);
        break;
      case CalibrationStep.eyeBaseline:
        _handleEyeBaseline(points);
        break;
      case CalibrationStep.completed:
        break;
    }
  }

  void _handleFaceDetection(List<FaceMeshPoint> points) {
    if (points.isNotEmpty) {
      _currentStep = CalibrationStep.lighting;
      _emitProgress(0.2, 'Verificando iluminación...', shouldVibrate: true);
    }
  }

  void _handleLighting(double brightness) {
    if (brightness > 0.3) {
      _currentStep = CalibrationStep.eyeBaseline;
      _emitProgress(0.4, 'Mantén los ojos abiertos y mira al frente', shouldVibrate: true);
    } else {
      _emitProgress(0.3, 'Aumenta la iluminación', requiresAction: true);
    }
  }

  void _handleEyeBaseline(List<FaceMeshPoint> points) {
    _collectSamples(points);

    double progress = 0.4 + (_openEyesEARs.length / 30) * 0.6;
    progress = min(progress, 0.95);

    if (_openEyesEARs.length >= 30) {
      _finishCalibration();
    } else {
      _emitProgress(progress, 'Calibrando ojos...', actionMessage: 'Mantén ojos abiertos');
    }
  }

  void _collectSamples(List<FaceMeshPoint> points) {
    double leftEar = _calculateEAR(points, LandmarkIndices.leftEye);
    double rightEar = _calculateEAR(points, LandmarkIndices.rightEye);
    double avgEar = (leftEar + rightEar) / 2.0;

    if (avgEar > 0.15) {
      _openEyesEARs.add(avgEar);
    }
  }

  double _calculateEAR(List<FaceMeshPoint> allPoints, List<int> indices) {
    if (indices.length < 6) return 0.0;
    FaceMeshPoint p1 = allPoints[indices[0]];
    FaceMeshPoint p2 = allPoints[indices[1]];
    FaceMeshPoint p3 = allPoints[indices[2]];
    FaceMeshPoint p4 = allPoints[indices[3]];
    FaceMeshPoint p5 = allPoints[indices[4]];
    FaceMeshPoint p6 = allPoints[indices[5]];

    double v1 = _distance(p2, p6);
    double v2 = _distance(p3, p5);
    double h = _distance(p1, p4);

    if (h == 0) return 0.0;
    return (v1 + v2) / (2.0 * h);
  }

  double _distance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  void _finishCalibration() {
    _isCalibrating = false;
    _isCalibrated = true;
    _currentStep = CalibrationStep.completed;

    double sum = _openEyesEARs.fold(0, (prev, element) => prev + element);
    double avgOpen = sum / _openEyesEARs.length;
    double calculatedThreshold = avgOpen * 0.8;

    _lastResult = CalibrationResult(
      isSuccessful: true,
      earThreshold: calculatedThreshold,
      baselinePitch: 0,
      baselineYaw: 0,
    );

    _emitProgress(1.0, '¡Calibración completada!', shouldVibrate: true);
  }

  void _resetData() {
    _openEyesEARs.clear();
  }

  void _emitProgress(double progress, String message, {bool shouldVibrate = false, bool requiresAction = false, String? actionMessage}) {
    _progressController.add(CalibrationProgress(
      step: _currentStep,
      stepProgress: progress,
      message: message,
      shouldVibrate: shouldVibrate,
      requiresAction: requiresAction,
      actionMessage: actionMessage,
    ));
  }

  void dispose() {
    _progressController.close();
  }
}