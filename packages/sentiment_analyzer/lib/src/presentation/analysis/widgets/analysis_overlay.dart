import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/analysis_view_model.dart';
import 'floating_menu_overlay.dart';
import '../../../core/logic/session_manager.dart';
import '../../../core/logic/state_aggregator.dart';
import '../../../core/constants/app_colors.dart';

class AnalysisOverlay extends StatelessWidget {
  final void Function(CombinedState state)? onStateChanged;
  final Stream<Map<String, dynamic>> feedbackStream;
  final SessionManager sessionManager;
  final Function(String url)? onVideoRequested;
  final VoidCallback? onVibrateRequested;

  const AnalysisOverlay({
    super.key,
    this.onStateChanged,
    required this.feedbackStream,
    required this.sessionManager,
    this.onVideoRequested,
    this.onVibrateRequested,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AnalysisViewModel>();

    if (onStateChanged != null && viewModel.currentState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChanged!(viewModel.currentState!);
      });
    }

    if (!viewModel.isInitialized || viewModel.cameraController == null) {
      return Positioned(
        right: 16, bottom: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.overlay, borderRadius: BorderRadius.circular(12)),
          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
        ),
      );
    }

    final borderColor = _getBorderColor(viewModel.currentState);

    return Stack(
      children: [
        Positioned(
          right: 16, bottom: 16, width: 100, height: 133,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CameraPreview(viewModel.cameraController!),
              ),
            ),
          ),
        ),
        if (viewModel.currentState != null)
          Positioned(
            right: 16, bottom: 160,
            child: _buildDetailedInfoPanel(context, viewModel.currentState!),
          ),
        Positioned.fill(
          child: FloatingMenuOverlay(
            sessionManager: sessionManager,
            feedbackStream: feedbackStream,
            onVideoRequested: onVideoRequested,
            onVibrateRequested: onVibrateRequested,
          ),
        ),
      ],
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
        color: AppColors.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          _buildMetricRow("Emoción", emotionText),
          _buildMetricRow("Confianza", "${(state.confidence * 100).toStringAsFixed(0)}%"),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(value, style: const TextStyle(color: AppColors.surface, fontWeight: FontWeight.w500, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getBorderColor(CombinedState? state) {
    if (state == null) return AppColors.statusNoLooking;
    if (state.drowsiness?.isYawning == true) return AppColors.statusDistracted;
    return _getStateColor(state.finalState);
  }

  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'concentrado': return AppColors.statusConcentrated;
      case 'distraido': return AppColors.statusDistracted;
      case 'frustrado': return AppColors.statusFrustrated;
      case 'durmiendo': return AppColors.statusSleeping;
      case 'no_mirando': return AppColors.statusNoLooking;
      default: return AppColors.surface;
    }
  }
}