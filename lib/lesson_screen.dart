import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
// Importa el storage y la clase de resultado
import 'package:sentiment_analyzer/src/calibration/calibration_storage.dart';
import 'package:sentiment_analyzer/src/calibration/calibration_service.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  final String currentUserId = 'alumno_123';
  final String currentLessonId = 'leccion_historia_ia';

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  CalibrationResult? _savedCalibration;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalibration();
  }

  // Carga la calibración guardada
  Future<void> _loadCalibration() async {
    final storage = CalibrationStorage();
    final calibration = await storage.load();

    if (mounted) {
      setState(() {
        _savedCalibration = calibration;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lección 1: Historia de la IA'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El concepto de Inteligencia Artificial',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                const Text(
                  'La inteligencia artificial (IA), en las ciencias de la computación, es la disciplina que intenta replicar y desarrollar la inteligencia y sus procesos implícitos a través de computadoras...',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 30),
                const Center(
                  child: Icon(
                    Icons.psychology_rounded,
                    size: 100,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),

          // Solo carga el manager cuando terminó de leer la memoria
          if (!_isLoading)
            SentimentAnalysisManager(
              userId: widget.currentUserId,
              lessonId: widget.currentLessonId,
              calibration: _savedCalibration, // PASA LA CALIBRACIÓN AQUÍ
            ),
        ],
      ),
    );
  }
}