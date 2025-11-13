import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key});

  final String currentUserId = 'alumno_123';
  final String currentLessonId = 'leccion_historia_ia';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lección 1: Historia de la IA'),
      ),
      body: Stack(
        children: [
          // --- CAPA 1: Contenido de la Lección ---
          // Este es el contenido normal de la App 1
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
                const SizedBox(height: 20),
                // Es buena práctica notificar al usuario
                const Opacity(
                  opacity: 0.7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Análisis de atención activo'),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Ahora que la importación es correcta,
          // Flutter encontrará esta clase.
          SentimentAnalysisManager(
            userId: currentUserId,
            lessonId: currentLessonId,
          ),
        ],
      ),
    );
  }
}