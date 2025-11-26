import 'dart:collection';
import 'dart:math';

/// Resultado del análisis de emociones
class EmotionResult {
  final String emotion;
  final String cognitiveState;
  final double confidence;
  final Map<String, double> scores;

  EmotionResult({
    required this.emotion,
    required this.cognitiveState,
    required this.confidence,
    required this.scores,
  });

  @override
  String toString() {
    return 'EmotionResult(emotion: $emotion, cognitive: $cognitiveState, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Analizador de emociones con suavizado temporal.
///
/// Implementación idéntica a emotion_classifier.py de Python:
/// - Mismo mapeo de emociones a estados cognitivos
/// - Mismo orden de labels del modelo HSEmotion
/// - Mismo algoritmo de suavizado por votación mayoritaria
/// - Misma lógica de confianza promediada
class EmotionAnalyzer {
  /// Mapeo de emoción a estado cognitivo
  /// IDÉNTICO a emotion_classifier.py: EMOTION_TO_COGNITIVE
  static const Map<String, String> _emotionToCognitive = {
    'Anger': 'frustrado',
    'Contempt': 'frustrado',
    'Disgust': 'frustrado',
    'Sadness': 'frustrado',
    'Fear': 'distraido',
    'Surprise': 'distraido',
    'Happiness': 'entendiendo',
    'Neutral': 'concentrado',
  };

  /// Labels de emociones en el ORDEN EXACTO del modelo HSEmotion (enet_b0_8_best_afew)
  ///
  /// CRÍTICO: Este orden DEBE coincidir con el orden de salida del modelo TFLite.
  /// El modelo HSEmotion usa el dataset AffectNet con 8 clases en este orden:
  ///
  /// Según el código Python (emotion_classifier.py):
  /// emotion_dict = {
  ///     "Anger": scores[0],
  ///     "Contempt": scores[1],
  ///     "Disgust": scores[2],
  ///     "Fear": scores[3],
  ///     "Happiness": scores[4],
  ///     "Neutral": scores[5],
  ///     "Sadness": scores[6],
  ///     "Surprise": scores[7]
  /// }
  static const List<String> _emotionLabels = [
    'Anger',     // índice 0
    'Contempt',  // índice 1
    'Disgust',   // índice 2
    'Fear',      // índice 3
    'Happiness', // índice 4
    'Neutral',   // índice 5
    'Sadness',   // índice 6
    'Surprise',  // índice 7
  ];

  /// Tamaño del historial para suavizado temporal
  final int _historySize;

  /// Mínimo de frames antes de aplicar suavizado
  final int _minHistoryForSmoothing;

  /// Historial de emociones detectadas (para votación mayoritaria)
  final ListQueue<String> _emotionHistory = ListQueue();

  /// Historial de confianzas (para promediado)
  final ListQueue<double> _confidenceHistory = ListQueue();

  /// Umbral mínimo de confianza para considerar una predicción válida
  final double _confidenceThreshold;

  EmotionAnalyzer({
    int historySize = 15,
    int minHistoryForSmoothing = 3,
    double confidenceThreshold = 0.15,
  })  : _historySize = historySize,
        _minHistoryForSmoothing = minHistoryForSmoothing,
        _confidenceThreshold = confidenceThreshold;

  /// Analiza las probabilidades de salida del modelo y retorna el resultado
  ///
  /// [probabilities] debe ser una lista de 8 valores (uno por emoción)
  /// en el orden definido por _emotionLabels
  EmotionResult analyze(List<double> probabilities) {
    // Validación de entrada
    if (probabilities.isEmpty) {
      return _createDefaultResult();
    }

    // Asegurar que tengamos 8 probabilidades
    if (probabilities.length != 8) {
      print('[EmotionAnalyzer] ADVERTENCIA: Se esperaban 8 probabilidades, '
          'recibidas ${probabilities.length}');
      // Intentar usar lo que tengamos, rellenando con ceros si es necesario
      while (probabilities.length < 8) {
        probabilities = [...probabilities, 0.0];
      }
    }

    // 1. Construir diccionario de scores y encontrar emoción dominante
    int maxIndex = 0;
    double maxProb = 0.0;
    final Map<String, double> currentScores = {};

    for (int i = 0; i < _emotionLabels.length; i++) {
      final label = _emotionLabels[i];
      final prob = i < probabilities.length ? probabilities[i] : 0.0;

      // Guardar como porcentaje (igual que Python: v * 100)
      currentScores[label] = prob * 100;

      if (prob > maxProb) {
        maxProb = prob;
        maxIndex = i;
      }
    }

    String currentEmotion = _emotionLabels[maxIndex];
    double currentConfidence = maxProb;

    // Log de debug (solo ocasionalmente para no saturar)
    if (_emotionHistory.length % 30 == 0) {
      print('[EmotionAnalyzer] Raw: $currentEmotion (${(currentConfidence * 100).toStringAsFixed(1)}%)');
      print('[EmotionAnalyzer] Top 3: ${_getTopEmotions(currentScores, 3)}');
    }

    // Si la confianza es muy baja, usar Neutral por defecto
    if (currentConfidence < _confidenceThreshold) {
      currentEmotion = 'Neutral';
      currentConfidence = 0.5;
    }

    // 2. Agregar al historial (mantener tamaño máximo)
    _emotionHistory.addLast(currentEmotion);
    _confidenceHistory.addLast(currentConfidence);

    while (_emotionHistory.length > _historySize) {
      _emotionHistory.removeFirst();
      _confidenceHistory.removeFirst();
    }

    // 3. Aplicar suavizado temporal si hay suficiente historial
    String smoothedEmotion = currentEmotion;
    double smoothedConfidence = currentConfidence;

    if (_emotionHistory.length >= _minHistoryForSmoothing) {
      // Votación mayoritaria (moda) - idéntico a Python
      final Map<String, int> emotionCounts = {};
      for (final e in _emotionHistory) {
        emotionCounts[e] = (emotionCounts[e] ?? 0) + 1;
      }

      // Encontrar la emoción más frecuente
      int maxCount = 0;
      for (final entry in emotionCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          smoothedEmotion = entry.key;
        }
      }

      // Promedio de confianza - idéntico a Python: np.mean(list(self._confidence_history))
      double sumConfidence = 0;
      for (final c in _confidenceHistory) {
        sumConfidence += c;
      }
      smoothedConfidence = sumConfidence / _confidenceHistory.length;
    }

    // 4. Mapear a estado cognitivo
    final cognitiveState = _emotionToCognitive[smoothedEmotion] ?? 'concentrado';

    return EmotionResult(
      emotion: smoothedEmotion,
      cognitiveState: cognitiveState,
      confidence: smoothedConfidence,
      scores: currentScores,
    );
  }

  /// Crea un resultado por defecto cuando no hay datos válidos
  EmotionResult _createDefaultResult() {
    return EmotionResult(
      emotion: 'Neutral',
      cognitiveState: 'concentrado',
      confidence: 0.0,
      scores: {
        for (var label in _emotionLabels) label: 0.0,
      },
    );
  }

  /// Obtiene las top N emociones para debug
  String _getTopEmotions(Map<String, double> scores, int n) {
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(n)
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}%')
        .join(', ');
  }

  /// Resetea el historial de suavizado
  void reset() {
    _emotionHistory.clear();
    _confidenceHistory.clear();
    print('[EmotionAnalyzer] Historial reseteado');
  }

  /// Obtiene estadísticas del historial actual
  Map<String, dynamic> getStats() {
    if (_emotionHistory.isEmpty) {
      return {'historySize': 0, 'dominantEmotion': 'N/A'};
    }

    final counts = <String, int>{};
    for (final e in _emotionHistory) {
      counts[e] = (counts[e] ?? 0) + 1;
    }

    String dominant = 'Neutral';
    int maxCount = 0;
    counts.forEach((emotion, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = emotion;
      }
    });

    double avgConfidence = 0;
    if (_confidenceHistory.isNotEmpty) {
      avgConfidence = _confidenceHistory.reduce((a, b) => a + b) /
          _confidenceHistory.length;
    }

    return {
      'historySize': _emotionHistory.length,
      'dominantEmotion': dominant,
      'dominantCount': maxCount,
      'avgConfidence': avgConfidence,
      'emotionCounts': counts,
    };
  }
}