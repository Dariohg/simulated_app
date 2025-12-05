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
      rightEyeOuter.x,
      rightEyeOuter.y,
      leftEyeOuter.x,
      leftEyeOuter.y,
    );

    final faceHeight = _distance2D(
      eyeCenterX,
      eyeCenterY,
      chin.x.toDouble(),
      chin.y.toDouble(),
    );

    if (faceWidth < 1 || faceHeight < 1) {
      return [0.0, 0.0, 0.0];
    }

    final yaw = ((nose.x - eyeCenterX) / faceWidth) * 90.0;
    final pitch = ((nose.y - eyeCenterY) / faceHeight) * 90.0;

    final roll = atan2(
      rightEyeOuter.y - leftEyeOuter.y,
      rightEyeOuter.x - leftEyeOuter.x,
    ) *
        (180.0 / pi);

    return [pitch, yaw, roll];
  }

  double _distance2D(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  AttentionResult analyze(List<FaceMeshPoint> points) {
    final direction = _calculateFaceDirection(points);
    var pitch = direction[0];
    var yaw = direction[1];
    final roll = direction[2];

    if (!_isCalibrated) {
      _calibrationFrames.add([pitch, yaw]);
      if (_calibrationFrames.length > _calibrationFramesRequired) {
        _calibrationFrames.removeFirst();
      }

      if (_calibrationFrames.length >= _calibrationFramesRequired) {
        final pitchValues = _calibrationFrames.map((f) => f[0]).toList();
        final yawValues = _calibrationFrames.map((f) => f[1]).toList();

        final pitchStd = _standardDeviation(pitchValues);
        final yawStd = _standardDeviation(yawValues);

        if (pitchStd < _calibrationStabilityThreshold &&
            yawStd < _calibrationStabilityThreshold) {
          _baselinePitch = _mean(pitchValues);
          _baselineYaw = _mean(yawValues);
          _isCalibrated = true;
        }
      }
    }

    if (_isCalibrated) {
      pitch -= _baselinePitch!;
      yaw -= _baselineYaw!;
    }

    _poseHistory.add([pitch.abs(), yaw.abs()]);
    if (_poseHistory.length > 5) {
      _poseHistory.removeFirst();
    }

    final avgPitch = _mean(_poseHistory.map((p) => p[0]).toList());
    final avgYaw = _mean(_poseHistory.map((p) => p[1]).toList());

    final isLooking = avgPitch < _pitchThreshold && avgYaw < _yawThreshold;

    if (!isLooking) {
      _notLookingCounter = min(_notLookingCounter + 1, _notLookingFramesThreshold + 10);
    } else {
      _notLookingCounter = max(0, _notLookingCounter - 2);
    }

    final isLookingAtScreen = _notLookingCounter < _notLookingFramesThreshold;

    return AttentionResult(
      pitch: pitch,
      yaw: yaw,
      roll: roll,
      isLookingAtScreen: isLookingAtScreen,
      notLookingFrames: _notLookingCounter,
    );
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = _mean(values);
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    return sqrt(squaredDiffs.reduce((a, b) => a + b) / values.length);
  }

  void reset() {
    _notLookingCounter = 0;
    _calibrationFrames.clear();
    _poseHistory.clear();
    _isCalibrated = false;
    _baselinePitch = null;
    _baselineYaw = null;
  }
}