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

  // --- Implementación de la Interfaz SentimentNetworkInterface ---

  @override
  Future<void> sendSessionData(Map<String, dynamic> data) async {
    try {
      // Usamos el método post interno para enviar los datos a un endpoint específico.
      // Ajusta '/session/data' al endpoint real de tu backend si es diferente.
      await post('/session/data', data);
    } catch (e) {
      // Manejo de errores silencioso o re-lanzamiento según tu necesidad
      print('Error enviando datos de sesión: $e');
      rethrow;
    }
  }

  // --- Métodos Auxiliares HTTP (Sin @override) ---

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