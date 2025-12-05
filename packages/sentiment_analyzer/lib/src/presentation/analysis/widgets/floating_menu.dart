import 'package:flutter/material.dart';
import '../../../data/services/session_service.dart';
import '../../notifications/widgets/notification_bell.dart';

class FloatingMenu extends StatefulWidget {
  final SessionService sessionService;
  final Function(String)? onVideoRequested;
  final VoidCallback? onCameraToggle;
  final bool isCameraVisible;

  const FloatingMenu({
    super.key,
    required this.sessionService,
    this.onVideoRequested,
    this.onCameraToggle,
    this.isCameraVisible = true,
  });

  @override
  State<FloatingMenu> createState() => _FloatingMenuState();
}

class _FloatingMenuState extends State<FloatingMenu> {
  bool _isMenuOpen = false;
  bool _isPaused = false;
  Offset _position = const Offset(20, 100);

  void _togglePause() async {
    if (_isPaused) {
      await widget.sessionService.resumeActivity();
    } else {
      await widget.sessionService.pauseActivity();
    }
    setState(() => _isPaused = !_isPaused);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildMenuButton(),
        childWhenDragging: Container(),
        onDraggableCanceled: (_, offset) => setState(() => _position = offset),
        child: GestureDetector(
          onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
          child: Column(
            children: [
              _buildMenuButton(),
              if (_isMenuOpen) _buildExpandedMenu(),
            ],
          ),
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
          ),
        ],
      ),
      child: const Icon(Icons.menu, color: Colors.white),
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
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            color: _isPaused ? Colors.green : Colors.orange,
            onPressed: _togglePause,
          ),
          if (widget.onCameraToggle != null)
            IconButton(
              icon: Icon(
                widget.isCameraVisible ? Icons.videocam_off : Icons.videocam,
              ),
              color: Colors.blueGrey,
              onPressed: widget.onCameraToggle,
            ),
          NotificationBell(
            notificationService: widget.sessionService.notificationService,
            onVideoRequested: widget.onVideoRequested,
          ),
        ],
      ),
    );
  }
}