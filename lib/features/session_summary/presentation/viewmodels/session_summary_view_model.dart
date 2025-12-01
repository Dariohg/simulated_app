import 'package:flutter/material.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/network/http_network_service.dart';

class SessionSummaryViewModel extends ChangeNotifier {
  final SessionModel session;
  final HttpNetworkService _httpService;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  SessionSummaryViewModel({
    required this.session,
    required HttpNetworkService httpService,
  }) : _httpService = httpService;

  Future<void> finalizeSession() async {
    _isSaving = true;
    notifyListeners();

    try {
      // Simular llamada al backend para cerrar la sesión oficialmente
      // await _httpService.closeSession(session.id);
      await Future.delayed(const Duration(seconds: 1));

    } catch (e) {
      debugPrint("Error cerrando sesión: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}