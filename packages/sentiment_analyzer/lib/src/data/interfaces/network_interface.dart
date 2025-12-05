abstract class SentimentNetworkInterface {
  Future<Map<String, dynamic>> getUserConfig(int userId);

  Future<Map<String, dynamic>> updateUserConfig({
    required int userId,
    required Map<String, dynamic> settings,
  });

  Future<Map<String, dynamic>> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  });

  Future<void> pauseSession(String sessionId);

  Future<void> resumeSession(String sessionId);

  Future<void> finalizeSession(String sessionId);

  Future<Map<String, dynamic>> startActivity({
    required String sessionId,
    required int externalActivityId,
    required String title,
    required String activityType,
    String? subtitle,
    String? content,
  });

  Future<void> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  });

  Future<void> abandonActivity(String activityUuid);

  Future<void> pauseActivity(String activityUuid);

  Future<void> resumeActivity(String activityUuid);
}