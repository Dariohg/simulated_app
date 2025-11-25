import 'drowsiness_analyzer.dart';
import 'attention_analyzer.dart';
import 'emotion_analyzer.dart';

class CombinedState {
  final String finalState;
  final DrowsinessResult? drowsiness;
  final AttentionResult? attention;
  final EmotionResult? emotion;
  final bool isCalibrating;

  CombinedState({
    required this.finalState,
    this.drowsiness,
    this.attention,
    this.emotion,
    required this.isCalibrating,
  });
}

class StateAggregator {
  // Prioridades basadas en tu README.md:
  // 1. DURMIENDO (Somnolencia)
  // 2. NO MIRA PANTALLA (Atención)
  // 3. FRUSTRADO (Emoción)
  // 4. DISTRAIDO (Emoción o Bostezo)
  // 5. CONCENTRADO (Emoción)
  // 6. ENTENDIENDO (Emoción)

  CombinedState aggregate({
    required DrowsinessResult drowsiness,
    required AttentionResult attention,
    EmotionResult? emotion,
    required bool isCalibrating,
  }) {
    String finalState = "desconocido";

    // Lógica de prioridades estricta (Python logic)
    if (drowsiness.isDrowsy) {
      finalState = "durmiendo";
    } else if (!attention.isLookingAtScreen) {
      finalState = "no_mirando";
    } else if (drowsiness.isYawning) {
      finalState = "distraido";
    } else if (emotion != null) {
      // Si no hay problema físico (sueño/atención), manda la emoción
      finalState = emotion.cognitiveState;
    } else {
      finalState = "concentrado"; // Default seguro
    }

    return CombinedState(
      finalState: finalState,
      drowsiness: drowsiness,
      attention: attention,
      emotion: emotion,
      isCalibrating: isCalibrating,
    );
  }
}