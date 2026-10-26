import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../services/beauty_shader_service.dart';
import '../services/hands_free_trigger_service.dart';

/// Visor de la cámara limpio y minimalista con relación de aspecto nativa (9:16, 16:9, 1:1, 4:5),
/// sin estiramiento de imagen, soporte para modo espejo y pantalla limpia sin botones invasivos.
class CameraViewfinderWidget extends StatelessWidget {
  final Widget? cameraPreview;
  final BeautyShaderService beautyService;
  final HandsFreeTriggerService triggerService;
  final bool isRecording;
  final bool isMirrorMode;
  final double aspectRatio;
  final bool isCameraActive;

  const CameraViewfinderWidget({
    super.key,
    this.cameraPreview,
    required this.beautyService,
    required this.triggerService,
    this.isRecording = false,
    this.isMirrorMode = false,
    this.aspectRatio = 9 / 16,
    this.isCameraActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pureBlackOled,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Previsualización de la cámara con encuadre nativo y sin distorsión
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRect(
                child: isCameraActive && cameraPreview != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: aspectRatio > 1.0 ? 1920 : 1080,
                          height: aspectRatio > 1.0 ? 1080 : 1920,
                          child: isMirrorMode
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(math.pi),
                                  child: cameraPreview!,
                                )
                              : cameraPreview!,
                        ),
                      )
                    : Container(
                        color: const Color(0xFF070709),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.borderDark, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.chordAmber.withAlpha(40),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  size: 38,
                                  color: AppColors.chordAmber,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isCameraActive ? 'Conectando Cámara...' : 'Modo Solo Karaoke / Audio',
                                style: AppTypography.sfProHeadline(fontSize: 16, color: AppColors.textWhite),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'El micrófono sigue tu voz en tiempo real',
                                style: AppTypography.sfProCaption(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // 2. Animación de cuenta regresiva manos libres (3... 2... 1...)
          if (triggerService.isCountingDown)
            Container(
              color: Colors.black.withAlpha(220),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${triggerService.countdownSeconds}',
                      style: AppTypography.sfProLyricStyle(fontSize: 110, color: AppColors.textWhite),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¡ToroCorp Music: Prepárate con tu guitarra!',
                      style: AppTypography.sfProHeadline(color: AppColors.chordAmber),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
