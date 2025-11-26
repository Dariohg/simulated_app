import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

/// Resultado del análisis de somnolencia
class DrowsinessResult {
  /// Eye Aspect Ratio - valor entre 0 y ~0.4
  /// Ojos abiertos: ~0.25-0.35
  /// Ojos cerrados: < 0.22
  final double ear;

  /// Mouth Aspect Ratio - valor entre 0 y ~1.0
  /// Boca cerrada: < 0.6
  /// Bostezando: > 0.6
  final double mar;

  /// Indica si se detecta somnolencia sostenida
  final bool isDrowsy;

  /// Indica si se detecta bostezo sostenido
  final bool isYawning;

  /// Contador de frames con ojos cerrados
  final int drowsyFrames;

  /// Contador de frames con boca abierta
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

/// Analizador de somnolencia basado en métricas EAR y MAR.
///
/// Implementación idéntica a drowsiness_analyzer.py de Python.
///
/// Métricas:
/// - EAR (Eye Aspect Ratio): Detecta si los ojos están cerrados
///   Fórmula: EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
///
/// - MAR (Mouth Aspect Ratio): Detecta bostezos
///   Fórmula: MAR = |p_top - p_bottom| / |p_left - p_right|
class DrowsinessAnalyzer {
  /// Umbral EAR para considerar ojos cerrados
  /// Valor por defecto: 0.22 (igual que Python)
  final double _earThreshold;

  /// Umbral MAR para considerar bostezo
  /// Valor por defecto: 0.6 (igual que Python)
  final double _marThreshold;

  /// Frames consecutivos para confirmar somnolencia
  /// Valor por defecto: 20 frames (igual que Python)
  final int _drowsyFramesThreshold;

  /// Frames consecutivos para confirmar bostezo
  /// Valor por defecto: 15 frames (igual que Python)
  final int _yawnFramesThreshold;

  /// Contador interno de frames con ojos cerrados
  int _drowsyCounter = 0;

  /// Contador interno de frames con boca abierta
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

  /// Calcula la distancia euclidiana entre dos puntos 2D
  double _distance(FaceMeshPoint p1, FaceMeshPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  /// Calcula EAR (Eye Aspect Ratio) para un ojo.
  ///
  /// Fórmula idéntica a Python:
  /// ```python
  /// EAR = (|p2-p6| + |p3-p5|) / (2.0 * |p1-p4|)
  /// ```
  ///
  /// Índices del ojo (6 puntos):
  /// - p1 = esquina exterior (índice 0 en la lista)
  /// - p2 = párpado superior exterior (índice 1)
  /// - p3 = párpado superior interior (índice 2)
  /// - p4 = esquina interior (índice 3)
  /// - p5 = párpado inferior interior (índice 4)
  /// - p6 = párpado inferior exterior (índice 5)
  double _calculateEAR(List<FaceMeshPoint> allPoints, List<int> eyeIndices) {
    if (eyeIndices.length < 6) {
      return 0.0;
    }

    // Obtener los 6 puntos del ojo
    final p1 = allPoints[eyeIndices[0]]; // Esquina exterior
    final p2 = allPoints[eyeIndices[1]]; // Párpado superior exterior
    final p3 = allPoints[eyeIndices[2]]; // Párpado superior interior
    final p4 = allPoints[eyeIndices[3]]; // Esquina interior
    final p5 = allPoints[eyeIndices[4]]; // Párpado inferior interior
    final p6 = allPoints[eyeIndices[5]]; // Párpado inferior exterior

    // Distancias verticales (apertura del ojo)
    final vertical1 = _distance(p2, p6);
    final vertical2 = _distance(p3, p5);

    // Distancia horizontal (ancho del ojo)
    final horizontal = _distance(p1, p4);

    // Evitar división por cero
    if (horizontal == 0) return 0.0;

    // Fórmula EAR
    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  /// Calcula MAR (Mouth Aspect Ratio) para detectar bostezos.
  ///
  /// Fórmula idéntica a Python:
  /// ```python
  /// MAR = |p_top - p_bottom| / |p_left - p_right|
  /// ```
  ///
  /// Índices de la boca (mínimo 4 puntos principales):
  /// - índice 0 = esquina izquierda
  /// - índice 1 = esquina derecha
  /// - índice 2 = labio superior centro
  /// - índice 3 = labio inferior centro
  double _calculateMAR(List<FaceMeshPoint> allPoints, List<int> mouthIndices) {
    if (mouthIndices.length < 4) {
      return 0.0;
    }

    final pLeft = allPoints[mouthIndices[0]];   // Esquina izquierda
    final pRight = allPoints[mouthIndices[1]];  // Esquina derecha
    final pTop = allPoints[mouthIndices[2]];    // Labio superior centro
    final pBottom = allPoints[mouthIndices[3]]; // Labio inferior centro

    // Distancia vertical (apertura de la boca)
    final vertical = _distance(pTop, pBottom);

    // Distancia horizontal (ancho de la boca)
    final horizontal = _distance(pLeft, pRight);

    // Evitar división por cero
    if (horizontal == 0) return 0.0;

    return vertical / horizontal;
  }

  /// Analiza los landmarks faciales para detectar somnolencia.
  ///
  /// [points] debe ser una lista de al menos 468 FaceMeshPoints
  DrowsinessResult analyze(List<FaceMeshPoint> points) {
    // Calcular EAR para ambos ojos
    final leftEar = _calculateEAR(points, LandmarkIndices.leftEye);
    final rightEar = _calculateEAR(points, LandmarkIndices.rightEye);

    // Promedio de ambos ojos (más robusto)
    final ear = (leftEar + rightEar) / 2.0;

    // Calcular MAR
    final mar = _calculateMAR(points, LandmarkIndices.mouth);

    // Lógica de contadores idéntica a Python:
    // - Si está por debajo del umbral, incrementar
    // - Si no, decrementar gradualmente (pero no menos que 0)
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

    // Determinar estados basados en umbrales de frames
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

  /// Resetea los contadores internos
  void reset() {
    _drowsyCounter = 0;
    _yawnCounter = 0;
  }

  /// Obtiene el estado actual de los contadores
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