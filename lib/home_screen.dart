import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCalibrated = false;

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
      body: ListView(
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
              title: const Text('Leccion 1: Historia de la IA'),
              subtitle: const Text('Duracion: 20 min'),
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.calculate_rounded, color: Colors.grey),
              title: const Text('Leccion 2: Matematicas (Bloqueado)'),
              subtitle: const Text('Duracion: 30 min'),
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
                  'Calibracion requerida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calibra el sistema para mejorar la precision',
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
        title: const Text('Calibracion necesaria'),
        content: const Text(
          'Para una mejor experiencia, te recomendamos calibrar el sistema antes de iniciar la leccion.',
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
    final result = await Navigator.pushNamed(context, '/calibration');
    if (result == true) {
      setState(() {
        _isCalibrated = true;
      });
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