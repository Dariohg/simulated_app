import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/services/session_manager_singleton.dart';

class HomeViewModel extends ChangeNotifier {
  final SessionManagerSingleton _singleton = SessionManagerSingleton();

  SessionManager? get sessionManager => _singleton.sessionManager;
  String? get sessionId => _singleton.sessionManager?.sessionId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> initializeSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _singleton.initializeIfNeeded();
      if (!success) {
        _error = 'No se pudo crear la sesion';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finalizeSession() async {
    try {
      await _singleton.finalizeSession();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}