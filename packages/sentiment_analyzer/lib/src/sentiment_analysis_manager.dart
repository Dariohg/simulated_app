import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/logic/session_manager.dart';
import 'data/models/calibration_result.dart';
import 'data/services/camera_service.dart';
import 'data/services/face_mesh_service.dart';
import 'presentation/analysis/viewmodel/analysis_view_model.dart';
import 'presentation/analysis/widgets/analysis_overlay.dart';
import 'presentation/analysis/widgets/floating_menu_overlay.dart';

class SentimentAnalysisManager extends StatefulWidget {
  final SessionManager sessionManager;
  final String externalActivityId;
  final String gatewayUrl;
  final String apiKey;
  final CalibrationResult? calibration;
  final bool isPaused;
  final VoidCallback? onVibrateRequested;
  final Function(String)? onInstructionReceived;
  final Function(String)? onPauseReceived;
  final Function(String, String?)? onVideoReceived;
  final Function(bool)? onConnectionStatusChanged;
  final Function(dynamic)? onStateChanged;
  final VoidCallback? onSettingsRequested;

  const SentimentAnalysisManager({
    super.key,
    required this.sessionManager,
    required this.externalActivityId,
    required this.gatewayUrl,
    required this.apiKey,
    this.calibration,
    this.isPaused = false,
    this.onVibrateRequested,
    this.onInstructionReceived,
    this.onPauseReceived,
    this.onVideoReceived,
    this.onConnectionStatusChanged,
    this.onStateChanged,
    this.onSettingsRequested,
  });

  @override
  State<SentimentAnalysisManager> createState() => _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> {
  late AnalysisViewModel _viewModel;
  bool _isCameraVisible = true;

  @override
  void initState() {
    super.initState();
    _viewModel = AnalysisViewModel(
      cameraService: CameraService(),
      faceMeshService: FaceMeshService(),
    );
    if (widget.calibration != null) {
      _viewModel.applyCalibration(widget.calibration!);
    }
  }

  @override
  void didUpdateWidget(SentimentAnalysisManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      _viewModel.setPaused(widget.isPaused);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _toggleCameraVisibility() {
    setState(() {
      _isCameraVisible = !_isCameraVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnalysisOverlay(
            viewModel: _viewModel,
            isVisible: _isCameraVisible,
          ),
          FloatingMenuOverlay(
            sessionManager: widget.sessionManager,
            recommendationStream: widget.sessionManager.recommendationStream,
            onVibrateRequested: widget.onVibrateRequested,
            onSettingsRequested: widget.onSettingsRequested,
            onToggleCamera: _toggleCameraVisibility,
            isCameraVisible: _isCameraVisible,
            onVideoReceived: widget.onVideoReceived,
            onPauseReceived: widget.onPauseReceived,
          ),
        ],
      ),
    );
  }
}