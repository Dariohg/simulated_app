import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/network_interface.dart';
import 'monitoring_websocket_service.dart';
import 'notification_service.dart';

class SessionService extends ChangeNotifier {
  final SentimentNetworkInterface network;
  final MonitoringWebSocketService websocket;
  final NotificationService notificationService;

  String? _sessionId;
  String? _activityUuid;
  int? _userId;
  bool _isActive = false;

  final StreamController<Map<String, dynamic>> _analysisController =
  StreamController<Map<String, dynamic>>.broadcast();

  String? get sessionId => _sessionId;
  String? get activityUuid => _activityUuid;
  bool get isActive => _isActive;
  Stream<Map<String, dynamic>> get analysisStream => _analysisController.stream;

  SessionService({
    required this.network,
    required String gatewayUrl,
    required String apiKey,
  }) : websocket = MonitoringWebSocketService(
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

      _sessionId = response['session_id'] as String;
      _userId = userId;
      _isActive = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> startActivity({
    required int externalActivityId,
    required String title,
    required String activityType,
    String? subtitle,
    String? content,
  }) async {
    if (_sessionId == null || _userId == null) return false;

    try {
      final response = await network.startActivity(
        sessionId: _sessionId!,
        externalActivityId: externalActivityId,
        title: title,
        activityType: activityType,
        subtitle: subtitle,
        content: content,
      );

      _activityUuid = response['activity_uuid'] as String;

      await websocket.connect(
        sessionId: _sessionId!,
        activityUuid: _activityUuid!,
        userId: _userId!,
        externalActivityId: externalActivityId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void sendAnalysisFrame(Map<String, dynamic> frameData) {
    if (_sessionId == null || _activityUuid == null) return;

    _analysisController.add(frameData);
    websocket.sendFrame(frameData);
  }

  Future<void> pauseActivity() async {
    if (_activityUuid != null) {
      await network.pauseActivity(_activityUuid!);
      websocket.pauseTransmission();
    }
  }

  Future<void> resumeActivity() async {
    if (_activityUuid != null) {
      await network.resumeActivity(_activityUuid!);
      websocket.resumeTransmission();
    }
  }

  Future<void> completeActivity(Map<String, dynamic> feedback) async {
    if (_activityUuid != null) {
      await network.completeActivity(
        activityUuid: _activityUuid!,
        feedback: feedback,
      );
      await websocket.disconnect();
      _activityUuid = null;
      notifyListeners();
    }
  }

  Future<void> abandonActivity() async {
    if (_activityUuid != null) {
      await network.abandonActivity(_activityUuid!);
      await websocket.disconnect();
      _activityUuid = null;
      notifyListeners();
    }
  }

  Future<void> pauseSession() async {
    if (_sessionId != null) {
      await network.pauseSession(_sessionId!);
    }
  }

  Future<void> resumeSession() async {
    if (_sessionId != null) {
      await network.resumeSession(_sessionId!);
    }
  }

  Future<void> finalizeSession() async {
    if (_sessionId != null) {
      if (_activityUuid != null) {
        await abandonActivity();
      }
      await network.finalizeSession(_sessionId!);
      _sessionId = null;
      _userId = null;
      _isActive = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    websocket.dispose();
    notificationService.dispose();
    _analysisController.close();
    super.dispose();
  }
}