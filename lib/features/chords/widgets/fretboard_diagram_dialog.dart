import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/chord_definition.dart';

/// Modal flotante que dibuja el diapasón de la guitarra con la posición de los dedos para un acorde.
class FretboardDiagramDialog extends StatelessWidget {
  final ChordDefinition chord;

  const FretboardDiagramDialog({super.key, required this.chord});

  static Future<void> show(BuildContext context, ChordDefinition chord) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (context) => FretboardDiagramDialog(chord: chord),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Acorde: ${chord.name}',
              style: AppTypography.sfProHeadline(fontSize: 22),
            ),
            if (chord.baseFret > 1) ...[
              const SizedBox(height: 4),
              Text(
                'Traste base: ${chord.baseFret}',
                style: AppTypography.sfProCaption(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              height: 220,
              child: CustomPaint(
                painter: _FretboardPainter(chord: chord),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textWhite,
                backgroundColor: AppColors.cardDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  final ChordDefinition chord;

  _FretboardPainter({required this.chord});

  @override
  void paint(Canvas canvas, Size size) {
    const int numFrets = 4;
    const int numStrings = 6;
    final double stringSpacing = size.width / (numStrings - 1);
    final double fretSpacing = (size.height - 30) / numFrets;

    final linePaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 1.5;

    final nutPaint = Paint()
      ..color = AppColors.textWhite
      ..strokeWidth = chord.baseFret == 1 ? 4.0 : 1.5;

    final dotPaint = Paint()
      ..color = AppColors.chordAmber
      ..style = PaintingStyle.fill;

    const double topOffset = 30;

    // Cejuela superior o primer traste
    canvas.drawLine(
      const Offset(0, topOffset),
      Offset(size.width, topOffset),
      nutPaint,
    );

    // Trastes horizontales
    for (int f = 1; f <= numFrets; f++) {
      final y = topOffset + f * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Cuerdas verticales (6 cuerdas)
    for (int s = 0; s < numStrings; s++) {
      final x = s * stringSpacing;
      canvas.drawLine(Offset(x, topOffset), Offset(x, topOffset + numFrets * fretSpacing), linePaint);
    }

    // Indicadores superiores (X / O) y puntos en los trastes
    for (int s = 0; s < numStrings; s++) {
      final x = s * stringSpacing;
      final fret = chord.frets[s];
      final finger = chord.fingers[s];

      if (fret == -1) {
        // Cuerda muteada (X)
        _drawCenteredText(canvas, '✕', Offset(x, 10), Colors.redAccent, 14);
      } else if (fret == 0) {
        // Cuerda al aire (O)
        _drawCenteredText(canvas, '○', Offset(x, 10), AppColors.textSecondary, 14);
      } else {
        // Dedo en traste
        final displayFret = fret - (chord.baseFret - 1);
        if (displayFret >= 1 && displayFret <= numFrets) {
          final y = topOffset + (displayFret - 0.5) * fretSpacing;
          canvas.drawCircle(Offset(x, y), 10, dotPaint);

          if (finger > 0) {
            _drawCenteredText(canvas, '$finger', Offset(x, y), Colors.black, 12, isBold: true);
          }
        }
      }
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize, {
    bool isBold = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter oldDelegate) => oldDelegate.chord != chord;
}
