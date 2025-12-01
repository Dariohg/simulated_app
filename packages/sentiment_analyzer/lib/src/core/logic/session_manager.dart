import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/interfaces/network_interface.dart';

enum SessionStatus {
  none,
  active,
  paused,
  pausedAutomatically,
  expired,
  finalized,
}

enum ActivityStatus {
  none,
  inProgress,
  paused,
  completed,
  abandoned,
}

class ActivityInfo {
  final String activityUuid;
  final int externalActivityId;
  final String title;
  final String? subtitle;
  final String? content;
  final String activityType;
  final DateTime startedAt;

  ActivityInfo({
    required this.activityUuid,
    required this.externalActivityId,
    required this.title,
    this.subtitle,
    this.content,
    required this.activityType,
    required this.startedAt,
  });
}

class SessionManager extends ChangeNotifier {
  final SentimentNetworkInterface network;
  final int userId;
  final String disabilityType;
  final bool cognitiveAnalysisEnabled;

  String? _sessionId;
  SessionStatus _sessionStatus = SessionStatus.none;
  ActivityStatus _activityStatus = ActivityStatus.none;
  ActivityInfo? _currentActivity;

  Timer? _heartbeatTimer;

  // Variables de reconexión ELIMINADAS para evitar warnings de código muerto
  // ya que desactivamos el heartbeat loop.

  String? get sessionId => _sessionId;
  SessionStatus get sessionStatus => _sessionStatus;
  ActivityStatus get activityStatus => _activityStatus;
  ActivityInfo? get currentActivity => _currentActivity;
  String? get currentActivityUuid => _currentActivity?.activityUuid;
  int? get currentExternalActivityId => _currentActivity?.externalActivityId;
  bool get hasActiveSession =>
      _sessionId != null && _sessionStatus == SessionStatus.active;
  bool get hasActiveActivity =>
      _currentActivity != null && _activityStatus == ActivityStatus.inProgress;

  SessionManager({
    required this.network,
    required this.userId,
    this.disabilityType = 'none',
    this.cognitiveAnalysisEnabled = true,
  });

  Future<bool> initializeSession() async {
    try {
      debugPrint('[SessionManager] Creando sesion para usuario $userId');

      final response = await network.createSession(
        userId: userId,
        disabilityType: disabilityType,
        cognitiveAnalysisEnabled: cognitiveAnalysisEnabled,
      );

      _sessionId = response['session_id'];
      _sessionStatus = SessionStatus.active;
      // _reconnectAttempts = 0; // Eliminado

      debugPrint('[SessionManager] Sesion creada: $_sessionId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SessionManager] Error creando sesion: $e');
      return false;
    }
  }

  Future<bool> recoverSession(String existingSessionId) async {
    try {
      debugPrint('[SessionManager] Recuperando sesion: $existingSessionId');

      final response = await network.getSession(existingSessionId);
      final status = response['status'] as String?;

      if (status == 'expirada' || status == 'finalizada') {
        debugPrint('[SessionManager] Sesion expirada/finalizada, creando nueva');
        return await initializeSession();
      }

      _sessionId = existingSessionId;

      if (status == 'pausada' || status == 'pausada_automaticamente') {
        _sessionStatus = SessionStatus.paused;
        await resumeSession();
      } else {
        _sessionStatus = SessionStatus.active;
      }

      final currentActivityData = response['current_activity'];
      if (currentActivityData != null) {
        _currentActivity = ActivityInfo(
          activityUuid: currentActivityData['activity_uuid'] ?? '',
          externalActivityId: currentActivityData['external_activity_id'],
          title: currentActivityData['title'] ?? '',
          activityType: 'recovered',
          startedAt:
          DateTime.tryParse(currentActivityData['started_at'] ?? '') ??
              DateTime.now(),
        );
        _activityStatus = ActivityStatus.inProgress;
      }

      debugPrint('[SessionManager] Sesion recuperada con estado: $status');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SessionManager] Error recuperando sesion: $e');
      return await initializeSession();
    }
  }

  Future<bool> startActivity({
    required int externalActivityId,
    required String title,
    String? subtitle,
    String? content,
    required String activityType,
  }) async {
    if (_sessionId == null) {
      debugPrint('[SessionManager] No hay sesion activa para iniciar actividad');
      return false;
    }

    try {
      debugPrint(
          '[SessionManager] Iniciando actividad: $title (ID: $externalActivityId)');

      final response = await network.startActivity(
        sessionId: _sessionId!,
        externalActivityId: externalActivityId,
        title: title,
        subtitle: subtitle,
        content: content,
        activityType: activityType,
      );

      if (response['status'] == 'activity_started') {
        final activityUuid = response['activity_uuid'] as String;

        _currentActivity = ActivityInfo(
          activityUuid: activityUuid,
          externalActivityId: externalActivityId,
          title: title,
          subtitle: subtitle,
          content: content,
          activityType: activityType,
          startedAt: DateTime.now(),
        );
        _activityStatus = ActivityStatus.inProgress;

        debugPrint('[SessionManager] Actividad iniciada: $activityUuid');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[SessionManager] Error iniciando actividad: $e');
      return false;
    }
  }

  Future<bool> completeActivity({required Map<String, dynamic> feedback}) async {
    if (_sessionId == null || _currentActivity == null) {
      debugPrint(
          '[SessionManager] No hay sesion/actividad activa para completar');
      return false;
    }

    try {
      debugPrint(
          '[SessionManager] Completando actividad: ${_currentActivity!.activityUuid}');

      final response = await network.completeActivity(
        activityUuid: _currentActivity!.activityUuid,
        feedback: feedback,
      );

      if (response['status'] == 'completada') {
        _activityStatus = ActivityStatus.completed;
        _currentActivity = null;

        debugPrint('[SessionManager] Actividad completada exitosamente');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[SessionManager] Error completando actividad: $e');
      return false;
    }
  }

  Future<bool> abandonActivity() async {
    if (_sessionId == null || _currentActivity == null) {
      debugPrint(
          '[SessionManager] No hay sesion/actividad activa para abandonar');
      return false;
    }

    try {
      debugPrint(
          '[SessionManager] Abandonando actividad: ${_currentActivity!.activityUuid}');

      final response = await network.abandonActivity(
        activityUuid: _currentActivity!.activityUuid,
      );

      if (response['status'] == 'abandonada') {
        _activityStatus = ActivityStatus.abandoned;
        _currentActivity = null;

        debugPrint('[SessionManager] Actividad abandonada exitosamente');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[SessionManager] Error abandonando actividad: $e');
      return false;
    }
  }

  Future<bool> pauseActivity() async {
    if (_currentActivity == null) {
      debugPrint('[SessionManager] No hay actividad activa para pausar');
      return false;
    }

    try {
      debugPrint(
          '[SessionManager] Pausando actividad: ${_currentActivity!.activityUuid}');

      final response = await network.pauseActivity(
        activityUuid: _currentActivity!.activityUuid,
      );

      if (response['status'] == 'pausada') {
        _activityStatus = ActivityStatus.paused;
        debugPrint('[SessionManager] Actividad pausada');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[SessionManager] Error pausando actividad: $e');
      return false;
    }
  }

  Future<bool> resumeActivity() async {
    if (_currentActivity == null) {
      debugPrint('[SessionManager] No hay actividad para reanudar');
      return false;
    }

    try {
      debugPrint(
          '[SessionManager] Reanudando actividad: ${_currentActivity!.activityUuid}');

      final response = await network.resumeActivity(
        activityUuid: _currentActivity!.activityUuid,
      );

      if (response['status'] == 'en_progreso') {
        _activityStatus = ActivityStatus.inProgress;
        debugPrint('[SessionManager] Actividad reanudada');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[SessionManager] Error reanudando actividad: $e');
      return false;
    }
  }

  Future<bool> pauseSession() async {
    if (_sessionId == null) return false;

    try {
      debugPrint('[SessionManager] Pausando sesion');

      await network.pauseSession(_sessionId!);
      _sessionStatus = SessionStatus.paused;

      debugPrint('[SessionManager] Sesion pausada');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SessionManager] Error pausando sesion: $e');
      return false;
    }
  }

  Future<bool> resumeSession() async {
    if (_sessionId == null) return false;

    try {
      debugPrint('[SessionManager] Reanudando sesion');

      await network.resumeSession(_sessionId!);
      _sessionStatus = SessionStatus.active;

      debugPrint('[SessionManager] Sesion reanudada');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SessionManager] Error reanudando sesion: $e');
      return false;
    }
  }

  Future<bool> finalizeSession() async {
    if (_sessionId == null) return false;

    try {
      debugPrint('[SessionManager] Finalizando sesion');

      if (_currentActivity != null) {
        await abandonActivity();
      }

      await network.finalizeSession(_sessionId!);
      _sessionStatus = SessionStatus.finalized;

      final finalizedSessionId = _sessionId;
      _sessionId = null;
      _currentActivity = null;
      _activityStatus = ActivityStatus.none;

      debugPrint('[SessionManager] Sesion finalizada: $finalizedSessionId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SessionManager] Error finalizando sesion: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}