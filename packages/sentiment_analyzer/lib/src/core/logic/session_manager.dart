import 'dart:async';
import '../../data/interfaces/network_interface.dart';

typedef DataProvider = Map<String, dynamic> Function();

class SessionManager {
  final SentimentNetworkInterface network;
  final int userId;

  bool _isPaused = false;
  Timer? _transmissionTimer;
  DataProvider? _dataProvider;

  bool get isPaused => _isPaused;

  SessionManager({
    required this.network,
    required this.userId
  });

  void setDataProvider(DataProvider provider) {
    _dataProvider = provider;
  }

  void startSession() {
    _isPaused = false;
    network.sendSessionStart(userId);
    _startTransmissionLoop();
  }

  void pauseSession({bool manual = false}) {
    _isPaused = true;
    _transmissionTimer?.cancel();
  }

  void resumeSession() {
    _isPaused = false;
    _startTransmissionLoop();
  }

  void _startTransmissionLoop() {
    _transmissionTimer?.cancel();
    _transmissionTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isPaused && _dataProvider != null) {
        final data = _dataProvider!();
        network.sendAnalysisData(data);
      }
    });
  }

  void dispose() {
    network.sendSessionEnd(userId);
    _transmissionTimer?.cancel();
  }
}