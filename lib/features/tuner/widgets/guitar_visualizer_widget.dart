import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/tuning_note.dart';
import '../services/pitch_detector.dart';

/// Componente visual interactivo de Guitarra (Pala, Clavijero, Diapasón y Pastillas)
/// Diseñado para 6 Cuerdas (Estándar) y 12 Cuerdas (Docerola).
///
/// Características visuales:
/// - Pala y mástil de guitarra detallados con trastes, cejuela de hueso e incrustaciones.
/// - Cuerdas metálicas con calibres graduados (cuerdas graves más gruesas, pares en docerola).
/// - Pastillas/Clavijas interactivas a los lados:
///   * Al seleccionar o tocar una pastilla, se ilumina en color en la pastilla y en la cuerda de la guitarra.
///   * Color Verde Neón (#30D158) cuando está perfectamente afinada.
///   * Color Ámbar/Naranja cuando está grave (apretar).
///   * Color Rojo cuando está aguda (aflojar).
///   * Color Oro/Cian cuando está seleccionada esperando nota.
class GuitarVisualizerWidget extends StatelessWidget {
  final GuitarType guitarType;
  final int? lockedStringIndex;
  final int? detectedStringIndex;
  final TuningResult currentResult;
  final ValueChanged<int?> onSelectString;

  const GuitarVisualizerWidget({
    super.key,
    required this.guitarType,
    required this.lockedStringIndex,
    required this.detectedStringIndex,
    required this.currentResult,
    required this.onSelectString,
  });

  @override
  Widget build(BuildContext context) {
    final notes = guitarType == GuitarType.sixString
        ? PitchDetector.standard6StringTuning
        : PitchDetector.standard12StringTuning;

    final int? activeIndex = lockedStringIndex ??
        (currentResult.detectedFrequency > 0 ? currentResult.targetStringIndex : null);

    // Color del estado de afinación para la pastilla y cuerda activa
    final Color activeColor = _getActiveColor(currentResult, activeIndex != null);

    // Separar notas en lado izquierdo y derecho de la guitarra
    final List<ReferenceNote> leftNotes;
    final List<ReferenceNote> rightNotes;

    if (guitarType == GuitarType.sixString) {
      // 6 Cuerdas:
      // Lado Izquierdo (Graves): 6ª E2, 5ª A2, 4ª D3
      // Lado Derecho (Agudas): 3ª G3, 2ª B3, 1ª E4
      leftNotes = [
        notes.firstWhere((n) => n.stringIndex == 6),
        notes.firstWhere((n) => n.stringIndex == 5),
        notes.firstWhere((n) => n.stringIndex == 4),
      ];
      rightNotes = [
        notes.firstWhere((n) => n.stringIndex == 3),
        notes.firstWhere((n) => n.stringIndex == 2),
        notes.firstWhere((n) => n.stringIndex == 1),
      ];
    } else {
      // 12 Cuerdas (Docerola):
      // Lado Izquierdo: pares 6, 5, 4 (cuerdas 12, 11, 10, 9, 8, 7)
      // Lado Derecho: pares 3, 2, 1 (cuerdas 6, 5, 4, 3, 2, 1)
      leftNotes = [
        notes.firstWhere((n) => n.stringIndex == 12),
        notes.firstWhere((n) => n.stringIndex == 11),
        notes.firstWhere((n) => n.stringIndex == 10),
        notes.firstWhere((n) => n.stringIndex == 9),
        notes.firstWhere((n) => n.stringIndex == 8),
        notes.firstWhere((n) => n.stringIndex == 7),
      ];
      rightNotes = [
        notes.firstWhere((n) => n.stringIndex == 6),
        notes.firstWhere((n) => n.stringIndex == 5),
        notes.firstWhere((n) => n.stringIndex == 4),
        notes.firstWhere((n) => n.stringIndex == 3),
        notes.firstWhere((n) => n.stringIndex == 2),
        notes.firstWhere((n) => n.stringIndex == 1),
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withAlpha(230),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.borderDark, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra Superior de Modo y Estado ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: activeIndex != null ? activeColor : AppColors.chordAmber,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lockedStringIndex != null
                        ? 'Cuerda Fija: $lockedStringIndexª ${_getNoteName(notes, lockedStringIndex!)}'
                        : (activeIndex != null
                            ? 'Detectada: $activeIndexª ${_getNoteName(notes, activeIndex)}'
                            : 'Modo Automático: Toca una cuerda'),
                    style: TextStyle(
                      color: activeIndex != null ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelectString(null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lockedStringIndex == null
                        ? AppColors.chordAmber
                        : Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: lockedStringIndex == null
                          ? AppColors.chordAmber
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Automático',
                    style: TextStyle(
                      color: lockedStringIndex == null ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Cuerpo Visual de la Guitarra con Pastillas Laterales ──
          SizedBox(
            height: guitarType == GuitarType.sixString ? 200 : 250,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna de Pastillas Izquierdas (Graves)
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: leftNotes.map((note) {
                      final isSelected = activeIndex == note.stringIndex;
                      return _buildPastillaButton(
                        note: note,
                        isSelected: isSelected,
                        activeColor: activeColor,
                        isLeft: true,
                        onTap: () => onSelectString(
                          lockedStringIndex == note.stringIndex ? null : note.stringIndex,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 6),

                // Centro: Pala, Cejuela, Diapasón y Cuerdas
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: CustomPaint(
                        painter: _GuitarHeadstockPainter(
                          guitarType: guitarType,
                          activeStringIndex: activeIndex,
                          activeColor: activeColor,
                          isSounding: currentResult.detectedFrequency > 0,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Columna de Pastillas Derechas (Agudas)
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rightNotes.map((note) {
                      final isSelected = activeIndex == note.stringIndex;
                      return _buildPastillaButton(
                        note: note,
                        isSelected: isSelected,
                        activeColor: activeColor,
                        isLeft: false,
                        onTap: () => onSelectString(
                          lockedStringIndex == note.stringIndex ? null : note.stringIndex,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastillaButton({
    required ReferenceNote note,
    required bool isSelected,
    required Color activeColor,
    required bool isLeft,
    required VoidCallback onTap,
  }) {
    final isInTune = isSelected && currentResult.isInTune && currentResult.detectedFrequency > 0;
    final isFlat = isSelected && currentResult.centsOffset < -3.5 && currentResult.detectedFrequency > 0;
    final isSharp = isSelected && currentResult.centsOffset > 3.5 && currentResult.detectedFrequency > 0;

    final Color borderColor = isSelected ? activeColor : Colors.white.withAlpha(25);
    final Color bgColor = isSelected ? activeColor.withAlpha(45) : Colors.black.withAlpha(120);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(140),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLeft && isSelected) ...[
              _buildStatusIcon(isInTune, isFlat, isSharp, activeColor),
              const SizedBox(width: 3),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  note.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: guitarType == GuitarType.sixString ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${note.stringIndex}ª',
                  style: TextStyle(
                    color: isSelected ? activeColor : AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (isLeft && isSelected) ...[
              const SizedBox(width: 3),
              _buildStatusIcon(isInTune, isFlat, isSharp, activeColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool inTune, bool isFlat, bool isSharp, Color color) {
    if (inTune) {
      return Icon(Icons.check_circle, color: color, size: 12);
    }
    if (isFlat) {
      return Icon(Icons.arrow_drop_up, color: color, size: 14);
    }
    if (isSharp) {
      return Icon(Icons.arrow_drop_down, color: color, size: 14);
    }
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _getNoteName(List<ReferenceNote> notes, int stringIdx) {
    final note = notes.firstWhere(
      (n) => n.stringIndex == stringIdx,
      orElse: () => notes.first,
    );
    return '(${note.name})';
  }

  Color _getActiveColor(TuningResult result, bool hasActive) {
    if (!hasActive) return AppColors.chordAmber;
    if (result.detectedFrequency <= 0) return AppColors.chordAmber;
    if (result.isInTune) return AppColors.tunerInTuneGreen;
    if (result.centsOffset < -3.5) return const Color(0xFFFF9F0A); // Grave (apretar)
    return const Color(0xFFFF453A); // Aguda (aflojar)
  }
}

/// Pintor que dibuja la pala de la guitarra, la cejuela de hueso, el diapasón y las cuerdas.
class _GuitarHeadstockPainter extends CustomPainter {
  final GuitarType guitarType;
  final int? activeStringIndex;
  final Color activeColor;
  final bool isSounding;

  _GuitarHeadstockPainter({
    required this.guitarType,
    required this.activeStringIndex,
    required this.activeColor,
    required this.isSounding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Fondo de Pala de Guitarra (Madera Ébano / Palisandro) ──
    final headstockPath = Path();
    final topY = h * 0.05;
    final nutY = h * 0.62;

    // Silueta acústica elegante de la pala
    headstockPath.moveTo(w * 0.22, nutY);
    headstockPath.lineTo(w * 0.16, topY + (h * 0.10));
    // Corona curva superior
    headstockPath.quadraticBezierTo(w * 0.18, topY, w * 0.50, topY + (h * 0.04));
    headstockPath.quadraticBezierTo(w * 0.82, topY, w * 0.84, topY + (h * 0.10));
    headstockPath.lineTo(w * 0.78, nutY);
    headstockPath.close();

    final woodGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF261D17),
        Color(0xFF140F0C),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final woodPaint = Paint()
      ..shader = woodGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(headstockPath, woodPaint);

    // Borde biselado dorado de la pala
    final borderPaint = Paint()
      ..color = const Color(0xFFFFB800).withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(headstockPath, borderPaint);

    // Emblema central ToroCorp (Diamante de madreperla)
    final emblemPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.fill;
    final diamondPath = Path();
    final dX = w * 0.50;
    final dY = topY + (h * 0.12);
    diamondPath.moveTo(dX, dY - 6);
    diamondPath.lineTo(dX + 5, dY);
    diamondPath.lineTo(dX, dY + 6);
    diamondPath.lineTo(dX - 5, dY);
    diamondPath.close();
    canvas.drawPath(diamondPath, emblemPaint);

    // ── 2. Cejuela de Hueso (Nut) ──
    final nutRect = Rect.fromLTWH(w * 0.20, nutY, w * 0.60, h * 0.04);
    final nutPaint = Paint()..color = const Color(0xFFF0EBE0);
    canvas.drawRRect(RRect.fromRectAndRadius(nutRect, const Radius.circular(2)), nutPaint);

    // ── 3. Diapasón (Mástil inferior con trastes) ──
    final fretboardRect = Rect.fromLTWH(w * 0.21, nutY + (h * 0.04), w * 0.58, h - (nutY + (h * 0.04)));
    final fretboardPaint = Paint()..color = const Color(0xFF161210);
    canvas.drawRect(fretboardRect, fretboardPaint);

    // Trastes metálicos (Frets)
    final fretPaint = Paint()
      ..color = const Color(0xFF8E8E93)
      ..strokeWidth = 1.2;
    final fretY1 = nutY + (h * 0.14);
    final fretY2 = nutY + (h * 0.24);
    canvas.drawLine(Offset(w * 0.21, fretY1), Offset(w * 0.79, fretY1), fretPaint);
    canvas.drawLine(Offset(w * 0.21, fretY2), Offset(w * 0.79, fretY2), fretPaint);

    // Marcador de posición (punto perlado en traste)
    final dotPaint = Paint()..color = Colors.white.withAlpha(120);
    canvas.drawCircle(Offset(w * 0.50, (fretY1 + fretY2) / 2), 2.5, dotPaint);

    // ── 4. Cuerdas Metálicas (Strings) ──
    if (guitarType == GuitarType.sixString) {
      _paintSixStrings(canvas, size, nutY);
    } else {
      _paintTwelveStrings(canvas, size, nutY);
    }
  }

  void _paintSixStrings(Canvas canvas, Size size, double nutY) {
    final w = size.width;
    final h = size.height;

    // Cuerdas 6 a 1 ordenadas de izquierda a derecha en el mástil:
    // 6ª E2 (izquierda), 5ª A2, 4ª D3, 3ª G3, 2ª B3, 1ª E4 (derecha)
    final stringIndices = [6, 5, 4, 3, 2, 1];
    final stringGauges = [2.8, 2.4, 2.0, 1.6, 1.3, 1.0]; // Calibres reales

    final startX = w * 0.25;
    final endX = w * 0.75;
    final spacing = (endX - startX) / 5;

    for (int i = 0; i < stringIndices.length; i++) {
      final sIdx = stringIndices[i];
      final x = startX + (i * spacing);
      final gauge = stringGauges[i];
      final isActive = activeStringIndex == sIdx;

      _drawStringLine(
        canvas: canvas,
        x: x,
        topY: h * 0.18 + (i % 3) * (h * 0.12),
        bottomY: h,
        gauge: gauge,
        isActive: isActive,
      );
    }
  }

  void _paintTwelveStrings(Canvas canvas, Size size, double nutY) {
    final w = size.width;
    final h = size.height;

    // 12 cuerdas agrupadas en 6 pares:
    // Par 6 (11 y 12), Par 5 (9 y 10), Par 4 (7 y 8), Par 3 (5 y 6), Par 2 (3 y 4), Par 1 (1 y 2)
    final pairs = [
      [11, 12],
      [9, 10],
      [7, 8],
      [5, 6],
      [3, 4],
      [1, 2],
    ];

    final startX = w * 0.24;
    final endX = w * 0.76;
    final pairSpacing = (endX - startX) / 5;

    for (int p = 0; p < pairs.length; p++) {
      final pair = pairs[p];
      final centerX = startX + (p * pairSpacing);

      // Cada par tiene dos cuerdas muy juntas
      final x1 = centerX - 2.0;
      final x2 = centerX + 2.0;

      final isFirstActive = activeStringIndex == pair[0];
      final isSecondActive = activeStringIndex == pair[1];

      _drawStringLine(
        canvas: canvas,
        x: x1,
        topY: h * 0.16 + (p % 3) * (h * 0.10),
        bottomY: h,
        gauge: p < 3 ? 1.8 : 1.2,
        isActive: isFirstActive,
      );

      _drawStringLine(
        canvas: canvas,
        x: x2,
        topY: h * 0.18 + (p % 3) * (h * 0.10),
        bottomY: h,
        gauge: p < 2 ? 1.0 : 1.2,
        isActive: isSecondActive,
      );
    }
  }

  void _drawStringLine({
    required Canvas canvas,
    required double x,
    required double topY,
    required double bottomY,
    required double gauge,
    required bool isActive,
  }) {
    if (isActive) {
      // Brillo resplandeciente exterior de la cuerda seleccionada
      final glowPaint = Paint()
        ..color = activeColor.withAlpha(180)
        ..strokeWidth = gauge + 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), glowPaint);

      // Cuerda principal en el color activo de la pastilla
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = gauge + 0.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), activePaint);

      // Núcleo blanco brillante si está sonando
      if (isSounding) {
        final corePaint = Paint()
          ..color = Colors.white.withAlpha(220)
          ..strokeWidth = math.max(0.8, gauge * 0.6)
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x, topY), Offset(x, bottomY), corePaint);
      }
    } else {
      // Cuerda metálica normal (Níquel / Fósforo Bronce sutil)
      final normalPaint = Paint()
        ..color = Colors.white.withAlpha(70)
        ..strokeWidth = gauge
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), normalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuitarHeadstockPainter oldDelegate) {
    return oldDelegate.guitarType != guitarType ||
        oldDelegate.activeStringIndex != activeStringIndex ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isSounding != isSounding;
  }
}
