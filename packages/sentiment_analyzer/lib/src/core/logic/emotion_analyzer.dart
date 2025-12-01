class EmotionResult {
  final String emotion;
  final double confidence;
  final String cognitiveState;
  final Map<String, double> scores;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.cognitiveState,
    required this.scores,
  });
}

class EmotionAnalyzer {
  static const List<String> emotionLabels = [
    'Angry',
    'Disgust',
    'Fear',
    'Happy',
    'Sad',
    'Surprise',
    'Neutral',
    'Contempt',
  ];

  static const Map<String, String> emotionToCognitiveState = {
    'Happy': 'entendiendo',
    'Surprise': 'entendiendo',
    'Neutral': 'neutral',
    'Sad': 'confundido',
    'Fear': 'confundido',
    'Angry': 'confundido',
    'Disgust': 'confundido',
    'Contempt': 'neutral',
  };

  EmotionResult analyze(List<double> probabilities) {
    if (probabilities.isEmpty || probabilities.length != emotionLabels.length) {
      return EmotionResult(
        emotion: 'Neutral',
        confidence: 0.0,
        cognitiveState: 'neutral',
        scores: {},
      );
    }

    int maxIndex = 0;
    double maxValue = probabilities[0];

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxValue) {
        maxValue = probabilities[i];
        maxIndex = i;
      }
    }

    final emotion = emotionLabels[maxIndex];
    final cognitiveState = emotionToCognitiveState[emotion] ?? 'neutral';

    final scores = <String, double>{};
    for (int i = 0; i < emotionLabels.length; i++) {
      scores[emotionLabels[i]] = probabilities[i] * 100;
    }

    return EmotionResult(
      emotion: emotion,
      confidence: maxValue,
      cognitiveState: cognitiveState,
      scores: scores,
    );
  }
}