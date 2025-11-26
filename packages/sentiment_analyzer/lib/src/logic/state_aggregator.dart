import 'drowsiness_analyzer.dart';
import 'attention_analyzer.dart';

/// Estado combinado del análisis de atención y emociones
class CombinedState {
  /// Estado cognitivo derivado de emociones (frustrado, distraido, concentrado, entendiendo)
  final String cognitiveState;

  /// Emoción detectada (Anger, Happiness, Neutral, etc.)
  final String emotion;

  /// Confianza de la predicción de emoción (0.0 - 1.0)
  final double confidence;

  /// Scores de todas las emociones (porcentajes)
  final Map<String, double> emotionScores;

  /// Resultado del análisis de somnolencia
  final DrowsinessResult? drowsiness;

  /// Resultado del análisis de atención
  final AttentionResult? attention;

  /// Estado final considerando todas las señales
  final String finalState;

  /// Indica si se detectó un rostro en el frame
  final bool faceDetected;

  /// Indica si el sistema está en proceso de calibración
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

/// Agregador de estados con sistema de prioridades.
///
/// Implementación idéntica a state_aggregator.py de Python.
///
/// Prioridades (de mayor a menor):
/// 1. durmiendo    - Ojos cerrados por tiempo prolongado
/// 2. no_mirando   - Cabeza girada fuera del rango
/// 3. frustrado    - Enojo, tristeza, disgusto (de emociones)
/// 4. distraido    - Miedo, sorpresa, bostezando
/// 5. concentrado  - Neutral, atento
/// 6. entendiendo  - Feliz, comprendiendo
///
/// La lógica es:
/// - Los estados físicos (somnolencia, no mirando) tienen PRIORIDAD sobre emociones
/// - Si no hay estados físicos activos, se usa el estado cognitivo de emociones
class StateAggregator {
  /// Prioridades de estados (menor número = mayor prioridad)
  /// Idéntico a STATE_PRIORITY en Python
  static const Map<String, int> statePriority = {
    'durmiendo': 1,    // Máxima prioridad
    'no_mirando': 2,
    'frustrado': 3,
    'distraido': 4,
    'concentrado': 5,
    'entendiendo': 6,  // Mínima prioridad
  };

  /// Agrega múltiples señales en un estado final.
  ///
  /// La lógica de prioridad es:
  /// 1. Si está dormido (ojos cerrados prolongadamente) → "durmiendo"
  /// 2. Si no mira la pantalla → "no_mirando"
  /// 3. Si está bostezando → "distraido"
  /// 4. Si ninguna condición física → usar estado cognitivo de emociones
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
    // Caso 1: Sin rostro detectado
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

    // Caso 2: Rostro detectado - aplicar lógica de prioridades
    // Empezar con el estado cognitivo de emociones como base
    String finalState = cognitiveState;

    // Prioridad 1: Somnolencia (ojos cerrados sostenidamente)
    // Esta es la condición más crítica
    if (drowsiness != null && drowsiness.isDrowsy) {
      finalState = 'durmiendo';
    }
    // Prioridad 2: No mirando la pantalla
    else if (attention != null && !attention.isLookingAtScreen) {
      finalState = 'no_mirando';
    }
    // Prioridad intermedia: Bostezando (subconjunto de distraido)
    // Solo aplica si no está dormido ni mirando hacia otro lado
    else if (drowsiness != null && drowsiness.isYawning) {
      finalState = 'distraido';
    }
    // Si ninguna condición física está activa, mantener el estado cognitivo
    // derivado de las emociones (ya asignado arriba)

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

  /// Compara dos estados y retorna el de mayor prioridad
  String getHigherPriorityState(String state1, String state2) {
    final priority1 = statePriority[state1] ?? 999;
    final priority2 = statePriority[state2] ?? 999;

    return priority1 <= priority2 ? state1 : state2;
  }

  /// Obtiene la descripción amigable de un estado
  static String getStateDescription(String state) {
    const descriptions = {
      'durmiendo': 'Ojos cerrados - posible somnolencia',
      'no_mirando': 'No está mirando la pantalla',
      'frustrado': 'Señales de frustración detectadas',
      'distraido': 'Señales de distracción detectadas',
      'concentrado': 'Atención normal',
      'entendiendo': 'Señales positivas de comprensión',
      'sin_rostro': 'No se detecta rostro',
      'desconocido': 'Estado no determinado',
    };

    return descriptions[state] ?? state;
  }

  /// Obtiene el color asociado a un estado (para UI)
  /// Retorna valores RGB como lista [r, g, b]
  static List<int> getStateColor(String state) {
    const colors = {
      'concentrado': [0, 255, 0],      // Verde
      'distraido': [255, 165, 0],      // Naranja
      'frustrado': [255, 0, 0],        // Rojo
      'entendiendo': [0, 255, 255],    // Cyan
      'durmiendo': [128, 0, 128],      // Púrpura
      'no_mirando': [100, 100, 100],   // Gris
      'sin_rostro': [128, 128, 128],   // Gris claro
      'desconocido': [128, 128, 128],  // Gris claro
    };

    return colors[state] ?? [255, 255, 255];
  }
}