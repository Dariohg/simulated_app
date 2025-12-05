import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../session_summary/presentation/views/session_summary_view.dart';

class ActivityView extends StatefulWidget {
  final SessionService sessionService;
  final int userId;
  final int externalActivityId;
  final String title;
  final String activityType;

  const ActivityView({
    super.key,
    required this.sessionService,
    required this.userId,
    required this.externalActivityId,
    required this.title,
    required this.activityType,
  });

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  bool _isVideoPlaying = false;
  bool _isCameraVisible = true;
  bool _isFinishing = false;

  void _handleVideoRequest(String videoUrl) async {
    setState(() => _isVideoPlaying = true);
    await widget.sessionService.pauseActivity();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoPlayerModal(
        videoUrl: videoUrl,
        onClose: () {
          Navigator.pop(context);
        },
      ),
    );

    if (mounted) {
      await widget.sessionService.resumeActivity();
      setState(() => _isVideoPlaying = false);
    }
  }

  void _toggleCameraVisibility() {
    setState(() => _isCameraVisible = !_isCameraVisible);
  }

  Future<void> _finishActivity() async {
    if (_isFinishing) return;

    setState(() => _isFinishing = true);

    await widget.sessionService.completeActivity({
      'rating': 5,
      'completed': true,
    });

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SessionSummaryView(),
        ),
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
                          widget.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tipo: ${widget.activityType}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Contenido de la actividad aquí...',
                          style: TextStyle(
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
            if (!_isFinishing && !_isVideoPlaying) ...[
              if (_isCameraVisible)
                AnalysisOverlay(sessionService: widget.sessionService),
              FloatingMenu(
                sessionService: widget.sessionService,
                onVideoRequested: _handleVideoRequest,
                onCameraToggle: _toggleCameraVisibility,
                isCameraVisible: _isCameraVisible,
              ),
            ],
          ],
        ),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isFinishing ? null : _finishActivity,
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
            onPressed: _isFinishing ? null : _closeActivity,
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