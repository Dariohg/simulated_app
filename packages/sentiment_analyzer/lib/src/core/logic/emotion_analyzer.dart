import 'dart:collection';

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
  // El orden DEBE coincidir con el entrenamiento del modelo TFLite
  static const List<String> emotionLabels = [
    'Angry',    // 0
    'Contempt', // 1
    'Disgust',  // 2
    'Fear',     // 3
    'Happy',    // 4
    'Neutral',  // 5
    'Sad',      // 6
    'Surprise', // 7
  ];

  // Historial para suavizar el "flickering" (parpadeo de emociones)
  final ListQueue<List<double>> _history = ListQueue();
  static const int _historySize = 10; // Reducido ligeramente para mayor reactividad

  // Umbrales ajustados para precisión
  static const double _minConfidence = 0.20;
  static const double _happyBoost = 1.1; // Pequeño impulso para detectar sonrisas sutiles

  EmotionResult analyze(List<double> probabilities) {
    if (probabilities.isEmpty || probabilities.length != emotionLabels.length) {
      return _createNeutralResult();
    }

    // Agregar al historial
    _history.add(probabilities);
    if (_history.length > _historySize) {
      _history.removeFirst();
    }

    // Calcular promedio ponderado (los cuadros recientes valen más)
    final smoothedProbabilities = List<double>.filled(emotionLabels.length, 0.0);
    double totalWeight = 0.0;

    int index = 0;
    for (final frameProbs in _history) {
      // Peso lineal: el cuadro más antiguo tiene peso 1, el más nuevo peso N
      double weight = (index + 1).toDouble();
      for (int i = 0; i < emotionLabels.length; i++) {
        smoothedProbabilities[i] += frameProbs[i] * weight;
      }
      totalWeight += weight;
      index++;
    }

    // Normalizar promedio
    for (int i = 0; i < smoothedProbabilities.length; i++) {
      smoothedProbabilities[i] /= totalWeight;
    }

    // Aplicar BOOST a 'Happy' (índice 4) para mejorar detección de satisfacción
    // Esto ayuda si el modelo es tímido con la felicidad
    smoothedProbabilities[4] *= _happyBoost;

    // Buscar la emoción dominante
    int maxIndex = 5; // Default Neutral
    double maxValue = 0.0;

    for (int i = 0; i < smoothedProbabilities.length; i++) {
      if (smoothedProbabilities[i] > maxValue) {
        maxValue = smoothedProbabilities[i];
        maxIndex = i;
      }
    }

    final emotion = emotionLabels[maxIndex];

    // Generar mapa de puntuaciones para UI (0-100)
    final scores = <String, double>{};
    for (int i = 0; i < emotionLabels.length; i++) {
      scores[emotionLabels[i]] = smoothedProbabilities[i] * 100;
    }

    // Filtro de ruido final
    if (maxValue < _minConfidence) {
      return _createNeutralResult();
    }

    return EmotionResult(
      emotion: emotion,
      confidence: maxValue,
      cognitiveState: _mapToCognitiveState(emotion),
      scores: scores,
    );
  }

  EmotionResult _createNeutralResult() {
    return EmotionResult(
      emotion: 'Neutral',
      confidence: 0.0,
      cognitiveState: 'concentrado',
      scores: {},
    );
  }

  String _mapToCognitiveState(String emotion) {
    switch (emotion) {
      case 'Happy':
        return 'entendiendo'; // Felicidad = Comprensión/Satisfacción
      case 'Angry':
      case 'Contempt':
      case 'Disgust':
      case 'Sad':
        return 'frustrado';   // Emociones negativas = Frustración
      case 'Fear':
      case 'Surprise':
        return 'distraido';   // Sorpresa/Miedo = Distracción/Confusión súbita
      case 'Neutral':
      default:
        return 'concentrado'; // Neutral = Atención estable
    }
  }

  void reset() {
    _history.clear();
  }
}