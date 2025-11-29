import 'dart:collection';
import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

class AttentionResult {
  final double pitch;
  final double yaw;
  final double roll;
  final bool isLookingAtScreen;
  final int notLookingFrames;

  AttentionResult({
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.isLookingAtScreen,
    required this.notLookingFrames,
  });
}

class AttentionAnalyzer {
  final double _pitchThreshold;
  final double _yawThreshold;
  final int _notLookingFramesThreshold;
  final int _calibrationFramesRequired;
  final double _calibrationStabilityThreshold;

  int _notLookingCounter = 0;
  double? _baselinePitch;
  double? _baselineYaw;

  final ListQueue<List<double>> _calibrationFrames = ListQueue();
  bool _isCalibrated = false;
  final ListQueue<List<double>> _poseHistory = ListQueue();

  AttentionAnalyzer({
    double pitchThreshold = 45.0,
    double yawThreshold = 45.0,
    int notLookingFramesThreshold = 25,
    int calibrationFramesRequired = 30,
    double calibrationStabilityThreshold = 15.0,
  })  : _pitchThreshold = pitchThreshold,
        _yawThreshold = yawThreshold,
        _notLookingFramesThreshold = notLookingFramesThreshold,
        _calibrationFramesRequired = calibrationFramesRequired,
        _calibrationStabilityThreshold = calibrationStabilityThreshold;

  bool get isCalibrated => _isCalibrated;

  void applyCalibration({
    required double baselinePitch,
    required double baselineYaw,
  }) {
    _baselinePitch = baselinePitch;
    _baselineYaw = baselineYaw;
    _isCalibrated = true;
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

  double _distance2D(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
  }

  List<double> _smoothPose(double pitch, double yaw) {
    _poseHistory.addLast([pitch, yaw]);

    while (_poseHistory.length > 5) {
      _poseHistory.removeFirst();
    }

    if (_poseHistory.length < 2) {
      return [pitch, yaw];
    }

    final pitches = _poseHistory.map((p) => p[0]).toList();
    final yaws = _poseHistory.map((p) => p[1]).toList();

    return [_median(pitches), _median(yaws)];
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    } else {
      return (sorted[mid - 1] + sorted[mid]) / 2;
    }
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return double.infinity;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  void _calibrate(double pitch, double yaw) {
    _calibrationFrames.addLast([pitch, yaw]);
    while (_calibrationFrames.length > _calibrationFramesRequired) {
      _calibrationFrames.removeFirst();
    }

    if (_calibrationFrames.length >= _calibrationFramesRequired && !_isCalibrated) {
      final pitches = _calibrationFrames.map((f) => f[0]).toList();
      final yaws = _calibrationFrames.map((f) => f[1]).toList();

      final pitchStd = _standardDeviation(pitches);
      final yawStd = _standardDeviation(yaws);

      if (pitchStd < _calibrationStabilityThreshold &&
          yawStd < _calibrationStabilityThreshold) {
        _baselinePitch = _median(pitches);
        _baselineYaw = _median(yaws);
        _isCalibrated = true;
      }
    }
  }

  AttentionResult analyze(List<FaceMeshPoint> points) {
    final rawDirection = _calculateFaceDirection(points);
    final smoothed = _smoothPose(rawDirection[0], rawDirection[1]);
    final pitch = smoothed[0];
    final yaw = smoothed[1];

    if (!_isCalibrated) {
      _calibrate(pitch, yaw);
      return AttentionResult(
        pitch: pitch,
        yaw: yaw,
        roll: 0.0,
        isLookingAtScreen: true,
        notLookingFrames: 0,
      );
    }

    final relativePitch = pitch - (_baselinePitch ?? 0);
    final relativeYaw = yaw - (_baselineYaw ?? 0);

    final isLooking = relativePitch.abs() <= _pitchThreshold &&
        relativeYaw.abs() <= _yawThreshold;

    if (!isLooking) {
      _notLookingCounter++;
    } else {
      _notLookingCounter = max(0, _notLookingCounter - 2);
    }

    final sustainedNotLooking = _notLookingCounter >= _notLookingFramesThreshold;

    return AttentionResult(
      pitch: relativePitch,
      yaw: relativeYaw,
      roll: 0.0,
      isLookingAtScreen: !sustainedNotLooking,
      notLookingFrames: _notLookingCounter,
    );
  }

  void reset() {
    _notLookingCounter = 0;
  }

  void resetCalibration() {
    _baselinePitch = null;
    _baselineYaw = null;
    _calibrationFrames.clear();
    _isCalibrated = false;
    _poseHistory.clear();
    _notLookingCounter = 0;
  }

  Map<String, dynamic> getStats() {
    return {
      'isCalibrated': _isCalibrated,
      'baselinePitch': _baselinePitch,
      'baselineYaw': _baselineYaw,
      'notLookingCounter': _notLookingCounter,
    };
  }
}