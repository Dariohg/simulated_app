import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

class DrowsinessResult {
  final double ear;
  final double mar;
  final bool isDrowsy;
  final bool isYawning;
  final int drowsyFrames;
  final int yawnFrames;

  DrowsinessResult({
    required this.ear,
    required this.mar,
    required this.isDrowsy,
    required this.isYawning,
    required this.drowsyFrames,
    required this.yawnFrames,
  });
}

class DrowsinessAnalyzer {
  double _earThreshold;
  final double _marThreshold;
  final int _drowsyFramesThreshold;
  final int _yawnFramesThreshold;
  final int _maxDrowsyBuffer;
  final int _maxYawnBuffer;

  int _drowsyCounter = 0;
  int _yawnCounter = 0;

  DrowsinessAnalyzer({
    double earThreshold = 0.21,
    double marThreshold = 0.6,
    int drowsyFramesThreshold = 20,
    int yawnFramesThreshold = 15,
    int maxDrowsyBuffer = 30,
    int maxYawnBuffer = 20,
  })  : _earThreshold = earThreshold,
        _marThreshold = marThreshold,
        _drowsyFramesThreshold = drowsyFramesThreshold,
        _yawnFramesThreshold = yawnFramesThreshold,
        _maxDrowsyBuffer = maxDrowsyBuffer,
        _maxYawnBuffer = maxYawnBuffer;

  void updateEarThreshold(double newThreshold) {
    _earThreshold = newThreshold;
  }

  double _distance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
  }

  double _calculateEAR(List<FaceMeshPoint> points, List<int> eyeIndices) {
    final p1 = points[eyeIndices[0]];
    final p2 = points[eyeIndices[1]];
    final p3 = points[eyeIndices[2]];
    final p4 = points[eyeIndices[3]];
    final p5 = points[eyeIndices[4]];
    final p6 = points[eyeIndices[5]];

    final vertical1 = _distance(p2, p6);
    final vertical2 = _distance(p3, p5);
    final horizontal = _distance(p1, p4);

    if (horizontal == 0) return 0.0;
    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  double _calculateMAR(List<FaceMeshPoint> points, List<int> mouthIndices) {
    final top = points[mouthIndices[0]];
    final bottom = points[mouthIndices[1]];
    final left = points[mouthIndices[2]];
    final right = points[mouthIndices[3]];

    final vertical = _distance(top, bottom);
    final horizontal = _distance(left, right);

    if (horizontal == 0) return 0.0;
    return vertical / horizontal;
  }

  DrowsinessResult analyze(List<FaceMeshPoint> points) {
    final leftEar = _calculateEAR(points, LandmarkIndices.leftEye);
    final rightEar = _calculateEAR(points, LandmarkIndices.rightEye);
    final ear = (leftEar + rightEar) / 2.0;
    final mar = _calculateMAR(points, LandmarkIndices.mouth);

    if (ear < _earThreshold) {
      _drowsyCounter = min(_drowsyCounter + 1, _maxDrowsyBuffer);
    } else {
      _drowsyCounter = max(0, _drowsyCounter - 1);
    }

    if (mar > _marThreshold) {
      _yawnCounter = min(_yawnCounter + 1, _maxYawnBuffer);
    } else {
      _yawnCounter = max(0, _yawnCounter - 1);
    }

    final isDrowsy = _drowsyCounter >= _drowsyFramesThreshold;
    final isYawning = _yawnCounter >= _yawnFramesThreshold;

    return DrowsinessResult(
      ear: ear,
      mar: mar,
      isDrowsy: isDrowsy,
      isYawning: isYawning,
      drowsyFrames: _drowsyCounter,
      yawnFrames: _yawnCounter,
    );
  }

  void reset() {
    _drowsyCounter = 0;
    _yawnCounter = 0;
  }

  Map<String, dynamic> getStats() {
    return {
      'drowsyCounter': _drowsyCounter,
      'yawnCounter': _yawnCounter,
    };
  }
}