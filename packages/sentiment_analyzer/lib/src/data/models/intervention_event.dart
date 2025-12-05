class InterventionEvent {
  final String packetId;
  final String type; // 'intervention' o 'haptic_nudge'
  final DateTime timestamp;

  // Triggers (Acciones unificadas)
  final String? videoUrl;
  final String? displayText;
  final bool vibrationEnabled;

  // Detalles (Métricas opcionales)
  final String? metricName;
  final double? value;

  InterventionEvent({
    required this.packetId,
    required this.type,
    required this.timestamp,
    this.videoUrl,
    this.displayText,
    this.vibrationEnabled = false,
    this.metricName,
    this.value,
  });

  factory InterventionEvent.fromJson(Map<String, dynamic> json) {
    // 1. Extraer triggers con seguridad
    final triggers = json['triggers'] as Map<String, dynamic>? ?? {};

    // 2. Extraer details con seguridad
    final details = json['details'] as Map<String, dynamic>? ?? {};

    return InterventionEvent(
      packetId: json['packet_id'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'intervention',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),

      // Lógica de Triggers Simplificada
      videoUrl: triggers['video_url'] as String?,
      displayText: triggers['display_text'] as String?,
      vibrationEnabled: triggers['vibration_enabled'] as bool? ?? false,

      metricName: details['metric_name'] as String?,
      value: (details['value'] as num?)?.toDouble(),
    );
  }

  // Helpers para la UI
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasText => displayText != null && displayText!.isNotEmpty;
}