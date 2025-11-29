class CalibrationResult {
  final bool isSuccessful;
  final double? earThreshold;
  final double? baselinePitch;
  final double? baselineYaw;

  CalibrationResult({
    required this.isSuccessful,
    this.earThreshold,
    this.baselinePitch,
    this.baselineYaw,
  });
}