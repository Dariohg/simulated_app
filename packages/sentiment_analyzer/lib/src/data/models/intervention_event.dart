class InterventionTriggers {
  final String? videoUrl;
  final String? displayText;
  final bool vibrationEnabled;

  InterventionTriggers({
    this.videoUrl,
    this.displayText,
    required this.vibrationEnabled,
  });

  factory InterventionTriggers.fromJson(Map<String, dynamic> json) {
    return InterventionTriggers(
      videoUrl: json['video_url'] as String?,
      displayText: json['display_text'] as String?,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? false,
    );
  }
}

class InterventionDetails {
  final String metricName;
  final double value;
  final double confidence;
  final int durationMs;

  InterventionDetails({
    required this.metricName,
    required this.value,
    required this.confidence,
    required this.durationMs,
  });

  factory InterventionDetails.fromJson(Map<String, dynamic> json) {
    return InterventionDetails(
      metricName: json['metric_name'] as String,
      value: (json['value'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      durationMs: json['duration_ms'] as int,
    );
  }
}

class InterventionEvent {
  final String packetId;
  final DateTime timestamp;
  final String type;
  final InterventionTriggers triggers;
  final InterventionDetails details;

  InterventionEvent({
    required this.packetId,
    required this.timestamp,
    required this.type,
    required this.triggers,
    required this.details,
  });

  factory InterventionEvent.fromJson(Map<String, dynamic> json) {
    return InterventionEvent(
      packetId: json['packet_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      triggers: InterventionTriggers.fromJson(json['triggers'] as Map<String, dynamic>),
      details: InterventionDetails.fromJson(json['details'] as Map<String, dynamic>),
    );
  }

  bool get isIntervention => type == 'intervention';
  bool get isHapticNudge => type == 'haptic_nudge';
  bool get hasVideo => triggers.videoUrl != null;
  bool get hasText => triggers.displayText != null;
  bool get hasVibration => triggers.vibrationEnabled;
}