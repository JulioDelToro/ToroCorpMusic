import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../services/beauty_shader_service.dart';
import '../services/hands_free_trigger_service.dart';

/// Visor de la cámara con relación de aspecto nativa (9:16, 16:9, 1:1, 4:5),
/// sin estiramiento de imagen, soporte para modo espejo y cuenta regresiva manos libres.
class CameraViewfinderWidget extends StatelessWidget {
  final Widget? cameraPreview;
  final BeautyShaderService beautyService;
  final HandsFreeTriggerService triggerService;
  final bool isRecording;
  final bool showBeautySlider;
  final bool isMirrorMode;
  final double aspectRatio;

  const CameraViewfinderWidget({
    super.key,
    this.cameraPreview,
    required this.beautyService,
    required this.triggerService,
    this.isRecording = false,
    this.showBeautySlider = false,
    this.isMirrorMode = false,
    this.aspectRatio = 9 / 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pureBlackOled,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Previsualización de la cámara con encuadre nativo y sin distorsión
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRect(
                child: cameraPreview != null
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
                        color: const Color(0xFF0A0A0C),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_outlined, size: 54, color: AppColors.borderDark),
                              const SizedBox(height: 12),
                              Text(
                                'Visor ToroCorp Music',
                                style: AppTypography.sfProHeadline(fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Formato: ${_getFormatName(aspectRatio)}',
                                style: AppTypography.sfProCaption(),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Control deslizante de filtro de belleza
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
                      color: Colors.black.withAlpha(220),
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

          // Botón accesible de prueba rápida de Manos Libres
          Positioned(
            left: 16,
            bottom: 120,
            child: GestureDetector(
              onTap: () {
                triggerService.triggerFromPalmGesture();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.front_hand, size: 16, color: AppColors.chordAmber),
                    const SizedBox(width: 6),
                    Text(
                      'Disparador Palma / Voz',
                      style: AppTypography.sfProCaption(fontSize: 11, color: AppColors.textWhite),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Animación de cuenta regresiva manos libres (3... 2... 1...)
          if (triggerService.isCountingDown)
            Container(
              color: Colors.black.withAlpha(200),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${triggerService.countdownSeconds}',
                      style: AppTypography.sfProLyricStyle(fontSize: 108, color: AppColors.textWhite),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.recordRed,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'GRABANDO',
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

  String _getFormatName(double ratio) {
    if ((ratio - (9 / 16)).abs() < 0.05) return '9:16 Vertical';
    if ((ratio - (16 / 9)).abs() < 0.05) return '16:9 Horizontal';
    if ((ratio - 1.0).abs() < 0.05) return '1:1 Cuadrado';
    if ((ratio - 0.8).abs() < 0.05) return '4:5 Retrato';
    return '${ratio.toStringAsFixed(2)} Aspecto';
  }
}
