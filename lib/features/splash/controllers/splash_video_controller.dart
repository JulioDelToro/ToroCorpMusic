import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Controlador para la reproducción del video de bienvenida (Splash Screen)
class SplashVideoController {
  final VoidCallback onFinished;
  final String videoAsset;

  VideoPlayerController? _videoPlayerController;
  bool _isFinished = false;

  SplashVideoController({
    required this.onFinished,
    this.videoAsset = 'assets/videos/intro_splash.mp4',
  });

  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  bool get isFinished => _isFinished;

  Future<void> initialize() async {
    try {
      final controller = VideoPlayerController.asset(videoAsset);
      _videoPlayerController = controller;

      await controller.initialize();
      controller.setLooping(false);
      await controller.play();

      controller.addListener(_videoListener);
    } catch (e) {
      // En entornos de test o si falla el códec, se completa limpiamente sin crashear
      debugPrint('VideoPlayer fallback en splash: $e');
    }
  }

  void _videoListener() {
    final controller = _videoPlayerController;
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.position >= controller.value.duration) {
        complete();
      }
    }
  }

  void skip() {
    complete();
  }

  void complete() {
    if (_isFinished) return;
    _isFinished = true;
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.pause();
    onFinished();
  }

  void dispose() {
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }
}
