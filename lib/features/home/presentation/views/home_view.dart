import 'package:flutter/material.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/mocks/mock_user.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../viewmodels/home_view_model.dart';
import '../../../calibration/presentation/views/calibration_view.dart';
import '../../../activity/presentation/views/activity_view.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel _viewModel = HomeViewModel();
  final CalibrationStorage _calibrationStorage = CalibrationStorage();

  @override
  void initState() {
    super.initState();
    _viewModel.initializeSession(MockUser.id, MockUser.disabilityType);
  }

  Future<void> _onActivitySelected(ActivityOption activity) async {
    if (_viewModel.sessionService == null) return;

    final savedCalibration = await _calibrationStorage.load();

    if (!mounted) return;

    if (savedCalibration != null && savedCalibration.isSuccessful) {
      await _viewModel.sessionService!.startActivity(
        externalActivityId: activity.externalActivityId,
        title: activity.title,
        activityType: activity.activityType,
        subtitle: activity.subtitle,
        content: activity.content,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityView(
            sessionService: _viewModel.sessionService!,
            userId: MockUser.id,
            externalActivityId: activity.externalActivityId,
            title: activity.title,
            activityType: activity.activityType,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalibrationView(
            sessionService: _viewModel.sessionService!,
            userId: MockUser.id,
            activityOption: activity,
          ),
        ),
      );
    }
  }

  Future<void> _confirmEndSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de estudio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _viewModel.finalizeSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión finalizada correctamente')),
        );
      }
    }
  }

  IconData _getIconForActivityType(String activityType) {
    switch (activityType) {
      case 'LECTURA':
        return Icons.book;
      case 'LOGICA':
        return Icons.calculate;
      case 'ATENCION':
        return Icons.center_focus_strong;
      default:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor Cognitivo"),
        actions: [
          if (_viewModel.sessionService != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _confirmEndSession,
              tooltip: 'Finalizar sesión',
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${_viewModel.error}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _viewModel.initializeSession(
                      MockUser.id,
                      MockUser.disabilityType,
                    ),
                    child: const Text("Reintentar"),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hola,", style: AppTextStyles.headline1),
                Text(
                  MockUser.name,
                  style: AppTextStyles.headline6.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                if (_viewModel.sessionService?.sessionId != null)
                  Text(
                    "Sesión: ${_viewModel.sessionService!.sessionId!.substring(0, 8)}...",
                    style: AppTextStyles.body2,
                  ),
                const SizedBox(height: 24),
                const Text("Actividades Disponibles:", style: AppTextStyles.body1),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: MockActivities.list.length,
                    itemBuilder: (context, index) {
                      final activity = MockActivities.list[index];
                      return Card(
                        elevation: 4,
                        child: InkWell(
                          onTap: () => _onActivitySelected(activity),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconForActivityType(activity.activityType),
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  activity.title,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body1,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}