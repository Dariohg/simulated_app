import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../viewmodel/calibration_view_model.dart';
import '../../../data/services/calibration_service.dart';
import '../../../core/constants/app_colors.dart';

class CalibrationScreen extends StatefulWidget {
  final VoidCallback onCalibrationComplete;
  final VoidCallback? onSkip;

  const CalibrationScreen({
    super.key,
    required this.onCalibrationComplete,
    this.onSkip,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CalibrationViewModel _viewModel;
  bool _calibrationStarted = false;

  @override
  void initState() {
    super.initState();
    _viewModel = CalibrationViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize();
  }

  void _onViewModelChanged() {
    if (_viewModel.isCalibrated) {
      widget.onCalibrationComplete();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_viewModel.isInitialized && _viewModel.cameraController != null)
            _buildFullScreenCamera(context, _viewModel.cameraController!)
          else
            Container(color: AppColors.background),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenCamera(
      BuildContext context, CameraController controller) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;

    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(controller)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Calibracion',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text('Omitir', style: TextStyle(color: Colors.white70)),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!_calibrationStarted) {
      return _buildStartScreen(context);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildFaceOverlay(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(context),
        ),
      ],
    );
  }

  Widget _buildStartScreen(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.face, size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          const Text(
            'Calibracion del sensor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para una mejor experiencia, calibraremos el sensor a tu rostro. Manten tu rostro centrado y bien iluminado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _viewModel.isInitialized
                  ? () {
                setState(() => _calibrationStarted = true);
                _viewModel.startCalibration();
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Iniciar', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceOverlay() {
    final progress = _viewModel.currentProgress;
    return CustomPaint(
      painter: _FaceGuidePainter(
        step: _viewModel.currentStep,
        progress: progress?.stepProgress ?? 0.0,
      ),
      child: Center(
        child: progress?.requiresAction == true
            ? _buildActionIndicator(progress!)
            : null,
      ),
    );
  }

  Widget _buildActionIndicator(CalibrationProgress progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.surface, size: 40),
          const SizedBox(height: 12),
          Text(
            progress.actionMessage ?? '',
            style: const TextStyle(color: AppColors.surface, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final progress = _viewModel.currentProgress;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.transparent, AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            Text(
              progress.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.surface, fontSize: 16),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.stepProgress,
              minHeight: 8,
              color: _getStepColor(_viewModel.currentStep),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _viewModel.resetCalibration();
              setState(() => _calibrationStarted = false);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Color _getStepColor(CalibrationStep step) {
    switch (step) {
      case CalibrationStep.faceDetection:
        return AppColors.calibrationFaceDetection;
      case CalibrationStep.lighting:
        return AppColors.calibrationLighting;
      case CalibrationStep.eyeBaseline:
        return AppColors.calibrationEyeBaseline;
      case CalibrationStep.completed:
        return AppColors.calibrationCompleted;
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
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.55,
      height: size.width * 0.85,
    );
    final paint = Paint()
      ..color = _getColor().withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(rect, paint);
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = _getColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -3.14159 / 2, 2 * 3.14159 * progress, false, progressPaint);
    }
  }

  Color _getColor() {
    switch (step) {
      case CalibrationStep.faceDetection:
        return AppColors.calibrationFaceDetection;
      case CalibrationStep.lighting:
        return AppColors.calibrationLighting;
      case CalibrationStep.eyeBaseline:
        return AppColors.calibrationEyeBaseline;
      case CalibrationStep.completed:
        return AppColors.calibrationCompleted;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}