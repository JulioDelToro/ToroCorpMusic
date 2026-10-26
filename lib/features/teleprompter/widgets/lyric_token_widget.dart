import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../chords/data/guitar_chords_database.dart';
import '../../chords/widgets/fretboard_diagram_dialog.dart';
import '../../scripts/models/lyric_token.dart';

/// Widget que renderiza una palabra en la parte superior y su acorde de apoyo en la parte inferior.
/// Al cantar o activarse, se ilumina en tiempo real en el color karaoke seleccionado por el usuario.
class LyricTokenWidget extends StatelessWidget {
  final LyricToken token;
  final bool isActive;
  final bool isPast;
  final double fontSize;
  final Color highlightColor;

  const LyricTokenWidget({
    super.key,
    required this.token,
    this.isActive = false,
    this.isPast = false,
    this.fontSize = 28.0,
    this.highlightColor = const Color(0xFFFFD60A),
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
        ? highlightColor
        : (isPast ? AppColors.textSecondary : AppColors.textWhite.withAlpha(210));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. FILA SUPERIOR: Letra cantada (Apple iOS SF Pro Bold con efecto iluminación karaoke)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? highlightColor.withAlpha(45) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? highlightColor.withAlpha(180) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppTypography.sfProLyricStyle(
                fontSize: fontSize,
                color: wordColor,
              ).copyWith(
                shadows: isActive
                    ? [
                        Shadow(
                          color: highlightColor.withAlpha(230),
                          blurRadius: 18,
                        ),
                        Shadow(
                          color: highlightColor,
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Text(token.word),
            ),
          ),

          const SizedBox(height: 3),

          // 2. FILA INFERIOR: Acorde o Nota de Apoyo (Apple iOS SF Mono)
          if (token.chordUnderneath != null)
            GestureDetector(
              onTap: () => _onChordTap(context, token.chordUnderneath!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? highlightColor.withAlpha(40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? highlightColor : AppColors.chordAmber.withAlpha(120),
                    width: 1,
                  ),
                ),
                child: Text(
                  token.chordUnderneath!,
                  style: AppTypography.sfMonoChordStyle(
                    fontSize: fontSize * 0.55,
                    color: isActive ? highlightColor : AppColors.chordAmber,
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
