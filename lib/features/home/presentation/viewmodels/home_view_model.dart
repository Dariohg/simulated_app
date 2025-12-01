import 'package:flutter/material.dart';
import '../../../../core/network/http_network_service.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/mocks/mock_user.dart';

class HomeViewModel extends ChangeNotifier {
  final HttpNetworkService _httpService = HttpNetworkService();

  SessionModel? _currentSession;
  SessionModel? get currentSession => _currentSession;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> initializeSession() async {
    if (_currentSession != null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSession = await _httpService.createSession(
        MockUser.id,
        MockUser.companyId,
        MockUser.disabilityType,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}