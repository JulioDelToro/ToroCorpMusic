import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/tutorial_topic.dart';

/// Modal animado que muestra el tutorial y explicación de uso para una función específica
class FeatureHelpDialog extends StatelessWidget {
  final TutorialTopic topic;

  const FeatureHelpDialog({super.key, required this.topic});

  static Future<void> show(BuildContext context, TutorialTopic topic) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (context) => FeatureHelpDialog(topic: topic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(topic.icon, color: AppColors.chordAmber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    topic.title,
                    style: AppTypography.sfProHeadline(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topic.summary,
              style: AppTypography.sfProCaption(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderDark, height: 1),
            const SizedBox(height: 14),

            // Pasos enumerados
            ...List.generate(topic.instructions.length, (idx) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.cardDark,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: AppTypography.sfProCaption(fontSize: 11, color: AppColors.chordAmber),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topic.instructions[idx],
                        style: AppTypography.sfProCaption(fontSize: 13, color: AppColors.textWhite),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                  foregroundColor: AppColors.textWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
