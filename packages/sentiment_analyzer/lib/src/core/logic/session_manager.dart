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

typedef BiometricDataProvider = Map<String, dynamic> Function();

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
  BiometricDataProvider? _dataProvider;

  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 3);

  String? get sessionId => _sessionId;
  SessionStatus get sessionStatus => _sessionStatus;
  ActivityStatus get activityStatus => _activityStatus;
  ActivityInfo? get currentActivity => _currentActivity;
  String? get currentActivityUuid => _currentActivity?.activityUuid;
  int? get currentExternalActivityId => _currentActivity?.externalActivityId;
  bool get hasActiveSession => _sessionId != null && _sessionStatus == SessionStatus.active;
  bool get hasActiveActivity => _currentActivity != null && _activityStatus == ActivityStatus.inProgress;

  SessionManager({
    required this.network,
    required this.userId,
    this.disabilityType = 'none',
    this.cognitiveAnalysisEnabled = true,
  });

  void setDataProvider(BiometricDataProvider provider) {
    _dataProvider = provider;
  }

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
      _reconnectAttempts = 0;

      _startHeartbeatLoop();

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
        _startHeartbeatLoop();
      }

      final currentActivityData = response['current_activity'];
      if (currentActivityData != null) {
        _currentActivity = ActivityInfo(
          activityUuid: currentActivityData['activity_uuid'] ?? '',
          externalActivityId: currentActivityData['external_activity_id'],
          title: currentActivityData['title'] ?? '',
          activityType: 'recovered',
          startedAt: DateTime.tryParse(currentActivityData['started_at'] ?? '') ?? DateTime.now(),
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
      debugPrint('[SessionManager] Iniciando actividad: $title (ID: $externalActivityId)');

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
      debugPrint('[SessionManager] No hay sesion/actividad activa para completar');
      return false;
    }

    try {
      debugPrint('[SessionManager] Completando actividad: ${_currentActivity!.activityUuid}');

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
      debugPrint('[SessionManager] No hay sesion/actividad activa para abandonar');
      return false;
    }

    try {
      debugPrint('[SessionManager] Abandonando actividad: ${_currentActivity!.activityUuid}');

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

  Future<bool> pauseSession() async {
    if (_sessionId == null) return false;

    try {
      debugPrint('[SessionManager] Pausando sesion');

      await network.pauseSession(_sessionId!);
      _sessionStatus = SessionStatus.paused;
      _stopHeartbeatLoop();

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
      _startHeartbeatLoop();

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
      _stopHeartbeatLoop();

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

  void _startHeartbeatLoop() {
    _stopHeartbeatLoop();

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) async {
      await _sendHeartbeat();
    });

    debugPrint('[SessionManager] Heartbeat loop iniciado');
  }

  void _stopHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('[SessionManager] Heartbeat loop detenido');
  }

  Future<void> _sendHeartbeat() async {
    if (_sessionId == null || _sessionStatus != SessionStatus.active) return;

    try {
      await network.sendHeartbeat(_sessionId!);
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('[SessionManager] Error en heartbeat: $e');
      await _handleConnectionError();
    }
  }

  Future<void> _handleConnectionError() async {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;

    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[SessionManager] Max intentos de reconexion alcanzados');
      _sessionStatus = SessionStatus.pausedAutomatically;
      _stopHeartbeatLoop();
      notifyListeners();
      _isReconnecting = false;
      return;
    }

    debugPrint('[SessionManager] Intento de reconexion $_reconnectAttempts/$maxReconnectAttempts');

    await Future.delayed(reconnectDelay * _reconnectAttempts);

    try {
      if (_sessionId != null) {
        final response = await network.getSession(_sessionId!);
        final status = response['status'];

        if (status == 'activa') {
          _sessionStatus = SessionStatus.active;
          debugPrint('[SessionManager] Reconexion exitosa');
        } else if (status == 'expirada' || status == 'finalizada') {
          debugPrint('[SessionManager] Sesion expirada, creando nueva');
          await initializeSession();
        }
      }
    } catch (e) {
      debugPrint('[SessionManager] Error en reconexion: $e');
    }

    _isReconnecting = false;
  }

  @override
  void dispose() {
    _stopHeartbeatLoop();
    super.dispose();
  }
}