import 'dart:collection';
import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import '../utils/landmark_indices.dart';

/// Resultado del análisis de atención
class AttentionResult {
  /// Inclinación vertical de la cabeza (grados)
  /// Positivo = mirando hacia abajo, Negativo = mirando hacia arriba
  final double pitch;

  /// Rotación horizontal de la cabeza (grados)
  /// Positivo = mirando a la derecha, Negativo = mirando a la izquierda
  final double yaw;

  /// Rotación lateral de la cabeza (grados) - no usado actualmente
  final double roll;

  /// Indica si está mirando a la pantalla
  final bool isLookingAtScreen;

  /// Contador de frames sin mirar la pantalla
  final int notLookingFrames;

  AttentionResult({
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.isLookingAtScreen,
    required this.notLookingFrames,
  });

  @override
  String toString() {
    return 'Attention(pitch: ${pitch.toStringAsFixed(1)}°, yaw: ${yaw.toStringAsFixed(1)}°, '
        'looking: $isLookingAtScreen)';
  }
}

/// Analizador de atención basado en pose de cabeza.
///
/// Implementación idéntica a attention_analyzer.py de Python.
///
/// Características:
/// - Calibración automática de posición base
/// - Suavizado de pose con mediana (más robusto que promedio)
/// - Umbral de estabilidad para calibración
/// - Decremento gradual del contador cuando vuelve a mirar
class AttentionAnalyzer {
  /// Umbral de inclinación vertical (grados) para considerar que no mira
  final double _pitchThreshold;

  /// Umbral de rotación horizontal (grados) para considerar que no mira
  final double _yawThreshold;

  /// Frames consecutivos para confirmar que no está mirando
  final int _notLookingFramesThreshold;

  /// Frames necesarios para calibración
  final int _calibrationFramesRequired;

  /// Umbral de desviación estándar para validar calibración estable
  final double _calibrationStabilityThreshold;

  /// Contador de frames sin mirar
  int _notLookingCounter = 0;

  /// Pitch base calibrado
  double? _baselinePitch;

  /// Yaw base calibrado
  double? _baselineYaw;

  /// Buffer de frames para calibración
  final ListQueue<List<double>> _calibrationFrames = ListQueue();

  /// Estado de calibración
  bool _isCalibrated = false;

  /// Historial de pose para suavizado
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

  /// Indica si el sistema está calibrado
  bool get isCalibrated => _isCalibrated;

  /// Calcula la dirección de la cara basándose en landmarks.
  ///
  /// Usa la relación entre nariz, ojos y mentón para estimar pitch y yaw.
  /// Idéntico a _calculate_face_direction en Python.
  List<double> _calculateFaceDirection(List<FaceMeshPoint> points) {
    // Obtener puntos clave
    final nose = points[LandmarkIndices.noseTip];
    final leftEyeOuter = points[LandmarkIndices.leftEyeOuter];
    final rightEyeOuter = points[LandmarkIndices.rightEyeOuter];
    final chin = points[LandmarkIndices.chin];

    // Centro de los ojos
    final eyeCenterX = (leftEyeOuter.x + rightEyeOuter.x) / 2;
    final eyeCenterY = (leftEyeOuter.y + rightEyeOuter.y) / 2;

    // Ancho de la cara (distancia entre ojos externos)
    final faceWidth = _distance2D(
      rightEyeOuter.x, rightEyeOuter.y,
      leftEyeOuter.x, leftEyeOuter.y,
    );

    if (faceWidth < 1) return [0.0, 0.0];

    // Yaw: desplazamiento horizontal de la nariz respecto al centro de ojos
    final horizontalOffset = (nose.x - eyeCenterX) / faceWidth;
    final yaw = horizontalOffset * 90;

    // Altura de la cara (desde ojos hasta mentón)
    final faceHeight = _distance2D(
      chin.x, chin.y,
      eyeCenterX, eyeCenterY,
    );

    if (faceHeight < 1) return [0.0, yaw];

    // Pitch: desplazamiento vertical de la nariz respecto al centro de ojos
    // El factor 0.3 es un offset porque la nariz está naturalmente debajo de los ojos
    final verticalOffset = (nose.y - eyeCenterY) / faceHeight;
    final pitch = (verticalOffset - 0.3) * 90;

    return [pitch, yaw];
  }

  /// Distancia 2D entre dos puntos
  double _distance2D(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
  }

  /// Suaviza la pose usando mediana (más robusto a outliers que promedio).
  /// Idéntico a _smooth_pose en Python.
  List<double> _smoothPose(double pitch, double yaw) {
    _poseHistory.addLast([pitch, yaw]);

    // Mantener máximo 5 frames en historial
    while (_poseHistory.length > 5) {
      _poseHistory.removeFirst();
    }

    if (_poseHistory.length < 2) {
      return [pitch, yaw];
    }

    // Calcular mediana de cada componente
    final pitches = _poseHistory.map((p) => p[0]).toList();
    final yaws = _poseHistory.map((p) => p[1]).toList();

    return [_median(pitches), _median(yaws)];
  }

  /// Calcula la mediana de una lista de valores
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

  /// Calcula la desviación estándar de una lista
  double _standardDeviation(List<double> values) {
    if (values.length < 2) return double.infinity;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;

    return sqrt(variance);
  }

  /// Proceso de calibración.
  ///
  /// Solo calibra cuando los valores de pose son estables (baja desviación estándar).
  /// Idéntico a _calibrate en Python.
  void _calibrate(double pitch, double yaw) {
    _calibrationFrames.addLast([pitch, yaw]);

    // Mantener solo los frames necesarios
    while (_calibrationFrames.length > _calibrationFramesRequired) {
      _calibrationFrames.removeFirst();
    }

    // Intentar calibrar cuando tengamos suficientes frames
    if (_calibrationFrames.length >= _calibrationFramesRequired && !_isCalibrated) {
      final pitches = _calibrationFrames.map((f) => f[0]).toList();
      final yaws = _calibrationFrames.map((f) => f[1]).toList();

      final pitchStd = _standardDeviation(pitches);
      final yawStd = _standardDeviation(yaws);

      // Solo calibrar si los valores son ESTABLES
      if (pitchStd < _calibrationStabilityThreshold &&
          yawStd < _calibrationStabilityThreshold) {
        _baselinePitch = _median(pitches);
        _baselineYaw = _median(yaws);
        _isCalibrated = true;

        print('[AttentionAnalyzer] ✓ Calibración exitosa');
        print('[AttentionAnalyzer]   Baseline pitch: ${_baselinePitch!.toStringAsFixed(2)}°');
        print('[AttentionAnalyzer]   Baseline yaw: ${_baselineYaw!.toStringAsFixed(2)}°');
        print('[AttentionAnalyzer]   Pitch std: ${pitchStd.toStringAsFixed(2)}');
        print('[AttentionAnalyzer]   Yaw std: ${yawStd.toStringAsFixed(2)}');
      }
    }
  }

  /// Analiza los landmarks faciales para determinar atención.
  AttentionResult analyze(List<FaceMeshPoint> points) {
    // Calcular dirección de la cara
    final rawDirection = _calculateFaceDirection(points);

    // Suavizar con historial
    final smoothed = _smoothPose(rawDirection[0], rawDirection[1]);
    final pitch = smoothed[0];
    final yaw = smoothed[1];

    // Si no está calibrado, intentar calibrar
    if (!_isCalibrated) {
      _calibrate(pitch, yaw);

      // Durante calibración, asumir que está mirando
      return AttentionResult(
        pitch: pitch,
        yaw: yaw,
        roll: 0.0,
        isLookingAtScreen: true,
        notLookingFrames: 0,
      );
    }

    // Calcular pose relativa al baseline
    final relativePitch = pitch - (_baselinePitch ?? 0);
    final relativeYaw = yaw - (_baselineYaw ?? 0);

    // Verificar si está mirando dentro de los umbrales
    final isLooking = relativePitch.abs() <= _pitchThreshold &&
        relativeYaw.abs() <= _yawThreshold;

    // Actualizar contador (idéntico a Python)
    if (!isLooking) {
      _notLookingCounter++;
    } else {
      // Decremento gradual cuando vuelve a mirar
      _notLookingCounter = max(0, _notLookingCounter - 2);
    }

    // Determinar si no está mirando de forma sostenida
    final sustainedNotLooking = _notLookingCounter >= _notLookingFramesThreshold;

    return AttentionResult(
      pitch: relativePitch,
      yaw: relativeYaw,
      roll: 0.0,
      isLookingAtScreen: !sustainedNotLooking,
      notLookingFrames: _notLookingCounter,
    );
  }

  /// Resetea el contador de no-mirando (sin afectar calibración)
  void reset() {
    _notLookingCounter = 0;
  }

  /// Resetea completamente incluyendo calibración
  void resetCalibration() {
    _baselinePitch = null;
    _baselineYaw = null;
    _calibrationFrames.clear();
    _isCalibrated = false;
    _poseHistory.clear();
    _notLookingCounter = 0;
    print('[AttentionAnalyzer] Calibración reseteada');
  }

  /// Obtiene estadísticas actuales
  Map<String, dynamic> getStats() {
    return {
      'isCalibrated': _isCalibrated,
      'baselinePitch': _baselinePitch,
      'baselineYaw': _baselineYaw,
      'notLookingCounter': _notLookingCounter,
      'calibrationProgress': '${_calibrationFrames.length}/$_calibrationFramesRequired',
    };
  }
}