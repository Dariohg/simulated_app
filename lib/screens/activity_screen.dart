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
            child: const Text('Continuar'),
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
    final duration = DateTime.now().difference(_startTime ?? DateTime.now());

    final feedback = {
      'completed': true,
      'duration_seconds': duration.inSeconds,
      'activity_type': widget.lesson.activityType,
    };

    final success = await sessionManager.completeActivity(feedback: feedback);

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _abandonActivity() async {
    final sessionManager = context.read<SessionManager>();

    final success = await sessionManager.abandonActivity();

    if (success && mounted) {
      Navigator.pop(context, false);
    }
  }

  void _handleVideoRequest(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el video')),
        );
      }
    }
  }

  void _handleVibrationRequest() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
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

    switch (type) {
      case 'vibration':
        _handleVibrationRequest();
        break;
      case 'pause':
        _showPauseSuggestion();
        break;
    }
  }

  void _showPauseSuggestion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sugerencia de descanso'),
        content: const Text(
          'Parece que necesitas un descanso. Te gustaria pausar la leccion por unos minutos?',
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
    final monitoringUrl = dotenv.env['MONITORING_WS_URL'] ?? 'ws://192.168.1.71:3008';

    final amqpUrl = dotenv.env['AMQP_URL'] ?? '';
    String amqpHost = 'localhost';
    String amqpUser = 'guest';
    String amqpPass = 'guest';
    String amqpVHost = '/';
    int amqpPort = 5672;

    if (amqpUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(amqpUrl);
        amqpHost = uri.host;
        amqpPort = uri.port == 0 ? 5672 : uri.port;
        final userInfo = uri.userInfo.split(':');
        amqpUser = userInfo.isNotEmpty ? userInfo[0] : 'guest';
        amqpPass = userInfo.length > 1 ? userInfo[1] : 'guest';
        amqpVHost = uri.path.length > 1 ? uri.path.substring(1) : '/';
      } catch (e) {
        debugPrint('[ActivityScreen] Error parseando AMQP URL: $e');
      }
    }

    return SentimentAnalysisManager(
      sessionManager: sessionManager,
      externalActivityId: widget.lesson.externalActivityId,
      calibration: _calibration,
      monitoringWebSocketUrl: monitoringUrl,
      amqpHost: amqpHost,
      amqpUser: amqpUser,
      amqpPass: amqpPass,
      amqpVirtualHost: amqpVHost,
      amqpPort: amqpPort,
      amqpQueue: 'feedback_queue_${sessionManager.userId}',
      onVideoRequested: _handleVideoRequest,
      onVibrateRequested: _handleVibrationRequest,
      onInterventionReceived: _handleIntervention,
    );
  }

  Widget _buildInterventionBanner() {
    Color color;
    IconData icon;
    String message;

    switch (_lastIntervention) {
      case 'vibration':
        color = Colors.orange;
        icon = Icons.notifications_active;
        message = 'Alerta de atencion';
        break;
      case 'instruction':
        color = Colors.blue;
        icon = Icons.help_outline;
        message = 'Ayuda disponible';
        break;
      case 'pause':
        color = Colors.green;
        icon = Icons.pause_circle;
        message = 'Considera tomar un descanso';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
        message = 'Intervencion';
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: color,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _abandonActivity,
                icon: const Icon(Icons.close),
                label: const Text('Abandonar'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _completeActivity,
                icon: const Icon(Icons.check),
                label: const Text('Completar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}