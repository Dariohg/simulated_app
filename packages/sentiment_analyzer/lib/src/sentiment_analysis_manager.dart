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
  State<SentimentAnalysisManager> createState() => _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> {
  late AnalysisViewModel _viewModel;
  late MonitoringWebSocketService _websocketService;
  bool _isCameraVisible = true;
  Timer? _frameTimer;
  int _frameCount = 0;
  int _wsNotReadyCount = 0;

  @override
  void initState() {
    super.initState();

    debugPrint('[SentimentAnalysisManager] ===== INICIANDO =====');

    // Inicializar ViewModel
    _viewModel = AnalysisViewModel(
      cameraService: CameraService(),
      faceMeshService: FaceMeshService(),
    );

    if (widget.calibration != null) {
      _viewModel.applyCalibration(widget.calibration!);
    }

    // Inicializar WebSocket
    _websocketService = MonitoringWebSocketService(
      gatewayUrl: widget.gatewayUrl,
      apiKey: widget.apiKey,
    );

    debugPrint('[SentimentAnalysisManager] WebSocket service creado');

    // Conectar WebSocket
    _connectWebSocket();

    // Escuchar cambios de estado
    _viewModel.addListener(_onStateChanged);

    // Timer para enviar frames periódicamente
    _frameTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _sendCurrentFrame();
    });

    debugPrint('[SentimentAnalysisManager] Frame timer iniciado');
  }

  Future<void> _connectWebSocket() async {
    debugPrint('[SentimentAnalysisManager] === INICIO CONEXION WEBSOCKET ===');

    final activityUuid = widget.sessionManager.currentActivity?.activityUuid;
    final sessionId = widget.sessionManager.sessionId;

    debugPrint('[SentimentAnalysisManager] activityUuid: $activityUuid');
    debugPrint('[SentimentAnalysisManager] sessionId: $sessionId');
    debugPrint('[SentimentAnalysisManager] userId: ${widget.sessionManager.userId}');

    if (activityUuid == null || sessionId == null) {
      debugPrint('[SentimentAnalysisManager] ERROR: FALTA DATOS - No se puede conectar');
      widget.onConnectionStatusChanged?.call(false);
      return;
    }

    final externalActivityId = widget.sessionManager.currentActivity?.externalActivityId;
    debugPrint('[SentimentAnalysisManager] externalActivityId: $externalActivityId');

    if (externalActivityId == null) {
      debugPrint('[SentimentAnalysisManager] ERROR: FALTA externalActivityId');
      widget.onConnectionStatusChanged?.call(false);
      return;
    }

    debugPrint('[SentimentAnalysisManager] Llamando a websocketService.connect()...');
    debugPrint('[SentimentAnalysisManager] Gateway URL: ${widget.gatewayUrl}');

    final success = await _websocketService.connect(
      sessionId: sessionId,
      activityUuid: activityUuid,
      userId: widget.sessionManager.userId,
      externalActivityId: externalActivityId,
    );

    debugPrint('[SentimentAnalysisManager] Resultado conexion: $success');

    if (success) {
      debugPrint('[SentimentAnalysisManager] OK: WebSocket conectado exitosamente');
      widget.onConnectionStatusChanged?.call(true);
    } else {
      debugPrint('[SentimentAnalysisManager] ERROR: No se pudo conectar WebSocket');
      widget.onConnectionStatusChanged?.call(false);
    }
  }

  void _onStateChanged() {
    widget.onStateChanged?.call(_viewModel.currentState);
  }

  void _sendCurrentFrame() {
    // Log del estado del WebSocket
    if (_websocketService.status != WebSocketStatus.ready) {
      // Solo loguear cada 50 intentos para no saturar
      if (_wsNotReadyCount % 50 == 0) {
        debugPrint('[SentimentAnalysisManager] PAUSED: WebSocket no esta listo: ${_websocketService.status}');
      }
      _wsNotReadyCount++;
      return;
    }

    if (widget.isPaused || _websocketService.isPaused) {
      debugPrint('[SentimentAnalysisManager] PAUSED: Transmision pausada');
      return;
    }

    final state = _viewModel.currentState;
    if (state == null) {
      debugPrint('[SentimentAnalysisManager] WARNING: State es null, no hay frame para enviar');
      return;
    }

    // Log cada 25 frames (cada ~5 segundos) para no saturar
    _frameCount++;

    if (_frameCount % 25 == 0) {
      debugPrint('[SentimentAnalysisManager] SENDING: Frame #$_frameCount');
      debugPrint('[SentimentAnalysisManager]   - Emocion: ${state.emotion}');
      debugPrint('[SentimentAnalysisManager]   - Estado: ${state.finalState}');
      debugPrint('[SentimentAnalysisManager]   - Rostro detectado: ${state.faceDetected}');
      debugPrint('[SentimentAnalysisManager]   - Mirando pantalla: ${state.attention?.isLookingAtScreen}');
    }

    // Construir el frame con la estructura esperada por el backend
    final frameData = {
      'analisis_sentimiento': {
        'emocion_principal': {
          'nombre': state.emotion,
          'confianza': state.confidence,
          'estado_cognitivo': state.finalState,
        },
        'desglose_emociones': state.emotionScores?.entries.map((e) => {
          'emocion': e.key,
          'confianza': e.value * 100,
        }).toList() ?? [],
      },
      'datos_biometricos': {
        'atencion': {
          'mirando_pantalla': state.attention?.isLookingAtScreen ?? false,
          'orientacion_cabeza': {
            'pitch': state.attention?.pitch ?? 0.0,
            'yaw': state.attention?.yaw ?? 0.0,
          },
        },
        'somnolencia': {
          'esta_durmiendo': state.drowsiness?.isDrowsy ?? false,
          'apertura_ojos_ear': state.drowsiness?.ear ?? 0.0,
        },
        'rostro_detectado': state.faceDetected,
      },
    };

    _websocketService.sendFrame(frameData);

    if (_frameCount % 25 == 0) {
      debugPrint('[SentimentAnalysisManager] OK: Frame enviado al WebSocket');
    }
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
          ),
        ],
      ),
    );
  }
}