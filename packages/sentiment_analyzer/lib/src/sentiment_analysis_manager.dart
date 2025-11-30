import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'presentation/analysis/viewmodel/analysis_view_model.dart';
import 'presentation/analysis/widgets/analysis_overlay.dart';

import 'data/services/camera_service.dart';
import 'data/services/face_mesh_service.dart';
import 'data/services/feedback_service.dart';
import 'data/services/monitoring_websocket_service.dart';
import 'data/models/calibration_result.dart';

import 'core/logic/state_aggregator.dart';
import 'core/logic/session_manager.dart';

class SentimentAnalysisManager extends StatefulWidget {
  final SessionManager sessionManager;
  final int externalActivityId;
  final CalibrationResult? calibration;
  final void Function(CombinedState state)? onStateChanged;

  final String monitoringWebSocketUrl;

  final String amqpHost;
  final String amqpQueue;
  final String amqpUser;
  final String amqpPass;
  final String amqpVirtualHost;
  final int amqpPort;

  final Function(String url)? onVideoRequested;
  final VoidCallback? onVibrateRequested;
  final Function(String type, double confidence)? onInterventionReceived;

  const SentimentAnalysisManager({
    super.key,
    required this.sessionManager,
    required this.externalActivityId,
    this.calibration,
    this.onStateChanged,
    required this.monitoringWebSocketUrl,
    this.amqpHost = 'localhost',
    this.amqpQueue = 'feedback_queue',
    this.amqpUser = 'guest',
    this.amqpPass = 'guest',
    this.amqpVirtualHost = '/',
    this.amqpPort = 5672,
    this.onVideoRequested,
    this.onVibrateRequested,
    this.onInterventionReceived,
  });

  @override
  State<SentimentAnalysisManager> createState() => _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> with WidgetsBindingObserver {
  late FeedbackService _feedbackService;
  late AnalysisViewModel _viewModel;
  late MonitoringWebSocketService _monitoringWs;

  Timer? _frameTimer;
  StreamSubscription? _interventionSubscription;

  static const Duration frameInterval = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _monitoringWs = MonitoringWebSocketService(
      baseUrl: widget.monitoringWebSocketUrl,
    );

    _feedbackService = FeedbackService();
    _feedbackService.connect(
      host: widget.amqpHost,
      queueName: widget.amqpQueue,
      username: widget.amqpUser,
      password: widget.amqpPass,
      virtualHost: widget.amqpVirtualHost,
      port: widget.amqpPort,
    );

    _viewModel = AnalysisViewModel(
      cameraService: CameraService(),
      faceMeshService: FaceMeshService(),
    );

    if (widget.calibration != null) {
      _viewModel.applyCalibration(widget.calibration!);
    }

    _connectMonitoringWebSocket();
    _setupInterventionListener();
  }

  Future<void> _connectMonitoringWebSocket() async {
    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) {
      debugPrint('[SentimentManager] No hay session_id, no se conecta WS');
      return;
    }

    final connected = await _monitoringWs.connect(sessionId);
    if (connected) {
      _startFrameTransmission();
    }
  }

  void _setupInterventionListener() {
    _interventionSubscription = _monitoringWs.interventions.listen((intervention) {
      _handleIntervention(intervention);
    });
  }

  void _handleIntervention(Map<String, dynamic> intervention) {
    final type = intervention['type'] as String?;
    final confidence = (intervention['confidence'] as num?)?.toDouble() ?? 0.0;

    debugPrint('[SentimentManager] Intervencion recibida: $type (confianza: $confidence)');

    widget.onInterventionReceived?.call(type ?? 'unknown', confidence);

    switch (type) {
      case 'vibration':
        widget.onVibrateRequested?.call();
        break;
      case 'instruction':
        break;
      case 'pause':
        break;
    }
  }

  void _startFrameTransmission() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(frameInterval, (_) {
      _sendCurrentFrame();
    });
    debugPrint('[SentimentManager] Transmision de frames iniciada');
  }

  void _stopFrameTransmission() {
    _frameTimer?.cancel();
    _frameTimer = null;
    debugPrint('[SentimentManager] Transmision de frames detenida');
  }

  void _sendCurrentFrame() {
    if (!_monitoringWs.isConnected) return;
    if (_viewModel.currentState == null) return;

    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    final frameData = _viewModel.currentState!.toJson(
      userId: widget.sessionManager.userId,
      sessionId: sessionId,
      externalActivityId: widget.externalActivityId,
    );

    _monitoringWs.sendFrame(frameData);

    widget.onStateChanged?.call(_viewModel.currentState!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopFrameTransmission();
        _monitoringWs.disconnect();
        widget.sessionManager.pauseSession();
        break;

      case AppLifecycleState.resumed:
        widget.sessionManager.resumeSession().then((_) {
          _connectMonitoringWebSocket();
        });
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopFrameTransmission();
    _interventionSubscription?.cancel();
    _monitoringWs.dispose();
    _feedbackService.disconnect();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const AnalysisOverlay(),
    );
  }
}