import 'attention_analyzer.dart';
import 'drowsiness_analyzer.dart';

class CombinedState {
  final String finalState;
  final String emotion;
  final double confidence;
  final Map<String, double>? emotionScores;
  final DrowsinessResult? drowsiness;
  final AttentionResult? attention;
  final bool faceDetected;
  final bool isCalibrating;

  CombinedState({
    required this.finalState,
    required this.emotion,
    required this.confidence,
    this.emotionScores,
    this.drowsiness,
    this.attention,
    required this.faceDetected,
    this.isCalibrating = false,
  });
}

class StateAggregator {
  CombinedState aggregate({
    required bool faceDetected,
    String cognitiveState = 'concentrado',
    String emotion = 'Neutral',
    double confidence = 0.0,
    Map<String, double>? emotionScores,
    DrowsinessResult? drowsiness,
    AttentionResult? attention,
    bool isCalibrating = false,
  }) {
    if (!faceDetected) {
      return CombinedState(
        finalState: 'no_mirando',
        emotion: 'N/A',
        confidence: 0.0,
        faceDetected: false,
        isCalibrating: isCalibrating,
      );
    }

    String finalState = cognitiveState;

    if (drowsiness != null && drowsiness.isDrowsy) {
      finalState = 'durmiendo';
    } else if (attention != null && !attention.isLookingAtScreen) {
      finalState = 'no_mirando';
    }

    return CombinedState(
      finalState: finalState,
      emotion: emotion,
      confidence: confidence,
      emotionScores: emotionScores,
      drowsiness: drowsiness,
      attention: attention,
      faceDetected: true,
      isCalibrating: isCalibrating,
    );
  }
}