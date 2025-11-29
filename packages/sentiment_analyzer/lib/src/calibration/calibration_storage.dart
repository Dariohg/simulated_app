import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'calibration_service.dart';

class CalibrationStorage {
  static const String _key = 'sentiment_calibration_data';

  /// Guarda el resultado de la calibración
  Future<void> save(CalibrationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(result.toMap());
      await prefs.setString(_key, jsonString);
    } catch (e) {
      print('[CalibrationStorage] Error guardando: $e');
    }
  }

  /// Recupera la calibración guardada
  Future<CalibrationResult?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);

      if (jsonString == null) return null;

      final map = jsonDecode(jsonString);
      return CalibrationResult.fromMap(map);
    } catch (e) {
      print('[CalibrationStorage] Error cargando: $e');
      return null;
    }
  }

  /// Borra la calibración (para forzar recalibración)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}