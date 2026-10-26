import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// Widget de marca de agua discreta para exportaciones de la versión gratuita.
class WatermarkOverlayWidget extends StatelessWidget {
  final String text;

  const WatermarkOverlayWidget({
    super.key,
    this.text = 'Toro Music',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 14, color: AppColors.chordAmber),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.sfProCaption(
              fontSize: 11,
              color: AppColors.textWhite.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}
