import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../../../data/services/camera_service.dart';
import '../../../data/services/face_mesh_service.dart';
import '../../../data/services/calibration_service.dart';
import '../../../data/services/calibration_storage.dart';

class CalibrationViewModel extends ChangeNotifier {
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final CalibrationService _calibrationService;
  final CalibrationStorage _storage = CalibrationStorage();

  bool _isInitialized = false;
  CalibrationProgress? _currentProgress;
  bool _isProcessing = false;

  StreamSubscription<bool>? _cameraReadySubscription;
  StreamSubscription<CalibrationProgress>? _progressSubscription;

  CalibrationViewModel({
    CameraService? cameraService,
    FaceMeshService? faceMeshService,
    CalibrationService? calibrationService,
  })  : _cameraService = cameraService ?? CameraService(),
        _faceMeshService = faceMeshService ?? FaceMeshService(),
        _calibrationService = calibrationService ?? CalibrationService();

  bool get isInitialized => _isInitialized;
  bool get isCalibrating => _calibrationService.isCalibrating;
  bool get isCalibrated => _calibrationService.isCalibrated;
  CalibrationProgress? get currentProgress => _currentProgress;
  CameraController? get cameraController => _cameraService.controller;
  CalibrationStep get currentStep => _calibrationService.currentStep;

  Future<void> initialize() async {
    _progressSubscription = _calibrationService.progressStream.listen((progress) {
      _currentProgress = progress;
      if (progress.shouldVibrate) HapticFeedback.mediumImpact();
      notifyListeners();
    });

    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        notifyListeners();
      }
    });

    await _cameraService.initializeCamera();
  }

  void startCalibration() {
    if (!_isInitialized) return;
    _calibrationService.startCalibration();
    _cameraService.startImageStream(_processFrame);
    notifyListeners();
  }

  void resetCalibration() {
    _cameraService.stopImageStream();
    _calibrationService.resetCalibration();
    _currentProgress = null;
    notifyListeners();
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing || !_calibrationService.isCalibrating) return;

    _isProcessing = true;
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final meshes = await _faceMeshService.processImage(inputImage);

      List<FaceMeshPoint>? points;
      if (meshes.isNotEmpty) {
        points = _preparePoints(meshes.first);
      }

      final double brightness = _calculateBrightness(image);

      _calibrationService.processFrame(points: points, brightness: brightness);

      if (_calibrationService.isCalibrated) {
        _cameraService.stopImageStream();
        HapticFeedback.mediumImpact();
        if (_calibrationService.lastResult != null) {
          await _storage.save(_calibrationService.lastResult!);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateBrightness(CameraImage image) {
    if (image.planes.isEmpty) return 0.5;
    final ByteBuffer buffer = image.planes[0].bytes.buffer;
    final Uint8List bytes = buffer.asUint8List();

    if (bytes.isEmpty) return 0.5;

    int sum = 0;
    final int step = (bytes.length / 100).ceil();
    int count = 0;

    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }

    if (count == 0) return 0.5;
    return (sum / count) / 255.0;
  }

  List<FaceMeshPoint> _preparePoints(FaceMesh mesh) {
    return List.generate(468, (index) => mesh.points.firstWhere(
            (p) => p.index == index,
        orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0)
    ));
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) allBytes.putUint8List(plane.bytes);
    final bytes = allBytes.done().buffer.asUint8List();

    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraReadySubscription?.cancel();
    _progressSubscription?.cancel();
    _cameraService.dispose();
    _faceMeshService.dispose();
    _calibrationService.dispose();
    super.dispose();
  }
}