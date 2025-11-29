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

  @override
  String toString() {
    return 'CombinedState(final: $finalState, emotion: $emotion, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'face: $faceDetected)';
  }
}

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

    String finalState = cognitiveState;

    if (drowsiness != null && drowsiness.isDrowsy) {
      finalState = 'durmiendo';
    } else if (attention != null && !attention.isLookingAtScreen) {
      finalState = 'no_mirando';
    } else if (drowsiness != null && drowsiness.isYawning) {
      finalState = 'distraido';
    }

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

  String getHigherPriorityState(String state1, String state2) {
    final priority1 = statePriority[state1] ?? 999;
    final priority2 = statePriority[state2] ?? 999;

    return priority1 <= priority2 ? state1 : state2;
  }

  static String getStateDescription(String state) {
    const descriptions = {
      'durmiendo': 'Ojos cerrados - posible somnolencia',
      'no_mirando': 'No esta mirando la pantalla',
      'frustrado': 'Senales de frustracion detectadas',
      'distraido': 'Senales de distraccion detectadas',
      'concentrado': 'Atencion normal',
      'entendiendo': 'Senales positivas de comprension',
      'sin_rostro': 'No se detecta rostro',
      'desconocido': 'Estado no determinado',
    };

    return descriptions[state] ?? state;
  }

  static List<int> getStateColor(String state) {
    const colors = {
      'concentrado': [0, 255, 0],
      'distraido': [255, 165, 0],
      'frustrado': [255, 0, 0],
      'entendiendo': [0, 255, 255],
      'durmiendo': [128, 0, 128],
      'no_mirando': [100, 100, 100],
      'sin_rostro': [128, 128, 128],
      'desconocido': [128, 128, 128],
    };

    return colors[state] ?? [255, 255, 255];
  }
}