import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

class DrowsinessResult {
  final double ear;
  final double mar;
  final bool isDrowsy;
  final bool isYawning;

  DrowsinessResult({
    required this.ear,
    required this.mar,
    required this.isDrowsy,
    required this.isYawning,
  });
}

class DrowsinessAnalyzer {
  final double _earThreshold = 0.22;
  final double _marThreshold = 0.6;
  final int _drowsyFramesThreshold = 20;
  final int _yawnFramesThreshold = 15;

  int _drowsyCounter = 0;
  int _yawnCounter = 0;

  double _calculateDistance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  double _calculateEAR(List<FaceMeshPoint> allPoints, List<int> indices) {
    final p1 = allPoints[indices[0]];
    final p2 = allPoints[indices[1]];
    final p3 = allPoints[indices[2]];
    final p4 = allPoints[indices[3]];
    final p5 = allPoints[indices[4]];
    final p6 = allPoints[indices[5]];

    final vertical1 = _calculateDistance(p2, p6);
    final vertical2 = _calculateDistance(p3, p5);
    final horizontal = _calculateDistance(p1, p4);

    if (horizontal == 0) return 0.0;
    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  double _calculateMAR(List<FaceMeshPoint> allPoints, List<int> indices) {
    if (indices.length < 8) return 0.0;

    final pTop = allPoints[indices[2]];
    final pBottom = allPoints[indices[3]];
    final pLeft = allPoints[indices[0]];
    final pRight = allPoints[indices[1]];

    final vertical = _calculateDistance(pTop, pBottom);
    final horizontal = _calculateDistance(pLeft, pRight);

    if (horizontal == 0) return 0.0;
    return vertical / horizontal;
  }

  DrowsinessResult analyze(List<FaceMeshPoint> points) {
    final leftEar = _calculateEAR(points, LandmarkIndices.leftEye);
    final rightEar = _calculateEAR(points, LandmarkIndices.rightEye);
    final ear = (leftEar + rightEar) / 2.0;
    final mar = _calculateMAR(points, LandmarkIndices.mouth);

    if (ear < _earThreshold) {
      _drowsyCounter++;
    } else {
      _drowsyCounter = max(0, _drowsyCounter - 1);
    }

    if (mar > _marThreshold) {
      _yawnCounter++;
    } else {
      _yawnCounter = max(0, _yawnCounter - 1);
    }

    return DrowsinessResult(
      ear: ear,
      mar: mar,
      isDrowsy: _drowsyCounter >= _drowsyFramesThreshold,
      isYawning: _yawnCounter >= _yawnFramesThreshold,
    );
  }

  void reset() {
    _drowsyCounter = 0;
    _yawnCounter = 0;
  }
}