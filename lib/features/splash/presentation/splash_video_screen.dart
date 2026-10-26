import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/splash_video_controller.dart';

/// Pantalla de bienvenida con reproducción de video intro en formato 9:16
/// sin botón de saltar: el usuario espera a que termine el video para acceder a la app.
class SplashVideoScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final String videoAsset;

  const SplashVideoScreen({
    super.key,
    required this.onFinished,
    this.videoAsset = 'assets/videos/intro_splash.mp4',
  });

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late final SplashVideoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SplashVideoController(
      onFinished: widget.onFinished,
      videoAsset: widget.videoAsset,
    );
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoCtrl = _controller.videoPlayerController;

    return Scaffold(
      backgroundColor: AppColors.pureBlackOled,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player en formato vertical 9:16 centrado
          if (videoCtrl != null && videoCtrl.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoCtrl.value.size.width,
                    height: videoCtrl.value.size.height,
                    child: VideoPlayer(videoCtrl),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
