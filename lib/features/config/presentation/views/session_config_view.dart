import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class SessionConfigView extends StatefulWidget {
  final String sessionId;
  final SentimentNetworkInterface networkService;

  const SessionConfigView({
    super.key,
    required this.sessionId,
    required this.networkService,
  });

  @override
  State<SessionConfigView> createState() => _SessionConfigViewState();
}

class _SessionConfigViewState extends State<SessionConfigView> {
  bool _isLoading = true;

  bool _cognitiveAnalysis = true;
  bool _textNotifications = true;
  bool _videoSuggestions = true;
  bool _vibrationAlerts = true;
  bool _pauseSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final sessionData = await widget.networkService.getSession(widget.sessionId);

      if (mounted) {
        setState(() {
          final config = sessionData['config'] ?? {};

          _cognitiveAnalysis = config['cognitive_analysis_enabled'] ?? true;
          _textNotifications = config['text_notifications'] ?? true;
          _videoSuggestions = config['video_suggestions'] ?? true;
          _vibrationAlerts = config['vibration_alerts'] ?? true;
          _pauseSuggestions = config['pause_suggestions'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando config: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConfig() async {
    try {
      await widget.networkService.updateConfig(
        sessionId: widget.sessionId,
        cognitiveAnalysisEnabled: _cognitiveAnalysis,
        textNotifications: _textNotifications,
        videoSuggestions: _videoSuggestions,
        vibrationAlerts: _vibrationAlerts,
        pauseSuggestions: _pauseSuggestions,
      );
    } catch (e) {
      debugPrint('Error guardando config: $e');
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
      appBar: AppBar(
        title: const Text('Configuración de Sesión'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Análisis Cognitivo'),
            subtitle: const Text('Habilitar análisis de emociones y atención'),
            value: _cognitiveAnalysis,
            onChanged: (val) {
              setState(() => _cognitiveAnalysis = val);
              _updateConfig();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Notificaciones de Texto'),
            value: _textNotifications,
            onChanged: (val) {
              setState(() => _textNotifications = val);
              _updateConfig();
            },
          ),
          SwitchListTile(
            title: const Text('Sugerencias de Video'),
            value: _videoSuggestions,
            onChanged: (val) {
              setState(() => _videoSuggestions = val);
              _updateConfig();
            },
          ),
          SwitchListTile(
            title: const Text('Alertas por Vibración'),
            value: _vibrationAlerts,
            onChanged: (val) {
              setState(() => _vibrationAlerts = val);
              _updateConfig();
            },
          ),
          SwitchListTile(
            title: const Text('Sugerencias de Pausa'),
            value: _pauseSuggestions,
            onChanged: (val) {
              setState(() => _pauseSuggestions = val);
              _updateConfig();
            },
          ),
        ],
      ),
    );
  }
}