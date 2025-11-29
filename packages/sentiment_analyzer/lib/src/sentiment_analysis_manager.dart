import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';
import 'services/feedback_service.dart';
import 'logic/state_aggregator.dart';
import 'calibration/calibration_service.dart';
import 'logic/session_manager.dart';
import 'ui/floating_menu_overlay.dart';
import 'services/network_interface.dart';

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
  final VoidCallback? onVibrateRequested; // <--- NUEVO CALLBACK

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
          create: (_) {
            final vm = FaceMeshViewModel(
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
      child: _AnalysisOverlay(
        onStateChanged: widget.onStateChanged,
        feedbackStream: _feedbackService.feedbackStream,
        sessionManager: _sessionManager,
        onVideoRequested: widget.onVideoRequested,
        onVibrateRequested: widget.onVibrateRequested,
      ),
    );
  }
}

class _AnalysisOverlay extends StatelessWidget {
  final void Function(CombinedState state)? onStateChanged;
  final Stream<Map<String, dynamic>> feedbackStream;
  final SessionManager sessionManager;
  final Function(String url)? onVideoRequested;
  final VoidCallback? onVibrateRequested;

  const _AnalysisOverlay({
    this.onStateChanged,
    required this.feedbackStream,
    required this.sessionManager,
    this.onVideoRequested,
    this.onVibrateRequested,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FaceMeshViewModel>();

    if (onStateChanged != null && viewModel.currentState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChanged!(viewModel.currentState!);
      });
    }

    // Si la cámara no está lista
    if (!viewModel.isInitialized || viewModel.cameraController == null) {
      return Positioned(
        right: 16, bottom: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    // Color del borde según estado
    final borderColor = _getBorderColor(viewModel.currentState);

    return Stack(
      children: [
        // 1. Cámara
        Positioned(
          right: 16, bottom: 16, width: 100, height: 133,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CameraPreview(viewModel.cameraController!),
              ),
            ),
          ),
        ),

        // 2. Panel de Información (RESTAURADO)
        if (viewModel.currentState != null)
          Positioned(
            right: 16, bottom: 160,
            child: _buildDetailedInfoPanel(context, viewModel.currentState!),
          ),

        // 3. Menú Flotante (Con callback de vibración)
        Positioned.fill(
          child: FloatingMenuOverlay(
            sessionManager: sessionManager,
            feedbackStream: feedbackStream,
            onVideoRequested: onVideoRequested,
            onVibrateRequested: onVibrateRequested,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInfoPanel(BuildContext context, CombinedState state) {
    // Lógica de prioridad para mostrar el estado más crítico
    String statusText = state.finalState.toUpperCase();
    Color statusColor = _getStateColor(state.finalState);

    // Detección explícita de bostezos
    if (state.drowsiness != null && state.drowsiness!.isYawning) {
      statusText = "BOSTEZANDO";
      statusColor = Colors.orangeAccent;
    }

    // Mostrar emoción dominante si es negativa
    String emotionText = state.emotion;
    if (state.emotion.toLowerCase() == 'angry') emotionText = "ENOJADO";
    if (state.emotion.toLowerCase() == 'sad') emotionText = "TRISTE";
    if (state.emotion.toLowerCase() == 'fear') emotionText = "MIEDO";

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Estado Principal
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),

          // Métricas Detalladas
          _buildMetricRow("Emoción", emotionText),
          _buildMetricRow("Confianza", "${(state.confidence * 100).toStringAsFixed(0)}%"),

          if (state.drowsiness != null)
            _buildMetricRow("Ojos (EAR)", state.drowsiness!.ear.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getBorderColor(CombinedState? state) {
    if (state == null) return Colors.grey;
    if (state.drowsiness?.isYawning == true) return Colors.orange;
    return _getStateColor(state.finalState);
  }

  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'concentrado': return Colors.green;
      case 'distraido': return Colors.orange;
      case 'frustrado': return Colors.red;
      case 'durmiendo': return Colors.purple;
      case 'no_mirando': return Colors.grey;
      default: return Colors.white;
    }
  }
}