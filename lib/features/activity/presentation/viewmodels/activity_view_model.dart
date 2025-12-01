import 'package:flutter/material.dart';
import '../../../../core/network/app_network_service.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/models/activity_model.dart';
import '../../../../core/models/biometric_frame_model.dart';
//import '../../../../core/models/monitoring_event_model.dart';
import '../../../../core/mocks/mock_activities.dart';

class ActivityViewModel extends ChangeNotifier {
  final AppNetworkService _httpService = AppNetworkService();
  final SessionModel session;
  final ActivityOption activityOption;

  ActivityModel? _activeActivity;
  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  String? _error;
  String? get error => _error;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  ActivityViewModel({required this.session, required this.activityOption});

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

      // CORREGIDO: Ajustado a los campos reales de tu ActivityModel
      if (response['activity_uuid'] != null) {
        _activeActivity = ActivityModel(
          activityUuid: response['activity_uuid'],
          sessionId: session.id, // Requerido por ActivityModel
          externalActivityId: activityOption.externalActivityId,
          status: 'active',      // Requerido por ActivityModel (valor por defecto o de respuesta)
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitializing = false;
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

    // CORREGIDO: Comentado para evitar el warning 'unused_local_variable'
    // ya que la llamada _httpService.sendMonitoringEvent aún no está implementada.
    /*
    final event = MonitoringEventModel(
      sessionId: session.id,
      userId: session.userId,
      externalActivityId: activityOption.externalActivityId,
      activityUuid: _activeActivity!.activityUuid,
      interventionType: interventionType,
      confidence: 1.0,
      context: frame.atencion,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    // _httpService.sendMonitoringEvent(event).catchError((_) {});
    */
  }

  Future<void> stopActivity() async {
    if (_activeActivity != null) {
      await _httpService.completeActivity(
        activityUuid: _activeActivity!.activityUuid,
        feedback: {},
      );
    }
  }
}