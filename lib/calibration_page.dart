import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class CalibrationPage extends StatelessWidget {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CalibrationScreen(
      onCalibrationComplete: () {
        _showCompletionDialog(context);
      },
      onSkip: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Calibracion Exitosa',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'El sistema ha sido calibrado segun tus caracteristicas faciales. La deteccion sera mas precisa.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text(
              'Continuar',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}