import 'package:flutter/material.dart';
import '../../../core/logic/session_manager.dart';
import '../../../core/constants/app_colors.dart';

class FloatingMenuOverlay extends StatefulWidget {
  final SessionManager sessionManager;
  final Stream<Map<String, dynamic>> feedbackStream;
  final Function(String url)? onVideoRequested;
  final VoidCallback? onVibrateRequested;

  const FloatingMenuOverlay({
    super.key,
    required this.sessionManager,
    required this.feedbackStream,
    this.onVideoRequested,
    this.onVibrateRequested,
  });

  @override
  State<FloatingMenuOverlay> createState() => _FloatingMenuOverlayState();
}

class _FloatingMenuOverlayState extends State<FloatingMenuOverlay> {
  Offset _position = const Offset(20, 100);
  bool _isExpanded = false;
  bool _hasAlert = false;
  Map<String, dynamic>? _alertData;

  @override
  void initState() {
    super.initState();
    widget.feedbackStream.listen((data) {
      if (!mounted) return;
      if (data['accion'] == 'vibracion') {
        widget.onVibrateRequested?.call();
        return;
      }
      setState(() {
        _alertData = data;
        _hasAlert = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final widgetWidth = _isExpanded ? 60.0 : 50.0;
    final widgetHeight = _isExpanded ? 240.0 : 50.0;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildBubble(isDragging: true),
        childWhenDragging: Container(),
        onDraggableCanceled: (velocity, offset) {
          setState(() {
            double x = offset.dx.clamp(0.0, size.width - widgetWidth);
            double y = offset.dy.clamp(topPadding, size.height - widgetHeight - 20);
            _position = Offset(x, y);
          });
        },
        child: _isExpanded ? _buildVerticalMenu() : _buildBubble(),
      ),
    );
  }

  Widget _buildBubble({bool isDragging = false}) {
    return GestureDetector(
      onTap: () {
        if (!isDragging) setState(() => _isExpanded = !_isExpanded);
      },
      child: Material(
        color: AppColors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(Icons.psychology, color: AppColors.surface),
            ),
            if (_hasAlert && !isDragging)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: AppColors.notificationDot, shape: BoxShape.circle),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalMenu() {
    return Material(
      color: AppColors.transparent,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.close, color: AppColors.iconClose), onPressed: () => setState(() => _isExpanded = false)),
            if (_hasAlert)
              IconButton(icon: const Icon(Icons.notifications_active, color: AppColors.notificationDot), onPressed: _showAlertDetail),
            IconButton(icon: const Icon(Icons.pause, color: AppColors.iconPause), onPressed: () => widget.sessionManager.pauseSession()),
            IconButton(icon: const Icon(Icons.play_arrow, color: AppColors.iconPlay), onPressed: () => widget.sessionManager.resumeSession()),
          ],
        ),
      ),
    );
  }

  void _showAlertDetail() {
    if (_alertData == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final content = _alertData!['contenido'] ?? {};
        final motivo = _alertData!['motivo'] ?? 'Asistente';
        return AlertDialog(
          title: Text(motivo, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content['mensaje'] ?? content['descripcion'] ?? ''),
              if (_alertData!['accion'] == 'video') ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Ver Video'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onVideoRequested?.call(content['url']);
                    _clearAlert();
                  },
                )
              ]
            ],
          ),
          actions: [TextButton(onPressed: () { Navigator.pop(ctx); _clearAlert(); }, child: const Text('OK'))],
        );
      },
    );
  }

  void _clearAlert() {
    setState(() {
      _hasAlert = false;
      _alertData = null;
      _isExpanded = false;
    });
  }
}