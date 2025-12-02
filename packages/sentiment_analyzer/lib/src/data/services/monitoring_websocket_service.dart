import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/recommendation_model.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  handshaking,
  ready,
  reconnecting,
  error,
}

class MonitoringWebSocketService extends ChangeNotifier {
  final String gatewayUrl;
  final String apiKey;

  WebSocketChannel? _channel;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  StreamSubscription? _streamSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 15);

  String? _currentSessionId;
  String? _currentActivityUuid;
  int? _userId;
  int? _externalActivityId;
  bool _isPaused = false;

  int _framesSent = 0;

  final StreamController<Recommendation> _recommendationController =
  StreamController<Recommendation>.broadcast();

  WebSocketStatus get status => _status;
  Stream<Recommendation> get recommendationStream => _recommendationController.stream;
  String? get currentActivityUuid => _currentActivityUuid;
  bool get isPaused => _isPaused;

  MonitoringWebSocketService({
    required this.gatewayUrl,
    required this.apiKey,
  });

  Future<bool> connect({
    required String sessionId,
    required String activityUuid,
    required int userId,
    required int externalActivityId,
  }) async {
    debugPrint('[MonitoringWS] ===== INICIO CONNECT =====');
    debugPrint('[MonitoringWS] sessionId: $sessionId');
    debugPrint('[MonitoringWS] activityUuid: $activityUuid');
    debugPrint('[MonitoringWS] userId: $userId');
    debugPrint('[MonitoringWS] externalActivityId: $externalActivityId');

    if (_status == WebSocketStatus.ready && _currentActivityUuid == activityUuid) {
      debugPrint('[MonitoringWS] Ya conectado a actividad: $activityUuid');
      return true;
    }

    await disconnect();

    _currentSessionId = sessionId;
    _currentActivityUuid = activityUuid;
    _userId = userId;
    _externalActivityId = externalActivityId;
    _framesSent = 0;

    _status = WebSocketStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = _buildWebSocketUrl(sessionId, activityUuid);
      debugPrint('[MonitoringWS] URL construida: $wsUrl');
      debugPrint('[MonitoringWS] Conectando...');

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['websocket'],
      );

      debugPrint('[MonitoringWS] Esperando ready...');
      await _channel!.ready;
      debugPrint('[MonitoringWS] Channel ready OK');

      _status = WebSocketStatus.handshaking;
      notifyListeners();

      _setupListeners();
      debugPrint('[MonitoringWS] Listeners configurados');

      debugPrint('[MonitoringWS] Iniciando handshake...');
      final handshakeSuccess = await _performHandshake(userId, externalActivityId);

      if (!handshakeSuccess) {
        debugPrint('[MonitoringWS] ERROR: Handshake fallido');
        await disconnect();
        return false;
      }

      debugPrint('[MonitoringWS] Handshake exitoso!');
      _status = WebSocketStatus.ready;
      _reconnectAttempts = 0;
      _startPingTimer();

      debugPrint('[MonitoringWS] ===== CONECTADO Y LISTO =====');
      debugPrint('[MonitoringWS] Estado: ready para actividad $activityUuid');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MonitoringWS] ERROR conectando: $e');
      _status = WebSocketStatus.error;
      notifyListeners();
      return false;
    }
  }

  void pauseTransmission() {
    if (!_isPaused) {
      _isPaused = true;
      debugPrint('[MonitoringWS] Transmision pausada');
      notifyListeners();
    }
  }

  void resumeTransmission() {
    if (_isPaused) {
      _isPaused = false;
      debugPrint('[MonitoringWS] Transmision reanudada');
      notifyListeners();
    }
  }

  String _buildWebSocketUrl(String sessionId, String activityUuid) {
    String wsBase = gatewayUrl;

    if (wsBase.startsWith('http://')) {
      wsBase = wsBase.replaceFirst('http://', 'ws://');
    } else if (wsBase.startsWith('https://')) {
      wsBase = wsBase.replaceFirst('https://', 'wss://');
    } else if (!wsBase.startsWith('ws://') && !wsBase.startsWith('wss://')) {
      wsBase = 'ws://$wsBase';
    }

    return '$wsBase/ws/$sessionId/$activityUuid?api_key=$apiKey';
  }

  Future<bool> _performHandshake(int userId, int externalActivityId) async {
    debugPrint('[MonitoringWS] _performHandshake() llamado');
    debugPrint('[MonitoringWS]   userId: $userId');
    debugPrint('[MonitoringWS]   externalActivityId: $externalActivityId');

    final completer = Completer<bool>();
    StreamSubscription? handshakeSubscription;
    Timer? timeoutTimer;

    handshakeSubscription = _channel!.stream.listen(
          (message) {
        debugPrint('[MonitoringWS] Mensaje recibido durante handshake: $message');
        try {
          final data = jsonDecode(message);
          debugPrint('[MonitoringWS] Mensaje parseado: ${data['type']}');

          if (data['type'] == 'handshake_ack') {
            debugPrint('[MonitoringWS] HANDSHAKE_ACK recibido!');
            timeoutTimer?.cancel();
            handshakeSubscription?.cancel();
            completer.complete(true);
          }
        } catch (e) {
          debugPrint('[MonitoringWS] Error parseando mensaje handshake: $e');
        }
      },
      onError: (error) {
        debugPrint('[MonitoringWS] Error en stream durante handshake: $error');
        timeoutTimer?.cancel();
        handshakeSubscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    timeoutTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[MonitoringWS] TIMEOUT esperando handshake_ack (5s)');
      handshakeSubscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    try {
      final handshakeMessage = jsonEncode({
        'type': 'handshake',
        'user_id': userId,
        'external_activity_id': externalActivityId,
      });

      debugPrint('[MonitoringWS] Enviando handshake: $handshakeMessage');
      _channel!.sink.add(handshakeMessage);
      debugPrint('[MonitoringWS] Handshake enviado, esperando ack...');

      final result = await completer.future;
      debugPrint('[MonitoringWS] Resultado handshake: $result');
      return result;
    } catch (e) {
      timeoutTimer.cancel();
      handshakeSubscription.cancel();
      debugPrint('[MonitoringWS] ERROR enviando handshake: $e');
      return false;
    }
  }

  void _setupListeners() {
    _streamSubscription?.cancel();
    _streamSubscription = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: false,
    );
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;

      if (type == 'handshake_ack' || type == 'pong') {
        return;
      }

      if (type == 'recommendation') {
        debugPrint('[MonitoringWS] Recomendacion recibida: ${data['action']}');
        final recommendation = Recommendation.fromJson(data);
        _recommendationController.add(recommendation);
      }
    } catch (e) {
      debugPrint('[MonitoringWS] Error parseando mensaje: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[MonitoringWS] Error en stream: $error');
    _status = WebSocketStatus.error;
    notifyListeners();
    _attemptReconnect();
  }

  void _handleDone() {
    debugPrint('[MonitoringWS] Stream cerrado (onDone)');
    _status = WebSocketStatus.disconnected;
    notifyListeners();

    if (_currentActivityUuid != null) {
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[MonitoringWS] Max intentos de reconexion alcanzados');
      _status = WebSocketStatus.error;
      notifyListeners();
      return;
    }

    if (_currentSessionId == null ||
        _currentActivityUuid == null ||
        _userId == null ||
        _externalActivityId == null) {
      return;
    }

    _reconnectAttempts++;
    _status = WebSocketStatus.reconnecting;
    notifyListeners();

    final delay = reconnectDelay * _reconnectAttempts;
    debugPrint('[MonitoringWS] Reconectando en ${delay.inSeconds}s (intento $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentActivityUuid != null) {
        connect(
          sessionId: _currentSessionId!,
          activityUuid: _currentActivityUuid!,
          userId: _userId!,
          externalActivityId: _externalActivityId!,
        );
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (_status == WebSocketStatus.ready) {
        _sendPing();
      }
    });
  }

  void _sendPing() {
    try {
      final pingMessage = jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _channel?.sink.add(pingMessage);
    } catch (e) {
      debugPrint('[MonitoringWS] Error enviando ping: $e');
    }
  }

  void sendFrame(Map<String, dynamic> frameData) {
    if (_status != WebSocketStatus.ready) {
      if (_framesSent % 50 == 0) {
        debugPrint('[MonitoringWS] No se puede enviar frame, estado: $_status');
      }
      return;
    }

    if (_isPaused) {
      return;
    }

    try {
      frameData['metadata'] ??= {};
      frameData['metadata']['timestamp'] = DateTime.now().toIso8601String();
      frameData['metadata']['user_id'] = _userId;
      frameData['metadata']['session_id'] = _currentSessionId;
      frameData['metadata']['external_activity_id'] = _externalActivityId;

      final message = jsonEncode(frameData);
      _channel?.sink.add(message);

      _framesSent++;

      if (_framesSent % 25 == 0) {
        debugPrint('[MonitoringWS] Frame #$_framesSent enviado');
      }
    } catch (e) {
      debugPrint('[MonitoringWS] ERROR enviando frame: $e');
    }
  }

  Future<void> disconnect() async {
    if (_currentActivityUuid != null) {
      debugPrint('[MonitoringWS] Desconectando de actividad: $_currentActivityUuid');
    }

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();

    await _channel?.sink.close();
    _channel = null;

    _currentSessionId = null;
    _currentActivityUuid = null;
    _userId = null;
    _externalActivityId = null;
    _reconnectAttempts = 0;
    _framesSent = 0;

    _status = WebSocketStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _recommendationController.close();
    super.dispose();
  }
}