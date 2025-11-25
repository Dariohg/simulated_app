import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';

class SentimentAnalysisManager extends StatelessWidget {
  // Corrección: Agregamos los parámetros que pide tu pantalla de lección
  final String userId;
  final String lessonId;

  const SentimentAnalysisManager({
    super.key,
    required this.userId,
    required this.lessonId,
  });

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
    // Escuchamos los cambios del ViewModel
    final viewModel = context.watch<FaceMeshViewModel>();

    // Si la cámara no está lista, no mostramos nada para evitar errores
    if (!viewModel.isInitialized || viewModel.cameraController == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 1. Capa de la Cámara (Pequeña en la esquina)
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

        // 2. Capa de Información (Estados detectados)
        if (viewModel.currentState != null)
          Positioned(
            right: 16,
            bottom: 180, // Justo encima de la cámara
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Estado Principal (DURMIENDO, CONCENTRADO, ETC.)
                  Text(
                    viewModel.currentState!.finalState.toUpperCase(),
                    style: TextStyle(
                      color: _getColorForState(viewModel.currentState!.finalState),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  // Indicador de calibración
                  if (viewModel.currentState!.isCalibrating)
                    const Text(
                      "CALIBRANDO...",
                      style: TextStyle(color: Colors.yellow, fontSize: 10),
                    ),
                  // Métricas técnicas (opcional, útil para depurar)
                  Text(
                    "EAR: ${viewModel.currentState!.drowsiness?.ear.toStringAsFixed(2) ?? '0.0'}",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

        // 3. Botón de Recalibración
        Positioned(
          right: 140,
          bottom: 16,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: viewModel.recalibrate,
            tooltip: 'Recalibrar posición',
          ),
        ),
      ],
    );
  }

  // Ayudante para colores según el estado
  Color _getColorForState(String state) {
    switch (state) {
      case 'concentrado': return Colors.green;
      case 'entendiendo': return Colors.greenAccent;
      case 'distraido': return Colors.orange;
      case 'durmiendo': return Colors.purple;
      case 'no_mirando': return Colors.grey;
      case 'frustrado': return Colors.red;
      default: return Colors.white;
    }
  }
}