import 'dart:collection';
import 'dart:math';

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
  // Mapeo exacto de tu emotion_classifier.py
  static const Map<String, String> _emotionToCognitive = {
    "Anger": "frustrado",
    "Contempt": "frustrado",
    "Disgust": "frustrado",
    "Sadness": "frustrado",
    "Fear": "distraido",
    "Surprise": "distraido",
    "Happiness": "entendiendo",
    "Neutral": "concentrado"
  };

  static const List<String> _emotionLabels = [
    "Anger", "Contempt", "Disgust", "Fear",
    "Happiness", "Neutral", "Sadness", "Surprise"
  ];

  final int _historySize = 15;
  final int _minHistoryForSmoothing = 3;

  final ListQueue<String> _emotionHistory = ListQueue();
  final ListQueue<double> _confidenceHistory = ListQueue();

  EmotionResult analyze(List<double> probabilities) {
    // 1. Encontrar la emoción dominante del frame actual
    int maxIndex = 0;
    double maxProb = 0.0;
    Map<String, double> currentScores = {};

    for (int i = 0; i < probabilities.length; i++) {
      String label = i < _emotionLabels.length ? _emotionLabels[i] : "Unknown";
      currentScores[label] = probabilities[i];
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    String currentEmotion = _emotionLabels.length > maxIndex ? _emotionLabels[maxIndex] : "Neutral";

    // 2. Añadir al historial
    if (_emotionHistory.length >= _historySize) {
      _emotionHistory.removeFirst();
      _confidenceHistory.removeFirst();
    }
    _emotionHistory.add(currentEmotion);
    _confidenceHistory.add(maxProb);

    // 3. Suavizado (Smoothing)
    String smoothedEmotion = currentEmotion;
    double smoothedConfidence = maxProb;

    if (_emotionHistory.length >= _minHistoryForSmoothing) {
      // Contar frecuencia de emociones en el historial
      Map<String, int> counts = {};
      for (var e in _emotionHistory) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
      // La emoción más frecuente (moda)
      smoothedEmotion = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      // Promedio de confianza
      double sumConf = _confidenceHistory.fold(0, (p, c) => p + c);
      smoothedConfidence = sumConf / _confidenceHistory.length;
    }

    // 4. Mapeo a estado cognitivo
    String cognitiveState = _emotionToCognitive[smoothedEmotion] ?? "concentrado";

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