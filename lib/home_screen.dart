import 'package:flutter/material.dart';
// Import CORREGIDO: Usamos el archivo barril, no la ruta interna src/...
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCalibrated = false;
  bool _isLoadingToCheck = true;

  @override
  void initState() {
    super.initState();
    _checkCalibrationStatus();
  }

  Future<void> _checkCalibrationStatus() async {
    // CalibrationStorage está disponible gracias al export en sentiment_analyzer.dart
    final storage = CalibrationStorage();
    final result = await storage.load();

    if (mounted) {
      setState(() {
        _isCalibrated = result != null && result.isSuccessful;
        _isLoadingToCheck = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma Educativa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context),
          ),
        ],
      ),
      body: _isLoadingToCheck
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bienvenido, Alumno',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (!_isCalibrated) _buildCalibrationBanner(context),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.history_edu_rounded, color: Colors.blue),
              title: const Text('Lección 1: Historia de la IA'),
              subtitle: const Text('Duración: 20 min'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                if (!_isCalibrated) {
                  _promptCalibration(context);
                } else {
                  Navigator.pushNamed(context, '/lesson');
                }
              },
            ),
          ),
          Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.calculate_rounded, color: Colors.grey),
              title: const Text('Lección 2: Matemáticas (Bloqueado)'),
              subtitle: const Text('Duración: 30 min'),
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calibración requerida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calibra el sistema para mejorar la precisión',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _navigateToCalibration(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Calibrar'),
          ),
        ],
      ),
    );
  }

  void _promptCalibration(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calibración necesaria'),
        content: const Text(
          'Para una mejor experiencia, te recomendamos calibrar el sistema antes de iniciar la lección.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamed(context, '/lesson');
            },
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToCalibration(context);
            },
            child: const Text('Calibrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCalibration(BuildContext context) async {
    // Esperamos el resultado (true si se completó)
    final result = await Navigator.pushNamed(context, '/calibration');

    // Recargamos el estado para quitar el banner si fue exitoso
    if (result == true) {
      _checkCalibrationStatus();
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Recalibrar sistema'),
              subtitle: Text(
                _isCalibrated ? 'Calibrado' : 'No calibrado',
                style: TextStyle(
                  color: _isCalibrated ? Colors.green : Colors.orange,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _navigateToCalibration(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de'),
              onTap: () {
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}