import 'package:flutter/foundation.dart'; // Necesario para debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_result.dart';

class CalibrationStorage {
  static const String _keyIsSuccessful = 'calibration_success';
  static const String _keyEarThreshold = 'calibration_ear_threshold';
  static const String _keyPitch = 'calibration_pitch';
  static const String _keyYaw = 'calibration_yaw';

  Future<void> save(CalibrationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyIsSuccessful, result.isSuccessful);

      if (result.earThreshold != null) {
        await prefs.setDouble(_keyEarThreshold, result.earThreshold!);
      }

      if (result.baselinePitch != null) {
        await prefs.setDouble(_keyPitch, result.baselinePitch!);
      }

      if (result.baselineYaw != null) {
        await prefs.setDouble(_keyYaw, result.baselineYaw!);
      }
    } catch (e) {
      debugPrint('[CalibrationStorage] Error guardando calibracion: $e');
    }
  }

  Future<CalibrationResult?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!prefs.containsKey(_keyIsSuccessful)) {
        return null;
      }

      final isSuccessful = prefs.getBool(_keyIsSuccessful) ?? false;
      final earThreshold = prefs.getDouble(_keyEarThreshold);
      final pitch = prefs.getDouble(_keyPitch);
      final yaw = prefs.getDouble(_keyYaw);

      return CalibrationResult(
        isSuccessful: isSuccessful,
        earThreshold: earThreshold,
        baselinePitch: pitch,
        baselineYaw: yaw,
      );
    } catch (e) {
      debugPrint('[CalibrationStorage] Error cargando calibracion: $e');
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsSuccessful);
    await prefs.remove(_keyEarThreshold);
    await prefs.remove(_keyPitch);
    await prefs.remove(_keyYaw);
  }
}