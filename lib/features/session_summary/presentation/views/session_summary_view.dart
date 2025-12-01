import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resumen")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Actividad Finalizada", style: AppTextStyles.headline1),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Volver al Inicio"),
            ),
          ],
        ),
      ),
    );
  }
}