import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/logic/session_manager.dart';
import 'data/models/calibration_result.dart';
import 'data/services/camera_service.dart';
import 'data/services/face_mesh_service.dart';
import 'data/services/monitoring_websocket_service.dart';
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
  State<SentimentAnalysisManager> createState() =>
      _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> {
  late AnalysisViewModel _viewModel;
  late MonitoringWebSocketService _websocketService;
  bool _isCameraVisible = true;
  Timer? _frameTimer;
  Timer? _retryConnectionTimer;
  int _frameCount = 0;
  int _wsNotReadyCount = 0;
  StreamSubscription? _recommendationSubscription;

  @override
  void initState() {
    super.initState();

    debugPrint('[SentimentAnalysisManager] ===== INICIANDO =====');

    _viewModel = AnalysisViewModel(
      cameraService: CameraService(),
      faceMeshService: FaceMeshService(),
    );

    if (widget.calibration != null) {
      _viewModel.applyCalibration(widget.calibration!);
    }

    _websocketService = MonitoringWebSocketService(
      gatewayUrl: widget.gatewayUrl,
      apiKey: widget.apiKey,
    );

    debugPrint('[SentimentAnalysisManager] WebSocket service creado');

    // Conectar el stream de recomendaciones del WebSocket al SessionManager
    _setupRecommendationForwarding();

    _initiateConnection();

    _viewModel.addListener(_onStateChanged);

    _frameTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _sendCurrentFrame();
    });

    debugPrint('[SentimentAnalysisManager] Frame timer iniciado');
  }

  void _setupRecommendationForwarding() {
    _recommendationSubscription = _websocketService.recommendationStream.listen(
          (recommendation) {
        debugPrint('[SentimentAnalysisManager] Recomendacion recibida del WS, reenviando a SessionManager');
        widget.sessionManager.emitRecommendation(recommendation);
      },
      onError: (error) {
        debugPrint('[SentimentAnalysisManager] Error en stream de recomendaciones: $error');
      },
    );
  }

  void _initiateConnection() {
    _connectWebSocket().then((success) {
      if (!success) {
        debugPrint(
            '[SentimentAnalysisManager] Conexion inicial fallida. Programando reintento...');
        _scheduleRetry();
      }
    });
  }

  void _scheduleRetry() {
    _retryConnectionTimer?.cancel();
    _retryConnectionTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      debugPrint('[SentimentAnalysisManager] Reintentando conexion...');
      _initiateConnection();
    });
  }

  Future<bool> _connectWebSocket() async {
    debugPrint('[SentimentAnalysisManager] === INICIO CONEXION WEBSOCKET ===');

    if (_websocketService.status == WebSocketStatus.ready ||
        _websocketService.status == WebSocketStatus.connected) {
      return true;
    }

    final activityUuid = widget.sessionManager.currentActivity?.activityUuid;
    final sessionId = widget.sessionManager.sessionId;

    if (activityUuid == null || sessionId == null) {
      debugPrint(
          '[SentimentAnalysisManager] ERROR: FALTA DATOS - Esperando datos de sesion...');
      return false;
    }

    final externalActivityId =
        widget.sessionManager.currentActivity?.externalActivityId;

    if (externalActivityId == null) {
      debugPrint('[SentimentAnalysisManager] ERROR: FALTA externalActivityId');
      return false;
    }

    final success = await _websocketService.connect(
      sessionId: sessionId,
      activityUuid: activityUuid,
      userId: widget.sessionManager.userId,
      externalActivityId: externalActivityId,
    );

    if (success) {
      debugPrint('[SentimentAnalysisManager] OK: WebSocket conectado exitosamente');
      widget.onConnectionStatusChanged?.call(true);
      return true;
    } else {
      debugPrint(
          '[SentimentAnalysisManager] ERROR: No se pudo conectar WebSocket');
      widget.onConnectionStatusChanged?.call(false);
      return false;
    }
  }

  void _onStateChanged() {
    widget.onStateChanged?.call(_viewModel.currentState);
  }

  void _sendCurrentFrame() {
    if (_websocketService.status != WebSocketStatus.ready) {
      if (_wsNotReadyCount % 50 == 0) {
        debugPrint(
            '[SentimentAnalysisManager] WS no ready (status: ${_websocketService.status}), frame ignorado');
      }
      _wsNotReadyCount++;
      return;
    }

    if (widget.isPaused || _websocketService.isPaused) {
      return;
    }

    _wsNotReadyCount = 0;

    final state = _viewModel.currentState;
    if (state == null) {
      return;
    }

    _frameCount++;

    if (_frameCount % 25 == 0) {
      debugPrint('[SentimentAnalysisManager] SENDING: Frame #$_frameCount');
    }

    final Map<String, dynamic> frameData = {
      'analisis_sentimiento': <String, dynamic>{
        'emocion_principal': <String, dynamic>{
          'nombre': state.emotion,
          'confianza': state.confidence,
          'estado_cognitivo': state.finalState,
        },
        'desglose_emociones': state.emotionScores?.entries
            .map((e) => <String, dynamic>{
          'emocion': e.key,
          'confianza': e.value * 100,
        })
            .toList() ??
            [],
      },
      'datos_biometricos': <String, dynamic>{
        'atencion': <String, dynamic>{
          'mirando_pantalla': state.attention?.isLookingAtScreen ?? false,
          'orientacion_cabeza': <String, dynamic>{
            'pitch': state.attention?.pitch ?? 0.0,
            'yaw': state.attention?.yaw ?? 0.0,
          },
        },
        'somnolencia': <String, dynamic>{
          'esta_durmiendo': state.drowsiness?.isDrowsy ?? false,
          'apertura_ojos_ear': state.drowsiness?.ear ?? 0.0,
        },
        'rostro_detectado': state.faceDetected,
      },
    };

    _websocketService.sendFrame(frameData);
  }

  @override
  void didUpdateWidget(SentimentAnalysisManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPaused != widget.isPaused) {
      _viewModel.setPaused(widget.isPaused);

      if (widget.isPaused) {
        _websocketService.pauseTransmission();
      } else {
        _websocketService.resumeTransmission();
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[SentimentAnalysisManager] Disposing...');
    _frameTimer?.cancel();
    _retryConnectionTimer?.cancel();
    _recommendationSubscription?.cancel();
    _viewModel.removeListener(_onStateChanged);
    _websocketService.disconnect();
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
            onInstructionReceived: widget.onInstructionReceived,
          ),
        ],
      ),
    );
  }
}