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

  @override
  void initState() {
    super.initState();
    _setupRecommendationListener();
  }

  void _setupRecommendationListener() {
    _recommendationSubscription =
        widget.recommendationStream?.listen((recommendation) {
          if (recommendation.action == 'vibration') {
            widget.onVibrateRequested?.call();
          } else {
            setState(() {
              _hasUnreadNotification = true;
            });

            if (recommendation.action == 'pause' && widget.onPauseReceived != null) {
              widget.onPauseReceived!(recommendation.content?.message ?? 'Descanso sugerido');
            } else if (recommendation.action == 'instruction' && recommendation.hasVideo && widget.onVideoReceived != null) {
              widget.onVideoReceived!(recommendation.content!.videoUrl!, recommendation.content?.message);
            }
          }
        });
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
              right: 12,
              top: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
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
            color: Colors.purple,
            onTap: () {},
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