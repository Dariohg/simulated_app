import 'dart:collection';

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
}

class EmotionAnalyzer {
  /// Mapeo idéntico a emotion_classifier.py
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

  /// Labels en el mismo orden que el modelo TFLite exportado
  static const List<String> _emotionLabels = [
    'Anger',
    'Contempt',
    'Disgust',
    'Fear',
    'Happiness',
    'Neutral',
    'Sadness',
    'Surprise',
  ];

  final int _historySize;
  final int _minHistoryForSmoothing;

  final ListQueue<String> _emotionHistory = ListQueue();
  final ListQueue<double> _confidenceHistory = ListQueue();

  EmotionAnalyzer({
    int historySize = 15,
    int minHistoryForSmoothing = 3,
  })  : _historySize = historySize,
        _minHistoryForSmoothing = minHistoryForSmoothing;

  EmotionResult analyze(List<double> probabilities) {
    if (probabilities.isEmpty) {
      return EmotionResult(
        emotion: 'Neutral',
        cognitiveState: 'concentrado',
        confidence: 0.0,
        scores: {},
      );
    }

    // 1. Construir diccionario de scores y encontrar emoción dominante
    int maxIndex = 0;
    double maxProb = 0.0;
    final Map<String, double> currentScores = {};

    for (int i = 0; i < probabilities.length && i < _emotionLabels.length; i++) {
      final label = _emotionLabels[i];
      final prob = probabilities[i];
      currentScores[label] = prob * 100; // Convertir a porcentaje como Python

      if (prob > maxProb) {
        maxProb = prob;
        maxIndex = i;
      }
    }

    String currentEmotion = maxIndex < _emotionLabels.length
        ? _emotionLabels[maxIndex]
        : 'Neutral';

    double currentConfidence = maxProb;

    // 2. Agregar al historial
    _emotionHistory.addLast(currentEmotion);
    _confidenceHistory.addLast(currentConfidence);

    if (_emotionHistory.length > _historySize) {
      _emotionHistory.removeFirst();
      _confidenceHistory.removeFirst();
    }

    // 3. Suavizado temporal (igual que Python)
    String smoothedEmotion = currentEmotion;
    double smoothedConfidence = currentConfidence;

    if (_emotionHistory.length >= _minHistoryForSmoothing) {
      // Contar frecuencia de emociones (moda)
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

      // Promedio de confianza (igual que Python: np.mean)
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

  void reset() {
    _emotionHistory.clear();
    _confidenceHistory.clear();
  }
}