import 'package:flutter/material.dart';
import '../logic/session_manager.dart';

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

  bool _hasAlert = false; // El punto rojo
  Map<String, dynamic>? _alertData;

  @override
  void initState() {
    super.initState();
    widget.feedbackStream.listen((data) {
      if (!mounted) return;

      // 1. SI ES VIBRACIÓN: Ejecutar y salir (NO MOSTRAR ALERTA VISUAL)
      if (data['accion'] == 'vibracion') {
        widget.onVibrateRequested?.call();
        return; // <-- IMPORTANTE: Aquí cortamos el flujo
      }

      // 2. SI ES OTRO TIPO (Video, Texto): Mostrar punto rojo
      setState(() {
        _alertData = data;
        _hasAlert = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double widgetWidth = _isExpanded ? 60.0 : 50.0;
    final double widgetHeight = _isExpanded ? 240.0 : 50.0;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildBubble(isDragging: true),
        childWhenDragging: Container(),
        onDraggableCanceled: (velocity, offset) {
          setState(() {
            // Lógica para no sacar el botón de la pantalla
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
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.psychology, color: Colors.white),
            ),
            // El punto rojo solo se muestra si _hasAlert es true (y vibración no lo activa)
            if (_hasAlert && !isDragging)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => setState(() => _isExpanded = false),
            ),
            if (_hasAlert)
              IconButton(
                icon: const Icon(Icons.notifications_active, color: Colors.red),
                onPressed: _showAlertDetail,
              ),
            IconButton(
              icon: const Icon(Icons.pause, color: Colors.orange),
              onPressed: () => widget.sessionManager.pauseSession(manual: true),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              onPressed: () => widget.sessionManager.resumeSession(),
            ),
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _clearAlert();
              },
              child: const Text('OK'),
            )
          ],
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