/// Índices de landmarks de MediaPipe Face Mesh.
///
/// Estos índices son IDÉNTICOS a los usados en el código Python
/// con MediaPipe Face Mesh (landmark_extractor.py).
///
/// MediaPipe Face Mesh detecta 468 landmarks faciales 3D.
///
/// Referencia visual:
/// https://github.com/google/mediapipe/blob/master/mediapipe/modules/face_geometry/data/canonical_face_model_uv_visualization.png
///
/// IMPORTANTE: Estos índices están validados contra el código Python original.
/// NO modificar sin verificar compatibilidad con el modelo.
class LandmarkIndices {
  // ============================================================
  // OJOS - Para cálculo de EAR (Eye Aspect Ratio)
  // ============================================================

  /// Ojo izquierdo (6 puntos para EAR)
  ///
  /// Orden: [esquina_ext, parpado_sup_ext, parpado_sup_int, esquina_int, parpado_inf_int, parpado_inf_ext]
  ///
  /// Python: LEFT_EYE_INDICES = [362, 385, 387, 263, 373, 380]
  ///
  /// Diagrama (vista frontal, ojo izquierdo del sujeto):
  /// ```
  ///          p2(385)   p3(387)
  ///              \       /
  ///               -------
  ///    p1(362) -|         |- p4(263)
  ///               -------
  ///              /       \
  ///          p6(380)   p5(373)
  /// ```
  static const List<int> leftEye = [362, 385, 387, 263, 373, 380];

  /// Ojo derecho (6 puntos para EAR)
  ///
  /// Orden: [esquina_ext, parpado_sup_ext, parpado_sup_int, esquina_int, parpado_inf_int, parpado_inf_ext]
  ///
  /// Python: RIGHT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
  ///
  /// Diagrama (vista frontal, ojo derecho del sujeto):
  /// ```
  ///          p2(160)   p3(158)
  ///              \       /
  ///               -------
  ///    p1(33)  -|         |- p4(133)
  ///               -------
  ///              /       \
  ///          p6(144)   p5(153)
  /// ```
  static const List<int> rightEye = [33, 160, 158, 133, 153, 144];

  // ============================================================
  // BOCA - Para cálculo de MAR (Mouth Aspect Ratio)
  // ============================================================

  /// Boca (puntos para MAR y análisis)
  ///
  /// Los primeros 4 puntos son los principales para MAR:
  /// [esquina_izq, esquina_der, labio_sup_centro, labio_inf_centro, ...]
  ///
  /// Python: MOUTH_INDICES = [61, 291, 0, 17, 405, 321, 375, 78, 191, 80, 81, 82]
  ///
  /// Para MAR solo necesitamos los primeros 4:
  /// - 61:  Esquina izquierda de la boca
  /// - 291: Esquina derecha de la boca
  /// - 0:   Centro del labio superior
  /// - 17:  Centro del labio inferior
  ///
  /// Diagrama:
  /// ```
  ///              p3(0) - labio superior
  ///               ___
  ///    p1(61) ---|   |--- p2(291)
  ///               ---
  ///              p4(17) - labio inferior
  /// ```
  static const List<int> mouth = [61, 291, 0, 17, 405, 321, 375, 78, 191, 80, 81, 82];

  // ============================================================
  // PUNTOS CLAVE FACIALES - Para cálculo de pose
  // ============================================================

  /// Punta de la nariz
  ///
  /// Python: NOSE_TIP_INDEX = 1
  ///
  /// Usado para calcular la dirección de la cara (pitch/yaw)
  static const int noseTip = 1;

  /// Mentón (punto más bajo de la barbilla)
  ///
  /// Python: CHIN_INDEX = 152
  ///
  /// Usado para calcular la altura de la cara y pitch
  static const int chin = 152;

  /// Esquina exterior del ojo izquierdo
  ///
  /// Python: LEFT_EYE_OUTER_INDEX = 263
  ///
  /// Usado para calcular el centro de los ojos y yaw
  static const int leftEyeOuter = 263;

  /// Esquina exterior del ojo derecho
  ///
  /// Python: RIGHT_EYE_OUTER_INDEX = 33
  ///
  /// Usado para calcular el centro de los ojos y yaw
  static const int rightEyeOuter = 33;

  // ============================================================
  // PUNTOS ADICIONALES (para futuras expansiones)
  // ============================================================

  /// Frente (centro superior)
  /// Útil para calcular inclinación de cabeza
  static const int forehead = 10;

  /// Puente nasal (entre los ojos)
  /// Punto de referencia central
  static const int noseBridge = 6;

  /// Centro de la ceja izquierda
  static const int leftEyebrowCenter = 282;

  /// Centro de la ceja derecha
  static const int rightEyebrowCenter = 52;

  // ============================================================
  // CONTORNO FACIAL (para debug/visualización)
  // ============================================================

  /// Puntos del contorno facial (silhouette)
  /// Útil para visualización del bounding box
  static const List<int> faceContour = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109
  ];

  // ============================================================
  // VALIDACIÓN
  // ============================================================

  /// Verifica que un índice de landmark sea válido (0-467)
  static bool isValidIndex(int index) {
    return index >= 0 && index < 468;
  }

  /// Verifica que todos los índices de una lista sean válidos
  static bool areValidIndices(List<int> indices) {
    return indices.every(isValidIndex);
  }

  /// Total de landmarks en Face Mesh
  static const int totalLandmarks = 468;
}