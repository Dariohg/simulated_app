import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart'; // <--- ESTA LINEA FALTABA
import '../viewmodel/analysis_view_model.dart';
import '../../../core/logic/state_aggregator.dart';
import '../../../core/constants/app_colors.dart';

class AnalysisOverlay extends StatelessWidget {
  final AnalysisViewModel viewModel;
  final bool isVisible;

  const AnalysisOverlay({
    super.key,
    required this.viewModel,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      child: Consumer<AnalysisViewModel>(
        builder: (context, vm, _) {
          if (!vm.isInitialized || vm.cameraController == null) {
            return const SizedBox(width: 120, height: 160);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vm.currentState != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildDetailedInfoPanel(context, vm.currentState!),
                ),
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(vm.cameraController!),
                      if (vm.currentState != null)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: vm.currentState!.faceDetected
                                  ? Colors.green
                                  : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Colors.white24, height: 8),
          _buildMetricRow("Emo", emotionText),
          _buildMetricRow(
              "Conf", "${(state.confidence * 100).toStringAsFixed(0)}%"),
          if (state.drowsiness != null)
            _buildMetricRow("EAR", state.drowsiness!.ear.toStringAsFixed(2)),
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
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
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