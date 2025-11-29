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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Capa de Cámara (Fondo completo corregido)
          if (viewModel.isInitialized && viewModel.cameraController != null)
            _buildFullScreenCamera(context, viewModel.cameraController!)
          else
            Container(color: Colors.black),

          // 2. Capa de UI (Gradiente y Contenidos)
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _buildContent(context, viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CORRECCIÓN VISUAL: Full Screen Camera con AspectRatio correcto (BoxFit.cover)
  Widget _buildFullScreenCamera(BuildContext context, CameraController controller) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    // Obtenemos el ratio de la cámara. Nota: en móviles value.aspectRatio suele ser width/height
    // pero invertido si está en portrait. Para portrait suele ser < 1.0 (ej 9/16).
    // CameraController maneja previewSize.
    if (!controller.value.isInitialized) return Container();

    // Calcular escala para simular BoxFit.cover
    final previewSize = controller.value.previewSize!;
    final previewHeight = previewSize.height;
    final previewWidth = previewSize.width;

    // En portrait, la camara nos da dimensiones "landscape", así que invertimos para el ratio
    final sensorRatio = previewHeight / previewWidth;

    double scale = 1.0;
    // Si el dispositivo es más "alto" que la imagen de la cámara
    if (deviceRatio < sensorRatio) {
      scale = sensorRatio / deviceRatio;
    } else {
      scale = deviceRatio / sensorRatio;
    }

    return Center(
      child: Transform.scale(
        scale: scale,
        child: AspectRatio(
          aspectRatio: sensorRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          if (widget.onSkip != null)
            IconButton(
              onPressed: widget.onSkip,
              icon: const Icon(Icons.close, color: Colors.white),
            )
          else
            const SizedBox(width: 48),
          const Expanded(
            child: Text(
              'Calibración',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    if (!_calibrationStarted) {
      return _buildWelcomeState(context, viewModel);
    }

    // Estado de calibración activa
    return Stack(
      children: [
        // Guía Facial en el centro
        Positioned.fill(
          child: _buildFaceOverlay(viewModel),
        ),
        // Panel inferior
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildWelcomeState(BuildContext context, CalibrationViewModel viewModel) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black54, // Fondo semitransparente para leer sobre la cámara
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.face_retouching_natural,
              size: 60,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 24),
            const Text(
              'Calibración Personalizada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Asegúrate de estar en un lugar iluminado y sostén el dispositivo frente a tu rostro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Iniciar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white54, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, CalibrationViewModel viewModel) {
    final progress = viewModel.currentProgress;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.4],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            Text(
              progress.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(viewModel.currentStep, progress.stepProgress),
            const SizedBox(height: 20),
          ],

          TextButton(
            onPressed: () {
              viewModel.resetCalibration();
              setState(() {
                _calibrationStarted = false;
              });
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(CalibrationStep step, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation<Color>(_getStepColor(step)),
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

    // CORRECCIÓN DE FORMA:
    // Hacemos el óvalo más estrecho (menos ancho) y mantenemos la altura
    // para asemejarse más a un rostro humano y no un círculo redondo.
    final faceWidth = size.width * 0.55;  // Reducido de 0.7-0.8 a 0.55
    final faceHeight = size.width * 0.85; // Altura proporcional

    final rect = Rect.fromCenter(
      center: center,
      width: faceWidth,
      height: faceHeight,
    );

    final paint = Paint()
      ..color = _getColor().withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Dibujar el óvalo guía base
    canvas.drawOval(rect, paint);

    // Dibujar el progreso como un arco sobre el óvalo
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = _getColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      // Dibujamos el arco ajustado al mismo rect
      // Empezamos arriba (-pi/2)
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        rect, // Usamos el mismo rect para que coincida perfectamente
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