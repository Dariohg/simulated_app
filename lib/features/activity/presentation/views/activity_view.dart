import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/config/env_config.dart';
import '../../../session_summary/presentation/views/session_summary_view.dart';
import '../../../config/presentation/views/session_config_view.dart';

class ActivityView extends StatefulWidget {
  final SessionManager sessionManager;
  final ActivityOption activityOption;

  const ActivityView({
    super.key,
    required this.sessionManager,
    required this.activityOption,
  });

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  bool _isInitializing = true;
  String? _error;
  bool _isSettingsOpen = false;
  bool _isConnected = false;
  CalibrationResult? _savedCalibration;

  @override
  void initState() {
    super.initState();
    _initializeActivityAndCalibration();
  }

  Future<void> _initializeActivityAndCalibration() async {
    try {
      final storage = CalibrationStorage();
      final results = await Future.wait([
        widget.sessionManager.startActivity(
          externalActivityId: widget.activityOption.externalActivityId,
          title: widget.activityOption.title,
          subtitle: widget.activityOption.subtitle,
          content: widget.activityOption.content,
          activityType: widget.activityOption.activityType,
        ),
        storage.load(),
      ]);

      final activitySuccess = results[0] as bool;
      final calibrationData = results[1] as CalibrationResult?;

      if (!activitySuccess) {
        _error = 'No se pudo iniciar la actividad';
      } else {
        _savedCalibration = calibrationData;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _finishActivity() async {
    await widget.sessionManager.completeActivity(feedback: {
      'rating': 5,
      'completed': true,
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SessionSummaryView()),
      );
    }
  }

  void _handleVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 500);
    }
  }

  void _handleVideo(String url, String? title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Video de ayuda'),
        content: Text('URL del video: $url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _openSettings() async {
    setState(() {
      _isSettingsOpen = true;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionConfigView(
          sessionId: widget.sessionManager.sessionId!,
          networkService: widget.sessionManager.network,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isSettingsOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activityOption.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.black87,
                        ),
                      ),
                      if (widget.activityOption.subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.activityOption.subtitle!,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        widget.activityOption.content ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SentimentAnalysisManager(
            sessionManager: widget.sessionManager,
            externalActivityId: widget.activityOption.externalActivityId.toString(),
            gatewayUrl: EnvConfig.apiGatewayUrl,
            apiKey: EnvConfig.apiToken,
            calibration: _savedCalibration,
            isPaused: _isSettingsOpen,
            onVibrateRequested: _handleVibration,
            onVideoReceived: _handleVideo,
            onSettingsRequested: _openSettings,
            onConnectionStatusChanged: (connected) {
              if (mounted && _isConnected != connected) {
                setState(() => _isConnected = connected);
              }
            },
            onStateChanged: (state) {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _finishActivity,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Finalizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }
}