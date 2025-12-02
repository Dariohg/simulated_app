class RecommendationContent {
  final String? type;
  final String? message;
  final String? videoUrl;
  final String? title;

  RecommendationContent({
    this.type,
    this.message,
    this.videoUrl,
    this.title,
  });

  factory RecommendationContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RecommendationContent();
    return RecommendationContent(
      type: json['type']?.toString(),
      message: json['message']?.toString(),
      videoUrl: json['video_url']?.toString(),
      title: json['title']?.toString(),
    );
  }
}

class VibrationPattern {
  final int duration;
  final int intensity;
  final List<int>? pattern;

  VibrationPattern({
    this.duration = 500,
    this.intensity = 100,
    this.pattern,
  });

  factory VibrationPattern.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VibrationPattern();
    return VibrationPattern(
      duration: _parseIntSafeDefault(json['duration'], 500),
      intensity: _parseIntSafeDefault(json['intensity'], 100),
      pattern: _parseIntListSafe(json['pattern']),
    );
  }
}

class RecommendationMetadata {
  final String? cognitiveEvent;
  final double? precision;
  final double? confidence;
  final String? topic;
  final String? contentType;

  RecommendationMetadata({
    this.cognitiveEvent,
    this.precision,
    this.confidence,
    this.topic,
    this.contentType,
  });

  factory RecommendationMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RecommendationMetadata();
    return RecommendationMetadata(
      cognitiveEvent: json['cognitive_event']?.toString(),
      precision: _parseDoubleSafe(json['precision']),
      confidence: _parseDoubleSafe(json['confidence']),
      topic: json['topic']?.toString(),
      contentType: json['content_type']?.toString(),
    );
  }
}

class Recommendation {
  final String sessionId;
  final int? userId;
  final String action;
  final RecommendationContent? content;
  final VibrationPattern? vibration;
  final RecommendationMetadata? metadata;
  final String? timestamp;

  Recommendation({
    required this.sessionId,
    this.userId,
    required this.action,
    this.content,
    this.vibration,
    this.metadata,
    this.timestamp,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      sessionId: json['session_id']?.toString() ?? '',
      userId: _parseIntSafeNullable(json['user_id']),
      action: json['action']?.toString() ?? 'unknown',
      content: RecommendationContent.fromJson(
        json['content'] is Map<String, dynamic> ? json['content'] : null,
      ),
      vibration: VibrationPattern.fromJson(
        json['vibration'] is Map<String, dynamic> ? json['vibration'] : null,
      ),
      metadata: RecommendationMetadata.fromJson(
        json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
      ),
      timestamp: json['timestamp']?.toString(),
    );
  }

  bool get isVibration => action == 'vibration';
  bool get isInstruction => action == 'instruction';
  bool get isPause => action == 'pause';
  bool get hasVideo => content?.videoUrl != null && content!.videoUrl!.isNotEmpty;
  bool get hasMessage => content?.message != null && content!.message!.isNotEmpty;
}

// Helper functions para parsing seguro
int _parseIntSafeDefault(dynamic value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int? _parseIntSafeNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDoubleSafe(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<int>? _parseIntListSafe(dynamic value) {
  if (value == null) return null;
  if (value is! List) return null;
  return value.map((e) {
    if (e is int) return e;
    if (e is num) return e.toInt();
    if (e is String) return int.tryParse(e) ?? 0;
    return 0;
  }).toList();
}