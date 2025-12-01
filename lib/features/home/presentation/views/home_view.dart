import 'package:flutter/material.dart';
import '../../../../core/mocks/mock_activities.dart';
import '../../../../core/mocks/mock_user.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../calibration/presentation/views/calibration_view.dart';
import '../viewmodels/home_view_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel _viewModel = HomeViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.initializeSession();
  }

  void _onActivitySelected(ActivityOption activity) {
    if (_viewModel.currentSession == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalibrationView(
          session: _viewModel.currentSession!,
          activityOption: activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monitor Cognitivo")),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.error != null) {
            return Center(child: Text("Error: ${_viewModel.error}"));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hola,", style: AppTextStyles.headline1),
                Text(MockUser.name, style: AppTextStyles.headline6.copyWith(color: AppColors.primary)),
                const SizedBox(height: 24),
                const Text("Actividades Disponibles:", style: AppTextStyles.body1),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: MockActivities.list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final activity = MockActivities.list[index];
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(activity.title, style: AppTextStyles.headline6),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activity.subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(activity.subtitle!, style: AppTextStyles.body2),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                  activity.activityType,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          onTap: () => _onActivitySelected(activity),
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