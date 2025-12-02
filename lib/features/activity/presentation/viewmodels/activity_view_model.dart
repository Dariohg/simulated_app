import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/network/app_network_service.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/models/activity_model.dart';
import '../../../../core/models/biometric_frame_model.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/mocks/mock_user.dart';
import '../../../../core/config/env_config.dart';

class ActivityViewModel extends ChangeNotifier {
  final AppNetworkService _httpService = AppNetworkService();
  final SessionModel session;
  final ActivityOption activityOption;
  final CalibrationStorage _calibrationStorage = CalibrationStorage();
  late final MonitoringWebSocketService _wsService;

  ActivityModel? _activeActivity;
  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  String? _error;
  String? get error => _error;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  CalibrationResult? _calibration;
  CalibrationResult? get calibration => _calibration;

  bool _needsCalibration = false;
  bool get needsCalibration => _needsCalibration;

  ActivityViewModel({required this.session, required this.activityOption}) {
    _wsService = MonitoringWebSocketService(
      gatewayUrl: EnvConfig.apiGatewayUrl,
      apiKey: EnvConfig.apiToken,
    );
  }

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    await _checkCalibration();
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _checkCalibration() async {
    final savedCalibration = await _calibrationStorage.load();
    if (savedCalibration != null && savedCalibration.isSuccessful) {
      _calibration = savedCalibration;
      _needsCalibration = false;
    } else {
      _calibration = null;
      _needsCalibration = true;
    }
  }

  Future<void> onCalibrationCompleted() async {
    await _checkCalibration();
    notifyListeners();
  }

  Future<void> startActivity() async {
    try {
      final response = await _httpService.startActivity(
        sessionId: session.id,
        externalActivityId: activityOption.externalActivityId,
        title: activityOption.title,
        subtitle: activityOption.subtitle,
        content: activityOption.content,
        activityType: activityOption.activityType,
      );

      if (response['activity_uuid'] != null) {
        _activeActivity = ActivityModel(
          activityUuid: response['activity_uuid'],
          sessionId: session.id,
          externalActivityId: activityOption.externalActivityId,
          status: 'active',
        );

        await _wsService.connect(
          sessionId: session.id,
          activityUuid: _activeActivity!.activityUuid,
          userId: MockUser.id,
          externalActivityId: activityOption.externalActivityId,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void onFrameProcessed(Map<String, dynamic> rawData) {
    if (_activeActivity == null) return;

    final frame = BiometricFrameModel(
      timestamp: DateTime.now().toIso8601String(),
      emocionPrincipal: rawData['emocion_principal'] ?? {},
      desgloseEmociones: List<Map<String, dynamic>>.from(rawData['desglose_emociones'] ?? []),
      atencion: rawData['atencion'] ?? {},
      somnolencia: rawData['somnolencia'] ?? {},
      rostroDetectado: rawData['rostro_detectado'] ?? false,
    );

    _wsService.sendFrame({
      'timestamp': frame.timestamp,
      'emocion_principal': frame.emocionPrincipal,
      'desglose_emociones': frame.desgloseEmociones,
      'atencion': frame.atencion,
      'somnolencia': frame.somnolencia,
      'rostro_detectado': frame.rostroDetectado,
    });

    _analyzeAndSend(frame);
  }

  void _analyzeAndSend(BiometricFrameModel frame) {
    final atencionVal = frame.atencion['valor'] as double? ?? 1.0;

    if (atencionVal < 0.3) {
      _feedbackMessage = "¡Concéntrate!";
    } else {
      _feedbackMessage = null;
    }
    notifyListeners();
  }

  Future<void> stopActivity() async {
    if (_activeActivity != null) {
      await _wsService.disconnect();
      await _httpService.completeActivity(
        activityUuid: _activeActivity!.activityUuid,
        feedback: {},
      );
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }
}