import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'calibration_service.dart';
import 'calibration_view_model.dart';

class CalibrationScreen extends StatelessWidget {
  final VoidCallback onCalibrationComplete;
  final VoidCallback? onSkip;

  const CalibrationScreen({
    super.key,
    required this.onCalibrationComplete,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalibrationViewModel()..initialize(),
      child: _CalibrationContent(
        onCalibrationComplete: onCalibrationComplete,
        onSkip: onSkip,
      ),
    );
  }
}

class _CalibrationContent extends StatefulWidget {
  final VoidCallback onCalibrationComplete;
  final VoidCallback? onSkip;

  const _CalibrationContent({
    required this.onCalibrationComplete,
    this.onSkip,
  });

  @override
  State<_CalibrationContent> createState() => _CalibrationContentState();
}

class _CalibrationContentState extends State<_CalibrationContent> {
  bool _calibrationStarted = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CalibrationViewModel>();

    if (viewModel.isCalibrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCalibrationComplete();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildContent(context, viewModel),
            ),
            _buildFooter(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (widget.onSkip != null)
            IconButton(
              onPressed: widget.onSkip,
              icon: const Icon(Icons.close, color: Colors.white54),
            )
          else
            const SizedBox(width: 48),
          const Expanded(
            child: Text(
              'Calibracion',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, CalibrationViewModel viewModel) {
    if (!viewModel.isInitialized) {
      return _buildLoadingState();
    }

    if (!_calibrationStarted) {
      return _buildWelcomeState(context, viewModel);
    }

    return _buildCalibrationState(context, viewModel);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
          SizedBox(height: 16),
          Text(
            'Iniciando camara...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(BuildContext context, CalibrationViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D2D2D),
              border: Border.all(
                color: const Color(0xFF4CAF50),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              size: 60,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Calibracion Personalizada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para mejorar la precision del sistema, necesitamos calibrar segun tus caracteristicas faciales.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildStepPreview(),
        ],
      ),
    );
  }

  Widget _buildStepPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildStepItem(
            icon: Icons.face,
            title: 'Deteccion de rostro',
            description: 'Verificamos que tu rostro sea visible',
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            icon: Icons.wb_sunny_outlined,
            title: 'Iluminacion',
            description: 'Comprobamos la luz ambiente',
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            icon: Icons.visibility,
            title: 'Calibracion de ojos',
            description: 'Ajustamos segun el tamano de tus ojos',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationState(BuildContext context, CalibrationViewModel viewModel) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildCameraPreview(viewModel),
        ),
        Expanded(
          flex: 2,
          child: _buildProgressSection(viewModel),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(CalibrationViewModel viewModel) {
    if (viewModel.cameraController == null) {
      return const Center(
        child: Text(
          'Camara no disponible',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _getStepColor(viewModel.currentStep),
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(viewModel.cameraController!),
            _buildFaceOverlay(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceOverlay(CalibrationViewModel viewModel) {
    final progress = viewModel.currentProgress;

    return CustomPaint(
      painter: _FaceGuidePainter(
        step: viewModel.currentStep,
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
    IconData icon;
    String text = progress.actionMessage ?? '';

    switch (progress.actionMessage) {
      case 'Ojos abiertos':
        icon = Icons.visibility;
        break;
      case 'Cierra los ojos':
      case 'Ojos cerrados':
        icon = Icons.visibility_off;
        break;
      default:
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(CalibrationViewModel viewModel) {
    final progress = viewModel.currentProgress;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepIndicators(viewModel),
          const SizedBox(height: 24),
          if (progress != null) ...[
            Text(
              progress.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(viewModel.currentStep, progress.stepProgress),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicators(CalibrationViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(
          CalibrationStep.faceDetection,
          viewModel.currentStep,
          Icons.face,
        ),
        _buildStepConnector(viewModel.currentStep.index >= 1),
        _buildStepDot(
          CalibrationStep.lighting,
          viewModel.currentStep,
          Icons.wb_sunny_outlined,
        ),
        _buildStepConnector(viewModel.currentStep.index >= 2),
        _buildStepDot(
          CalibrationStep.eyeBaseline,
          viewModel.currentStep,
          Icons.visibility,
        ),
      ],
    );
  }

  Widget _buildStepDot(CalibrationStep step, CalibrationStep current, IconData icon) {
    final isActive = current == step;
    final isCompleted = current.index > step.index;

    Color bgColor;
    Color iconColor;

    if (isCompleted) {
      bgColor = const Color(0xFF4CAF50);
      iconColor = Colors.white;
    } else if (isActive) {
      bgColor = const Color(0xFF2196F3);
      iconColor = Colors.white;
    } else {
      bgColor = const Color(0xFF3D3D3D);
      iconColor = Colors.white54;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 40,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildProgressBar(CalibrationStep step, double progress) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFF3D3D3D),
            valueColor: AlwaysStoppedAnimation<Color>(_getStepColor(step)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            color: _getStepColor(step),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, CalibrationViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_calibrationStarted)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: viewModel.isInitialized
                    ? () {
                  setState(() {
                    _calibrationStarted = true;
                  });
                  viewModel.startCalibration();
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Iniciar Calibracion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else if (viewModel.isCalibrating)
            TextButton(
              onPressed: () {
                viewModel.resetCalibration();
                setState(() {
                  _calibrationStarted = false;
                });
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStepColor(CalibrationStep step) {
    switch (step) {
      case CalibrationStep.faceDetection:
        return const Color(0xFF2196F3);
      case CalibrationStep.lighting:
        return const Color(0xFFFFC107);
      case CalibrationStep.eyeBaseline:
        return const Color(0xFF9C27B0);
      case CalibrationStep.completed:
        return const Color(0xFF4CAF50);
    }
  }
}

class _FaceGuidePainter extends CustomPainter {
  final CalibrationStep step;
  final double progress;

  _FaceGuidePainter({
    required this.step,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final paint = Paint()
      ..color = _getColor().withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.6,
        height: radius * 2,
      ),
      paint,
    );

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = _getColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * 3.14159 * progress;

      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: radius * 1.7,
          height: radius * 2.1,
        ),
        -3.14159 / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  Color _getColor() {
    switch (step) {
      case CalibrationStep.faceDetection:
        return const Color(0xFF2196F3);
      case CalibrationStep.lighting:
        return const Color(0xFFFFC107);
      case CalibrationStep.eyeBaseline:
        return const Color(0xFF9C27B0);
      case CalibrationStep.completed:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) {
    return oldDelegate.step != step || oldDelegate.progress != progress;
  }
}