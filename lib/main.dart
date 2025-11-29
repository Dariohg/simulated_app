import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Imports del package y la app
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import 'package:simulated_app/home_screen.dart';
import 'package:simulated_app/lesson_screen.dart';
import 'package:simulated_app/calibration_page.dart';
import 'package:simulated_app/services/http_network_service.dart';

// SessionManager debe importarse del package para instanciarlo globalmente
import 'package:sentiment_analyzer/src/logic/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Instanciamos la red aquí
  final networkService = HttpNetworkService(
    baseUrl: 'http://192.168.1.XX:3004', // Tu IP Local
    apiKey: dotenv.env['API_KEY_EMOTIONAI'] ?? '',
  );

  // Session Manager Global
  final sessionManager = SessionManager(
    network: networkService,
    userId: 12, // Usuario fijo para demo
  );

  runApp(
    MultiProvider(
      providers: [
        // Proveedor global de la sesión (para que persista entre pantallas)
        Provider<SessionManager>.value(value: sessionManager),
        // Proveedor global del servicio de red (por si se necesita)
        Provider<SentimentNetworkInterface>.value(value: networkService),
      ],
      child: const SimulatedApp(),
    ),
  );
}

class SimulatedApp extends StatelessWidget {
  const SimulatedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Educativa',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/lesson': (context) => const LessonScreen(),
        '/calibration': (context) => const CalibrationPage(),
      },
    );
  }
}