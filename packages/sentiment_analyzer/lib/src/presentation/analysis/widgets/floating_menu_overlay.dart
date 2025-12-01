import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/logic/session_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/recommendation_model.dart';

class FloatingMenuOverlay extends StatefulWidget {
  final SessionManager sessionManager;
  final Stream<Recommendation>? recommendationStream;
  final VoidCallback? onVibrateRequested;

  const FloatingMenuOverlay({
    super.key,
    required this.sessionManager,
    this.recommendationStream,
    this.onVibrateRequested,
  });

  @override
  State<FloatingMenuOverlay> createState() => _FloatingMenuOverlayState();
}

class _FloatingMenuOverlayState extends State<FloatingMenuOverlay> {
  bool _isPaused = false;
  StreamSubscription<Recommendation>? _recommendationSubscription;
  Recommendation? _currentRecommendation;
  bool _showNotification = false;

  @override
  void initState() {
    super.initState();
    _setupRecommendationListener();
  }

  void _setupRecommendationListener() {
    _recommendationSubscription = widget.recommendationStream?.listen((recommendation) {
      setState(() {
        _currentRecommendation = recommendation;
        _showNotification = true;
      });

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showNotification = false;
          });
        }
      });
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
    return Stack(
      children: [
        Positioned(
          right: 16,
          top: 16,
          child: Row(
            children: [
              _buildControlButton(
                icon: _isPaused ? Icons.play_arrow : Icons.pause,
                color: _isPaused ? AppColors.iconPlay : AppColors.iconPause,
                onTap: _togglePause,
              ),
            ],
          ),
        ),
        if (_showNotification && _currentRecommendation != null)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: _buildNotificationCard(_currentRecommendation!),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildNotificationCard(Recommendation recommendation) {
    IconData icon;
    Color color;
    String title;

    switch (recommendation.action) {
      case 'vibration':
        icon = Icons.vibration;
        color = Colors.orange;
        title = 'Atencion';
        break;
      case 'instruction':
        icon = recommendation.hasVideo ? Icons.play_circle : Icons.lightbulb;
        color = Colors.blue;
        title = recommendation.hasVideo ? 'Video de ayuda' : 'Sugerencia';
        break;
      case 'pause':
        icon = Icons.coffee;
        color = Colors.purple;
        title = 'Descanso sugerido';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'Notificacion';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (recommendation.hasMessage)
                  Text(
                    recommendation.content!.message!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showNotification = false;
              });
            },
            child: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }
}