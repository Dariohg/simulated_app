import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// RUTA CORREGIDA SEGÚN TU ESTRUCTURA:
import 'presentation/analysis/viewmodel/analysis_view_model.dart';
import 'presentation/analysis/widgets/analysis_overlay.dart';

import 'data/services/camera_service.dart';
import 'data/services/face_mesh_service.dart';
import 'data/services/feedback_service.dart';
import 'data/interfaces/network_interface.dart';
import 'data/models/calibration_result.dart';

import 'core/logic/state_aggregator.dart';
import 'core/logic/session_manager.dart';

class SentimentAnalysisManager extends StatefulWidget {
  final String userId;
  final String lessonId;
  final CalibrationResult? calibration;
  final void Function(CombinedState state)? onStateChanged;

  final SentimentNetworkInterface networkInterface;

  final String amqpHost;
  final String amqpQueue;
  final String amqpUser;
  final String amqpPass;
  final String amqpVirtualHost;
  final int amqpPort;

  final Function(String url)? onVideoRequested;
  final VoidCallback? onVibrateRequested;

  const SentimentAnalysisManager({
    super.key,
    required this.userId,
    required this.lessonId,
    this.calibration,
    this.onStateChanged,
    required this.networkInterface,
    this.amqpHost = 'localhost',
    this.amqpQueue = 'feedback_queue',
    this.amqpUser = 'guest',
    this.amqpPass = 'guest',
    this.amqpVirtualHost = '/',
    this.amqpPort = 5672,
    this.onVideoRequested,
    this.onVibrateRequested,
  });

  @override
  State<SentimentAnalysisManager> createState() => _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> {
  late SessionManager _sessionManager;
  late FeedbackService _feedbackService;

  @override
  void initState() {
    super.initState();

    _sessionManager = SessionManager(
      network: widget.networkInterface,
      userId: int.tryParse(widget.userId) ?? 0,
    );
    _sessionManager.startSession();

    _feedbackService = FeedbackService();
    _feedbackService.connect(
      host: widget.amqpHost,
      queueName: widget.amqpQueue,
      username: widget.amqpUser,
      password: widget.amqpPass,
      virtualHost: widget.amqpVirtualHost,
      port: widget.amqpPort,
    );
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    _feedbackService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // USAMOS AnalysisViewModel (el nombre correcto para tu estructura)
          create: (_) {
            final vm = AnalysisViewModel(
              cameraService: CameraService(),
              faceMeshService: FaceMeshService(),
            );
            if (widget.calibration != null) {
              vm.applyCalibration(widget.calibration!);
            }
            return vm;
          },
        ),
        Provider<SessionManager>.value(value: _sessionManager),
      ],
      child: AnalysisOverlay(
        onStateChanged: widget.onStateChanged,
        feedbackStream: _feedbackService.feedbackStream,
        sessionManager: _sessionManager,
        onVideoRequested: widget.onVideoRequested,
        onVibrateRequested: widget.onVibrateRequested,
      ),
    );
  }
}