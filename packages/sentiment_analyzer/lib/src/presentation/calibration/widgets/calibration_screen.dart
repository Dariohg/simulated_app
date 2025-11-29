import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/calibration_view_model.dart';
import '../../../data/services/calibration_service.dart';
import '../../../core/constants/app_colors.dart';

class CalibrationScreen extends StatelessWidget {
  final VoidCallback onCalibrationComplete;
  final VoidCallback? onSkip;

  const CalibrationScreen({super.key, required this.onCalibrationComplete, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalibrationViewModel()..initialize(),
      child: _CalibrationContent(onCalibrationComplete: onCalibrationComplete, onSkip: onSkip),
    );
  }
}

class _CalibrationContent extends StatefulWidget {
  final VoidCallback onCalibrationComplete;
  final VoidCallback? onSkip;
  const _CalibrationContent({required this.onCalibrationComplete, this.onSkip});
  @override
  State<_CalibrationContent> createState() => _CalibrationContentState();
}

class _CalibrationContentState extends State<_CalibrationContent> {
  bool _calibrationStarted = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CalibrationViewModel>();
    if (viewModel.isCalibrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCalibrationComplete());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (viewModel.isInitialized && viewModel.cameraController != null)
            _buildFullScreenCamera(context, viewModel.cameraController!)
          else
            Container(color: AppColors.background),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildContent(context, viewModel)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenCamera(BuildContext context, CameraController controller) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    if (!controller.value.isInitialized) return Container();
    final previewSize = controller.value.previewSize!;
    final sensorRatio = previewSize.height / previewSize.width;
    double scale = (deviceRatio < sensorRatio) ? sensorRatio / deviceRatio : deviceRatio / sensorRatio;
    return Center(
      child: Transform.scale(
        scale: scale,
        child: AspectRatio(aspectRatio: sensorRatio, child: CameraPreview(controller)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          if (widget.onSkip != null)
            IconButton(onPressed: widget.onSkip, icon: const Icon(Icons.close, color: AppColors.surface))
          else
            const SizedBox(width: 48),
          const Expanded(
            child: Text('Calibración', textAlign: TextAlign.center, style: TextStyle(color: AppColors.surface, fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, CalibrationViewModel viewModel) {
    if (!viewModel.isInitialized) return const Center(child: CircularProgressIndicator(color: AppColors.success));
    if (!_calibrationStarted) return _buildWelcomeState(context, viewModel);

    return Stack(
      children: [
        Positioned.fill(child: _buildFaceOverlay(viewModel)),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomPanel(context, viewModel)),
      ],
    );
  }

  Widget _buildWelcomeState(BuildContext context, CalibrationViewModel viewModel) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.overlay, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.face_retouching_natural, size: 60, color: AppColors.success),
            const SizedBox(height: 24),
            const Text('Calibración Personalizada', style: TextStyle(color: AppColors.surface, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: viewModel.isInitialized ? () { setState(() => _calibrationStarted = true); viewModel.startCalibration(); } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.surface),
                child: const Text('Iniciar', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceOverlay(CalibrationViewModel viewModel) {
    final progress = viewModel.currentProgress;
    return CustomPaint(
      painter: _FaceGuidePainter(step: viewModel.currentStep, progress: progress?.stepProgress ?? 0.0),
      child: Center(child: progress?.requiresAction == true ? _buildActionIndicator(progress!) : null),
    );
  }

  Widget _buildActionIndicator(CalibrationProgress progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(30)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.surface, size: 40),
          const SizedBox(height: 12),
          Text(progress.actionMessage ?? '', style: const TextStyle(color: AppColors.surface, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, CalibrationViewModel viewModel) {
    final progress = viewModel.currentProgress;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.transparent, AppColors.background], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            Text(progress.message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.surface, fontSize: 16)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress.stepProgress, minHeight: 8, color: _getStepColor(viewModel.currentStep)),
          ],
          TextButton(onPressed: () { viewModel.resetCalibration(); setState(() => _calibrationStarted = false); }, child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Color _getStepColor(CalibrationStep step) {
    switch (step) {
      case CalibrationStep.faceDetection: return AppColors.calibrationFaceDetection;
      case CalibrationStep.lighting: return AppColors.calibrationLighting;
      case CalibrationStep.eyeBaseline: return AppColors.calibrationEyeBaseline;
      case CalibrationStep.completed: return AppColors.calibrationCompleted;
    }
  }
}

class _FaceGuidePainter extends CustomPainter {
  final CalibrationStep step;
  final double progress;
  _FaceGuidePainter({required this.step, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width * 0.55, height: size.width * 0.85);
    final paint = Paint()..color = _getColor().withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawOval(rect, paint);
    if (progress > 0) {
      final progressPaint = Paint()..color = _getColor()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -3.14159 / 2, 2 * 3.14159 * progress, false, progressPaint);
    }
  }

  Color _getColor() {
    switch (step) {
      case CalibrationStep.faceDetection: return AppColors.calibrationFaceDetection;
      case CalibrationStep.lighting: return AppColors.calibrationLighting;
      case CalibrationStep.eyeBaseline: return AppColors.calibrationEyeBaseline;
      case CalibrationStep.completed: return AppColors.calibrationCompleted;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}