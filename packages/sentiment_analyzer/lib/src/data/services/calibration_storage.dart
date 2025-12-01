import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_result.dart';

class CalibrationStorage {
  // Usamos una clave nueva para evitar conflictos con versiones viejas
  static const String _keyCalibration = 'calibration_data_v2';

  Future<void> save(CalibrationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guardamos todo el objeto como JSON string
      final jsonString = jsonEncode(result.toJson());
      await prefs.setString(_keyCalibration, jsonString);
      debugPrint('[CalibrationStorage] Calibracion guardada OK');
    } catch (e) {
      debugPrint('[CalibrationStorage] Error guardando: $e');
    }
  }

  Future<CalibrationResult?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyCalibration);

      if (jsonString == null) {
        debugPrint('[CalibrationStorage] No hay calibracion guardada');
        return null;
      }

      final jsonMap = jsonDecode(jsonString);
      final result = CalibrationResult.fromJson(jsonMap);

      if (!result.isSuccessful) {
        return null;
      }

      return result;
    } catch (e) {
      debugPrint('[CalibrationStorage] Error cargando: $e');
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCalibration);
  }
}