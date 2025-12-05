class AnalysisFrame {
  final String sessionId;
  final String activityUuid;
  final int userId;
  final int externalActivityId;
  final DateTime timestamp;
  final Map<String, dynamic> faceMetrics;

  AnalysisFrame({
    required this.sessionId,
    required this.activityUuid,
    required this.userId,
    required this.externalActivityId,
    required this.timestamp,
    required this.faceMetrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'face_metrics': faceMetrics,
      'metadata': {
        'timestamp': timestamp.toIso8601String(),
        'session_id': sessionId,
        'user_id': userId,
        'external_activity_id': externalActivityId,
      },
    };
  }
}