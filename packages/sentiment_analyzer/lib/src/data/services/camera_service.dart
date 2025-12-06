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

  bool _isDisposed = false;
  bool _isInitializing = false;

  Future<void> initializeCamera() async {
    if (_isDisposed) return;

    if (_isInitializing) return;
    _isInitializing = true;

    try {
      if (_controller != null && _controller!.value.isInitialized) {
        _cameraReadyController.add(true);
        return;
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('[CameraService] ERROR: No se encontraron camaras');
        if (!_isDisposed) _cameraReadyController.add(false);
        return;
      }

      _cameraDescription = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!_isDisposed) {
        _cameraReadyController.add(true);
      }
    } catch (e) {
      debugPrint('[CameraService] ERROR inicializando camara: $e');
      if (!_isDisposed) {
        _cameraReadyController.add(false);
      }
    } finally {
      _isInitializing = false;
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (_controller?.value.isInitialized != true) return;
    if (_controller?.value.isStreamingImages == true) return;

    try {
      _controller?.startImageStream(onImage);
    } catch (e) {
      debugPrint('[CameraService] Error iniciando stream: $e');
    }
  }

  Future<void> stopCamera() async {
    await stopImageStreamAsync();

    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('[CameraService] Error haciendo dispose del controller: $e');
      }
      _controller = null;
    }
  }

  void stopImageStream() {
    if (_controller?.value.isStreamingImages == true) {
      try {
        _controller?.stopImageStream();
      } catch (e) {
        debugPrint('[CameraService] Error deteniendo stream: $e');
      }
    }
  }

  Future<void> stopImageStreamAsync() async {
    if (_controller?.value.isStreamingImages == true) {
      try {
        await _controller?.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('[CameraService] Error deteniendo stream async: $e');
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await stopCamera();
    await _cameraReadyController.close();
  }
}