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

  @override
  String toString() {
    return 'Drowsiness(EAR: ${ear.toStringAsFixed(3)}, MAR: ${mar.toStringAsFixed(3)}, '
        'drowsy: $isDrowsy, yawning: $isYawning)';
  }
}

class DrowsinessAnalyzer {
  double _earThreshold;
  final double _marThreshold;
  final int _drowsyFramesThreshold;
  final int _yawnFramesThreshold;

  int _drowsyCounter = 0;
  int _yawnCounter = 0;

  // Límite máximo de frames acumulados para evitar que el estado se quede "pegado"
  // Si el umbral es 20, permitimos acumular hasta 30. Así, si el usuario despierta,
  // solo tarda unos pocos frames en bajar de 30 a <20, en lugar de bajar desde 1000.
  late final int _maxDrowsyBuffer;
  late final int _maxYawnBuffer;

  DrowsinessAnalyzer({
    double earThreshold = 0.22,
    double marThreshold = 0.6,
    int drowsyFramesThreshold = 20,
    int yawnFramesThreshold = 15,
  })  : _earThreshold = earThreshold,
        _marThreshold = marThreshold,
        _drowsyFramesThreshold = drowsyFramesThreshold,
        _yawnFramesThreshold = yawnFramesThreshold {
    _maxDrowsyBuffer = drowsyFramesThreshold + 10;
    _maxYawnBuffer = yawnFramesThreshold + 10;
  }

  void updateEarThreshold(double threshold) {
    _earThreshold = threshold;
  }

  double get earThreshold => _earThreshold;

  double _distance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  double _calculateEAR(List<FaceMeshPoint> allPoints, List<int> eyeIndices) {
    if (eyeIndices.length < 6) return 0.0;

    final p1 = allPoints[eyeIndices[0]];
    final p2 = allPoints[eyeIndices[1]];
    final p3 = allPoints[eyeIndices[2]];
    final p4 = allPoints[eyeIndices[3]];
    final p5 = allPoints[eyeIndices[4]];
    final p6 = allPoints[eyeIndices[5]];

    final vertical1 = _distance(p2, p6);
    final vertical2 = _distance(p3, p5);
    final horizontal = _distance(p1, p4);

    if (horizontal == 0) return 0.0;

    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  double _calculateMAR(List<FaceMeshPoint> allPoints, List<int> mouthIndices) {
    if (mouthIndices.length < 4) return 0.0;

    final pLeft = allPoints[mouthIndices[0]];
    final pRight = allPoints[mouthIndices[1]];
    final pTop = allPoints[mouthIndices[2]];
    final pBottom = allPoints[mouthIndices[3]];

    final vertical = _distance(pTop, pBottom);
    final horizontal = _distance(pLeft, pRight);

    if (horizontal == 0) return 0.0;

    return vertical / horizontal;
  }

  DrowsinessResult analyze(List<FaceMeshPoint> points) {
    final leftEar = _calculateEAR(points, LandmarkIndices.leftEye);
    final rightEar = _calculateEAR(points, LandmarkIndices.rightEye);
    final ear = (leftEar + rightEar) / 2.0;

    final mar = _calculateMAR(points, LandmarkIndices.mouth);

    // CORRECCIÓN: Usamos min() para topar el contador.
    if (ear < _earThreshold) {
      _drowsyCounter = min(_drowsyCounter + 1, _maxDrowsyBuffer);
    } else {
      // Recuperación rápida: Restamos de 1 en 1, pero al estar topado el maximo, baja rapido.
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
      'drowsyThreshold': _drowsyFramesThreshold,
      'yawnThreshold': _yawnFramesThreshold,
      'earThreshold': _earThreshold,
      'marThreshold': _marThreshold,
    };
  }
}