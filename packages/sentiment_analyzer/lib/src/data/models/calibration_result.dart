class CalibrationResult {
  final bool isSuccessful;
  final double? earThreshold;
  final double? baselinePitch;
  final double? baselineYaw;
  final DateTime? calibratedAt;

  CalibrationResult({
    required this.isSuccessful,
    this.earThreshold,
    this.baselinePitch,
    this.baselineYaw,
    this.calibratedAt,
  });

  factory CalibrationResult.failed() {
    return CalibrationResult(isSuccessful: false);
  }

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    return CalibrationResult(
      isSuccessful: json['is_successful'] as bool? ?? false,
      earThreshold: (json['ear_threshold'] as num?)?.toDouble(),
      baselinePitch: (json['baseline_pitch'] as num?)?.toDouble(),
      baselineYaw: (json['baseline_yaw'] as num?)?.toDouble(),
      calibratedAt: json['calibrated_at'] != null
          ? DateTime.tryParse(json['calibrated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_successful': isSuccessful,
      'ear_threshold': earThreshold,
      'baseline_pitch': baselinePitch,
      'baseline_yaw': baselineYaw,
      'calibrated_at': calibratedAt?.toIso8601String(),
    };
  }
}