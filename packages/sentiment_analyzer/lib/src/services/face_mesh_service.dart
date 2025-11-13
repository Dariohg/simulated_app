import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class FaceMeshService {
  late FaceMeshDetector _detector;
  bool _isBusy = false;

  FaceMeshService() {
    // Usamos el constructor que te funcionaba
    _detector = FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
  }

  Future<List<FaceMesh>> processImage(InputImage inputImage) async {
    if (_isBusy) return [];

    _isBusy = true;
    try {
      final meshes = await _detector.processImage(inputImage);
      return meshes;
    } catch (e) {
      debugPrint("Error al procesar imagen con ML Kit: $e");
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _detector.close();
  }
}