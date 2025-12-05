import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../activity/presentation/views/activity_view.dart';

class CalibrationView extends StatefulWidget {
  final int userId;
  final SessionService sessionService;
  final ActivityOption activityOption;

  const CalibrationView({
    super.key,
    required this.userId,
    required this.sessionService,
    required this.activityOption,
  });

  @override
  State<CalibrationView> createState() => _CalibrationViewState();
}

class _CalibrationViewState extends State<CalibrationView> {
  void _startActivity() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ActivityView(
          userId: widget.userId,
          sessionService: widget.sessionService,
          activityOption: widget.activityOption,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibración')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Mire a la cámara y mantenga una expresión neutral',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startActivity,
              child: const Text('Iniciar Actividad'),
            ),
          ],
        ),
      ),
    );
  }
}