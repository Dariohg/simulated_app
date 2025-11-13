import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../../services/camera_service.dart';
import '../../services/face_mesh_service.dart';
import '../../services/network_service.dart';

class FaceMeshViewModel extends ChangeNotifier {
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final NetworkService _networkService;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  CameraController? get cameraController => _cameraService.controller;

  // List<FaceMesh> _faceMeshes = [];
  // Size? _imageSize;

  StreamSubscription<bool>? _cameraReadySubscription;

  final Stopwatch _logStopwatch = Stopwatch();
  bool _isLogPending = false;

  FaceMeshViewModel({
    required CameraService cameraService,
    required FaceMeshService faceMeshService,
    required NetworkService networkService,
  })  : _cameraService = cameraService,
        _faceMeshService = faceMeshService,
        _networkService = networkService {
    initialize();
    _logStopwatch.start();
  }

  Future<void> initialize() async {
    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        _cameraService.startImageStream(_onImageFrame);
        notifyListeners();
      } else {
        _isInitialized = false;
        notifyListeners();
      }
    });

    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      debugPrint("Error en ViewModel al inicializar cámara: $e");
      _isInitialized = false;
      notifyListeners();
    }
  }

  void _onImageFrame(CameraImage image) {
    final InputImage? inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    _faceMeshService.processImage(inputImage).then((meshes) {
      if (meshes.isNotEmpty) {
        _logDataToConsole(meshes);
      }
    });
  }

  void _logDataToConsole(List<FaceMesh> meshes) {
    const int throttleMilliseconds = 1000;
    if (!_isLogPending &&
        _logStopwatch.elapsedMilliseconds > throttleMilliseconds) {
      _isLogPending = true;
      _logStopwatch.reset();

      _networkService.logMeshDaTA(meshes);

      _isLogPending = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    final writeBuffer = WriteBuffer();
    for (final Plane plane in image.planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    final bytes = writeBuffer.done().buffer.asUint8List();

    final imageRotation = _getInputImageRotation(camera.sensorOrientation);

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    try {
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0,
        ),
      );
    } catch (e) {
      debugPrint("Error al convertir imagen: $e");
      return null;
    }
  }

  InputImageRotation _getInputImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    _cameraReadySubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    super.dispose();
  }
}