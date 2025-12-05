class UserConfig {
  final int userId;
  final DateTime updatedAt;
  final bool cognitiveAnalysisEnabled;
  final bool textNotifications;
  final bool videoSuggestions;
  final bool vibrationAlerts;
  final bool pauseSuggestions;

  UserConfig({
    required this.userId,
    required this.updatedAt,
    required this.cognitiveAnalysisEnabled,
    required this.textNotifications,
    required this.videoSuggestions,
    required this.vibrationAlerts,
    required this.pauseSuggestions,
  });

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>;
    return UserConfig(
      userId: json['user_id'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      cognitiveAnalysisEnabled: settings['cognitive_analysis_enabled'] as bool,
      textNotifications: settings['text_notifications'] as bool,
      videoSuggestions: settings['video_suggestions'] as bool,
      vibrationAlerts: settings['vibration_alerts'] as bool,
      pauseSuggestions: settings['pause_suggestions'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': {
        'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
        'text_notifications': textNotifications,
        'video_suggestions': videoSuggestions,
        'vibration_alerts': vibrationAlerts,
        'pause_suggestions': pauseSuggestions,
      },
    };
  }
}