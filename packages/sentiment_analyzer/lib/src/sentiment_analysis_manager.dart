import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';
import 'logic/state_aggregator.dart';
import 'calibration/calibration_service.dart'; // Importar

class SentimentAnalysisManager extends StatelessWidget {
  final String userId;
  final String lessonId;
  final CalibrationResult? calibration; // Nuevo parámetro
  final void Function(CombinedState state)? onStateChanged;

  const SentimentAnalysisManager({
    super.key,
    required this.userId,
    required this.lessonId,
    this.calibration, // Recibir calibración
    this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        // Crear instancia
        final viewModel = FaceMeshViewModel(
          cameraService: CameraService(),
          faceMeshService: FaceMeshService(),
        );

        // APLICAR CALIBRACIÓN SI EXISTE
        if (calibration != null) {
          viewModel.applyCalibration(calibration!);
        }

        return viewModel;
      },
      child: _AnalysisOverlay(onStateChanged: onStateChanged),
    );
  }
}

class _AnalysisOverlay extends StatelessWidget {
  final void Function(CombinedState state)? onStateChanged;

  const _AnalysisOverlay({this.onStateChanged});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FaceMeshViewModel>();

    if (onStateChanged != null && viewModel.currentState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChanged!(viewModel.currentState!);
      });
    }

    if (!viewModel.isInitialized || viewModel.cameraController == null) {
      // Indicador pequeño de carga
      return Positioned(
        right: 16,
        bottom: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          right: 16,
          bottom: 16,
          width: 100,
          height: 133,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _getBorderColor(viewModel.currentState),
                  width: 2,
                ),
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
            right: 16,
            bottom: 160,
            child: _buildInfoPanel(context, viewModel),
          ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context, FaceMeshViewModel viewModel) {
    final state = viewModel.currentState!;

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 180),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getStateColor(state.finalState).withOpacity(0.5),
          width: 1,
        ),
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
                  shape: BoxShape.circle,
                  color: _getStateColor(state.finalState),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getStateLabel(state.finalState),
                  style: TextStyle(
                    color: _getStateColor(state.finalState),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (state.faceDetected) ...[
            _buildMetricRow('Emoción', state.emotion, Colors.white70),
            _buildMetricRow(
              'Confianza',
              '${(state.confidence * 100).toStringAsFixed(0)}%',
              _getConfidenceColor(state.confidence),
            ),
          ],
          if (state.isCalibrating) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Usando valores por defecto',
                style: TextStyle(color: Colors.blue, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getBorderColor(CombinedState? state) {
    if (state == null) return Colors.grey;
    return _getStateColor(state.finalState);
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'concentrado': return Colors.green;
      case 'entendiendo': return Colors.greenAccent;
      case 'distraido': return Colors.orange;
      case 'durmiendo': return const Color(0xFF607D8B);
      case 'no_mirando': return Colors.grey;
      case 'frustrado': return Colors.red;
      case 'sin_rostro': return Colors.grey.shade600;
      default: return Colors.white;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.yellow;
    return Colors.orange;
  }

  String _getStateLabel(String state) {
    return state.toUpperCase();
  }
}