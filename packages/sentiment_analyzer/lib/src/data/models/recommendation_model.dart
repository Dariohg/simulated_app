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
      type: json['type'] as String?,
      message: json['message'] as String?,
      videoUrl: json['video_url'] as String?,
      title: json['title'] as String?,
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
      duration: json['duration'] as int? ?? 500,
      intensity: json['intensity'] as int? ?? 100,
      pattern: (json['pattern'] as List<dynamic>?)?.cast<int>(),
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
      cognitiveEvent: json['cognitive_event'] as String?,
      precision: (json['precision'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      topic: json['topic'] as String?,
      contentType: json['content_type'] as String?,
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
      sessionId: json['session_id'] as String? ?? '',
      userId: json['user_id'] as int?,
      action: json['action'] as String? ?? 'unknown',
      content: RecommendationContent.fromJson(json['content'] as Map<String, dynamic>?),
      vibration: VibrationPattern.fromJson(json['vibration'] as Map<String, dynamic>?),
      metadata: RecommendationMetadata.fromJson(json['metadata'] as Map<String, dynamic>?),
      timestamp: json['timestamp'] as String?,
    );
  }

  bool get isVibration => action == 'vibration';
  bool get isInstruction => action == 'instruction';
  bool get isPause => action == 'pause';
  bool get hasVideo => content?.videoUrl != null && content!.videoUrl!.isNotEmpty;
  bool get hasMessage => content?.message != null && content!.message!.isNotEmpty;
}