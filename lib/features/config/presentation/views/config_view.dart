import 'package:flutter/material.dart';
import '../../../../../core/config/env_config.dart';
import '../../../../../core/network/app_network_service.dart';

class ConfigView extends StatefulWidget {
  final int userId;

  const ConfigView({super.key, required this.userId});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  bool _isLoading = true;
  late AppNetworkService _networkService;

  // Settings locales
  bool _cognitiveAnalysis = true;
  bool _textNotifications = true;
  bool _videoSuggestions = true;
  bool _vibrationAlerts = true;

  @override
  void initState() {
    super.initState();
    _networkService = AppNetworkService(EnvConfig.apiGatewayUrl, EnvConfig.apiToken);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _networkService.getUserConfig(widget.userId);
      final settings = config['settings'] ?? {};

      setState(() {
        _cognitiveAnalysis = settings['cognitive_analysis_enabled'] ?? true;
        _textNotifications = settings['text_notifications'] ?? true;
        _videoSuggestions = settings['video_suggestions'] ?? true;
        _vibrationAlerts = settings['vibration_alerts'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando configuración: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    // Actualización optimista
    setState(() {
      if (key == 'cognitive_analysis_enabled') _cognitiveAnalysis = value;
      if (key == 'text_notifications') _textNotifications = value;
      if (key == 'video_suggestions') _videoSuggestions = value;
      if (key == 'vibration_alerts') _vibrationAlerts = value;
    });

    try {
      await _networkService.updateUserConfig(
        userId: widget.userId,
        settings: {
          'cognitive_analysis_enabled': _cognitiveAnalysis,
          'text_notifications': _textNotifications,
          'video_suggestions': _videoSuggestions,
          'vibration_alerts': _vibrationAlerts,
        },
      );
    } catch (e) {
      // Revertir en caso de error (opcional, o mostrar mensaje)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error guardando configuración')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Preferencias de Monitoreo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Análisis Cognitivo"),
            subtitle: const Text("Permitir análisis facial y de atención"),
            value: _cognitiveAnalysis,
            onChanged: (v) => _updateSetting('cognitive_analysis_enabled', v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Notificaciones de Texto"),
            subtitle: const Text("Recibir sugerencias escritas"),
            value: _textNotifications,
            onChanged: (v) => _updateSetting('text_notifications', v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Sugerencias de Video"),
            subtitle: const Text("Recibir recomendaciones de contenido multimedia"),
            value: _videoSuggestions,
            onChanged: (v) => _updateSetting('video_suggestions', v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Alertas de Vibración"),
            subtitle: const Text("Vibrar al recibir intervenciones"),
            value: _vibrationAlerts,
            onChanged: (v) => _updateSetting('vibration_alerts', v),
          ),
        ],
      ),
    );
  }
}