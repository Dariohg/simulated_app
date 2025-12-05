import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onClose;

  const VideoPlayerModal({
    super.key,
    required this.videoUrl,
    required this.onClose,
  });

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  YoutubePlayerController? _youtubeController;

  bool _isYoutube = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final ytId = YoutubePlayer.convertUrlToId(widget.videoUrl);
      if (ytId != null) {
        _isYoutube = true;
        _youtubeController = YoutubePlayerController(
          initialVideoId: ytId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
      } else {
        _isYoutube = false;
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );

        await _videoPlayerController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
            );
          },
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            width: double.infinity,
            height: 400,
            alignment: Alignment.center,
            child: _buildPlayerContent(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_isLoading) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "Error al cargar video: $_error\nURL: ${widget.videoUrl}",
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_isYoutube && _youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
      );
    }

    if (!_isYoutube && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const Text("No se pudo cargar el reproductor", style: TextStyle(color: Colors.white));
  }
}