import 'package:flutter/material.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/intervention_event.dart';

class NotificationModal extends StatelessWidget {
  final NotificationService notificationService;
  final Function(String)? onVideoRequested;
  final VoidCallback? onTextDismissed;

  const NotificationModal({
    super.key,
    required this.notificationService,
    this.onVideoRequested,
    this.onTextDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final notification = notificationService.currentNotification;
    if (notification == null) {
      Navigator.pop(context);
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: notification.hasVideo
            ? _buildVideoNotification(context, notification)
            : _buildTextNotification(context, notification),
      ),
    );
  }

  Widget _buildTextNotification(BuildContext context, InterventionEvent event) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline, size: 48, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          event.displayText ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              notificationService.markAsRead();
              onTextDismissed?.call();
              Navigator.pop(context);
            },
            child: const Text('Entendido'),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoNotification(BuildContext context, InterventionEvent event) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_circle_outline, size: 48, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          event.displayText ?? 'Video disponible',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  notificationService.markAsRead();
                  Navigator.pop(context);
                },
                child: const Text('Ignorar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final videoUrl = event.videoUrl;
                  if (videoUrl != null) {
                    notificationService.markAsRead();
                    Navigator.pop(context);
                    onVideoRequested?.call(videoUrl);
                  }
                },
                child: const Text('Ver Ahora'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}