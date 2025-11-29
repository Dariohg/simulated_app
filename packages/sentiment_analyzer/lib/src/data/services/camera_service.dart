import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraDescription? _cameraDescription;
  CameraDescription? get cameraDescription => _cameraDescription;

  final StreamController<bool> _cameraReadyController = StreamController.broadcast();
  Stream<bool> get onCameraReady => _cameraReadyController.stream;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraReadyController.add(false);
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
      _cameraReadyController.add(true);
    } catch (e) {
      _cameraReadyController.add(false);
      rethrow;
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (_controller?.value.isInitialized != true) return;
    if (_controller?.value.isStreamingImages == true) return;
    _controller?.startImageStream(onImage);
  }

  void stopImageStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
  }

  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _cameraReadyController.close();
  }
}