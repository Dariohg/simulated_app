import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/config/env_config.dart';
import '../../../session_summary/presentation/views/session_summary_view.dart';

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
  String? _instructionMessage;
  bool _showPauseDialog = false;

  @override
  void initState() {
    super.initState();
    _startActivity();
  }

  Future<void> _startActivity() async {
    try {
      final success = await widget.sessionManager.startActivity(
        externalActivityId: widget.activityOption.externalActivityId,
        title: widget.activityOption.title,
        subtitle: widget.activityOption.subtitle,
        content: widget.activityOption.content,
        activityType: widget.activityOption.activityType,
      );

      if (!success) {
        _error = 'No se pudo iniciar la actividad';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isInitializing = false;
      });
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
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(duration: 500);
    }
  }

  void _handleInstruction(String message) {
    setState(() {
      _instructionMessage = message;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _instructionMessage = null;
        });
      }
    });
  }

  void _handlePause(String message) {
    setState(() {
      _showPauseDialog = true;
    });
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
          SentimentAnalysisManager(
            sessionManager: widget.sessionManager,
            externalActivityId: widget.activityOption.externalActivityId,
            gatewayUrl: EnvConfig.apiGatewayUrl,
            apiKey: EnvConfig.apiToken,
            onVibrateRequested: _handleVibration,
            onInstructionReceived: _handleInstruction,
            onPauseReceived: _handlePause,
            onVideoReceived: _handleVideo,
            onStateChanged: (state) {
              print('[ActivityView] Estado: ${state.finalState}');
            },
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: _buildHeader(),
          ),
          if (_instructionMessage != null)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: _buildInstructionBanner(),
            ),
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: _buildBottomControls(),
          ),
          if (_showPauseDialog) _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.activityOption.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (widget.activityOption.subtitle != null)
                  Text(
                    widget.activityOption.subtitle!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _instructionMessage!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Salir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _finishActivity,
          icon: const Icon(Icons.check),
          label: const Text('Finalizar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.coffee, size: 48, color: Colors.purple),
              const SizedBox(height: 16),
              const Text(
                'Descanso sugerido',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detectamos que podrias necesitar un descanso.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPauseDialog = false;
                      });
                    },
                    child: const Text('Continuar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showPauseDialog = false;
                      });
                    },
                    child: const Text('Tomar descanso'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}