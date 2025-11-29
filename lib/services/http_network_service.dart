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

  @override
  Future<void> sendSessionStart(int userId) async {
    try {
      await post('/session/start', {'userId': userId});
    } catch (e) {
      print('Error sending session start: $e');
    }
  }

  @override
  Future<void> sendSessionEnd(int userId) async {
    try {
      await post('/session/end', {'userId': userId});
    } catch (e) {
      print('Error sending session end: $e');
    }
  }

  @override
  Future<void> sendHeartbeat(int userId) async {
    try {
      await post('/session/heartbeat', {'userId': userId});
    } catch (e) {
      print('Error sending heartbeat: $e');
    }
  }

  @override
  Future<void> sendAnalysisData(Map<String, dynamic> data) async {
    try {
      await post('/session/data', data);
    } catch (e) {
      print('Error sending analysis data: $e');
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Error POST: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Error DELETE: $e');
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Error GET: $e');
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw HttpException('${response.statusCode}: ${response.body}');
    }
  }
}