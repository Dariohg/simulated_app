import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

enum CalibrationStep {
  faceDetection,
  lighting,
  eyeBaseline,
  completed,
}

class CalibrationResult {
  final bool isSuccessful;
  final double? baselineEAR;
  final double? earThreshold;
  final double? baselinePitch;
  final double? baselineYaw;
  final double? avgBrightness;
  final String? errorMessage;
  final DateTime calibratedAt;

  CalibrationResult({
    required this.isSuccessful,
    this.baselineEAR,
    this.earThreshold,
    this.baselinePitch,
    this.baselineYaw,
    this.avgBrightness,
    this.errorMessage,
    DateTime? calibratedAt,
  }) : calibratedAt = calibratedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'isSuccessful': isSuccessful,
      'baselineEAR': baselineEAR,
      'earThreshold': earThreshold,
      'baselinePitch': baselinePitch,
      'baselineYaw': baselineYaw,
      'avgBrightness': avgBrightness,
      'calibratedAt': calibratedAt.toIso8601String(),
    };
  }

  factory CalibrationResult.fromMap(Map<String, dynamic> map) {
    return CalibrationResult(
      isSuccessful: map['isSuccessful'] ?? false,
      baselineEAR: map['baselineEAR'],
      earThreshold: map['earThreshold'],
      baselinePitch: map['baselinePitch'],
      baselineYaw: map['baselineYaw'],
      avgBrightness: map['avgBrightness'],
      calibratedAt: map['calibratedAt'] != null
          ? DateTime.parse(map['calibratedAt'])
          : DateTime.now(),
    );
  }
}

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
  static const int _framesForFaceDetection = 30;
  static const int _framesForLighting = 20;
  static const int _framesForEyeOpen = 30;
  static const int _framesForEyeClosed = 20;
  static const double _minBrightness = 0.3;
  static const double _maxBrightness = 0.9;

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
  bool _vibrationTriggered = false;

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
    _emitProgress('Coloca tu rostro frente a la camara', 0.0);
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
    _vibrationTriggered = false;
  }

  CalibrationProgress? processFrame({
    required List<FaceMeshPoint>? points,
    required double? brightness,
  }) {
    if (!_isCalibrating) return null;

    switch (_currentStep) {
      case CalibrationStep.faceDetection:
        return _processFaceDetection(points);
      case CalibrationStep.lighting:
        return _processLighting(points, brightness);
      case CalibrationStep.eyeBaseline:
        return _processEyeBaseline(points);
      case CalibrationStep.completed:
        return null;
    }
  }

  CalibrationProgress _processFaceDetection(List<FaceMeshPoint>? points) {
    if (points == null || points.length < 468) {
      _faceDetectionScores.add(0.0);
    } else {
      final stability = _calculateFaceStability(points);
      _faceDetectionScores.add(stability);
      _collectPoseData(points);
    }

    if (_faceDetectionScores.length > _framesForFaceDetection) {
      _faceDetectionScores.removeAt(0);
    }

    final progress = _faceDetectionScores.length / _framesForFaceDetection;
    final avgStability = _faceDetectionScores.isEmpty
        ? 0.0
        : _faceDetectionScores.reduce((a, b) => a + b) / _faceDetectionScores.length;

    if (_faceDetectionScores.length >= _framesForFaceDetection &&
        avgStability > 0.7) {
      _currentStep = CalibrationStep.lighting;
      _brightnessValues.clear();
      return _emitProgress('Rostro detectado. Verificando iluminacion...', 1.0);
    }

    String message;
    if (points == null || points.length < 468) {
      message = 'No se detecta rostro. Acercate a la camara.';
    } else if (avgStability < 0.5) {
      message = 'Manten el rostro quieto y centrado.';
    } else {
      message = 'Detectando rostro... Manten la posicion.';
    }

    return _emitProgress(message, progress);
  }

  CalibrationProgress _processLighting(List<FaceMeshPoint>? points, double? brightness) {
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

    String message;
    bool lightingOk = false;

    if (avgBrightness < _minBrightness) {
      message = 'Iluminacion muy baja. Busca mejor luz.';
    } else if (avgBrightness > _maxBrightness) {
      message = 'Iluminacion muy alta. Evita luz directa.';
    } else {
      lightingOk = true;
      message = 'Iluminacion correcta.';
    }

    if (_brightnessValues.length >= _framesForLighting && lightingOk) {
      _currentStep = CalibrationStep.eyeBaseline;
      _eyeOpenEARValues.clear();
      _waitingForEyeClose = false;
      _vibrationTriggered = false;
      return _emitProgress(
        'Manten los ojos abiertos naturalmente.',
        1.0,
        requiresAction: true,
        actionMessage: 'Ojos abiertos',
      );
    }

    return _emitProgress(message, progress);
  }

  CalibrationProgress _processEyeBaseline(List<FaceMeshPoint>? points) {
    if (points == null || points.length < 468) {
      return _emitProgress(
        'Rostro perdido. Vuelve a posicionarte.',
        0.0,
      );
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
        _vibrationTriggered = false;
        return _emitProgress(
          'Ahora cierra los ojos por 2 segundos.',
          0.5,
          requiresAction: true,
          actionMessage: 'Cierra los ojos',
          shouldVibrate: true,
        );
      }

      return _emitProgress(
        'Manten los ojos abiertos naturalmente.',
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
        return _emitProgress(
          'Calibracion completada.',
          1.0,
          shouldVibrate: true,
        );
      }

      return _emitProgress(
        'Manten los ojos cerrados...',
        progress,
        requiresAction: true,
        actionMessage: 'Ojos cerrados',
      );
    }
  }

  void _completeCalibration() {
    final avgOpenEAR = _eyeOpenEARValues.isEmpty
        ? 0.25
        : _eyeOpenEARValues.reduce((a, b) => a + b) / _eyeOpenEARValues.length;

    final avgClosedEAR = _eyeClosedEARValues.isEmpty
        ? 0.15
        : _eyeClosedEARValues.reduce((a, b) => a + b) / _eyeClosedEARValues.length;

    final earThreshold = avgClosedEAR + (avgOpenEAR - avgClosedEAR) * 0.4;

    final avgPitch = _pitchValues.isEmpty
        ? 0.0
        : _pitchValues.reduce((a, b) => a + b) / _pitchValues.length;

    final avgYaw = _yawValues.isEmpty
        ? 0.0
        : _yawValues.reduce((a, b) => a + b) / _yawValues.length;

    final avgBrightness = _brightnessValues.isEmpty
        ? 0.5
        : _brightnessValues.reduce((a, b) => a + b) / _brightnessValues.length;

    _lastResult = CalibrationResult(
      isSuccessful: true,
      baselineEAR: avgOpenEAR,
      earThreshold: earThreshold,
      baselinePitch: avgPitch,
      baselineYaw: avgYaw,
      avgBrightness: avgBrightness,
    );

    _currentStep = CalibrationStep.completed;
    _isCalibrating = false;

    debugPrint('[CalibrationService] Calibracion completada:');
    debugPrint('[CalibrationService]   EAR ojos abiertos: ${avgOpenEAR.toStringAsFixed(4)}');
    debugPrint('[CalibrationService]   EAR ojos cerrados: ${avgClosedEAR.toStringAsFixed(4)}');
    debugPrint('[CalibrationService]   Umbral EAR: ${earThreshold.toStringAsFixed(4)}');
    debugPrint('[CalibrationService]   Pitch base: ${avgPitch.toStringAsFixed(2)}');
    debugPrint('[CalibrationService]   Yaw base: ${avgYaw.toStringAsFixed(2)}');
  }

  double _calculateFaceStability(List<FaceMeshPoint> points) {
    if (points.length < 468) return 0.0;

    final leftEye = points[LandmarkIndices.leftEyeOuter];
    final rightEye = points[LandmarkIndices.rightEyeOuter];

    final faceWidth = _distance2D(leftEye.x, leftEye.y, rightEye.x, rightEye.y);

    if (faceWidth < 50) return 0.3;
    if (faceWidth < 80) return 0.6;
    if (faceWidth < 120) return 0.8;
    return 1.0;
  }

  void _collectPoseData(List<FaceMeshPoint> points) {
    final direction = _calculateFaceDirection(points);
    _pitchValues.add(direction[0]);
    _yawValues.add(direction[1]);

    while (_pitchValues.length > 60) {
      _pitchValues.removeAt(0);
      _yawValues.removeAt(0);
    }
  }

  List<double> _calculateFaceDirection(List<FaceMeshPoint> points) {
    final nose = points[LandmarkIndices.noseTip];
    final leftEyeOuter = points[LandmarkIndices.leftEyeOuter];
    final rightEyeOuter = points[LandmarkIndices.rightEyeOuter];
    final chin = points[LandmarkIndices.chin];

    final eyeCenterX = (leftEyeOuter.x + rightEyeOuter.x) / 2;
    final eyeCenterY = (leftEyeOuter.y + rightEyeOuter.y) / 2;

    final faceWidth = _distance2D(
      rightEyeOuter.x, rightEyeOuter.y,
      leftEyeOuter.x, leftEyeOuter.y,
    );

    if (faceWidth < 1) return [0.0, 0.0];

    final horizontalOffset = (nose.x - eyeCenterX) / faceWidth;
    final yaw = horizontalOffset * 90;

    final faceHeight = _distance2D(chin.x, chin.y, eyeCenterX, eyeCenterY);

    if (faceHeight < 1) return [0.0, yaw];

    final verticalOffset = (nose.y - eyeCenterY) / faceHeight;
    final pitch = (verticalOffset - 0.3) * 90;

    return [pitch, yaw];
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

  CalibrationProgress _emitProgress(
      String message,
      double progress, {
        bool requiresAction = false,
        String? actionMessage,
        bool shouldVibrate = false,
      }) {
    final result = CalibrationProgress(
      currentStep: _currentStep,
      stepProgress: progress.clamp(0.0, 1.0),
      message: message,
      requiresAction: requiresAction,
      actionMessage: actionMessage,
      shouldVibrate: shouldVibrate,
    );
    _progressController.add(result);
    return result;
  }

  void dispose() {
    _progressController.close();
  }
}