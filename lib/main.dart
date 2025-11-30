import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sentiment_analyzer/sentiment_analyzer.dart';

import 'services/http_network_service.dart';
import 'mocks/mock_data.dart';
import 'screens/home_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/calibration_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final prefs = await SharedPreferences.getInstance();

  final gatewayUrl = dotenv.env['GATEWAY_URL'] ?? 'http://192.168.1.71:3000';
  final apiKey = dotenv.env['API_KEY'] ?? '';

  final networkService = HttpNetworkService(
    baseUrl: gatewayUrl,
    apiKey: apiKey,
  );

  final sessionManager = SessionManager(
    network: networkService,
    userId: MockDataProvider.currentUser.id,
    disabilityType: MockDataProvider.currentUser.disabilityType,
    cognitiveAnalysisEnabled: true,
  );

  final savedSessionId = prefs.getString('session_id');
  if (savedSessionId != null) {
    await sessionManager.recoverSession(savedSessionId);
  } else {
    await sessionManager.initializeSession();
  }

  if (sessionManager.sessionId != null) {
    await prefs.setString('session_id', sessionManager.sessionId!);
  }

  sessionManager.addListener(() {
    if (sessionManager.sessionId != null) {
      prefs.setString('session_id', sessionManager.sessionId!);
    } else {
      prefs.remove('session_id');
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionManager>.value(value: sessionManager),
        Provider<HttpNetworkService>.value(value: networkService),
      ],
      child: const EducationalApp(),
    ),
  );
}

class EducationalApp extends StatelessWidget {
  const EducationalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plataforma Educativa',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );

          case '/activity':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ActivityScreen(
                lesson: args['lesson'] as MockLesson,
              ),
            );

          case '/calibration':
            return MaterialPageRoute(
              builder: (_) => const CalibrationPage(),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
        }
      },
    );
  }
}