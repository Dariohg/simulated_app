import 'drowsiness_analyzer.dart';
import 'attention_analyzer.dart';
class CombinedState {
  final String cognitiveState;
  final String emotion;
  final double confidence;
  final Map<String, double> emotionScores;
  final DrowsinessResult? drowsiness;
  final AttentionResult? attention;
  final String finalState;
  final bool faceDetected;
  final bool isCalibrating;

  CombinedState({
    required this.cognitiveState,
    required this.emotion,
    required this.confidence,
    required this.emotionScores,
    this.drowsiness,
    this.attention,
    required this.finalState,
    required this.faceDetected,
    required this.isCalibrating,
  });
}

/// Agregador de estados con prioridades idénticas a state_aggregator.py
///
/// Prioridades (de mayor a menor):
/// 1. durmiendo    - Ojos cerrados prolongadamente
/// 2. no_mirando   - Cabeza girada fuera del rango
/// 3. frustrado    - Enojo, tristeza, disgusto
/// 4. distraido    - Miedo, sorpresa, bostezando
/// 5. concentrado  - Neutral, atento
/// 6. entendiendo  - Feliz, comprendiendo
class StateAggregator {
  static const Map<String, int> statePriority = {
    'durmiendo': 1,
    'no_mirando': 2,
    'frustrado': 3,
    'distraido': 4,
    'concentrado': 5,
    'entendiendo': 6,
  };

  CombinedState aggregate({
    required bool faceDetected,
    String cognitiveState = 'desconocido',
    String emotion = 'Unknown',
    double confidence = 0.0,
    Map<String, double>? emotionScores,
    DrowsinessResult? drowsiness,
    AttentionResult? attention,
    bool isCalibrating = false,
  }) {
    // Sin rostro detectado
    if (!faceDetected) {
      return CombinedState(
        cognitiveState: 'desconocido',
        emotion: 'Unknown',
        confidence: 0.0,
        emotionScores: emotionScores ?? {},
        drowsiness: null,
        attention: null,
        finalState: 'sin_rostro',
        faceDetected: false,
        isCalibrating: false,
      );
    }

    // Determinar estado final según prioridades (idéntico a Python)
    String finalState = cognitiveState;

    // Prioridad 1: Somnolencia (ojos cerrados)
    if (drowsiness != null && drowsiness.isDrowsy) {
      finalState = 'durmiendo';
    }
    // Prioridad 2: No mirando pantalla
    else if (attention != null && !attention.isLookingAtScreen) {
      finalState = 'no_mirando';
    }
    // Prioridad 4: Bostezando (subconjunto de distraido)
    else if (drowsiness != null && drowsiness.isYawning) {
      finalState = 'distraido';
    }
    // Si no hay condiciones físicas especiales, usar estado cognitivo de emociones

    return CombinedState(
      cognitiveState: cognitiveState,
      emotion: emotion,
      confidence: confidence,
      emotionScores: emotionScores ?? {},
      drowsiness: drowsiness,
      attention: attention,
      finalState: finalState,
      faceDetected: true,
      isCalibrating: isCalibrating,
    );
  }
}