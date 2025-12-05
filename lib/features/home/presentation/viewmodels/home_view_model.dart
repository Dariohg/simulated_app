import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/network/app_network_service.dart';

class HomeViewModel extends ChangeNotifier {
  SessionService? _sessionService;
  bool _isLoading = false;
  String? _error;

  SessionService? get sessionService => _sessionService;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initializeSession(int userId, String disabilityType) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final network = AppNetworkService(
        EnvConfig.apiGatewayUrl,
        EnvConfig.apiToken,
      );

      _sessionService = SessionService(
        network: network,
        gatewayUrl: EnvConfig.apiGatewayUrl,
        apiKey: EnvConfig.apiToken,
      );

      await _sessionService!.createSession(
        userId: userId,
        disabilityType: disabilityType,
        cognitiveAnalysisEnabled: true,
      );

    } catch (e) {
      if (_sessionService == null) {
        final network = AppNetworkService(
          EnvConfig.apiGatewayUrl,
          EnvConfig.apiToken,
        );
        _sessionService = SessionService(
          network: network,
          gatewayUrl: EnvConfig.apiGatewayUrl,
          apiKey: EnvConfig.apiToken,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finalizeSession() async {
    if (_sessionService != null) {
      await _sessionService!.finalizeSession();
      _sessionService = null;
      notifyListeners();
    }
  }
}