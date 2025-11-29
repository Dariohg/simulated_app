import 'dart:async';
import '../../data/interfaces/network_interface.dart';

class SessionManager {
  final SentimentNetworkInterface network;
  final int userId;
  bool _isPaused = false;
  Timer? _timer;

  SessionManager({required this.network, required this.userId});

  void startSession() {
    _isPaused = false;
    _startHeartbeat();
  }

  void pauseSession({bool manual = false}) {
    _isPaused = true;
    _timer?.cancel();
  }

  void resumeSession() {
    _isPaused = false;
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isPaused) {
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}