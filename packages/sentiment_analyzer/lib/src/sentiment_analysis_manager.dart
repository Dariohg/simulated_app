import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';
import 'logic/state_aggregator.dart';

class SentimentAnalysisManager extends StatelessWidget {
  final String userId;
  final String lessonId;
  final void Function(CombinedState state)? onStateChanged;

  const SentimentAnalysisManager({
    super.key,
    required this.userId,
    required this.lessonId,
    this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FaceMeshViewModel(
        cameraService: CameraService(),
        faceMeshService: FaceMeshService(),
      ),
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
      return Positioned(
        right: 16,
        bottom: 16,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  'Iniciando...',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
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
        Positioned(
          right: 120,
          bottom: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: viewModel.recalibrate,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
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
            _buildMetricRow('Emocion', state.emotion, Colors.white70),
            _buildMetricRow(
              'Confianza',
              '${(state.confidence * 100).toStringAsFixed(0)}%',
              _getConfidenceColor(state.confidence),
            ),
          ],
          if (state.drowsiness != null) ...[
            const Divider(color: Colors.white24, height: 12),
            _buildMetricRow(
              'EAR',
              state.drowsiness!.ear.toStringAsFixed(3),
              state.drowsiness!.ear < 0.22 ? Colors.orange : Colors.green,
            ),
            if (state.drowsiness!.isYawning)
              _buildMetricRow('Estado', 'BOSTEZANDO', Colors.orange),
          ],
          if (state.isCalibrating) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Calibrando...',
                    style: TextStyle(color: Colors.yellow, fontSize: 10),
                  ),
                ],
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
      case 'concentrado':
        return Colors.green;
      case 'entendiendo':
        return Colors.greenAccent;
      case 'distraido':
        return Colors.orange;
      case 'durmiendo':
        return const Color(0xFF607D8B);
      case 'no_mirando':
        return Colors.grey;
      case 'frustrado':
        return Colors.red;
      case 'sin_rostro':
        return Colors.grey.shade600;
      default:
        return Colors.white;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.yellow;
    return Colors.orange;
  }

  String _getStateLabel(String state) {
    const labels = {
      'concentrado': 'CONCENTRADO',
      'entendiendo': 'ENTENDIENDO',
      'distraido': 'DISTRAIDO',
      'durmiendo': 'SOMNOLIENTO',
      'no_mirando': 'NO MIRA',
      'frustrado': 'FRUSTRADO',
      'sin_rostro': 'SIN ROSTRO',
      'desconocido': 'ANALIZANDO...',
    };
    return labels[state] ?? state.toUpperCase();
  }
}