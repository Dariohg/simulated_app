import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/network_interface.dart';

enum SessionStatus { active, paused, ended, error, offline }

class SessionManager extends WidgetsBindingObserver {
  final SentimentNetworkInterface _network;
  final int userId;
  final String disabilityType;

  String? _sessionId;
  SessionStatus _status = SessionStatus.ended;
  Timer? _heartbeatTimer;
  int? _currentActivityId;

  final StreamController<SessionStatus> _statusController = StreamController.broadcast();
  Stream<SessionStatus> get statusStream => _statusController.stream;

  SessionManager({
    required SentimentNetworkInterface network,
    required this.userId,
    this.disabilityType = 'auditiva',
  }) : _network = network {
    WidgetsBinding.instance.addObserver(this);
    _monitorConnectivity();
  }

  String? get sessionId => _sessionId;
  bool get isSessionActive => _sessionId != null && _status == SessionStatus.active;

  // --- GESTIÓN DE SESIÓN ---

  Future<void> startSession() async {
    try {
      final response = await _network.post('/sessions', {
        'user_id': userId,
        'disability_type': disabilityType,
        'cognitive_analysis_enabled': true,
      });

      // Verificamos si la respuesta contiene el ID (algunas APIs devuelven mapas diferentes)
      if (response.containsKey('session_id')) {
        _sessionId = response['session_id'];
        _setStatus(SessionStatus.active);
        debugPrint('[SessionManager] Sesión iniciada: $_sessionId');
        _startHeartbeat();
      }
    } catch (e) {
      debugPrint('[SessionManager] Error iniciando sesión: $e');
      _setStatus(SessionStatus.error);
    }
  }

  Future<void> endSession() async {
    if (_sessionId == null) return;

    _stopHeartbeat();
    try {
      await _network.delete('/sessions/$_sessionId');
      debugPrint('[SessionManager] Sesión finalizada en servidor.');
    } catch (e) {
      debugPrint('[SessionManager] Error al finalizar (limpieza local): $e');
    } finally {
      _sessionId = null;
      _currentActivityId = null;
      _setStatus(SessionStatus.ended);
    }
  }

  Future<void> pauseSession({bool manual = false}) async {
    if (_sessionId == null || _status == SessionStatus.paused) return;

    _stopHeartbeat();
    try {
      await _network.post('/sessions/$_sessionId/pause', {});
      _setStatus(SessionStatus.paused);
    } catch (e) {
      debugPrint('[SessionManager] Error pausando: $e');
      _setStatus(SessionStatus.paused); // Pausa local forzada
    }
  }

  Future<void> resumeSession() async {
    if (_sessionId == null) return;

    try {
      await _network.post('/sessions/$_sessionId/resume', {});
      _setStatus(SessionStatus.active);
      _startHeartbeat();
    } catch (e) {
      debugPrint('[SessionManager] Error reanudando: $e');
    }
  }

  // --- GESTIÓN DE ACTIVIDADES ---

  Future<void> startActivity(int activityId, String title, String subtitle, {String type = 'lectura'}) async {
    if (_sessionId == null) await startSession();
    if (_sessionId == null) return;

    _currentActivityId = activityId;
    try {
      await _network.post('/sessions/$_sessionId/activity/start', {
        'external_activity_id': activityId,
        'title': title,
        'subtitle': subtitle,
        'activity_type': type,
      });
      debugPrint('[SessionManager] Actividad $activityId iniciada.');
    } catch (e) {
      debugPrint('[SessionManager] Error iniciando actividad: $e');
    }
  }

  Future<void> completeActivity({Map<String, dynamic>? feedbackData}) async {
    if (_sessionId == null || _currentActivityId == null) return;

    try {
      final body = {
        'external_activity_id': _currentActivityId,
        if (feedbackData != null) 'feedback': feedbackData,
      };

      await _network.post('/sessions/$_sessionId/activity/complete', body);
      debugPrint('[SessionManager] Actividad $_currentActivityId completada.');
      _currentActivityId = null;
    } catch (e) {
      debugPrint('[SessionManager] Error completando actividad: $e');
    }
  }

  Future<void> abandonActivity() async {
    if (_sessionId == null || _currentActivityId == null) return;

    try {
      await _network.post('/sessions/$_sessionId/activity/abandon', {
        'external_activity_id': _currentActivityId
      });
      _currentActivityId = null;
    } catch (e) {
      debugPrint('[SessionManager] Error abandonando actividad: $e');
    }
  }

  // --- HEARTBEAT ---
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_status == SessionStatus.active && _sessionId != null) {
        try {
          await _network.post('/sessions/$_sessionId/heartbeat', {});
        } catch (e) {
          debugPrint('[SessionManager] Fallo heartbeat: $e');
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // --- CICLO DE VIDA ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionId == null) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('[SessionManager] App minimizada -> Pausando');
      pauseSession();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[SessionManager] App retomada -> Reanudando');
      resumeSession();
    }
  }

  // --- CONECTIVIDAD ---
  void _monitorConnectivity() {
    // CORRECCIÓN: Usamos la firma para connectivity_plus ^5.0.2 (Stream<ConnectivityResult>)
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final hasInternet = result != ConnectivityResult.none;

      if (!hasInternet && _status == SessionStatus.active) {
        debugPrint('[SessionManager] Offline -> Pausando lógica interna');
        _stopHeartbeat();
        _setStatus(SessionStatus.offline);
      } else if (hasInternet && _status == SessionStatus.offline) {
        debugPrint('[SessionManager] Online -> Reanudando');
        if (_sessionId != null) {
          resumeSession();
        }
      }
    });
  }

  void _setStatus(SessionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _statusController.close();
  }
}