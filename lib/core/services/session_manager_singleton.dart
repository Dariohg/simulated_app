import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../network/app_network_service.dart';
import '../mocks/mock_user.dart';

class SessionManagerSingleton {
  static final SessionManagerSingleton _instance = SessionManagerSingleton._internal();

  factory SessionManagerSingleton() => _instance;

  SessionManagerSingleton._internal();

  SessionManager? _sessionManager;
  final AppNetworkService _networkService = AppNetworkService();

  SessionManager? get sessionManager => _sessionManager;

  Future<bool> initializeIfNeeded() async {
    if (_sessionManager != null && _sessionManager!.hasActiveSession) {
      return true;
    }

    _sessionManager = SessionManager(
      network: _networkService,
      userId: MockUser.id,
      disabilityType: MockUser.disabilityType,
      cognitiveAnalysisEnabled: true,
    );

    return await _sessionManager!.initializeSession();
  }

  Future<void> finalizeSession() async {
    if (_sessionManager != null) {
      await _sessionManager!.finalizeSession();
      _sessionManager = null;
    }
  }
}