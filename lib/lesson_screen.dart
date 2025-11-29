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
        title: const Text('Leccion 1: Historia de la IA'),
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
                  'La inteligencia artificial (IA), en las ciencias de la computacion, es la disciplina que intenta replicar y desarrollar la inteligencia y sus procesos implicitos a traves de computadoras...',
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
                const Opacity(
                  opacity: 0.7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Analisis de atencion activo'),
                    ],
                  ),
                )
              ],
            ),
          ),
          SentimentAnalysisManager(
            userId: currentUserId,
            lessonId: currentLessonId,
          ),
        ],
      ),
    );
  }
}