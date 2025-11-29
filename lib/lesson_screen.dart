import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Nuevos imports para funcionalidades nativas
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import 'services/http_network_service.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  final String currentUserId = '12';
  final String currentLessonId = 'leccion_historia_ia';

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  CalibrationResult? _savedCalibration;
  bool _isLoading = true;

  late final SentimentNetworkInterface _networkService;

  // Variables AMQP
  late String _amqpHost;
  late String _amqpUser;
  late String _amqpPass;
  late String _amqpVHost;
  late int _amqpPort;
  late String _amqpQueue;

  @override
  void initState() {
    super.initState();
    _setupEnvironment();
    _loadCalibration();
  }

  void _setupEnvironment() {
    final apiKey = dotenv.env['API_KEY_EMOTIONAI'] ?? '';

    _networkService = HttpNetworkService(
      baseUrl: 'http://192.168.1.71:8000', // Ajusta a tu IP local y Puerto de la API Python
      apiKey: apiKey,
    );

    final amqpUrl = dotenv.env['AMQP_URL'] ?? '';
    if (amqpUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(amqpUrl);
        _amqpHost = uri.host;
        _amqpPort = uri.port == 0 ? 5672 : uri.port;
        final userInfo = uri.userInfo.split(':');
        _amqpUser = userInfo.isNotEmpty ? userInfo[0] : 'guest';
        _amqpPass = userInfo.length > 1 ? userInfo[1] : 'guest';
        _amqpVHost = uri.path.length > 1 ? uri.path.substring(1) : '/';
      } catch (e) {
        debugPrint('Error parseando AMQP: $e');
        _amqpHost = 'localhost'; _amqpUser = 'guest'; _amqpPass = 'guest'; _amqpVHost = '/'; _amqpPort = 5672;
      }
    } else {
      _amqpHost = 'localhost'; _amqpUser = 'guest'; _amqpPass = 'guest'; _amqpVHost = '/'; _amqpPort = 5672;
    }

    final queueBase = dotenv.env['EMOTIONAI_SERVICE_QUEUE'] ?? 'feedback_queue';
    _amqpQueue = '${queueBase}_${widget.currentUserId}';
  }

  Future<void> _loadCalibration() async {
    final storage = CalibrationStorage();
    final calibration = await storage.load();
    if (mounted) setState(() { _savedCalibration = calibration; _isLoading = false; });
  }

  // --- IMPLEMENTACIÓN DE VIDEO ---
  Future<void> _handleVideoRequest(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el video')));
    }
  }

  // --- IMPLEMENTACIÓN DE VIBRACIÓN ---
  void _handleVibrationRequest() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lección 1')),
      body: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text('Contenido de la lección...')),
          ),

          if (!_isLoading)
            SentimentAnalysisManager(
              userId: widget.currentUserId,
              lessonId: widget.currentLessonId,
              calibration: _savedCalibration,

              networkInterface: _networkService,

              amqpHost: _amqpHost,
              amqpUser: _amqpUser,
              amqpPass: _amqpPass,
              amqpVirtualHost: _amqpVHost,
              amqpPort: _amqpPort,
              amqpQueue: _amqpQueue,

              // Pasamos las funciones que ejecutan la acción real
              onVideoRequested: _handleVideoRequest,
              onVibrateRequested: _handleVibrationRequest,
            ),
        ],
      ),
    );
  }
}