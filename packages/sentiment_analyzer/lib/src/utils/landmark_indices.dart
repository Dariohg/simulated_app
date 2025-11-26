/// Índices de landmarks de MediaPipe Face Mesh
///
/// Estos índices son IDÉNTICOS a los usados en el código Python
/// con MediaPipe Face Mesh (landmark_extractor.py)
///
/// Referencia: https://github.com/google/mediapipe/blob/master/mediapipe/modules/face_geometry/data/canonical_face_model_uv_visualization.png
class LandmarkIndices {
  /// Ojo izquierdo (6 puntos para EAR)
  /// Orden: [esquina_ext, parpado_sup_ext, parpado_sup_int, esquina_int, parpado_inf_int, parpado_inf_ext]
  /// Python: LEFT_EYE_INDICES = [362, 385, 387, 263, 373, 380]
  static const List<int> leftEye = [362, 385, 387, 263, 373, 380];

  /// Ojo derecho (6 puntos para EAR)
  /// Orden: [esquina_ext, parpado_sup_ext, parpado_sup_int, esquina_int, parpado_inf_int, parpado_inf_ext]
  /// Python: RIGHT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
  static const List<int> rightEye = [33, 160, 158, 133, 153, 144];

  /// Boca (puntos para MAR)
  /// Primeros 4 puntos son los principales para MAR:
  /// [esquina_izq, esquina_der, labio_sup_centro, labio_inf_centro, ...]
  /// Python: MOUTH_INDICES = [61, 291, 0, 17, 405, 321, 375, 78, 191, 80, 81, 82]
  static const List<int> mouth = [61, 291, 0, 17, 405, 321, 375, 78, 191, 80, 81, 82];

  /// Punta de la nariz
  /// Python: NOSE_TIP_INDEX = 1
  static const int noseTip = 1;

  /// Mentón
  /// Python: CHIN_INDEX = 152
  static const int chin = 152;

  /// Esquina exterior del ojo izquierdo
  /// Python: LEFT_EYE_OUTER_INDEX = 263
  static const int leftEyeOuter = 263;

  /// Esquina exterior del ojo derecho
  /// Python: RIGHT_EYE_OUTER_INDEX = 33
  static const int rightEyeOuter = 33;

  /// Frente (centro superior)
  static const int forehead = 10;

  /// Puente nasal
  static const int noseBridge = 6;
}