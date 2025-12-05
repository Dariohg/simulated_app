class SessionModel {
  final String id;
  final int userId;
  final String companyId;
  final String disabilityType;
  final bool cognitiveAnalysisEnabled;

  SessionModel({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.disabilityType,
    required this.cognitiveAnalysisEnabled,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['session_id'],
      userId: json['user_id'],
      companyId: json['company_id'],
      disabilityType: json['disability_type'],
      cognitiveAnalysisEnabled: json['cognitive_analysis_enabled'],
    );
  }
}