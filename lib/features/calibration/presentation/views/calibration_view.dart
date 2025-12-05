import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../activity/presentation/views/activity_view.dart';

class CalibrationView extends StatelessWidget {
  final SessionService sessionService;
  final int userId;
  final ActivityOption activityOption;

  const CalibrationView({
    super.key,
    required this.sessionService,
    required this.userId,
    required this.activityOption,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationScreen(
      onCalibrationComplete: () {
        _navigateToActivity(context);
      },
      onSkip: () {
        _navigateToActivity(context);
      },
    );
  }

  void _navigateToActivity(BuildContext context) async {
    await sessionService.startActivity(
      externalActivityId: activityOption.externalActivityId,
      title: activityOption.title,
      activityType: activityOption.activityType,
      subtitle: activityOption.subtitle,
      content: activityOption.content,
    );

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityView(
            sessionService: sessionService,
            userId: userId,
            externalActivityId: activityOption.externalActivityId,
            title: activityOption.title,
            activityType: activityOption.activityType,
          ),
        ),
      );
    }
  }
}