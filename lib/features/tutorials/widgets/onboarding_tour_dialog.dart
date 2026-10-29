import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/tutorial_topic.dart';

/// Modal de bienvenida y recorrido inicial de funciones (Onboarding Tour)
class OnboardingTourDialog extends StatefulWidget {
  const OnboardingTourDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (context) => const OnboardingTourDialog(),
    );
  }

  @override
  State<OnboardingTourDialog> createState() => _OnboardingTourDialogState();
}

class _OnboardingTourDialogState extends State<OnboardingTourDialog> {
  int _currentStep = 0;

  final List<TutorialTopic> _tourTopics = [
    TutorialTopic.cameraAndDynamicIsland,
    TutorialTopic.palmGesture,
    TutorialTopic.metronome,
    TutorialTopic.tuner,
    TutorialTopic.vocalTracking,
    TutorialTopic.chordDictionary,
  ];

  @override
  Widget build(BuildContext context) {
    final topic = _tourTopics[_currentStep];
    final isLast = _currentStep == _tourTopics.length - 1;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height > 0 ? mediaQuery.size.height * 0.85 : 600.0;

    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: maxHeight,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Bienvenido a ToroCorp Music',
                      style: AppTypography.sfProHeadline(fontSize: 16, color: AppColors.chordAmber),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentStep + 1} de ${_tourTopics.length}',
                    style: AppTypography.sfProCaption(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Icon(topic.icon, color: AppColors.chordAmber, size: 48),
              const SizedBox(height: 12),
              Text(
                topic.title,
                style: AppTypography.sfProHeadline(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                topic.summary,
                style: AppTypography.sfProCaption(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Botones de navegación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    Flexible(
                      child: TextButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: Text(
                          'Anterior',
                          style: AppTypography.sfProCaption(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Omitir',
                          style: AppTypography.sfProCaption(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLast) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _currentStep++);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.chordAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isLast ? '¡Empezar a grabar!' : 'Siguiente',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
