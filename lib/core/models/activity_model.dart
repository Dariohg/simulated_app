class ActivityModel {
  final String activityUuid;
  final String sessionId;
  final int externalActivityId;
  final String status;

  ActivityModel({
    required this.activityUuid,
    required this.sessionId,
    required this.externalActivityId,
    required this.status,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      activityUuid: json['activity_uuid'],
      sessionId: json['session_id'],
      externalActivityId: json['external_activity_id'],
      status: json['status'],
    );
  }
}