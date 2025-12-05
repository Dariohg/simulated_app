import 'package:flutter/material.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/network/app_network_service.dart';

class SessionSummaryViewModel extends ChangeNotifier {
  final SessionModel session;
  // final AppNetworkService _httpService; // Eliminado: No se usa en el código actual

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  SessionSummaryViewModel({
    required this.session,
    required AppNetworkService httpService,
  }); // : _httpService = httpService; // Eliminado inicializador de campo no usado

  Future<void> finalizeSession() async {
    _isSaving = true;
    notifyListeners();

    try {
      // Simular llamada al backend para cerrar la sesión oficialmente
      // await _httpService.finalizeSession(session.id);
      await Future.delayed(const Duration(seconds: 1));

    } catch (e) {
      debugPrint("Error cerrando sesión: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}