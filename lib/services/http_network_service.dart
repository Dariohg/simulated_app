import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class HttpNetworkService implements SentimentNetworkInterface {
  final String baseUrl;
  final String apiKey;
  final http.Client _client = http.Client();

  HttpNetworkService({
    required this.baseUrl,
    required this.apiKey,
  });

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  @override
  Future<Map<String, dynamic>> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  }) async {
    return await _post('/sessions/', {
      'user_id': userId,
      'disability_type': disabilityType,
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
    });
  }

  @override
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    return await _get('/sessions/$sessionId');
  }

  @override
  Future<void> sendHeartbeat(String sessionId) async {
    await _post('/sessions/$sessionId/heartbeat', {});
  }

  @override
  Future<void> pauseSession(String sessionId) async {
    await _post('/sessions/$sessionId/pause', {});
  }

  @override
  Future<void> resumeSession(String sessionId) async {
    await _post('/sessions/$sessionId/resume', {});
  }

  @override
  Future<Map<String, dynamic>> finalizeSession(String sessionId) async {
    return await _delete('/sessions/$sessionId');
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
    return await _post('/sessions/$sessionId/activity/start', {
      'external_activity_id': externalActivityId,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      'activity_type': activityType,
    });
  }

  @override
  Future<Map<String, dynamic>> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  }) async {
    return await _post('/activities/$activityUuid/complete', {
      'feedback': feedback,
    });
  }

  @override
  Future<Map<String, dynamic>> abandonActivity({
    required String activityUuid,
  }) async {
    return await _post('/activities/$activityUuid/abandon', {});
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
    await _post('/sessions/$sessionId/config', {
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
      'text_notifications': textNotifications,
      'video_suggestions': videoSuggestions,
      'vibration_alerts': vibrationAlerts,
      'pause_suggestions': pauseSuggestions,
    });
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Sin conexion a internet: $e');
    } catch (e) {
      throw NetworkException('Error en POST $endpoint: $e');
    }
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.get(uri, headers: _headers);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Sin conexion a internet: $e');
    } catch (e) {
      throw NetworkException('Error en GET $endpoint: $e');
    }
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.delete(uri, headers: _headers);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Sin conexion a internet: $e');
    } catch (e) {
      throw NetworkException('Error en DELETE $endpoint: $e');
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'status': 'ok'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw AuthException('No autorizado');
    } else if (response.statusCode == 404) {
      throw NotFoundException('Recurso no encontrado');
    } else {
      String message = 'Error del servidor';
      try {
        final body = jsonDecode(response.body);
        message = body['detail'] ?? body['error'] ?? message;
      } catch (_) {}
      throw NetworkException('$message (${response.statusCode})');
    }
  }

  void dispose() {
    _client.close();
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);

  @override
  String toString() => message;
}