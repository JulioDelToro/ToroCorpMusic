import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../controllers/splash_video_controller.dart';

/// Pantalla de bienvenida con reproducción de video intro a pantalla completa
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controller.skip,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player a pantalla completa
            if (videoCtrl != null && videoCtrl.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: videoCtrl.value.aspectRatio,
                  child: VideoPlayer(videoCtrl),
                ),
              )
            else
              const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
                  ),
                ),
              ),

            // Indicador sutil de omitir en la esquina inferior
            Positioned(
              bottom: 32,
              right: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    'Saltar',
                    style: AppTypography.sfProCaption(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
