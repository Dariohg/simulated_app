import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../viewmodel/analysis_view_model.dart';
import '../../../core/logic/state_aggregator.dart';
import '../../../core/logic/session_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/recommendation_model.dart';
import 'floating_menu_overlay.dart';

class AnalysisOverlay extends StatelessWidget {
  final AnalysisViewModel viewModel;
  final SessionManager sessionManager;
  final Stream<Recommendation>? recommendationStream;
  final VoidCallback? onVibrateRequested;

  const AnalysisOverlay({
    super.key,
    required this.viewModel,
    required this.sessionManager,
    this.recommendationStream,
    this.onVibrateRequested,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (!viewModel.isInitialized || viewModel.cameraController == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: viewModel.cameraController!.value.aspectRatio,
                child: CameraPreview(viewModel.cameraController!),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getBorderColor(viewModel.currentState).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: viewModel.currentState?.faceDetected == true
                            ? Colors.green
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      viewModel.currentState?.finalState.toUpperCase() ?? 'CARGANDO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (viewModel.currentState != null)
              Positioned(
                right: 16,
                bottom: 160,
                child: _buildDetailedInfoPanel(context, viewModel.currentState!),
              ),
            Positioned.fill(
              child: FloatingMenuOverlay(
                sessionManager: sessionManager,
                recommendationStream: recommendationStream,
                onVibrateRequested: onVibrateRequested,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailedInfoPanel(BuildContext context, CombinedState state) {
    String statusText = state.finalState.toUpperCase();
    Color statusColor = _getStateColor(state.finalState);

    if (state.drowsiness != null && state.drowsiness!.isYawning) {
      statusText = "BOSTEZANDO";
      statusColor = AppColors.statusDistracted;
    }

    String emotionText = state.emotion;
    if (state.emotion.toLowerCase() == 'angry') emotionText = "ENOJADO";
    if (state.emotion.toLowerCase() == 'sad') emotionText = "TRISTE";
    if (state.emotion.toLowerCase() == 'fear') emotionText = "MIEDO";

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          _buildMetricRow("Emocion", emotionText),
          _buildMetricRow(
              "Confianza", "${(state.confidence * 100).toStringAsFixed(0)}%"),
          if (state.drowsiness != null)
            _buildMetricRow("Ojos (EAR)", state.drowsiness!.ear.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.surface,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(CombinedState? state) {
    if (state == null || !state.faceDetected) {
      return Colors.grey;
    }
    return _getStateColor(state.finalState);
  }

  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'concentrado':
      case 'entendiendo':
        return AppColors.statusConcentrated;
      case 'distraido':
      case 'no_mirando':
        return AppColors.statusDistracted;
      case 'frustrado':
      case 'confundido':
        return AppColors.statusFrustrated;
      case 'durmiendo':
        return AppColors.statusSleeping;
      default:
        return Colors.grey;
    }
  }
}