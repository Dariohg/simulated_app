class LandmarkIndices {
  // Ojos (puntos clave para EAR)
  static const List<int> leftEye = [33, 160, 158, 133, 153, 144];
  static const List<int> rightEye = [362, 385, 387, 263, 373, 380];

  // Cejas (opcional para expresiones)
  static const List<int> leftEyebrow = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46];
  static const List<int> rightEyebrow = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276];

  // Labios (puntos clave para MAR/bostezo)
  // 61: comisura izq, 291: comisura der, 0: labio sup centro, 17: labio inf centro
  static const List<int> mouth = [61, 291, 0, 17];

  // Puntos para la orientación de la cabeza (Head Pose)
  static const int noseTip = 1;
  static const int chin = 152;
  static const int leftEyeOuter = 33;
  static const int rightEyeOuter = 263;
  static const int leftMouthCorner = 61;
  static const int rightMouthCorner = 291;
}