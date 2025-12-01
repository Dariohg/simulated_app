import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/network/app_network_service.dart';
import '../../../../core/mocks/mock_user.dart';

class HomeViewModel extends ChangeNotifier {
  final AppNetworkService _networkService = AppNetworkService();
  SessionManager? _sessionManager;

  SessionManager? get sessionManager => _sessionManager;
  String? get sessionId => _sessionManager?.sessionId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> initializeSession() async {
    if (_sessionManager != null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessionManager = SessionManager(
        network: _networkService,
        userId: MockUser.id,
        disabilityType: MockUser.disabilityType,
        cognitiveAnalysisEnabled: true,
      );

      final success = await _sessionManager!.initializeSession();
      if (!success) {
        _error = 'No se pudo crear la sesion';
        _sessionManager = null;
      }
    } catch (e) {
      _error = e.toString();
      _sessionManager = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finalizeSession() async {
    if (_sessionManager == null) return;

    try {
      await _sessionManager!.finalizeSession();
      _sessionManager = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}