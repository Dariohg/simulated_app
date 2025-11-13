import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class NetworkService {
  // No necesitamos 'dio' ya que solo vamos a simular la llamada
  NetworkService();

  /// Serializa los datos de la malla y los imprime en la consola como un JSON.
  void logMeshDaTA(List<FaceMesh> meshes) {
    try {
      // 1. Convertir los datos de la malla a un formato JSON (Map)
      final data = _serializeMeshes(meshes);
      if (data.isEmpty) return; // No imprimir si no hay cara

      // 2. Usamos jsonEncode para convertir el Map a un String JSON
      // jsonEncode con JsonEncoder.withIndent('  ') lo formatea de manera legible
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // 3. Usamos debugPrint para una salida de consola más limpia y completa
      debugPrint('--- SIMULACIÓN DE ENVÍO A BACKEND ---');
      debugPrint(jsonString);
      debugPrint('----------------------------------------');
    } catch (e) {
      debugPrint('Error al serializar JSON: $e');
    }
  }

  /// Método privado para convertir List<FaceMesh> a un Map serializable.
  Map<String, dynamic> _serializeMeshes(List<FaceMesh> meshes) {
    // Tomamos solo la primera malla (generalmente solo hay una cara)
    if (meshes.isEmpty) return {};

    final mesh = meshes.first;

    // Convertimos la lista de puntos a una lista de Mapas
    final pointsList = mesh.points.map((point) {
      return {
        'index': point.index,
        'x': point.x,
        'y': point.y,
        'z': point.z, // El eje Z es la profundidad
      };
    }).toList();

    // Creamos el objeto JSON final
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'face': {
        'boundingBox': {
          'left': mesh.boundingBox.left,
          'top': mesh.boundingBox.top,
          'right': mesh.boundingBox.right,
          'bottom': mesh.boundingBox.bottom,
        },
        'points_count': pointsList.length,
        'points': pointsList,
      }
    };
  }
}