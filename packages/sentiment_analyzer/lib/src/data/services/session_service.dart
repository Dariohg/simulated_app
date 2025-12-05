import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/network_interface.dart';
import '../models/intervention_event.dart';
import 'monitoring_websocket_service.dart';
import 'notification_service.dart';

class SessionService extends ChangeNotifier {
  final SentimentNetworkInterface network;
  final MonitoringWebSocketService websocket;
  final NotificationService notificationService;

  String? _sessionId;
  String? _activityUuid;
  int? _userId;

  final StreamController<Map<String, dynamic>> _analysisController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<InterventionEvent> get interventionStream => websocket.interventionStream;
  Stream<Map<String, dynamic>> get analysisStream => _analysisController.stream;
  String? get sessionId => _sessionId;
  String? get activityUuid => _activityUuid;

  SessionService({
    required this.network,
    required String gatewayUrl,
    required String apiKey,
  })  : websocket = MonitoringWebSocketService(
    gatewayUrl: gatewayUrl,
    apiKey: apiKey,
  ),
        notificationService = NotificationService() {
    websocket.interventionStream.listen((event) {
      notificationService.addNotification(event);
    });
  }

  Future<bool> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  }) async {
    try {
      final response = await network.createSession(
        userId: userId,
        disabilityType: disabilityType,
        cognitiveAnalysisEnabled: cognitiveAnalysisEnabled,
      );
      _sessionId = response['session_id'];
      _userId = userId;
      notifyListeners();
      return true;
    } catch (e) {
      _sessionId = "offline_session_${DateTime.now().millisecondsSinceEpoch}";
      _userId = userId;
      notifyListeners();
      return true;
    }
  }

  Future<bool> startActivity({
    required int externalActivityId,
    required String title,
    required String activityType,
    String? subtitle,
    String? content,
  }) async {
    if (_userId == null) return false;

    try {
      if (_sessionId != null && !_sessionId!.startsWith("offline")) {
        final response = await network.startActivity(
          sessionId: _sessionId!,
          externalActivityId: externalActivityId,
          title: title,
          activityType: activityType,
          subtitle: subtitle,
          content: content,
        );
        _activityUuid = response['activity_uuid'];
      } else {
        _activityUuid = "offline_activity_${DateTime.now().millisecondsSinceEpoch}";
      }

      await websocket.connect(
        sessionId: _sessionId ?? "offline",
        activityUuid: _activityUuid!,
        userId: _userId!,
        externalActivityId: externalActivityId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _activityUuid = "offline_activity_${DateTime.now().millisecondsSinceEpoch}";
      notifyListeners();
      return true;
    }
  }

  void sendAnalysisFrame(Map<String, dynamic> frameData) {
    if (_activityUuid != null) {
      _analysisController.add(frameData);
      websocket.sendFrame(frameData);
    }
  }

  Future<void> pauseActivity() async {
    try {
      if (_activityUuid != null && !_activityUuid!.startsWith("offline")) {
        await network.pauseActivity(_activityUuid!);
      }
      websocket.pauseTransmission();
    } catch (_) {}
  }

  Future<void> resumeActivity() async {
    try {
      if (_activityUuid != null && !_activityUuid!.startsWith("offline")) {
        await network.resumeActivity(_activityUuid!);
      }
      websocket.resumeTransmission();
    } catch (_) {}
  }

  Future<void> completeActivity(Map<String, dynamic> feedback) async {
    try {
      if (_activityUuid != null && !_activityUuid!.startsWith("offline")) {
        await network.completeActivity(
          activityUuid: _activityUuid!,
          feedback: feedback,
        );
      }
    } catch (_) {}
    await websocket.disconnect();
    _activityUuid = null;
    notifyListeners();
  }

  Future<void> abandonActivity() async {
    try {
      if (_activityUuid != null && !_activityUuid!.startsWith("offline")) {
        await network.abandonActivity(_activityUuid!);
      }
    } catch (_) {}
    await websocket.disconnect();
    _activityUuid = null;
    notifyListeners();
  }

  Future<void> finalizeSession() async {
    try {
      if (_sessionId != null && !_sessionId!.startsWith("offline")) {
        if (_activityUuid != null) {
          await abandonActivity();
        }
      }
    } catch (_) {}
    await websocket.disconnect();
    _sessionId = null;
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    websocket.dispose();
    notificationService.dispose();
    _analysisController.close();
    super.dispose();
  }
}