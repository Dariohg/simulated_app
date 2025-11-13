import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraDescription? _cameraDescription;
  CameraDescription? get cameraDescription => _cameraDescription;

  // Usamos un StreamController para notificar cuando la cámara está lista,
  // en lugar de depender solo de un Future.
  final StreamController<bool> _cameraReadyController =
  StreamController.broadcast();
  Stream<bool> get onCameraReady => _cameraReadyController.stream;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();

      // Busca la cámara frontal
      _cameraDescription = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, // Fallback a la primera cámara
      );

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.low, // Resolución media es suficiente para ML
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21 // Bueno para ML Kit en Android
            : ImageFormatGroup.bgra8888, // Default para iOS
      );

      await _controller!.initialize();
      _cameraReadyController.add(true); // Notifica que la cámara está lista
    } catch (e) {
      debugPrint("Error al inicializar la cámara: $e");
      _cameraReadyController.add(false); // Notifica un error
      rethrow;
    }
  }

  // Pasa la función (callback) que se llamará en cada frame
  void startImageStream(Function(CameraImage) onImage) {
    if (_controller?.value.isInitialized == false) {
      debugPrint("El controlador no está inicializado.");
      return;
    }
    if (_controller?.value.isStreamingImages == true) {
      debugPrint("El stream ya estaba iniciado.");
      return;
    }
    _controller?.startImageStream(onImage);
  }

  void stopImageStream() {
    _controller?.stopImageStream();
  }

  void dispose() {
    _controller?.dispose();
    _cameraReadyController.close();
  }
}