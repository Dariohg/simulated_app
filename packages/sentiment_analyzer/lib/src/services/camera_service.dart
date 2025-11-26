import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Servicio para gestión de la cámara.
///
/// Proporciona acceso al stream de imágenes de la cámara frontal
/// en formato optimizado para procesamiento de ML.
class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraDescription? _cameraDescription;
  CameraDescription? get cameraDescription => _cameraDescription;

  // Stream para notificar cuando la cámara está lista
  final StreamController<bool> _cameraReadyController =
  StreamController.broadcast();
  Stream<bool> get onCameraReady => _cameraReadyController.stream;

  /// Inicializa la cámara frontal
  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('[CameraService] ERROR: No se encontraron cámaras');
        _cameraReadyController.add(false);
        return;
      }

      // Buscar cámara frontal, o usar la primera disponible
      _cameraDescription = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('[CameraService] Cámara seleccionada: ${_cameraDescription!.name}');
      debugPrint('[CameraService] Dirección: ${_cameraDescription!.lensDirection}');
      debugPrint('[CameraService] Orientación sensor: ${_cameraDescription!.sensorOrientation}°');

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.low, // Baja resolución para mejor rendimiento en ML
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21  // Mejor para ML Kit en Android
            : ImageFormatGroup.bgra8888, // iOS
      );

      await _controller!.initialize();

      debugPrint('[CameraService] ✓ Cámara inicializada');
      debugPrint('[CameraService] Resolución: ${_controller!.value.previewSize}');

      _cameraReadyController.add(true);
    } catch (e) {
      debugPrint('[CameraService] ERROR inicializando cámara: $e');
      _cameraReadyController.add(false);
      rethrow;
    }
  }

  /// Inicia el stream de imágenes
  void startImageStream(Function(CameraImage) onImage) {
    if (_controller?.value.isInitialized != true) {
      debugPrint('[CameraService] ERROR: Controlador no inicializado');
      return;
    }

    if (_controller?.value.isStreamingImages == true) {
      debugPrint('[CameraService] Stream ya está activo');
      return;
    }

    _controller?.startImageStream(onImage);
    debugPrint('[CameraService] ✓ Stream de imágenes iniciado');
  }

  /// Detiene el stream de imágenes
  void stopImageStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
      debugPrint('[CameraService] Stream de imágenes detenido');
    }
  }

  /// Libera recursos
  void dispose() {
    debugPrint('[CameraService] Liberando recursos...');
    stopImageStream();
    _controller?.dispose();
    _cameraReadyController.close();
  }
}