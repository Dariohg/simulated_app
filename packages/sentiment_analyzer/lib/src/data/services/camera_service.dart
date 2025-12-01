import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _cameraDescription;
  bool _isInitialized = false;

  final StreamController<bool> _cameraReadyController =
  StreamController<bool>.broadcast();

  CameraController? get controller => _controller;
  CameraDescription? get cameraDescription => _cameraDescription;
  bool get isInitialized => _isInitialized;
  Stream<bool> get onCameraReady => _cameraReadyController.stream;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[CameraService] No hay camaras disponibles');
        _cameraReadyController.add(false);
        return;
      }

      _cameraDescription = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _cameraReadyController.add(true);
      debugPrint('[CameraService] Camara inicializada');
    } catch (e) {
      debugPrint('[CameraService] Error inicializando camara: $e');
      _cameraReadyController.add(false);
    }
  }

  void startImageStream(void Function(CameraImage image) onImage) {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    try {
      _controller!.startImageStream(onImage);
      debugPrint('[CameraService] Stream de imagenes iniciado');
    } catch (e) {
      debugPrint('[CameraService] Error iniciando stream: $e');
    }
  }

  void stopImageStream() {
    if (_controller == null || !_isInitialized) return;
    if (!_controller!.value.isStreamingImages) return;

    try {
      _controller!.stopImageStream();
      debugPrint('[CameraService] Stream de imagenes detenido');
    } catch (e) {
      debugPrint('[CameraService] Error deteniendo stream: $e');
    }
  }

  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _cameraReadyController.close();
    debugPrint('[CameraService] Disposed');
  }
}