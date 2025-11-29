import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// CORRECCIÓN: Importar el archivo barril para reconocer la interfaz
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

  @override
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

  @override
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