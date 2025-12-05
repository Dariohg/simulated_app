import 'package:dio/dio.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class AppNetworkService implements SentimentNetworkInterface {
  final Dio _dio;

  AppNetworkService(String baseUrl, String apiKey)
      : _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
    ),
  );

  @override
  Future<Map<String, dynamic>> getUserConfig(int userId) async {
    final response = await _dio.get('/users/$userId/config');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateUserConfig({
    required int userId,
    required Map<String, dynamic> settings,
  }) async {
    final response = await _dio.patch(
      '/users/$userId/config',
      data: {'settings': settings},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  }) async {
    final response = await _dio.post('/sessions/', data: {
      'user_id': userId,
      'disability_type': disabilityType,
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> pauseSession(String sessionId) async {
    await _dio.post('/sessions/$sessionId/pause');
  }

  @override
  Future<void> resumeSession(String sessionId) async {
    await _dio.post('/sessions/$sessionId/resume');
  }

  @override
  Future<void> finalizeSession(String sessionId) async {
    await _dio.delete('/sessions/$sessionId');
  }

  @override
  Future<Map<String, dynamic>> startActivity({
    required String sessionId,
    required int externalActivityId,
    required String title,
    required String activityType,
    String? subtitle,
    String? content,
  }) async {
    final response = await _dio.post(
      '/sessions/$sessionId/activity/start',
      data: {
        'external_activity_id': externalActivityId,
        'title': title,
        'activity_type': activityType,
        if (subtitle != null) 'subtitle': subtitle,
        if (content != null) 'content': content,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  }) async {
    await _dio.post('/activities/$activityUuid/complete', data: {'feedback': feedback});
  }

  @override
  Future<void> abandonActivity(String activityUuid) async {
    await _dio.post('/activities/$activityUuid/abandon');
  }

  @override
  Future<void> pauseActivity(String activityUuid) async {
    await _dio.post('/activities/$activityUuid/pause');
  }

  @override
  Future<void> resumeActivity(String activityUuid) async {
    await _dio.post('/activities/$activityUuid/resume');
  }
}