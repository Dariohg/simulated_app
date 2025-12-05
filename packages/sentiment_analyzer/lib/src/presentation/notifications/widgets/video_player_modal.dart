import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerModal extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onClose;

  const VideoPlayerModal({
    super.key,
    required this.videoUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.video_library,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      videoUrl,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _launchVideo(),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Abrir en navegador'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Finalizar y Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchVideo() async {
    final uri = Uri.parse(videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }
}