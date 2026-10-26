import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/tuning_note.dart';

/// Widget visual para afinación de guitarra con indicador de aguja y tolerancia en cents.
class GuitarTunerWidget extends StatelessWidget {
  final TuningResult currentTuning;
  final bool isListening;

  const GuitarTunerWidget({
    super.key,
    required this.currentTuning,
    this.isListening = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = currentTuning.isInTune
        ? AppColors.tunerInTuneGreen
        : (currentTuning.centsOffset.abs() > 20 ? AppColors.tunerFlatRed : AppColors.chordAmber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTuning.isInTune ? AppColors.tunerInTuneGreen : AppColors.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nota Principal y Frecuencia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentTuning.closestNote,
                    style: AppTypography.sfProLyricStyle(fontSize: 24, color: statusColor),
                  ),
                ],
              ),
              Text(
                '${currentTuning.detectedFrequency.toStringAsFixed(1)} Hz',
                style: AppTypography.sfMonoChordStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Aguja de Afinación
          SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: _TunerNeedlePainter(
                centsOffset: currentTuning.centsOffset.clamp(-50.0, 50.0),
                statusColor: statusColor,
              ),
            ),
          ),

          // Escala de Cents (-50b ... 0 ... +50#)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('-50¢', style: AppTypography.sfProCaption(fontSize: 11)),
                Text(
                  currentTuning.isInTune ? 'AFINADO' : (currentTuning.centsOffset < 0 ? 'Bajo' : 'Alto'),
                  style: AppTypography.sfProCaption(
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
                Text('+50¢', style: AppTypography.sfProCaption(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TunerNeedlePainter extends CustomPainter {
  final double centsOffset; // -50.0 a +50.0
  final Color statusColor;

  _TunerNeedlePainter({required this.centsOffset, required this.statusColor});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final trackPaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Barra de fondo
    canvas.drawLine(Offset(10, size.height / 2), Offset(size.width - 10, size.height / 2), trackPaint);

    // Marca central (afinación objetivo)
    final centerMarkPaint = Paint()
      ..color = AppColors.tunerInTuneGreen
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(centerX, (size.height / 2) - 8),
      Offset(centerX, (size.height / 2) + 8),
      centerMarkPaint,
    );

    // Posición calculada de la aguja (-50 a +50 mapeado a los extremos)
    final needleX = centerX + (centsOffset / 50.0) * (centerX - 20);

    final needlePaint = Paint()
      ..color = statusColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(needleX, 4),
      Offset(needleX, size.height - 4),
      needlePaint,
    );

    // Círculo indicador
    canvas.drawCircle(Offset(needleX, size.height / 2), 5, Paint()..color = statusColor);
  }

  @override
  bool shouldRepaint(covariant _TunerNeedlePainter oldDelegate) =>
      oldDelegate.centsOffset != centsOffset || oldDelegate.statusColor != statusColor;
}
