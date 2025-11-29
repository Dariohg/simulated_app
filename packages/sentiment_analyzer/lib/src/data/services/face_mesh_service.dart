import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class FaceMeshService {
  late FaceMeshDetector _detector;
  bool _isBusy = false;

  FaceMeshService() {
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  }

  Future<List<FaceMesh>> processImage(InputImage inputImage) async {
    if (_isBusy) return [];
    _isBusy = true;
    try {
      final meshes = await _detector.processImage(inputImage);
      return meshes;
    } catch (e) {
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _detector.close();
  }
}