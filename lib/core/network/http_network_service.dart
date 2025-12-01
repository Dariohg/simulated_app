import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/session_model.dart';
import '../models/activity_model.dart';
import '../models/monitoring_event_model.dart';
import '../config/env_config.dart';

class HttpNetworkService {
  final String baseUrl;
  final http.Client _client;

  HttpNetworkService({http.Client? client})
      : baseUrl = EnvConfig.apiGatewayUrl,
        _client = client ?? http.Client();

  Future<SessionModel> createSession(int userId, String companyId, String disabilityType) async {
    final url = Uri.parse('$baseUrl/sessions/create');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'company_id': companyId,
        'disability_type': disabilityType,
        'cognitive_analysis_enabled': true
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return SessionModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create session: ${response.statusCode}');
    }
  }

  Future<ActivityModel> startActivity(String sessionId, int externalActivityId) async {
    final url = Uri.parse('$baseUrl/sessions/activity/start');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'external_activity_id': externalActivityId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ActivityModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to start activity: ${response.statusCode}');
    }
  }

  Future<void> sendMonitoringEvent(MonitoringEventModel event) async {
    final url = Uri.parse('$baseUrl/monitoring/event');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(event.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send event: ${response.statusCode}');
    }
  }

  Future<void> stopActivity(String activityUuid) async {
    final url = Uri.parse('$baseUrl/sessions/activity/$activityUuid/complete');
    await _client.post(url);
  }
}