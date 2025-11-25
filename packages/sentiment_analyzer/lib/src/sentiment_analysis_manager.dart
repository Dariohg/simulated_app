import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';

class SentimentAnalysisManager extends StatelessWidget {
  const SentimentAnalysisManager({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FaceMeshViewModel(
        cameraService: CameraService(),
        faceMeshService: FaceMeshService(),
      ),
      child: const _AnalysisOverlay(),
    );
  }
}

class _AnalysisOverlay extends StatelessWidget {
  const _AnalysisOverlay();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FaceMeshViewModel>();

    if (!viewModel.isInitialized || viewModel.cameraController == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Camera Layer
        Positioned(
          right: 16,
          bottom: 16,
          width: 120,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CameraPreview(viewModel.cameraController!),
          ),
        ),

        // Info Layer
        if (viewModel.currentState != null)
          Positioned(
            right: 16,
            bottom: 180,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    viewModel.currentState!.finalState.toUpperCase(),
                    style: TextStyle(
                      color: _getColorForState(viewModel.currentState!.finalState),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (viewModel.currentState!.isCalibrating)
                    const Text(
                      "CALIBRANDO...",
                      style: TextStyle(color: Colors.yellow, fontSize: 10),
                    ),
                  Text(
                    "EAR: ${viewModel.currentState!.drowsiness?.ear.toStringAsFixed(2) ?? '0.0'}",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

        // Calibration Button
        Positioned(
          right: 140,
          bottom: 16,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: viewModel.recalibrate,
            tooltip: 'Recalibrar',
          ),
        ),
      ],
    );
  }

  Color _getColorForState(String state) {
    switch (state) {
      case 'concentrado': return Colors.green;
      case 'distraido': return Colors.orange;
      case 'durmiendo': return Colors.purple;
      case 'no_mirando': return Colors.grey;
      case 'frustrado': return Colors.red;
      default: return Colors.white;
    }
  }
}