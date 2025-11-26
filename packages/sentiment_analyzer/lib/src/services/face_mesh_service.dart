import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Servicio para detección de Face Mesh usando ML Kit.
///
/// Detecta 468 landmarks faciales 3D en tiempo real.
class FaceMeshService {
  late FaceMeshDetector _detector;
  bool _isBusy = false;

  // Estadísticas
  int _processCount = 0;
  int _successCount = 0;
  int _errorCount = 0;

  FaceMeshService() {
    _detector = FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
  }

  /// Procesa una imagen y retorna los face meshes detectados
  Future<List<FaceMesh>> processImage(InputImage inputImage) async {
    if (_isBusy) return [];

    _isBusy = true;
    _processCount++;

    try {
      final meshes = await _detector.processImage(inputImage);

      if (meshes.isNotEmpty) {
        _successCount++;
      }

      return meshes;
    } catch (e) {
      _errorCount++;

      // Log solo los primeros errores para no saturar
      if (_errorCount <= 5) {
        debugPrint('[FaceMeshService] Error procesando imagen: $e');
      }

      return [];
    } finally {
      _isBusy = false;
    }
  }

  /// Obtiene estadísticas del servicio
  Map<String, dynamic> getStats() {
    return {
      'processCount': _processCount,
      'successCount': _successCount,
      'errorCount': _errorCount,
      'successRate': _processCount > 0
          ? (_successCount / _processCount * 100).toStringAsFixed(1)
          : 'N/A',
    };
  }

  /// Libera recursos
  void dispose() {
    debugPrint('[FaceMeshService] Liberando recursos...');
    debugPrint('[FaceMeshService] Stats: ${getStats()}');
    _detector.close();
  }
}