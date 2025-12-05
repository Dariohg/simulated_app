import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import '../models/intervention_event.dart';

class NotificationService extends ChangeNotifier {
  InterventionEvent? _currentNotification;
  bool _hasUnread = false;

  InterventionEvent? get currentNotification => _currentNotification;
  bool get hasUnread => _hasUnread;

  void addNotification(InterventionEvent event) {
    final hadPrevious = _currentNotification != null;

    _currentNotification = event;
    _hasUnread = true;

    _vibrate(hadPrevious);
    notifyListeners();
  }

  void markAsRead() {
    _currentNotification = null;
    _hasUnread = false;
    notifyListeners();
  }

  Future<void> _vibrate(bool isReplacement) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    if (isReplacement) {
      await Vibration.vibrate(pattern: [0, 200, 100, 200]);
    } else {
      await Vibration.vibrate(duration: 200);
    }
  }

  @override
  void dispose() {
    _currentNotification = null;
    _hasUnread = false;
    super.dispose();
  }
}