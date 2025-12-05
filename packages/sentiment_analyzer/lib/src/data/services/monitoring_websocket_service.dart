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

  String? _currentSessionId;
  String? _currentActivityUuid;
  int? _userId;
  int? _externalActivityId;
  bool _isPaused = false;

  final StreamController<InterventionEvent> _interventionController =
  StreamController<InterventionEvent>.broadcast();

  WebSocketStatus get status => _status;
  Stream<InterventionEvent> get interventionStream => _interventionController.stream;
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
    await disconnect();

    _currentSessionId = sessionId;
    _currentActivityUuid = activityUuid;
    _userId = userId;
    _externalActivityId = externalActivityId;

    _status = WebSocketStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = _buildWebSocketUrl(sessionId, activityUuid);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl), protocols: ['websocket']);
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

  String _buildWebSocketUrl(String sessionId, String activityUuid) {
    String wsBase = gatewayUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$wsBase/ws/$sessionId/$activityUuid?api_key=$apiKey';
  }

  Future<bool> _performHandshake(int userId, int externalActivityId) async {
    final completer = Completer<bool>();
    final subscription = _broadcastStream!.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'handshake_ack' && !completer.isCompleted) {
          completer.complete(true);
        }
      } catch (_) {}
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    try {
      _channel!.sink.add(jsonEncode({
        "type": "handshake",
        "user_id": userId,
        "external_activity_id": externalActivityId
      }));
      final result = await completer.future;
      await subscription.cancel();
      return result;
    } catch (e) {
      await subscription.cancel();
      return false;
    }
  }

  void _setupListeners() {
    _streamSubscription?.cancel();
    if (_broadcastStream == null) return;
    _streamSubscription = _broadcastStream!.listen(_handleMessage,
        onError: _handleError, onDone: _handleDone);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      if (type == 'intervention' || type == 'haptic_nudge') {
        _interventionController.add(InterventionEvent.fromJson(data));
      }
    } catch (_) {}
  }

  void sendFrame(Map<String, dynamic> frameData) {
    if (_status != WebSocketStatus.ready || _isPaused) return;
    try {
      frameData['metadata'] ??= {};
      frameData['metadata']['timestamp'] = DateTime.now().toIso8601String();
      frameData['metadata']['user_id'] = _userId;
      frameData['metadata']['session_id'] = _currentSessionId;
      frameData['metadata']['external_activity_id'] = _externalActivityId;
      _channel?.sink.add(jsonEncode(frameData));
    } catch (_) {}
  }

  void pauseTransmission() => _isPaused = true;
  void resumeTransmission() => _isPaused = false;

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_status == WebSocketStatus.ready) {
        _channel?.sink.add(jsonEncode({"type": "ping", "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000}));
      }
    });
  }

  void _handleError(error) { _status = WebSocketStatus.error; notifyListeners(); _attemptReconnect(); }
  void _handleDone() { _status = WebSocketStatus.disconnected; notifyListeners(); _attemptReconnect(); }

  void _attemptReconnect() {
    if (_reconnectAttempts >= 5 || _currentSessionId == null) return;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_currentActivityUuid != null) {
        connect(sessionId: _currentSessionId!, activityUuid: _currentActivityUuid!, userId: _userId!, externalActivityId: _externalActivityId!);
      }
    });
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _broadcastStream = null;
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