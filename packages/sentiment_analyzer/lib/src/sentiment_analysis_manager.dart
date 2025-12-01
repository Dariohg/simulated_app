import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'presentation/analysis/viewmodel/analysis_view_model.dart';
import 'presentation/analysis/widgets/analysis_overlay.dart';

import 'data/services/camera_service.dart';
import 'data/services/face_mesh_service.dart';
import 'data/services/monitoring_websocket_service.dart';
import 'data/models/calibration_result.dart';
import 'data/models/recommendation_model.dart';

import 'core/logic/state_aggregator.dart';
import 'core/logic/session_manager.dart';

class SentimentAnalysisManager extends StatefulWidget {
  final SessionManager sessionManager;
  final int externalActivityId;
  final CalibrationResult? calibration;
  final void Function(CombinedState state)? onStateChanged;

  final String gatewayUrl;
  final String apiKey;

  final VoidCallback? onVibrateRequested;
  final Function(String message)? onInstructionReceived;
  final Function(String message)? onPauseReceived;
  final Function(String url, String? title)? onVideoReceived;
  final Function(Recommendation recommendation)? onRecommendationReceived;

  const SentimentAnalysisManager({
    super.key,
    required this.sessionManager,
    required this.externalActivityId,
    this.calibration,
    this.onStateChanged,
    required this.gatewayUrl,
    required this.apiKey,
    this.onVibrateRequested,
    this.onInstructionReceived,
    this.onPauseReceived,
    this.onVideoReceived,
    this.onRecommendationReceived,
  });

  @override
  State<SentimentAnalysisManager> createState() =>
      _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager>
    with WidgetsBindingObserver {
  late AnalysisViewModel _viewModel;
  late MonitoringWebSocketService _monitoringWs;

  Timer? _frameTimer;
  StreamSubscription<Recommendation>? _recommendationSubscription;

  static const Duration frameInterval = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _monitoringWs = MonitoringWebSocketService(
      gatewayUrl: widget.gatewayUrl,
      apiKey: widget.apiKey,
    );

    _viewModel = AnalysisViewModel(
      cameraService: CameraService(),
      faceMeshService: FaceMeshService(),
    );

    if (widget.calibration != null) {
      _viewModel.applyCalibration(widget.calibration!);
    }

    _connectMonitoringWebSocket();
    _setupRecommendationListener();
  }

  Future<void> _connectMonitoringWebSocket() async {
    final sessionId = widget.sessionManager.sessionId;
    final activityUuid = widget.sessionManager.currentActivityUuid;

    if (sessionId == null) {
      debugPrint('[SentimentManager] No hay session_id, no se conecta WS');
      return;
    }

    if (activityUuid == null) {
      debugPrint('[SentimentManager] No hay activity_uuid, no se conecta WS');
      return;
    }

    final connected = await _monitoringWs.connect(
      sessionId: sessionId,
      activityUuid: activityUuid,
      userId: widget.sessionManager.userId,
      externalActivityId: widget.externalActivityId,
    );

    if (connected) {
      _startFrameTransmission();
    } else {
      debugPrint('[SentimentManager] Fallo la conexion WebSocket');
    }
  }

  void _setupRecommendationListener() {
    _recommendationSubscription =
        _monitoringWs.recommendations.listen(_handleRecommendation);
  }

  void _handleRecommendation(Recommendation recommendation) {
    debugPrint(
        '[SentimentManager] Recomendacion recibida: ${recommendation.action}');

    widget.onRecommendationReceived?.call(recommendation);

    switch (recommendation.action) {
      case 'vibration':
        widget.onVibrateRequested?.call();
        break;

      case 'instruction':
        if (recommendation.hasVideo) {
          widget.onVideoReceived?.call(
            recommendation.content!.videoUrl!,
            recommendation.content?.title,
          );
        } else if (recommendation.hasMessage) {
          widget.onInstructionReceived?.call(recommendation.content!.message!);
        }
        break;

      case 'pause':
        final message =
            recommendation.content?.message ?? 'Se recomienda tomar un descanso';
        widget.onPauseReceived?.call(message);
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

    final frameData = _viewModel.currentState!.toJson();
    _monitoringWs.sendFrame(frameData);

    widget.onStateChanged?.call(_viewModel.currentState!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      default:
        break;
    }
  }

  void _handleAppPaused() {
    debugPrint('[SentimentManager] App pausada');
    _viewModel.setPaused(true);
    _stopFrameTransmission();
  }

  void _handleAppResumed() {
    debugPrint('[SentimentManager] App reanudada');
    _viewModel.setPaused(false);

    if (_monitoringWs.isConnected) {
      _startFrameTransmission();
    } else {
      _connectMonitoringWebSocket();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopFrameTransmission();
    _recommendationSubscription?.cancel();
    _monitoringWs.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnalysisOverlay(
      viewModel: _viewModel,
      sessionManager: widget.sessionManager,
      recommendationStream: _monitoringWs.recommendations,
      onVibrateRequested: widget.onVibrateRequested,
    );
  }
}