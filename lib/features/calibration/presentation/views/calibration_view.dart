import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../activity/presentation/views/activity_view.dart';

class CalibrationView extends StatelessWidget {
  final SessionManager sessionManager;
  final ActivityOption activityOption;

  const CalibrationView({
    super.key,
    required this.sessionManager,
    required this.activityOption,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationScreen(
      onCalibrationComplete: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityView(
              sessionManager: sessionManager,
              activityOption: activityOption,
            ),
          ),
        );
      },
      onSkip: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityView(
              sessionManager: sessionManager,
              activityOption: activityOption,
            ),
          ),
        );
      },
    );
  }
}