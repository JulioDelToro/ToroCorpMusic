import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../chords/data/guitar_chords_database.dart';
import '../../chords/widgets/fretboard_diagram_dialog.dart';
import '../../scripts/models/lyric_token.dart';

/// Widget que renderiza una palabra en la parte superior y su acorde de apoyo en la parte inferior.
/// Al tocar el acorde inferior, abre el diagrama interactivo de digitación en el diapasón.
class LyricTokenWidget extends StatelessWidget {
  final LyricToken token;
  final bool isActive;
  final bool isPast;
  final double fontSize;

  const LyricTokenWidget({
    super.key,
    required this.token,
    this.isActive = false,
    this.isPast = false,
    this.fontSize = 28.0,
  });

  void _onChordTap(BuildContext context, String chordName) {
    final db = GuitarChordsDatabase();
    final chordDef = db.getChord(chordName);
    if (chordDef != null) {
      FretboardDiagramDialog.show(context, chordDef);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordColor = isActive
        ? AppColors.textWhite
        : (isPast ? AppColors.textSecondary : AppColors.textWhite.withAlpha(200));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. FILA SUPERIOR: Letra cantada (Apple iOS SF Pro Bold)
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTypography.sfProLyricStyle(
              fontSize: fontSize,
              color: wordColor,
            ).copyWith(
              shadows: isActive
                  ? [
                      Shadow(
                        color: AppColors.chordAmber.withAlpha(220),
                        blurRadius: 16,
                      ),
                      const Shadow(
                        color: Colors.white,
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Text(token.word),
          ),

          const SizedBox(height: 3),

          // 2. FILA INFERIOR: Acorde o Nota de Apoyo (Apple iOS SF Mono)
          if (token.chordUnderneath != null)
            GestureDetector(
              onTap: () => _onChordTap(context, token.chordUnderneath!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.chordAmber.withAlpha(60) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? AppColors.chordAmber : AppColors.chordAmber.withAlpha(120),
                    width: 1,
                  ),
                ),
                child: Text(
                  token.chordUnderneath!,
                  style: AppTypography.sfMonoChordStyle(
                    fontSize: fontSize * 0.55,
                    color: AppColors.chordAmber,
                  ),
                ),
              ),
            )
          else
            SizedBox(height: fontSize * 0.55 + 6), // Mantiene la alineación vertical uniforme
        ],
      ),
    );
  }
}
