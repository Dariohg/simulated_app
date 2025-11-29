import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraDescription? _cameraDescription;
  CameraDescription? get cameraDescription => _cameraDescription;

  final StreamController<bool> _cameraReadyController =
  StreamController.broadcast();
  Stream<bool> get onCameraReady => _cameraReadyController.stream;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('[CameraService] ERROR: No se encontraron camaras');
        _cameraReadyController.add(false);
        return;
      }

      _cameraDescription = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('[CameraService] Camara seleccionada: ${_cameraDescription!.name}');
      debugPrint('[CameraService] Direccion: ${_cameraDescription!.lensDirection}');
      debugPrint('[CameraService] Orientacion sensor: ${_cameraDescription!.sensorOrientation}');

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      debugPrint('[CameraService] Camara inicializada');
      debugPrint('[CameraService] Resolucion: ${_controller!.value.previewSize}');

      _cameraReadyController.add(true);
    } catch (e) {
      debugPrint('[CameraService] ERROR inicializando camara: $e');
      _cameraReadyController.add(false);
      rethrow;
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (_controller?.value.isInitialized != true) {
      debugPrint('[CameraService] ERROR: Controlador no inicializado');
      return;
    }

    if (_controller?.value.isStreamingImages == true) {
      debugPrint('[CameraService] Stream ya esta activo');
      return;
    }

    _controller?.startImageStream(onImage);
    debugPrint('[CameraService] Stream de imagenes iniciado');
  }

  void stopImageStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
      debugPrint('[CameraService] Stream de imagenes detenido');
    }
  }

  void dispose() {
    debugPrint('[CameraService] Liberando recursos...');
    stopImageStream();
    _controller?.dispose();
    _cameraReadyController.close();
  }
}