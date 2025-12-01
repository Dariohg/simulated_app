import 'dart:async';
import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../../core/utils/landmark_indices.dart';
import '../models/calibration_result.dart'; // Import correcto del modelo

enum CalibrationStep { faceDetection, lighting, eyeBaseline, completed }

class CalibrationProgress {
  final CalibrationStep currentStep;
  final double stepProgress;
  final String message;
  final bool requiresAction;
  final String? actionMessage;
  final bool shouldVibrate;

  CalibrationProgress({
    required this.currentStep,
    required this.stepProgress,
    required this.message,
    this.requiresAction = false,
    this.actionMessage,
    this.shouldVibrate = false,
  });
}

class CalibrationService {
  static const int _framesBuffer = 60;
  static const int _targetGoodFrames = 45;
  static const double _stabilityThreshold = 0.4;
  static const int _framesForLighting = 25;
  static const int _framesForEyeOpen = 40;
  static const int _framesForEyeClosed = 25;

  CalibrationStep _currentStep = CalibrationStep.faceDetection;
  CalibrationResult? _lastResult;

  final List<double> _faceDetectionScores = [];
  final List<double> _brightnessValues = [];
  final List<double> _eyeOpenEARValues = [];
  final List<double> _eyeClosedEARValues = [];
  final List<double> _pitchValues = [];
  final List<double> _yawValues = [];

  bool _isCalibrating = false;
  bool _waitingForEyeClose = false;

  final StreamController<CalibrationProgress> _progressController =
  StreamController<CalibrationProgress>.broadcast();

  Stream<CalibrationProgress> get progressStream => _progressController.stream;
  CalibrationStep get currentStep => _currentStep;
  bool get isCalibrating => _isCalibrating;
  bool get isCalibrated => _lastResult?.isSuccessful ?? false;
  CalibrationResult? get lastResult => _lastResult;

  void startCalibration() {
    _isCalibrating = true;
    _currentStep = CalibrationStep.faceDetection;
    _clearBuffers();
    _emitProgress('Coloca tu rostro frente a la cámara', 0.0);
  }

  void resetCalibration() {
    _isCalibrating = false;
    _lastResult = null;
    _currentStep = CalibrationStep.faceDetection;
    _clearBuffers();
  }

  void _clearBuffers() {
    _faceDetectionScores.clear();
    _brightnessValues.clear();
    _eyeOpenEARValues.clear();
    _eyeClosedEARValues.clear();
    _pitchValues.clear();
    _yawValues.clear();
    _waitingForEyeClose = false;
  }

  void processFrame({
    required List<FaceMeshPoint>? points,
    required double? brightness,
  }) {
    if (!_isCalibrating || _progressController.isClosed) return;

    switch (_currentStep) {
      case CalibrationStep.faceDetection:
        _processFaceDetection(points);
        break;
      case CalibrationStep.lighting:
        _processLighting(points, brightness);
        break;
      case CalibrationStep.eyeBaseline:
        _processEyeBaseline(points);
        break;
      case CalibrationStep.completed:
        break;
    }
  }

  void _processFaceDetection(List<FaceMeshPoint>? points) {
    double currentFrameStability = 0.0;
    bool isFaceDetected = points != null && points.length >= 468;

    if (isFaceDetected) {
      currentFrameStability = _calculateFaceStability(points);
      if (currentFrameStability >= 0.3) {
        _collectPoseData(points);
      }
    }

    _faceDetectionScores.add(currentFrameStability);
    if (_faceDetectionScores.length > _framesBuffer) {
      _faceDetectionScores.removeAt(0);
    }

    int goodFramesCount = _faceDetectionScores
        .where((score) => score >= _stabilityThreshold)
        .length;

    double progress = goodFramesCount / _targetGoodFrames;

    if (goodFramesCount >= _targetGoodFrames) {
      _currentStep = CalibrationStep.lighting;
      _brightnessValues.clear();
      _emitProgress('Rostro detectado. Verificando luz...', 1.0);
      return;
    }

    String message;
    if (!isFaceDetected) {
      message = 'No se detecta rostro.';
    } else if (currentFrameStability < _stabilityThreshold) {
      message = 'Acércate un poco más y mantén la posición.';
    } else {
      message = 'Analizando rostro... ${(progress * 100).toInt()}%';
    }

    _emitProgress(message, progress);
  }

  void _processLighting(List<FaceMeshPoint>? points, double? brightness) {
    if (points == null || points.length < 468) {
      _emitProgress('Rostro perdido.', 0.0);
      return;
    }

    if (brightness != null) {
      _brightnessValues.add(brightness);
    }

    if (_brightnessValues.length > _framesForLighting) {
      _brightnessValues.removeAt(0);
    }

    final progress = _brightnessValues.length / _framesForLighting;
    final avgBrightness = _brightnessValues.isEmpty
        ? 0.5
        : _brightnessValues.reduce((a, b) => a + b) / _brightnessValues.length;

    String message = 'Verificando luz...';
    bool lightingOk = avgBrightness >= 0.2 && avgBrightness <= 0.95;

    if (avgBrightness < 0.2) message = 'Poca luz detectada.';
    if (avgBrightness > 0.95) message = 'Demasiada luz.';

    if (_brightnessValues.length >= _framesForLighting && lightingOk) {
      _currentStep = CalibrationStep.eyeBaseline;
      _eyeOpenEARValues.clear();
      _waitingForEyeClose = false;
      _emitProgress(
        'Listo. Mantén los ojos abiertos.',
        1.0,
        requiresAction: true,
        actionMessage: 'Ojos abiertos',
      );
      return;
    }

    _emitProgress(message, progress);
  }

  void _processEyeBaseline(List<FaceMeshPoint>? points) {
    if (points == null || points.length < 468) {
      _emitProgress('Rostro perdido.', 0.0);
      return;
    }

    final ear = _calculateEAR(points);

    if (!_waitingForEyeClose) {
      _eyeOpenEARValues.add(ear);
      if (_eyeOpenEARValues.length > _framesForEyeOpen) {
        _eyeOpenEARValues.removeAt(0);
      }

      final progress = _eyeOpenEARValues.length / _framesForEyeOpen;

      if (_eyeOpenEARValues.length >= _framesForEyeOpen) {
        _waitingForEyeClose = true;
        _eyeClosedEARValues.clear();
        _emitProgress(
          'Ahora cierra los ojos por 2 segundos.',
          0.5,
          requiresAction: true,
          actionMessage: 'Cierra los ojos',
          shouldVibrate: true,
        );
        return;
      }

      _emitProgress(
        'Midiendo ojos abiertos...',
        progress * 0.5,
        requiresAction: true,
        actionMessage: 'Ojos abiertos',
      );
    } else {
      _eyeClosedEARValues.add(ear);
      if (_eyeClosedEARValues.length > _framesForEyeClosed) {
        _eyeClosedEARValues.removeAt(0);
      }

      final progress = 0.5 + (_eyeClosedEARValues.length / _framesForEyeClosed) * 0.5;

      if (_eyeClosedEARValues.length >= _framesForEyeClosed) {
        _completeCalibration();
        _emitProgress(
          'Calibración completada.',
          1.0,
          shouldVibrate: true,
        );
        return;
      }

      _emitProgress(
        'Mantén los ojos cerrados...',
        progress,
        requiresAction: true,
        actionMessage: 'Ojos cerrados',
      );
    }
  }

  void _completeCalibration() {
    final avgOpenEAR = _eyeOpenEARValues.isEmpty
        ? 0.30
        : _eyeOpenEARValues.reduce((a, b) => a + b) / _eyeOpenEARValues.length;

    final avgClosedEAR = _eyeClosedEARValues.isEmpty
        ? 0.15
        : _eyeClosedEARValues.reduce((a, b) => a + b) / _eyeClosedEARValues.length;

    final earThreshold = avgClosedEAR + (avgOpenEAR - avgClosedEAR) * 0.4;

    // Aquí usamos el constructor del modelo importado
    _lastResult = CalibrationResult(
      isSuccessful: true,
      baselineEAR: avgOpenEAR,
      earThreshold: earThreshold,
      baselinePitch: 0,
      baselineYaw: 0,
      avgBrightness: 0.5,
      calibratedAt: DateTime.now(),
    );

    _currentStep = CalibrationStep.completed;
    _isCalibrating = false;
  }

  double _calculateFaceStability(List<FaceMeshPoint> points) {
    if (points.length < 468) return 0.0;
    final leftEye = points[LandmarkIndices.leftEyeOuter];
    final rightEye = points[LandmarkIndices.rightEyeOuter];
    final faceWidth = _distance2D(leftEye.x, leftEye.y, rightEye.x, rightEye.y);

    if (faceWidth < 10) return 0.0;
    if (faceWidth < 20) return 0.4;
    if (faceWidth < 35) return 0.6;
    return 1.0;
  }

  void _collectPoseData(List<FaceMeshPoint> points) {
    // Implementación simplificada
  }

  double _calculateEAR(List<FaceMeshPoint> points) {
    final leftEar = _calculateSingleEyeEAR(points, LandmarkIndices.leftEye);
    final rightEar = _calculateSingleEyeEAR(points, LandmarkIndices.rightEye);
    return (leftEar + rightEar) / 2.0;
  }

  double _calculateSingleEyeEAR(List<FaceMeshPoint> points, List<int> eyeIndices) {
    if (eyeIndices.length < 6) return 0.0;
    final p1 = points[eyeIndices[0]];
    final p2 = points[eyeIndices[1]];
    final p3 = points[eyeIndices[2]];
    final p4 = points[eyeIndices[3]];
    final p5 = points[eyeIndices[4]];
    final p6 = points[eyeIndices[5]];

    final vertical1 = _distance2D(p2.x, p2.y, p6.x, p6.y);
    final vertical2 = _distance2D(p3.x, p3.y, p5.x, p5.y);
    final horizontal = _distance2D(p1.x, p1.y, p4.x, p4.y);

    if (horizontal == 0) return 0.0;
    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  double _distance2D(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
  }

  void _emitProgress(String message, double progress, {bool requiresAction = false, String? actionMessage, bool shouldVibrate = false}) {
    if (_progressController.isClosed) return;
    _progressController.add(CalibrationProgress(
      currentStep: _currentStep,
      stepProgress: progress.clamp(0.0, 1.0),
      message: message,
      requiresAction: requiresAction,
      actionMessage: actionMessage,
      shouldVibrate: shouldVibrate,
    ));
  }

  void dispose() {
    _progressController.close();
  }
}