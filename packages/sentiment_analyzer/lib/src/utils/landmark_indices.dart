/// Indices de landmarks de MediaPipe Face Mesh.
class LandmarkIndices {
  static const List<int> leftEye = [362, 385, 387, 263, 373, 380];
  static const List<int> rightEye = [33, 160, 158, 133, 153, 144];
  static const List<int> mouth = [61, 291, 0, 17, 405, 321, 375, 78, 191, 80, 81, 82];
  static const int noseTip = 1;
  static const int chin = 152;
  static const int leftEyeOuter = 263;
  static const int rightEyeOuter = 33;
  static const int forehead = 10;
  static const int noseBridge = 6;
  static const int leftEyebrowCenter = 282;
  static const int rightEyebrowCenter = 52;

  static const List<int> faceContour = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109
  ];

  static bool isValidIndex(int index) {
    return index >= 0 && index < 468;
  }

  static bool areValidIndices(List<int> indices) {
    return indices.every(isValidIndex);
  }

  static const int totalLandmarks = 468;
}