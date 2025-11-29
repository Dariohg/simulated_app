import 'package:flutter/material.dart';
import 'package:simulated_app/home_screen.dart';
import 'package:simulated_app/lesson_screen.dart';
import 'package:simulated_app/calibration_page.dart';

void main() {
  runApp(const SimulatedApp());
}

class SimulatedApp extends StatelessWidget {
  const SimulatedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Educativa (Simulada)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/lesson': (context) => const LessonScreen(),
        '/calibration': (context) => const CalibrationPage(),
      },
    );
  }
}