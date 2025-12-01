import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/models/session_model.dart';
import '../../../activity/presentation/views/activity_view.dart';
import '../viewmodels/calibration_view_model.dart';

class CalibrationView extends StatefulWidget {
  final SessionModel session;

  const CalibrationView({super.key, required this.session});

  @override
  State<CalibrationView> createState() => _CalibrationViewState();
}

class _CalibrationViewState extends State<CalibrationView> {
  final CalibrationViewModel _viewModel = CalibrationViewModel();

  @override
  void initState() {
    super.initState();
    // Iniciar calibración automáticamente al entrar
    _viewModel.startCalibration();
  }

  void _navigateToActivity() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityView(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _viewModel.isCalibrationComplete
                            ? "¡Listo!"
                            : "Calibrando...",
                        style: AppTextStyles.headline1.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      if (!_viewModel.isCalibrationComplete) ...[
                        LinearProgressIndicator(
                          value: _viewModel.progress,
                          minHeight: 10,
                          backgroundColor: AppColors.background,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Por favor, mantén tu rostro visible frente a la cámara.",
                          style: AppTextStyles.body2,
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _navigateToActivity,
                            child: const Text("COMENZAR ACTIVIDAD"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}