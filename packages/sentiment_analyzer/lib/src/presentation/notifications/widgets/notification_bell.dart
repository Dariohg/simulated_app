import 'package:flutter/material.dart';
import '../../../data/services/notification_service.dart';
import 'notification_modal.dart';

class NotificationBell extends StatelessWidget {
  final NotificationService notificationService;
  final Function(String)? onVideoRequested;
  final VoidCallback? onTextDismissed;

  const NotificationBell({
    super.key,
    required this.notificationService,
    this.onVideoRequested,
    this.onTextDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notificationService,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              // CORRECCIÓN: Color explícito visible (Azul) para que no se pierda en el fondo blanco
              color: Colors.blue,
              // Si no hay notificaciones, onPressed es null y el color se atenúa automáticamente
              onPressed: notificationService.hasUnread
                  ? () => _showNotificationModal(context)
                  : null,
            ),

            if (notificationService.hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NotificationModal(
        notificationService: notificationService,
        onVideoRequested: onVideoRequested,
        onTextDismissed: onTextDismissed,
      ),
    );
  }
}