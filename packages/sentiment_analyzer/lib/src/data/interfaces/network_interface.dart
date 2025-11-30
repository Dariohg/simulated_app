abstract class SentimentNetworkInterface {
  Future<Map<String, dynamic>> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  });

  Future<Map<String, dynamic>> getSession(String sessionId);

  Future<void> sendHeartbeat(String sessionId);

  Future<void> pauseSession(String sessionId);

  Future<void> resumeSession(String sessionId);

  Future<Map<String, dynamic>> finalizeSession(String sessionId);

  Future<Map<String, dynamic>> startActivity({
    required String sessionId,
    required int externalActivityId,
    required String title,
    String? subtitle,
    String? content,
    required String activityType,
  });

  Future<Map<String, dynamic>> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  });

  Future<Map<String, dynamic>> abandonActivity({
    required String activityUuid,
  });

  Future<void> updateConfig({
    required String sessionId,
    required bool cognitiveAnalysisEnabled,
    required bool textNotifications,
    required bool videoSuggestions,
    required bool vibrationAlerts,
    required bool pauseSuggestions,
  });
}