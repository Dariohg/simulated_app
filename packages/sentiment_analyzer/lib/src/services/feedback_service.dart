import 'dart:async';
import 'dart:convert';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/foundation.dart';

class FeedbackService {
  Client? _client;
  StreamSubscription? _subscription;

  final StreamController<Map<String, dynamic>> _feedbackController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get feedbackStream => _feedbackController.stream;

  Future<void> connect({
    required String host,
    required String queueName,
    String virtualHost = '/',
    String username = 'guest',
    String password = 'guest',
    int port = 5672,
  }) async {
    try {
      ConnectionSettings settings = ConnectionSettings(
        host: host,
        port: port,
        virtualHost: virtualHost,
        // CORRECCIÓN: Nombre correcto de la clase de autenticación
        authProvider: PlainAuthenticator(username, password),
      );

      _client = Client(settings: settings);

      Channel channel = await _client!.channel();
      Queue queue = await channel.queue(queueName, durable: true);
      Consumer consumer = await queue.consume();

      debugPrint('[FeedbackService] Conectado a RabbitMQ: $queueName');

      _subscription = consumer.listen((AmqpMessage message) {
        try {
          final payload = message.payloadAsString;
          debugPrint("[FeedbackService] Mensaje recibido: $payload");

          final Map<String, dynamic> data = jsonDecode(payload);
          _feedbackController.add(data);

        } catch (e) {
          debugPrint("[FeedbackService] Error decodificando mensaje: $e");
        }
      });
    } catch (e) {
      debugPrint("[FeedbackService] Error de conexión RabbitMQ: $e");
    }
  }

  void dispose() {
    _subscription?.cancel();
    _client?.close();
    _feedbackController.close();
    debugPrint('[FeedbackService] Desconectado.');
  }
}