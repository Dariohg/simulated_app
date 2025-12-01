import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../config/env_config.dart';

class AppNetworkService implements SentimentNetworkInterface {
  late final Dio _dio;
  final String baseUrl;
  final String apiKey;

  AppNetworkService({String? baseUrl, String? apiKey})
      : baseUrl = baseUrl ?? EnvConfig.apiGatewayUrl,
        apiKey = apiKey ?? EnvConfig.apiToken {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${this.apiKey}',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[DIO] $obj'),
    ));
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
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _dio.get('/sessions/$sessionId');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> sendHeartbeat(String sessionId) async {
    await _dio.post('/sessions/$sessionId/heartbeat');
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
  Future<Map<String, dynamic>> finalizeSession(String sessionId) async {
    final response = await _dio.delete('/sessions/$sessionId');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> startActivity({
    required String sessionId,
    required int externalActivityId,
    required String title,
    String? subtitle,
    String? content,
    required String activityType,
  }) async {
    final response = await _dio.post('/sessions/$sessionId/activity/start', data: {
      'external_activity_id': externalActivityId,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      'activity_type': activityType,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/complete', data: {
      'feedback': feedback,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> abandonActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/abandon');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> pauseActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/pause');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> resumeActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/resume');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> updateConfig({
    required String sessionId,
    required bool cognitiveAnalysisEnabled,
    required bool textNotifications,
    required bool videoSuggestions,
    required bool vibrationAlerts,
    required bool pauseSuggestions,
  }) async {
    await _dio.post('/sessions/$sessionId/config', data: {
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
      'text_notifications': textNotifications,
      'video_suggestions': videoSuggestions,
      'vibration_alerts': vibrationAlerts,
      'pause_suggestions': pauseSuggestions,
    });
  }
}