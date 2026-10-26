import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../services/beauty_shader_service.dart';
import '../services/hands_free_trigger_service.dart';

/// Visor de la cámara con soporte para filtro de belleza, modo espejo y cuenta regresiva manos libres
class CameraViewfinderWidget extends StatelessWidget {
  final Widget? cameraPreview;
  final BeautyShaderService beautyService;
  final HandsFreeTriggerService triggerService;
  final bool isRecording;
  final bool showBeautySlider;
  final bool isMirrorMode;

  const CameraViewfinderWidget({
    super.key,
    this.cameraPreview,
    required this.beautyService,
    required this.triggerService,
    this.isRecording = false,
    this.showBeautySlider = false,
    this.isMirrorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pureBlackOled,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Previsualización de la cámara (con soporte para modo espejo)
          cameraPreview != null
              ? (isMirrorMode
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: cameraPreview!,
                    )
                  : cameraPreview!)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_outlined, size: 48, color: AppColors.borderDark),
                      const SizedBox(height: 8),
                      Text(
                        'Visor de Cámara ToroCorp Music',
                        style: AppTypography.sfProCaption(),
                      ),
                    ],
                  ),
                ),

          // Control deslizante de filtro de belleza (aparece cuando se activa en el menú)
          if (showBeautySlider)
            Positioned(
              right: 16,
              top: 140,
              child: AnimatedBuilder(
                animation: beautyService,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(210),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_fix_high, color: AppColors.chordAmber, size: 20),
                        const SizedBox(height: 8),
                        RotatedBox(
                          quarterTurns: 3,
                          child: SizedBox(
                            width: 130,
                            child: Slider(
                              value: beautyService.intensity,
                              min: 0.0,
                              max: 1.0,
                              activeColor: AppColors.chordAmber,
                              inactiveColor: AppColors.borderDark,
                              onChanged: beautyService.setIntensity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(beautyService.intensity * 100).toInt()}%',
                          style: AppTypography.sfProCaption(fontSize: 11, color: AppColors.textWhite),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Animación de cuenta regresiva manos libres (3... 2... 1...)
          if (triggerService.isCountingDown)
            Container(
              color: Colors.black.withAlpha(190),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${triggerService.countdownSeconds}',
                      style: AppTypography.sfProLyricStyle(fontSize: 96, color: AppColors.textWhite),
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

          // Indicador de estado de grabación
          if (isRecording)
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.recordRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'REC',
                        style: AppTypography.sfProCaption(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
