import 'dart:collection';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

class AttentionResult {
  final double pitch;
  final double yaw;
  final bool isLookingAtScreen;

  AttentionResult({
    required this.pitch,
    required this.yaw,
    required this.isLookingAtScreen,
  });
}

class AttentionAnalyzer {
  final double _pitchThreshold = 45.0;
  final double _yawThreshold = 45.0;
  final int _notLookingFramesThreshold = 25;

  int _notLookingCounter = 0;
  double? _baselinePitch;
  double? _baselineYaw;
  final ListQueue<List<double>> _calibrationFrames = ListQueue(30);
  bool _isCalibrated = false;
  final ListQueue<List<double>> _poseHistory = ListQueue(5);

  bool get isCalibrated => _isCalibrated;

  List<double> _calculateFaceDirection(List<FaceMeshPoint> points) {
    final nose = points[LandmarkIndices.noseTip];
    final leftEye = points[LandmarkIndices.leftEyeOuter];
    final rightEye = points[LandmarkIndices.rightEyeOuter];
    final chin = points[LandmarkIndices.chin];

    final eyeCenterX = (leftEye.x + rightEye.x) / 2;
    final eyeCenterY = (leftEye.y + rightEye.y) / 2;

    final faceWidth = (rightEye.x - leftEye.x).abs();
    if (faceWidth < 1) return [0.0, 0.0];

    final horizontalOffset = (nose.x - eyeCenterX) / faceWidth;
    final yaw = horizontalOffset * 90;

    final faceHeight = (chin.y - eyeCenterY).abs();
    if (faceHeight < 1) return [0.0, yaw];

    final verticalOffset = (nose.y - eyeCenterY) / faceHeight;
    final pitch = (verticalOffset - 0.3) * 90;

    return [pitch, yaw];
  }

  List<double> _smoothPose(double pitch, double yaw) {
    _poseHistory.add([pitch, yaw]);
    if (_poseHistory.length > 5) _poseHistory.removeFirst();

    if (_poseHistory.length < 2) return [pitch, yaw];

    double sumPitch = 0;
    double sumYaw = 0;
    for (var pose in _poseHistory) {
      sumPitch += pose[0];
      sumYaw += pose[1];
    }
    return [sumPitch / _poseHistory.length, sumYaw / _poseHistory.length];
  }

  void _calibrate(double pitch, double yaw) {
    _calibrationFrames.add([pitch, yaw]);
    if (_calibrationFrames.length > 30) _calibrationFrames.removeFirst();

    if (_calibrationFrames.length >= 30 && !_isCalibrated) {
      double sumPitch = 0;
      double sumYaw = 0;
      for (var frame in _calibrationFrames) {
        sumPitch += frame[0];
        sumYaw += frame[1];
      }
      _baselinePitch = sumPitch / 30;
      _baselineYaw = sumYaw / 30;
      _isCalibrated = true;
      print("[INFO] Calibración completada");
    }
  }

  AttentionResult analyze(List<FaceMeshPoint> points) {
    final rawDirection = _calculateFaceDirection(points);
    final smoothed = _smoothPose(rawDirection[0], rawDirection[1]);
    final pitch = smoothed[0];
    final yaw = smoothed[1];

    if (!_isCalibrated) {
      _calibrate(pitch, yaw);
      return AttentionResult(pitch: pitch, yaw: yaw, isLookingAtScreen: true);
    }

    final relativePitch = pitch - (_baselinePitch ?? 0);
    final relativeYaw = yaw - (_baselineYaw ?? 0);

    final isLooking = relativePitch.abs() <= _pitchThreshold &&
        relativeYaw.abs() <= _yawThreshold;

    if (!isLooking) {
      _notLookingCounter++;
    } else {
      _notLookingCounter = _notLookingCounter > 1 ? _notLookingCounter - 2 : 0;
    }

    return AttentionResult(
      pitch: relativePitch,
      yaw: relativeYaw,
      isLookingAtScreen: _notLookingCounter < _notLookingFramesThreshold,
    );
  }

  void resetCalibration() {
    _baselinePitch = null;
    _baselineYaw = null;
    _calibrationFrames.clear();
    _isCalibrated = false;
    _poseHistory.clear();
    _notLookingCounter = 0;
  }
}