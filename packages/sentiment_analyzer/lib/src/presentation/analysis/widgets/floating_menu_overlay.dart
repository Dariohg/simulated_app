import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/logic/session_manager.dart';
import '../../../data/models/recommendation_model.dart';

class FloatingMenuOverlay extends StatefulWidget {
  final SessionManager sessionManager;
  final Stream<Recommendation>? recommendationStream;
  final VoidCallback? onVibrateRequested;
  final VoidCallback? onSettingsRequested;
  final VoidCallback onToggleCamera;
  final bool isCameraVisible;
  final Function(String, String?)? onVideoReceived;
  final Function(String)? onPauseReceived;
  final Function(String)? onInstructionReceived;

  const FloatingMenuOverlay({
    super.key,
    required this.sessionManager,
    this.recommendationStream,
    this.onVibrateRequested,
    this.onSettingsRequested,
    required this.onToggleCamera,
    required this.isCameraVisible,
    this.onVideoReceived,
    this.onPauseReceived,
    this.onInstructionReceived,
  });

  @override
  State<FloatingMenuOverlay> createState() => _FloatingMenuOverlayState();
}

class _FloatingMenuOverlayState extends State<FloatingMenuOverlay> {
  bool _isMenuOpen = false;
  bool _isPaused = false;
  Offset _position = const Offset(20, 100);
  StreamSubscription<Recommendation>? _recommendationSubscription;
  bool _hasUnreadNotification = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _setupRecommendationListener();
  }

  void _setupRecommendationListener() {
    debugPrint('[FloatingMenuOverlay] Configurando listener de recomendaciones');
    debugPrint('[FloatingMenuOverlay] Stream es null: ${widget.recommendationStream == null}');

    _recommendationSubscription = widget.recommendationStream?.listen(
          (recommendation) {
        debugPrint('[FloatingMenuOverlay] Recomendacion recibida: ${recommendation.action}');
        debugPrint('[FloatingMenuOverlay] Mensaje: ${recommendation.content?.message}');

        if (recommendation.action == 'vibration') {
          widget.onVibrateRequested?.call();
        } else {
          setState(() {
            _hasUnreadNotification = true;
            _lastMessage = recommendation.content?.message;
          });

          if (recommendation.action == 'pause') {
            final message = recommendation.content?.message ?? 'Descanso sugerido';
            widget.onPauseReceived?.call(message);
            _showNotificationSnackBar(message, Colors.orange);
          } else if (recommendation.action == 'instruction') {
            final message = recommendation.content?.message ?? '';

            if (recommendation.hasVideo && widget.onVideoReceived != null) {
              widget.onVideoReceived!(
                recommendation.content!.videoUrl!,
                recommendation.content?.message,
              );
            } else if (message.isNotEmpty) {
              // Mostrar instrucción de texto
              widget.onInstructionReceived?.call(message);
              _showNotificationSnackBar(message, Colors.blue);
            }
          }
        }
      },
      onError: (error) {
        debugPrint('[FloatingMenuOverlay] Error en stream: $error');
      },
    );
  }

  void _showNotificationSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recommendationSubscription?.cancel();
    super.dispose();
  }

  void _togglePause() async {
    if (_isPaused) {
      await widget.sessionManager.resumeActivity();
    } else {
      await widget.sessionManager.pauseActivity();
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildMenuButton(),
        childWhenDragging: Container(),
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          setState(() {
            _position = offset;
          });
        },
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isMenuOpen = !_isMenuOpen;
                  if (_isMenuOpen) _hasUnreadNotification = false;
                });
              },
              child: _buildMenuButton(),
            ),
            if (_isMenuOpen) _buildExpandedMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.menu, color: Colors.white),
          ),
          if (_hasUnreadNotification)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            color: _isPaused ? Colors.green : Colors.orange,
            onTap: _togglePause,
          ),
          _buildMenuItem(
            icon: widget.isCameraVisible ? Icons.videocam_off : Icons.videocam,
            color: Colors.blueGrey,
            onTap: widget.onToggleCamera,
          ),
          _buildMenuItem(
            icon: Icons.settings,
            color: Colors.grey,
            onTap: widget.onSettingsRequested ?? () {},
          ),
          _buildMenuItem(
            icon: Icons.notifications,
            color: _hasUnreadNotification ? Colors.red : Colors.purple,
            onTap: () {
              if (_lastMessage != null) {
                _showNotificationSnackBar(_lastMessage!, Colors.blue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onTap,
    );
  }
}