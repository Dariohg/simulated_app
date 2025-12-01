import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../session_summary/presentation/views/session_summary_view.dart';
import '../viewmodels/activity_view_model.dart';

class ActivityView extends StatefulWidget {
  final SessionModel session;
  final ActivityOption activityOption;

  const ActivityView({
    super.key,
    required this.session,
    required this.activityOption,
  });

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final ActivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ActivityViewModel(
      session: widget.session,
      activityOption: widget.activityOption,
    );
    _viewModel.startActivity();
  }

  void _finishActivity() async {
    await _viewModel.stopActivity();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SessionSummaryView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Stack(
            children: [
              // 1. Capa de Cámara
              Positioned.fill(
                child: SentimentAnalyzer(
                  onAnalysisComplete: _viewModel.onFrameProcessed,
                  showDebugOverlay: false,
                ),
              ),

              // 2. Header
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activityOption.title, // CORREGIDO
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          // Si hay contenido específico para leer, lo mostramos pequeño
                          if (widget.activityOption.content != null)
                            Text(
                              "Contenido disponible",
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle, color: Colors.red, size: 40),
                      onPressed: _finishActivity,
                    ),
                  ],
                ),
              ),

              // ... resto del código igual (Feedback y Loading)
              if (_viewModel.feedbackMessage != null)
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          _viewModel.feedbackMessage!,
                          style: AppTextStyles.headline6.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_viewModel.isInitializing)
                Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Iniciando actividad...", style: TextStyle(color: Colors.white))
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}