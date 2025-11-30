import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class MonitoringWebSocketService extends ChangeNotifier {
  final String baseUrl;

  WebSocketChannel? _channel;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  String? _currentSessionId;

  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 30);

  final StreamController<Map<String, dynamic>> _interventionController =
  StreamController<Map<String, dynamic>>.broadcast();

  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;
  Stream<Map<String, dynamic>> get interventions => _interventionController.stream;

  MonitoringWebSocketService({required this.baseUrl});

  Future<bool> connect(String sessionId) async {
    if (_status == WebSocketStatus.connected && _currentSessionId == sessionId) {
      debugPrint('[MonitoringWS] Ya conectado a sesion: $sessionId');
      return true;
    }

    await disconnect();

    _currentSessionId = sessionId;
    _status = WebSocketStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = _buildWebSocketUrl(sessionId);
      debugPrint('[MonitoringWS] Conectando a: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready;

      _status = WebSocketStatus.connected;
      _reconnectAttempts = 0;

      _setupListeners();
      _startPingTimer();

      debugPrint('[MonitoringWS] Conectado exitosamente');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MonitoringWS] Error conectando: $e');
      _status = WebSocketStatus.error;
      notifyListeners();
      return false;
    }
  }

  String _buildWebSocketUrl(String sessionId) {
    String wsBase = baseUrl;

    if (wsBase.startsWith('http://')) {
      wsBase = wsBase.replaceFirst('http://', 'ws://');
    } else if (wsBase.startsWith('https://')) {
      wsBase = wsBase.replaceFirst('https://', 'wss://');
    } else if (!wsBase.startsWith('ws://') && !wsBase.startsWith('wss://')) {
      wsBase = 'ws://$wsBase';
    }

    return '$wsBase/ws/$sessionId';
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
      debugPrint('[MonitoringWS] Mensaje recibido: $data');

      if (data.containsKey('intervention_id') || data.containsKey('type')) {
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

    if (_currentSessionId != null) {
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

    if (_currentSessionId == null) return;

    _reconnectAttempts++;
    _status = WebSocketStatus.reconnecting;
    notifyListeners();

    final delay = reconnectDelay * _reconnectAttempts;
    debugPrint('[MonitoringWS] Reconectando en ${delay.inSeconds}s (intento $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentSessionId != null) {
        connect(_currentSessionId!);
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (_status == WebSocketStatus.connected) {
        sendPing();
      }
    });
  }

  void sendPing() {
    if (_status != WebSocketStatus.connected) return;

    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      debugPrint('[MonitoringWS] Error enviando ping: $e');
    }
  }

  void sendFrame(Map<String, dynamic> frameData) {
    if (_status != WebSocketStatus.connected) {
      debugPrint('[MonitoringWS] No conectado, frame descartado');
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