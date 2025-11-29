import 'dart:async';

class FeedbackService {
  final _feedbackController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get feedbackStream => _feedbackController.stream;

  void connect({
    required String host,
    required String queueName,
    required String username,
    required String password,
    String virtualHost = '/',
    int port = 5672,
  }) {}

  void dispose() {
    _feedbackController.close();
  }
}