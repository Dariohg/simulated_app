import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

import '../mocks/mock_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isCalibrated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCalibrationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sessionManager = context.read<SessionManager>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        sessionManager.pauseSession();
        break;
      case AppLifecycleState.resumed:
        sessionManager.resumeSession();
        break;
      case AppLifecycleState.detached:
        sessionManager.finalizeSession();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkCalibrationStatus() async {
    final storage = CalibrationStorage();
    final result = await storage.load();

    if (mounted) {
      setState(() {
        _isCalibrated = result != null && result.isSuccessful;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma Educativa'),
        actions: [
          _buildSessionIndicator(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _checkCalibrationStatus,
        child: ListView(
          children: [
            _buildUserHeader(),
            if (!_isCalibrated) _buildCalibrationBanner(),
            _buildSessionStatusCard(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Lecciones Disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...MockDataProvider.lessons.map(_buildLessonCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionIndicator() {
    return Consumer<SessionManager>(
      builder: (context, sessionManager, _) {
        Color color;
        IconData icon;

        switch (sessionManager.sessionStatus) {
          case SessionStatus.active:
            color = Colors.green;
            icon = Icons.cloud_done;
            break;
          case SessionStatus.paused:
          case SessionStatus.pausedAutomatically:
            color = Colors.orange;
            icon = Icons.cloud_off;
            break;
          case SessionStatus.expired:
          case SessionStatus.finalized:
            color = Colors.red;
            icon = Icons.cloud_off;
            break;
          case SessionStatus.none:
            color = Colors.grey;
            icon = Icons.cloud_queue;
            break;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(icon, color: color, size: 20),
        );
      },
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            child: Text(
              MockDataProvider.currentUser.name[0],
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, ${MockDataProvider.currentUser.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  MockDataProvider.currentUser.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationBanner() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.amber.shade100,
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.amber),
        title: const Text('Calibracion requerida'),
        subtitle: const Text('Calibra el sistema para mejor precision'),
        trailing: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/calibration'),
          child: const Text('Calibrar'),
        ),
      ),
    );
  }

  Widget _buildSessionStatusCard() {
    return Consumer<SessionManager>(
      builder: (context, sessionManager, _) {
        String statusText;
        Color statusColor;

        switch (sessionManager.sessionStatus) {
          case SessionStatus.active:
            statusText = 'Sesion activa';
            statusColor = Colors.green;
            break;
          case SessionStatus.paused:
            statusText = 'Sesion pausada';
            statusColor = Colors.orange;
            break;
          case SessionStatus.pausedAutomatically:
            statusText = 'Sesion pausada (automatico)';
            statusColor = Colors.orange;
            break;
          case SessionStatus.expired:
            statusText = 'Sesion expirada';
            statusColor = Colors.red;
            break;
          case SessionStatus.finalized:
            statusText = 'Sesion finalizada';
            statusColor = Colors.grey;
            break;
          case SessionStatus.none:
            statusText = 'Sin sesion';
            statusColor = Colors.grey;
            break;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(Icons.person, color: statusColor),
            title: Text(statusText),
            subtitle: sessionManager.sessionId != null
                ? Text(
              'ID: ${sessionManager.sessionId!.substring(0, 8)}...',
              style: const TextStyle(fontSize: 12),
            )
                : null,
            trailing: sessionManager.sessionStatus == SessionStatus.none ||
                sessionManager.sessionStatus == SessionStatus.expired
                ? ElevatedButton(
              onPressed: () async {
                await sessionManager.initializeSession();
              },
              child: const Text('Reconectar'),
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildLessonCard(MockLesson lesson) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildLessonIcon(lesson.activityType),
        title: Text(lesson.title),
        subtitle: Text(lesson.subtitle),
        trailing: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 32),
        onTap: () => _startLesson(lesson),
      ),
    );
  }

  Widget _buildLessonIcon(String activityType) {
    IconData icon;
    Color color;

    switch (activityType) {
      case 'reading':
        icon = Icons.menu_book;
        color = Colors.blue;
        break;
      case 'quiz':
        icon = Icons.quiz;
        color = Colors.orange;
        break;
      case 'video':
        icon = Icons.play_circle;
        color = Colors.red;
        break;
      case 'exercise':
        icon = Icons.edit_note;
        color = Colors.green;
        break;
      case 'coding':
        icon = Icons.code;
        color = Colors.teal;
        break;
      default:
        icon = Icons.article;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color),
    );
  }

  void _startLesson(MockLesson lesson) {
    if (!_isCalibrated) {
      _promptCalibration(lesson);
      return;
    }

    Navigator.pushNamed(
      context,
      '/activity',
      arguments: {'lesson': lesson},
    );
  }

  void _promptCalibration(MockLesson? pendingLesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibracion necesaria'),
        content: const Text(
          'Para una mejor experiencia de aprendizaje, necesitas calibrar el sistema de monitoreo primero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Despues'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/calibration').then((_) {
                _checkCalibrationStatus();
              });
            },
            child: const Text('Calibrar ahora'),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Calibrar sistema'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/calibration').then((_) {
                  _checkCalibrationStatus();
                });
              },
            ),
            Consumer<SessionManager>(
              builder: (context, sessionManager, _) => ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reiniciar sesion'),
                onTap: () async {
                  Navigator.pop(context);
                  await sessionManager.finalizeSession();
                  await sessionManager.initializeSession();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Plataforma Educativa',
      applicationVersion: '1.0.0',
      children: [
        const Text(
          'Sistema de aprendizaje adaptativo con monitoreo cognitivo.',
        ),
      ],
    );
  }
}