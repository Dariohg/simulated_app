import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../services/camera_service.dart';
import '../services/face_mesh_service.dart';
import 'calibration_service.dart';
import 'calibration_storage.dart'; // Importar storage

class CalibrationViewModel extends ChangeNotifier {
  final CameraService _cameraService;
  final FaceMeshService _faceMeshService;
  final CalibrationService _calibrationService;
  final CalibrationStorage _storage = CalibrationStorage(); // Instancia de storage

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
  CalibrationResult? get calibrationResult => _calibrationService.lastResult;
  CameraController? get cameraController => _cameraService.controller;
  CalibrationStep get currentStep => _calibrationService.currentStep;

  Future<void> initialize() async {
    _progressSubscription = _calibrationService.progressStream.listen((progress) {
      _currentProgress = progress;
      if (progress.shouldVibrate) {
        _triggerVibration();
      }
      notifyListeners();
    });

    _cameraReadySubscription = _cameraService.onCameraReady.listen((isReady) {
      if (isReady) {
        _isInitialized = true;
        notifyListeners();
      }
    });

    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      debugPrint('[CalibrationViewModel] Error inicializando camara: $e');
    }
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
    if (_isProcessing) return;
    if (!_calibrationService.isCalibrating) return;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final meshes = await _faceMeshService.processImage(inputImage);

      List<FaceMeshPoint>? points;
      if (meshes.isNotEmpty) {
        points = _preparePoints(meshes.first);
      }

      final brightness = _calculateBrightness(image);

      _calibrationService.processFrame(
        points: points,
        brightness: brightness,
      );

      // Si terminó de calibrar, guardar y detener
      if (_calibrationService.isCalibrated) {
        _cameraService.stopImageStream();
        _triggerVibration();

        // GUARDADO AUTOMÁTICO
        if (_calibrationService.lastResult != null) {
          await _storage.save(_calibrationService.lastResult!);
          debugPrint('[CalibrationViewModel] Calibración guardada exitosamente.');
        }
      }
    } catch (e) {
      debugPrint('[CalibrationViewModel] Error procesando frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  List<FaceMeshPoint> _preparePoints(FaceMesh mesh) {
    return List.generate(
      468,
          (index) => mesh.points.firstWhere(
            (p) => p.index == index,
        orElse: () => FaceMeshPoint(index: index, x: 0, y: 0, z: 0),
      ),
    );
  }

  double _calculateBrightness(CameraImage image) {
    if (image.planes.isEmpty) return 0.5;
    final bytes = image.planes[0].bytes;
    if (bytes.isEmpty) return 0.5;

    int sum = 0;
    final step = bytes.length ~/ 1000;
    int count = 0;

    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }

    if (count == 0) return 0.5;
    return (sum / count) / 255.0;
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraService.cameraDescription;
    if (camera == null) return null;

    try {
      final allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[CalibrationViewModel] Error convirtiendo imagen: $e');
      return null;
    }
  }

  void _triggerVibration() {
    HapticFeedback.mediumImpact();
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