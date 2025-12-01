class MonitoringEventModel {
  final String sessionId;
  final int userId;
  final int externalActivityId;
  final String activityUuid;
  final String interventionType;
  final double confidence;
  final Map<String, dynamic> context;
  final int timestamp;

  MonitoringEventModel({
    required this.sessionId,
    required this.userId,
    required this.externalActivityId,
    required this.activityUuid,
    required this.interventionType,
    required this.confidence,
    required this.context,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      "session_id": sessionId,
      "user_id": userId,
      "external_activity_id": externalActivityId,
      "activity_uuid": activityUuid,
      "intervention_type": interventionType,
      "confidence": confidence,
      "context": context,
      "timestamp": timestamp,
    };
  }
}