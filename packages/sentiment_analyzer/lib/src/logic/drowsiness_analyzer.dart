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
  final double _earThreshold;
  final double _marThreshold;
  final int _drowsyFramesThreshold;
  final int _yawnFramesThreshold;

  int _drowsyCounter = 0;
  int _yawnCounter = 0;

  DrowsinessAnalyzer({
    double earThreshold = 0.22,
    double marThreshold = 0.6,
    int drowsyFramesThreshold = 20,
    int yawnFramesThreshold = 15,
  })  : _earThreshold = earThreshold,
        _marThreshold = marThreshold,
        _drowsyFramesThreshold = drowsyFramesThreshold,
        _yawnFramesThreshold = yawnFramesThreshold;

  /// Calcula distancia euclidiana entre dos puntos
  double _distance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  /// EAR (Eye Aspect Ratio) - Fórmula idéntica a Python:
  /// EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
  ///
  /// Índices del ojo (6 puntos):
  /// p1 = esquina exterior (índice 0)
  /// p2 = párpado superior exterior (índice 1)
  /// p3 = párpado superior interior (índice 2)
  /// p4 = esquina interior (índice 3)
  /// p5 = párpado inferior interior (índice 4)
  /// p6 = párpado inferior exterior (índice 5)
  double _calculateEAR(List<FaceMeshPoint> allPoints, List<int> eyeIndices) {
    final p1 = allPoints[eyeIndices[0]]; // Esquina exterior
    final p2 = allPoints[eyeIndices[1]]; // Párpado superior exterior
    final p3 = allPoints[eyeIndices[2]]; // Párpado superior interior
    final p4 = allPoints[eyeIndices[3]]; // Esquina interior
    final p5 = allPoints[eyeIndices[4]]; // Párpado inferior interior
    final p6 = allPoints[eyeIndices[5]]; // Párpado inferior exterior

    final vertical1 = _distance(p2, p6);
    final vertical2 = _distance(p3, p5);
    final horizontal = _distance(p1, p4);

    if (horizontal == 0) return 0.0;

    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  /// MAR (Mouth Aspect Ratio) - Fórmula idéntica a Python:
  /// MAR = |p_top - p_bottom| / |p_left - p_right|
  ///
  /// Índices de la boca (mínimo 4 puntos principales):
  /// índice 0 = esquina izquierda
  /// índice 1 = esquina derecha
  /// índice 2 = labio superior centro
  /// índice 3 = labio inferior centro
  double _calculateMAR(List<FaceMeshPoint> allPoints, List<int> mouthIndices) {
    if (mouthIndices.length < 4) return 0.0;

    final pLeft = allPoints[mouthIndices[0]];   // Esquina izquierda
    final pRight = allPoints[mouthIndices[1]];  // Esquina derecha
    final pTop = allPoints[mouthIndices[2]];    // Labio superior centro
    final pBottom = allPoints[mouthIndices[3]]; // Labio inferior centro

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

    // Lógica de contadores idéntica a Python
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
      drowsyFrames: _drowsyCounter,
      yawnFrames: _yawnCounter,
    );
  }

  void reset() {
    _drowsyCounter = 0;
    _yawnCounter = 0;
  }
}