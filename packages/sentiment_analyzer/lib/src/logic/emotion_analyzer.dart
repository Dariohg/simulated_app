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

  @override
  String toString() {
    return 'EmotionResult(emotion: $emotion, cognitive: $cognitiveState, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class EmotionAnalyzer {
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
  final double _confidenceThreshold;

  EmotionAnalyzer({
    int historySize = 10,
    int minHistoryForSmoothing = 3,
    double confidenceThreshold = 0.15,
  })  : _historySize = historySize,
        _minHistoryForSmoothing = minHistoryForSmoothing,
        _confidenceThreshold = confidenceThreshold;

  EmotionResult analyze(List<double> probabilities) {
    if (probabilities.isEmpty) {
      return _createDefaultResult();
    }

    if (probabilities.length != 8) {
      while (probabilities.length < 8) {
        probabilities = [...probabilities, 0.0];
      }
    }

    int maxIndex = 0;
    double maxProb = 0.0;
    final Map<String, double> currentScores = {};

    for (int i = 0; i < _emotionLabels.length; i++) {
      final label = _emotionLabels[i];
      final prob = i < probabilities.length ? probabilities[i] : 0.0;

      currentScores[label] = prob * 100;

      if (prob > maxProb) {
        maxProb = prob;
        maxIndex = i;
      }
    }

    String currentEmotion = _emotionLabels[maxIndex];
    double currentConfidence = maxProb;

    if (currentConfidence < _confidenceThreshold) {
      currentEmotion = 'Neutral';
      currentConfidence = 0.5;
    }

    _emotionHistory.addLast(currentEmotion);
    _confidenceHistory.addLast(currentConfidence);

    while (_emotionHistory.length > _historySize) {
      _emotionHistory.removeFirst();
      _confidenceHistory.removeFirst();
    }

    String finalEmotion = currentEmotion;
    double finalConfidence = currentConfidence;

    if (currentConfidence > 0.85) {
      finalEmotion = currentEmotion;
      finalConfidence = currentConfidence;
    } else if (_emotionHistory.length >= _minHistoryForSmoothing) {
      final Map<String, int> emotionCounts = {};
      for (final e in _emotionHistory) {
        emotionCounts[e] = (emotionCounts[e] ?? 0) + 1;
      }

      int maxCount = 0;
      for (final entry in emotionCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          finalEmotion = entry.key;
        }
      }

      double sumConfidence = 0;
      for (final c in _confidenceHistory) {
        sumConfidence += c;
      }
      finalConfidence = sumConfidence / _confidenceHistory.length;
    }

    final cognitiveState = _emotionToCognitive[finalEmotion] ?? 'concentrado';

    return EmotionResult(
      emotion: finalEmotion,
      cognitiveState: cognitiveState,
      confidence: finalConfidence,
      scores: currentScores,
    );
  }

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

  void reset() {
    _emotionHistory.clear();
    _confidenceHistory.clear();
  }

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