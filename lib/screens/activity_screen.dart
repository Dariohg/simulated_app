import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sentiment_analyzer/sentiment_analyzer.dart';

import '../mocks/mock_data.dart';

class ActivityScreen extends StatefulWidget {
  final MockLesson lesson;

  const ActivityScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _activityStarted = false;
  CalibrationResult? _calibration;
  DateTime? _startTime;

  String? _lastIntervention;
  bool _showInterventionBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialize() async {
    final storage = CalibrationStorage();
    _calibration = await storage.load();

    await _startActivityOnServer();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _startTime = DateTime.now();
      });
    }
  }

  Future<void> _startActivityOnServer() async {
    final sessionManager = context.read<SessionManager>();

    final success = await sessionManager.startActivity(
      externalActivityId: widget.lesson.externalActivityId,
      title: widget.lesson.title,
      subtitle: widget.lesson.subtitle,
      content: widget.lesson.content,
      activityType: widget.lesson.activityType,
    );

    if (success) {
      _activityStarted = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  Future<bool> _onWillPop() async {
    if (!_activityStarted) {
      return true;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de la leccion'),
        content: const Text('Tienes una leccion en progreso. Que deseas hacer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'abandon'),
            child: const Text('Abandonar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'complete'),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (result == 'complete') {
      await _completeActivity();
      return true;
    } else if (result == 'abandon') {
      await _abandonActivity();
      return true;
    }

    return false;
  }

  Future<void> _completeActivity() async {
    final sessionManager = context.read<SessionManager>();

    final feedback = {
      'rating': 5,
      'duration_seconds': DateTime.now().difference(_startTime!).inSeconds,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final success = await sessionManager.completeActivity(feedback: feedback);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leccion completada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _abandonActivity() async {
    final sessionManager = context.read<SessionManager>();
    await sessionManager.abandonActivity();
  }

  void _handleIntervention(String type, double confidence) {
    setState(() {
      _lastIntervention = type;
      _showInterventionBanner = true;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showInterventionBanner = false;
        });
      }
    });
  }

  Future<void> _handleVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500, amplitude: 128);
    }
  }

  Future<void> _handleVideoRequest(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showPauseSuggestion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sugerencia de descanso'),
        content: const Text(
          'Parece que necesitas un descanso. '
              'Te gustaria pausar la leccion por unos minutos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Tomar descanso'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.lesson.title),
          actions: [
            if (_activityStarted)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: _completeActivity,
                tooltip: 'Completar leccion',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
          children: [
            _buildActivityContent(),
            if (_activityStarted) _buildSentimentAnalysisOverlay(),
            if (_showInterventionBanner) _buildInterventionBanner(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildActivityContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivityHeader(),
          const SizedBox(height: 16),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildActivityTypeIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.lesson.subtitle.isNotEmpty)
                    Text(
                      widget.lesson.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTypeIcon() {
    IconData icon;
    Color color;

    switch (widget.lesson.activityType) {
      case 'reading':
        icon = Icons.menu_book;
        color = Colors.blue;
        break;
      case 'quiz':
        icon = Icons.quiz;
        color = Colors.orange;
        break;
      case 'video':
        icon = Icons.play_circle;
        color = Colors.red;
        break;
      case 'exercise':
        icon = Icons.edit_note;
        color = Colors.green;
        break;
      case 'coding':
        icon = Icons.code;
        color = Colors.teal;
        break;
      default:
        icon = Icons.article;
        color = Colors.grey;
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          widget.lesson.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentAnalysisOverlay() {
    final sessionManager = context.read<SessionManager>();
    final gatewayUrl = dotenv.env['GATEWAY_URL'] ?? 'http://192.168.1.71:3000';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    final amqpUrl = dotenv.env['AMQP_URL'] ?? '';

    return SentimentAnalysisManager(
      sessionManager: sessionManager,
      externalActivityId: widget.lesson.externalActivityId,
      calibration: _calibration,
      gatewayUrl: gatewayUrl,
      apiKey: apiKey,
      amqpHost: _parseAmqpHost(amqpUrl),
      amqpQueue: 'recommendations',
      amqpUser: _parseAmqpUser(amqpUrl),
      amqpPass: _parseAmqpPass(amqpUrl),
      amqpVirtualHost: _parseAmqpVhost(amqpUrl),
      amqpPort: 5672,
      onStateChanged: (state) {},
      onInterventionReceived: _handleIntervention,
      onVibrateRequested: _handleVibration,
      onVideoRequested: _handleVideoRequest,
    );
  }

  String _parseAmqpHost(String url) {
    try {
      final uri = Uri.parse(url.replaceFirst('amqps://', 'https://').replaceFirst('amqp://', 'http://'));
      return uri.host;
    } catch (_) {
      return 'localhost';
    }
  }

  String _parseAmqpUser(String url) {
    try {
      final uri = Uri.parse(url.replaceFirst('amqps://', 'https://').replaceFirst('amqp://', 'http://'));
      return uri.userInfo.split(':').first;
    } catch (_) {
      return 'guest';
    }
  }

  String _parseAmqpPass(String url) {
    try {
      final uri = Uri.parse(url.replaceFirst('amqps://', 'https://').replaceFirst('amqp://', 'http://'));
      final parts = uri.userInfo.split(':');
      return parts.length > 1 ? parts[1] : 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  String _parseAmqpVhost(String url) {
    try {
      final uri = Uri.parse(url.replaceFirst('amqps://', 'https://').replaceFirst('amqp://', 'http://'));
      return uri.path.isEmpty ? '/' : uri.path.substring(1);
    } catch (_) {
      return '/';
    }
  }

  Widget _buildInterventionBanner() {
    Color bannerColor;
    String bannerText;
    IconData bannerIcon;

    switch (_lastIntervention) {
      case 'vibration':
        bannerColor = Colors.orange;
        bannerText = 'Atencion detectada baja';
        bannerIcon = Icons.vibration;
        break;
      case 'instruction':
        bannerColor = Colors.blue;
        bannerText = 'Sugerencia disponible';
        bannerIcon = Icons.lightbulb_outline;
        break;
      case 'pause':
        bannerColor = Colors.purple;
        bannerText = 'Considera tomar un descanso';
        bannerIcon = Icons.pause_circle_outline;
        break;
      default:
        bannerColor = Colors.grey;
        bannerText = 'Intervencion';
        bannerIcon = Icons.info_outline;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: bannerColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(bannerIcon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bannerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showInterventionBanner = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!_activityStarted) return const SizedBox.shrink();

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _completeActivity,
            icon: const Icon(Icons.check),
            label: const Text('Completar'),
          ),
        ],
      ),
    );
  }
}