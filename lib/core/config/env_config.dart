import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get apiGatewayUrl => dotenv.env['API_GATEWAY_URL'] ?? 'http://localhost:8000';
  static String get apiToken => dotenv.env['API_TOKEN'] ?? '';
}