import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../session_summary/presentation/views/session_summary_view.dart';

class ActivityView extends StatefulWidget {
  final SessionService sessionService;
  final ActivityOption activityOption;
  final int userId;

  const ActivityView({
    super.key,
    required this.sessionService,
    required this.activityOption,
    required this.userId,
  });

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  bool _isFinishing = false;
  bool _isCameraVisible = true;
  StreamSubscription? _interventionSubscription;

  @override
  void initState() {
    super.initState();
    _setupInterventions();
  }

  void _setupInterventions() {
    // Escuchamos eventos del WebSocket
    _interventionSubscription = widget.sessionService.interventionStream.listen((event) {
      if (!mounted) return;

      if (event.vibrationEnabled) {
        Vibration.vibrate(duration: 500);
      }

      // Notificación visual discreta (SnackBar)
      if ((event.videoUrl != null && event.videoUrl!.isNotEmpty) ||
          (event.displayText != null && event.displayText!.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nueva recomendación disponible. Revisa la campana."),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _handleVideoRequest(String videoUrl) async {
    await widget.sessionService.pauseActivity();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoPlayerModal(
        videoUrl: videoUrl,
        onClose: () => Navigator.pop(context),
      ),
    );

    if (mounted) {
      await widget.sessionService.resumeActivity();
    }
  }

  void _toggleCameraVisibility() {
    setState(() => _isCameraVisible = !_isCameraVisible);
  }

  Future<void> _finishActivity() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    await widget.sessionService.completeActivity({'rating': 5, 'completed': true});

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SessionSummaryView()),
            (route) => false,
      );
    }
  }

  Future<void> _closeActivity() async {
    await widget.sessionService.abandonActivity();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _interventionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activityOption.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (widget.activityOption.subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.activityOption.subtitle!,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          widget.activityOption.content ?? 'Sigue las instrucciones del instructor.',
                          style: const TextStyle(fontSize: 18, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!_isFinishing && _isCameraVisible)
              AnalysisOverlay(
                sessionService: widget.sessionService,
              ),
            if (!_isFinishing)
              FloatingMenu(
                sessionService: widget.sessionService,
                onVideoRequested: _handleVideoRequest,
                onCameraToggle: _toggleCameraVisibility,
                isCameraVisible: _isCameraVisible,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isFinishing ? null : _finishActivity,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Finalizar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isFinishing ? null : _closeActivity,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}