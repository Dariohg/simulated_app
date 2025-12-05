import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/intervention_event.dart';

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
  Stream<dynamic>? _broadcastStream;

  WebSocketStatus _status = WebSocketStatus.disconnected;
  StreamSubscription? _streamSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 100;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration pingInterval = Duration(seconds: 15);

  String? _currentSessionId;
  String? _currentActivityUuid;
  int? _userId;
  int? _externalActivityId;
  bool _isPaused = false;

  final StreamController<InterventionEvent> _interventionController =
  StreamController<InterventionEvent>.broadcast();

  WebSocketStatus get status => _status;
  Stream<InterventionEvent> get interventionStream => _interventionController.stream;
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
    if (_status == WebSocketStatus.ready && _currentActivityUuid == activityUuid) {
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

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['websocket'],
      );

      await _channel!.ready;

      _broadcastStream = _channel!.stream.asBroadcastStream();

      _status = WebSocketStatus.handshaking;
      notifyListeners();

      _setupListeners();

      final handshakeSuccess = await _performHandshake(userId, externalActivityId);

      if (!handshakeSuccess) {
        _status = WebSocketStatus.error;
        notifyListeners();
        return false;
      }

      _status = WebSocketStatus.ready;
      _reconnectAttempts = 0;
      _startPingTimer();

      notifyListeners();
      return true;
    } catch (e) {
      _status = WebSocketStatus.error;
      notifyListeners();
      return false;
    }
  }

  void pauseTransmission() {
    if (!_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  void resumeTransmission() {
    if (_isPaused) {
      _isPaused = false;
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
    if (_broadcastStream == null) {
      return false;
    }

    final completer = Completer<bool>();
    StreamSubscription? handshakeSubscription;
    Timer? timeoutTimer;

    handshakeSubscription = _broadcastStream!.listen(
          (message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'handshake_ack') {
            if (!completer.isCompleted) completer.complete(true);
            handshakeSubscription?.cancel();
            timeoutTimer?.cancel();
          }
        } catch (e) {
          debugPrint('[WS] Error handshake: $e');
        }
      },
      onError: (error) {
        if (!completer.isCompleted) completer.complete(false);
        handshakeSubscription?.cancel();
        timeoutTimer?.cancel();
      },
    );

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(false);
        handshakeSubscription?.cancel();
      }
    });

    try {
      final handshakeMessage = jsonEncode({
        'type': 'handshake',
        'user_id': userId,
        'external_activity_id': externalActivityId,
      });

      _channel!.sink.add(handshakeMessage);

      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      handshakeSubscription.cancel();
      return false;
    }
  }

  void _setupListeners() {
    _streamSubscription?.cancel();

    if (_broadcastStream == null) return;

    _streamSubscription = _broadcastStream!.listen(
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

      if (type == 'intervention' || type == 'haptic_nudge') {
        final event = InterventionEvent.fromJson(data);
        _interventionController.add(event);
      }
    } catch (e) {
      debugPrint('[WS] Error: $e');
    }
  }

  void _handleError(dynamic error) {
    _status = WebSocketStatus.error;
    notifyListeners();
    _attemptReconnect();
  }

  void _handleDone() {
    _status = WebSocketStatus.disconnected;
    notifyListeners();

    if (_currentActivityUuid != null) {
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
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

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
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
      debugPrint('[WS] Error ping: $e');
    }
  }

  void sendFrame(Map<String, dynamic> frameData) {
    if (_status != WebSocketStatus.ready) {
      return;
    }

    if (_isPaused) {
      return;
    }

    try {
      frameData['metadata'] ??= <String, dynamic>{};
      frameData['metadata']['timestamp'] = DateTime.now().toIso8601String();
      frameData['metadata']['user_id'] = _userId;
      frameData['metadata']['session_id'] = _currentSessionId;
      frameData['metadata']['external_activity_id'] = _externalActivityId;

      final message = jsonEncode(frameData);
      _channel?.sink.add(message);
    } catch (e) {
      _status = WebSocketStatus.error;
      notifyListeners();
      _attemptReconnect();
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();

    try {
      await _channel?.sink.close();
    } catch (e) {
      debugPrint('[WS] Error disconnect: $e');
    }
    _channel = null;
    _broadcastStream = null;

    _currentSessionId = null;
    _currentActivityUuid = null;
    _userId = null;
    _externalActivityId = null;
    _reconnectAttempts = 0;

    _status = WebSocketStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _interventionController.close();
    super.dispose();
  }
}