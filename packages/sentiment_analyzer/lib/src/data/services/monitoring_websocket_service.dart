import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

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

  String? _currentSessionId;
  String? _currentActivityUuid;
  int? _userId;
  int? _externalActivityId;

  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration handshakeTimeout = Duration(seconds: 10);

  final StreamController<Map<String, dynamic>> _interventionController =
  StreamController<Map<String, dynamic>>.broadcast();

  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.ready;
  bool get isConnecting => _status == WebSocketStatus.connecting || _status == WebSocketStatus.handshaking;
  Stream<Map<String, dynamic>> get interventions => _interventionController.stream;
  String? get currentActivityUuid => _currentActivityUuid;

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
    if (_status == WebSocketStatus.ready &&
        _currentActivityUuid == activityUuid) {
      debugPrint('[MonitoringWS] Ya conectado a actividad: $activityUuid');
      return true;
    }

    await disconnect();

    _currentSessionId = sessionId;
    _currentActivityUuid = activityUuid;
    _userId = userId;
    _externalActivityId = externalActivityId;

    _status = WebSocketStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = _buildWebSocketUrl(sessionId, activityUuid);
      debugPrint('[MonitoringWS] Conectando a: $wsUrl');

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['websocket'],
      );

      await _channel!.ready;

      _status = WebSocketStatus.handshaking;
      notifyListeners();

      _setupListeners();

      final handshakeSuccess = await _performHandshake(userId, externalActivityId);

      if (!handshakeSuccess) {
        debugPrint('[MonitoringWS] Handshake fallido');
        await disconnect();
        return false;
      }

      _status = WebSocketStatus.ready;
      _reconnectAttempts = 0;
      _startPingTimer();

      debugPrint('[MonitoringWS] Conectado y listo para actividad $activityUuid');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MonitoringWS] Error conectando: $e');
      _status = WebSocketStatus.error;
      notifyListeners();
      return false;
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
    final completer = Completer<bool>();
    StreamSubscription? handshakeSubscription;
    Timer? timeoutTimer;

    try {
      timeoutTimer = Timer(handshakeTimeout, () {
        if (!completer.isCompleted) {
          debugPrint('[MonitoringWS] Timeout en handshake');
          completer.complete(false);
        }
      });

      handshakeSubscription = _channel?.stream.listen((message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;

          if (data['type'] == 'handshake_ack' && data['status'] == 'ready') {
            debugPrint('[MonitoringWS] Handshake exitoso');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } else if (data.containsKey('error')) {
            debugPrint('[MonitoringWS] Error en handshake: ${data['error']}');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        } catch (e) {
          debugPrint('[MonitoringWS] Error parseando respuesta de handshake: $e');
        }
      });

      final handshakeMessage = jsonEncode({
        'type': 'handshake',
        'user_id': userId,
        'external_activity_id': externalActivityId,
      });

      debugPrint('[MonitoringWS] Enviando handshake: $handshakeMessage');
      _channel?.sink.add(handshakeMessage);

      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      await handshakeSubscription?.cancel();
    }
  }

  void _setupListeners() {
    _subscription?.cancel();

    _subscription = _channel?.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      if (data['type'] == 'handshake_ack') {
        return;
      }

      debugPrint('[MonitoringWS] Mensaje recibido: $data');

      if (data.containsKey('intervention_id') ||
          (data.containsKey('type') && data['type'] != 'pong')) {
        _interventionController.add(data);
      }
    } catch (e) {
      debugPrint('[MonitoringWS] Error parseando mensaje: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[MonitoringWS] Error: $error');
    _status = WebSocketStatus.error;
    notifyListeners();
    _attemptReconnect();
  }

  void _handleDone() {
    debugPrint('[MonitoringWS] Conexion cerrada');
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
    if (_status != WebSocketStatus.ready) return;

    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      debugPrint('[MonitoringWS] Error enviando ping: $e');
    }
  }

  void sendFrame(Map<String, dynamic> frameData) {
    if (_status != WebSocketStatus.ready) {
      debugPrint('[MonitoringWS] No listo, frame descartado (status: $_status)');
      return;
    }

    try {
      final json = jsonEncode(frameData);
      _channel?.sink.add(json);
    } catch (e) {
      debugPrint('[MonitoringWS] Error enviando frame: $e');
    }
  }

  Future<void> disconnect() async {
    debugPrint('[MonitoringWS] Desconectando');

    _pingTimer?.cancel();
    _pingTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (e) {
      debugPrint('[MonitoringWS] Error cerrando canal: $e');
    }

    _channel = null;
    _currentSessionId = null;
    _currentActivityUuid = null;
    _userId = null;
    _externalActivityId = null;
    _status = WebSocketStatus.disconnected;
    _reconnectAttempts = 0;

    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _interventionController.close();
    super.dispose();
  }
}