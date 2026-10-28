import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/tuning_note.dart';

/// Modelo de botón circular de cuerda (Pastilla / Clavija)
class StringButtonConfig {
  final int stringIndex;
  final String noteLetter; // Ej: 'D', 'A', 'E', 'G', 'B'
  final String fullName; // Ej: 'D3', 'A2', 'E2'
  final bool isLeft;
  final int verticalOrder; // 0 (arriba) a 2 o 5 (abajo)

  const StringButtonConfig({
    required this.stringIndex,
    required this.noteLetter,
    required this.fullName,
    required this.isLeft,
    required this.verticalOrder,
  });
}

/// Componente visual de afinador estilo GuitarTuna para 6 y 12 cuerdas.
/// 100% código propio vectorial en Flutter, comercialmente vendible y sin dependencias de terceros.
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

  Color _getActiveColor(TuningResult result, bool isSelected) {
    if (!isSelected) return AppColors.tunerInTuneGreen;
    if (result.detectedFrequency <= 0) return const Color(0xFF00D084);
    if (result.isInTune) return const Color(0xFF00D084); // Verde GuitarTuna
    if (result.centsOffset < -3.5) return const Color(0xFFFF9F0A); // Grave (apretar)
    return const Color(0xFFFF453A); // Aguda (aflojar)
  }

  List<StringButtonConfig> _getButtonsConfig() {
    if (guitarType == GuitarType.sixString) {
      // 6 Cuerdas:
      // Izquierda (arriba hacia abajo): 4ª D, 5ª A, 6ª E
      // Derecha (arriba hacia abajo): 3ª G, 2ª B, 1ª E
      return const [
        StringButtonConfig(stringIndex: 4, noteLetter: 'D', fullName: 'D3', isLeft: true, verticalOrder: 0),
        StringButtonConfig(stringIndex: 5, noteLetter: 'A', fullName: 'A2', isLeft: true, verticalOrder: 1),
        StringButtonConfig(stringIndex: 6, noteLetter: 'E', fullName: 'E2', isLeft: true, verticalOrder: 2),
        StringButtonConfig(stringIndex: 3, noteLetter: 'G', fullName: 'G3', isLeft: false, verticalOrder: 0),
        StringButtonConfig(stringIndex: 2, noteLetter: 'B', fullName: 'B3', isLeft: false, verticalOrder: 1),
        StringButtonConfig(stringIndex: 1, noteLetter: 'E', fullName: 'E4', isLeft: false, verticalOrder: 2),
      ];
    } else {
      // 12 Cuerdas (Docerola):
      // Izquierda (arriba hacia abajo): pares D, A, E (cuerdas 8, 7, 10, 9, 12, 11)
      // Derecha (arriba hacia abajo): pares G, B, E (cuerdas 6, 5, 4, 3, 2, 1)
      return const [
        StringButtonConfig(stringIndex: 8, noteLetter: 'D', fullName: 'D4', isLeft: true, verticalOrder: 0),
        StringButtonConfig(stringIndex: 7, noteLetter: 'D', fullName: 'D3', isLeft: true, verticalOrder: 1),
        StringButtonConfig(stringIndex: 10, noteLetter: 'A', fullName: 'A3', isLeft: true, verticalOrder: 2),
        StringButtonConfig(stringIndex: 9, noteLetter: 'A', fullName: 'A2', isLeft: true, verticalOrder: 3),
        StringButtonConfig(stringIndex: 12, noteLetter: 'E', fullName: 'E3', isLeft: true, verticalOrder: 4),
        StringButtonConfig(stringIndex: 11, noteLetter: 'E', fullName: 'E2', isLeft: true, verticalOrder: 5),
        StringButtonConfig(stringIndex: 6, noteLetter: 'G', fullName: 'G4', isLeft: false, verticalOrder: 0),
        StringButtonConfig(stringIndex: 5, noteLetter: 'G', fullName: 'G3', isLeft: false, verticalOrder: 1),
        StringButtonConfig(stringIndex: 4, noteLetter: 'B', fullName: 'B3', isLeft: false, verticalOrder: 2),
        StringButtonConfig(stringIndex: 3, noteLetter: 'B', fullName: 'B3', isLeft: false, verticalOrder: 3),
        StringButtonConfig(stringIndex: 2, noteLetter: 'E', fullName: 'E4', isLeft: false, verticalOrder: 4),
        StringButtonConfig(stringIndex: 1, noteLetter: 'E', fullName: 'E4', isLeft: false, verticalOrder: 5),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? activeIndex = lockedStringIndex ??
        (currentResult.detectedFrequency > 0 ? currentResult.targetStringIndex : null);

    final Color activeColor = _getActiveColor(currentResult, activeIndex != null);
    final allConfigs = _getButtonsConfig();
    final leftConfigs = allConfigs.where((c) => c.isLeft).toList()
      ..sort((a, b) => a.verticalOrder.compareTo(b.verticalOrder));
    final rightConfigs = allConfigs.where((c) => !c.isLeft).toList()
      ..sort((a, b) => a.verticalOrder.compareTo(b.verticalOrder));

    final is12 = guitarType == GuitarType.twelveString;
    final double buttonSize = is12 ? 34.0 : 44.0;
    final double fontSize = is12 ? 13.0 : 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 1. Pala y Mástil de Guitarra Central ──
            Positioned.fill(
              child: CustomPaint(
                painter: _RealisticGuitarHeadstockPainter(
                  guitarType: guitarType,
                  activeStringIndex: activeIndex,
                  activeColor: activeColor,
                  isSounding: currentResult.detectedFrequency > 0,
                ),
              ),
            ),

            // ── 2. Botones Circulares Izquierdos (Pastillas de Cuerdas) ──
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              width: buttonSize + 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: leftConfigs.map((config) {
                  final bool isSelected = activeIndex == config.stringIndex;
                  return _buildPastillaCircle(
                    config: config,
                    isSelected: isSelected,
                    activeColor: activeColor,
                    buttonSize: buttonSize,
                    fontSize: fontSize,
                  );
                }).toList(),
              ),
            ),

            // ── 3. Botones Circulares Derechos (Pastillas de Cuerdas) ──
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              width: buttonSize + 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rightConfigs.map((config) {
                  final bool isSelected = activeIndex == config.stringIndex;
                  return _buildPastillaCircle(
                    config: config,
                    isSelected: isSelected,
                    activeColor: activeColor,
                    buttonSize: buttonSize,
                    fontSize: fontSize,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPastillaCircle({
    required StringButtonConfig config,
    required bool isSelected,
    required Color activeColor,
    required double buttonSize,
    required double fontSize,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (lockedStringIndex == config.stringIndex) {
          onSelectString(null); // Deseleccionar y regresar a Automático
        } else {
          onSelectString(config.stringIndex);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? activeColor
              : const Color(0xFF22262B).withAlpha(220),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF38404A),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(200),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            config.noteLetter,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pintor fotorrealista que dibuja la pala de guitarra acústica / docerola estilo GuitarTuna.
/// Todo con primitivas de Canvas (curvas de Bézier, sombreados, clavijas de cromo, cejuela y cuerdas).
class _RealisticGuitarHeadstockPainter extends CustomPainter {
  final GuitarType guitarType;
  final int? activeStringIndex;
  final Color activeColor;
  final bool isSounding;

  _RealisticGuitarHeadstockPainter({
    required this.guitarType,
    required this.activeStringIndex,
    required this.activeColor,
    required this.isSounding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final is12 = guitarType == GuitarType.twelveString;

    // Coordenadas verticales de referencia
    final topY = h * 0.04;
    final nutY = is12 ? h * 0.82 : h * 0.74;
    final fretboardBottomY = h;

    // Ancho de la pala
    final leftNutX = w * (is12 ? 0.32 : 0.30);
    final rightNutX = w * (is12 ? 0.68 : 0.70);
    final leftTopX = w * (is12 ? 0.26 : 0.22);
    final rightTopX = w * (is12 ? 0.74 : 0.78);

    // ── 1. Silueta de la Pala de Guitarra ──
    final headstockPath = Path();
    headstockPath.moveTo(leftNutX, nutY);
    headstockPath.lineTo(leftTopX, topY + (h * (is12 ? 0.08 : 0.12)));

    // Corona superior clásica acústica (arcos suaves inspirados en guitarras acústicas finas)
    if (is12) {
      headstockPath.quadraticBezierTo(w * 0.28, topY, w * 0.50, topY + (h * 0.03));
      headstockPath.quadraticBezierTo(w * 0.72, topY, rightTopX, topY + (h * 0.08));
    } else {
      // 6 cuerdas: Corona con 3 suaves crestas como en la foto de GuitarTuna
      headstockPath.quadraticBezierTo(w * 0.24, topY + 4, w * 0.36, topY + (h * 0.04));
      headstockPath.quadraticBezierTo(w * 0.50, topY - 2, w * 0.64, topY + (h * 0.04));
      headstockPath.quadraticBezierTo(w * 0.76, topY + 4, rightTopX, topY + (h * 0.12));
    }

    headstockPath.lineTo(rightNutX, nutY);
    headstockPath.close();

    // ── 2. Pintura de Madera de la Pala ──
    if (is12) {
      // 12 cuerdas: Ébano oscuro / negro satinado con reflejo diagonal
      final darkWoodGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2C2F33),
          Color(0xFF16181B),
          Color(0xFF101114),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

      final woodPaint = Paint()..shader = darkWoodGradient;
      canvas.drawPath(headstockPath, woodPaint);

      // Brillo / destello diagonal satinado
      final sheenPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(28),
            Colors.white.withAlpha(0),
          ],
          stops: const [0.35, 0.50, 0.65],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(headstockPath, sheenPaint);
    } else {
      // 6 cuerdas: Caoba acústica cálida / abeto tostado (Warm Mahogany Sunburst)
      final mahoganyGradient = const RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 1.1,
        colors: [
          Color(0xFFB06836), // Centro cálido ámbar/miel
          Color(0xFF7A401C), // Transición caoba
          Color(0xFF381A08), // Bordes oscuros
        ],
      ).createShader(Rect.fromLTWH(leftTopX, topY, rightTopX - leftTopX, nutY - topY));

      final woodPaint = Paint()..shader = mahoganyGradient;
      canvas.drawPath(headstockPath, woodPaint);
    }

    // ── 3. Doble Ribete (Binding) Perfilado Marfil / Crema ──
    final outerBindingPaint = Paint()
      ..color = const Color(0xFFF3EEDD) // Crema marfil
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(headstockPath, outerBindingPaint);

    final innerPurflingPaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(headstockPath, innerPurflingPaint);

    // ── 4. Tapa de Alma (Truss Rod Cover) Oscura con Tornillos ──
    final trussY = nutY - (h * (is12 ? 0.12 : 0.14));
    final trussWidth = is12 ? w * 0.12 : w * 0.14;
    final trussPath = Path();
    trussPath.moveTo(w * 0.50 - trussWidth / 2, nutY - 3);
    trussPath.lineTo(w * 0.50 + trussWidth / 2, nutY - 3);
    trussPath.lineTo(w * 0.50 + trussWidth / 3, trussY);
    trussPath.quadraticBezierTo(w * 0.50, trussY - 6, w * 0.50 - trussWidth / 3, trussY);
    trussPath.close();

    final trussPaint = Paint()..color = const Color(0xFF141416);
    canvas.drawPath(trussPath, trussPaint);
    final trussBorderPaint = Paint()
      ..color = const Color(0xFF2C2D30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(trussPath, trussBorderPaint);

    // Tornillos de la tapa
    final screwPaint = Paint()..color = const Color(0xFFB0B3B8);
    canvas.drawCircle(Offset(w * 0.50, trussY + 4), 1.2, screwPaint);
    canvas.drawCircle(Offset(w * 0.50, nutY - 8), 1.2, screwPaint);

    // ── 5. Cejuela de Hueso (Bone Nut) ──
    final nutRect = Rect.fromLTWH(leftNutX - 2, nutY, (rightNutX - leftNutX) + 4, h * 0.026);
    final nutPaint = Paint()..color = const Color(0xFFF5EFE0); // Hueso natural pulido
    canvas.drawRRect(RRect.fromRectAndRadius(nutRect, const Radius.circular(2)), nutPaint);

    // Sombra inferior de la cejuela
    final nutShadowPaint = Paint()..color = Colors.black.withAlpha(90);
    canvas.drawLine(Offset(leftNutX - 2, nutY + (h * 0.026)), Offset(rightNutX + 2, nutY + (h * 0.026)), nutShadowPaint);

    // ── 6. Diapasón y Trastes Metálicos Inferiores ──
    final fretboardRect = Rect.fromLTWH(
      leftNutX - 1,
      nutY + (h * 0.026),
      (rightNutX - leftNutX) + 2,
      fretboardBottomY - (nutY + (h * 0.026)),
    );
    final fretboardPaint = Paint()..color = const Color(0xFF1F1A17); // Palisandro oscuro
    canvas.drawRect(fretboardRect, fretboardPaint);

    // Trastes níquel
    final fretPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 1.6;
    final fret1Y = nutY + (h * 0.09);
    final fret2Y = nutY + (h * 0.17);
    if (fret1Y < fretboardBottomY) {
      canvas.drawLine(Offset(leftNutX - 1, fret1Y), Offset(rightNutX + 1, fret1Y), fretPaint);
    }
    if (fret2Y < fretboardBottomY) {
      canvas.drawLine(Offset(leftNutX - 1, fret2Y), Offset(rightNutX + 1, fret2Y), fretPaint);
    }

    // ── 7. Clavijas y Postes Cromados + Cuerdas Metálicas ──
    if (is12) {
      _paint12StringHeadstockDetails(canvas, size, topY, nutY);
    } else {
      _paint6StringHeadstockDetails(canvas, size, topY, nutY);
    }
  }

  void _paint6StringHeadstockDetails(Canvas canvas, Size size, double topY, double nutY) {
    final w = size.width;
    final h = size.height;

    // 3 Clavijas a la izquierda (cuerdas 4, 5, 6) y 3 a la derecha (cuerdas 3, 2, 1)
    final leftPegY = [topY + (h * 0.18), topY + (h * 0.34), topY + (h * 0.50)];
    final rightPegY = [topY + (h * 0.18), topY + (h * 0.34), topY + (h * 0.50)];

    final leftPostX = w * 0.35;
    final rightPostX = w * 0.65;

    final leftEdgeX = w * 0.22;
    final rightEdgeX = w * 0.78;

    // Dibujar clavijas de cromo exteriores y postes centrales
    for (int i = 0; i < 3; i++) {
      _drawChromePeg(canvas, leftEdgeX - (i * 1.5), leftPostX, leftPegY[i], isLeft: true);
      _drawChromePeg(canvas, rightEdgeX + (i * 1.5), rightPostX, rightPegY[i], isLeft: false);
    }

    // Cuerdas en el mástil (6ª a 1ª ordenadas de izquierda a derecha en la cejuela)
    // 6ª E2 (82.4Hz), 5ª A2 (110Hz), 4ª D3 (146.8Hz), 3ª G3 (196Hz), 2ª B3 (246.9Hz), 1ª E4 (329.6Hz)
    final nutLeft = w * 0.34;
    final nutRight = w * 0.66;
    final nutStep = (nutRight - nutLeft) / 5;

    // Mapeo: cuerda -> (postX, postY, nutX, calibre)
    final stringData = [
      // 6ª cuerda (Mi grave) -> Peg izquierdo inferior (i = 2)
      _StringDef(index: 6, postX: leftPostX, postY: leftPegY[2], nutX: nutLeft, gauge: 2.8),
      // 5ª cuerda (La) -> Peg izquierdo medio (i = 1)
      _StringDef(index: 5, postX: leftPostX, postY: leftPegY[1], nutX: nutLeft + (nutStep * 1), gauge: 2.3),
      // 4ª cuerda (Re) -> Peg izquierdo superior (i = 0)
      _StringDef(index: 4, postX: leftPostX, postY: leftPegY[0], nutX: nutLeft + (nutStep * 2), gauge: 1.9),
      // 3ª cuerda (Sol) -> Peg derecho superior (i = 0)
      _StringDef(index: 3, postX: rightPostX, postY: rightPegY[0], nutX: nutLeft + (nutStep * 3), gauge: 1.6),
      // 2ª cuerda (Si) -> Peg derecho medio (i = 1)
      _StringDef(index: 2, postX: rightPostX, postY: rightPegY[1], nutX: nutLeft + (nutStep * 4), gauge: 1.3),
      // 1ª cuerda (Mi aguda) -> Peg derecho inferior (i = 2)
      _StringDef(index: 1, postX: rightPostX, postY: rightPegY[2], nutX: nutRight, gauge: 1.0),
    ];

    for (final s in stringData) {
      final isActive = activeStringIndex == s.index;
      _drawGuitarStringPath(
        canvas: canvas,
        postX: s.postX,
        postY: s.postY,
        nutX: s.nutX,
        nutY: nutY,
        bottomY: h,
        gauge: s.gauge,
        isActive: isActive,
      );
    }
  }

  void _paint12StringHeadstockDetails(Canvas canvas, Size size, double topY, double nutY) {
    final w = size.width;
    final h = size.height;

    // 6 Clavijas a cada lado en docerola
    final pegCount = 6;
    final startY = topY + (h * 0.10);
    final endY = nutY - (h * 0.08);
    final pegStep = (endY - startY) / (pegCount - 1);

    final leftPostX = w * 0.39;
    final rightPostX = w * 0.61;
    final leftEdgeX = w * 0.28;
    final rightEdgeX = w * 0.72;

    for (int i = 0; i < pegCount; i++) {
      final y = startY + (i * pegStep);
      _drawChromePeg(canvas, leftEdgeX, leftPostX, y, isLeft: true, isSmall: true);
      _drawChromePeg(canvas, rightEdgeX, rightPostX, y, isLeft: false, isSmall: true);
    }

    // 6 Pares de cuerdas en la cejuela (Par 6 al Par 1 de izquierda a derecha)
    final nutLeft = w * 0.36;
    final nutRight = w * 0.64;
    final pairStep = (nutRight - nutLeft) / 5;

    // Pares:
    // Par 6 (cuerdas 12 y 11) -> Pegs izquierdos 5 y 4
    // Par 5 (cuerdas 10 y 9)  -> Pegs izquierdos 3 y 2
    // Par 4 (cuerdas 8 y 7)   -> Pegs izquierdos 1 y 0
    // Par 3 (cuerdas 6 y 5)   -> Pegs derechos 0 y 1
    // Par 2 (cuerdas 4 y 3)   -> Pegs derechos 2 y 3
    // Par 1 (cuerdas 2 y 1)   -> Pegs derechos 4 y 5
    final pairs12 = [
      // Par 6: E3 (12) y E2 (11)
      _PairDef(
        string1: _StringDef(index: 12, postX: leftPostX, postY: startY + (5 * pegStep), nutX: nutLeft - 1.5, gauge: 1.4),
        string2: _StringDef(index: 11, postX: leftPostX, postY: startY + (4 * pegStep), nutX: nutLeft + 1.5, gauge: 2.2),
      ),
      // Par 5: A3 (10) y A2 (9)
      _PairDef(
        string1: _StringDef(index: 10, postX: leftPostX, postY: startY + (3 * pegStep), nutX: nutLeft + (pairStep * 1) - 1.5, gauge: 1.3),
        string2: _StringDef(index: 9, postX: leftPostX, postY: startY + (2 * pegStep), nutX: nutLeft + (pairStep * 1) + 1.5, gauge: 1.8),
      ),
      // Par 4: D4 (8) y D3 (7)
      _PairDef(
        string1: _StringDef(index: 8, postX: leftPostX, postY: startY + (1 * pegStep), nutX: nutLeft + (pairStep * 2) - 1.5, gauge: 1.2),
        string2: _StringDef(index: 7, postX: leftPostX, postY: startY + (0 * pegStep), nutX: nutLeft + (pairStep * 2) + 1.5, gauge: 1.6),
      ),
      // Par 3: G4 (6) y G3 (5)
      _PairDef(
        string1: _StringDef(index: 6, postX: rightPostX, postY: startY + (0 * pegStep), nutX: nutLeft + (pairStep * 3) - 1.5, gauge: 1.1),
        string2: _StringDef(index: 5, postX: rightPostX, postY: startY + (1 * pegStep), nutX: nutLeft + (pairStep * 3) + 1.5, gauge: 1.4),
      ),
      // Par 2: B3 (4) y B3 (3)
      _PairDef(
        string1: _StringDef(index: 4, postX: rightPostX, postY: startY + (2 * pegStep), nutX: nutLeft + (pairStep * 4) - 1.5, gauge: 1.2),
        string2: _StringDef(index: 3, postX: rightPostX, postY: startY + (3 * pegStep), nutX: nutLeft + (pairStep * 4) + 1.5, gauge: 1.2),
      ),
      // Par 1: E4 (2) y E4 (1)
      _PairDef(
        string1: _StringDef(index: 2, postX: rightPostX, postY: startY + (4 * pegStep), nutX: nutRight - 1.5, gauge: 1.0),
        string2: _StringDef(index: 1, postX: rightPostX, postY: startY + (5 * pegStep), nutX: nutRight + 1.5, gauge: 1.0),
      ),
    ];

    for (final pair in pairs12) {
      final is1Active = activeStringIndex == pair.string1.index;
      final is2Active = activeStringIndex == pair.string2.index;

      _drawGuitarStringPath(
        canvas: canvas,
        postX: pair.string1.postX,
        postY: pair.string1.postY,
        nutX: pair.string1.nutX,
        nutY: nutY,
        bottomY: h,
        gauge: pair.string1.gauge,
        isActive: is1Active,
      );

      _drawGuitarStringPath(
        canvas: canvas,
        postX: pair.string2.postX,
        postY: pair.string2.postY,
        nutX: pair.string2.nutX,
        nutY: nutY,
        bottomY: h,
        gauge: pair.string2.gauge,
        isActive: is2Active,
      );
    }
  }

  void _drawChromePeg(
    Canvas canvas,
    double edgeX,
    double postX,
    double y, {
    required bool isLeft,
    bool isSmall = false,
  }) {
    final pegWidth = isSmall ? 10.0 : 13.0;
    final pegHeight = isSmall ? 14.0 : 18.0;

    // 1. Poste de metal en la pala
    final postRadius = isSmall ? 3.5 : 4.5;
    final postPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE6E8EA), Color(0xFF8A9096), Color(0xFF4A4E53)],
      ).createShader(Rect.fromCircle(center: Offset(postX, y), radius: postRadius));
    canvas.drawCircle(Offset(postX, y), postRadius, postPaint);

    // Agujero central del poste
    final holePaint = Paint()..color = const Color(0xFF1E2124);
    canvas.drawCircle(Offset(postX, y), postRadius * 0.45, holePaint);

    // 2. Vástago/Eje de cromo
    final shaftPaint = Paint()
      ..color = const Color(0xFFBDC1C6)
      ..strokeWidth = isSmall ? 2.0 : 2.5;
    canvas.drawLine(Offset(edgeX, y), Offset(isLeft ? edgeX - 8 : edgeX + 8, y), shaftPaint);

    // 3. Clavija ovalada exterior tipo mariposa de cromo (Chrome Tuning Key)
    final keyCenterX = isLeft ? edgeX - (pegWidth / 2 + 6) : edgeX + (pegWidth / 2 + 6);
    final keyRect = Rect.fromCenter(
      center: Offset(keyCenterX, y),
      width: pegWidth,
      height: pegHeight,
    );

    final keyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFF1F3F4), // Brillo de cromo blanco
        Color(0xFFD2D6DA),
        Color(0xFF7A8086),
        Color(0xFFE4E7EB),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    ).createShader(keyRect);

    final keyPaint = Paint()..shader = keyGradient;
    canvas.drawRRect(RRect.fromRectAndRadius(keyRect, Radius.circular(pegWidth / 2)), keyPaint);

    final keyBorder = Paint()
      ..color = const Color(0xFF5F6368)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(RRect.fromRectAndRadius(keyRect, Radius.circular(pegWidth / 2)), keyBorder);
  }

  void _drawGuitarStringPath({
    required Canvas canvas,
    required double postX,
    required double postY,
    required double nutX,
    required double nutY,
    required double bottomY,
    required double gauge,
    required bool isActive,
  }) {
    final path = Path();
    path.moveTo(postX, postY);
    path.lineTo(nutX, nutY);
    path.lineTo(nutX, bottomY);

    if (isActive) {
      // Brillo exterior neón resplandeciente
      final glowPaint = Paint()
        ..color = activeColor.withAlpha(200)
        ..strokeWidth = gauge + 3.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawPath(path, glowPaint);

      // Cuerda en el color activo
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = gauge + 0.9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, activePaint);

      // Núcleo blanco brillante si está sonando
      if (isSounding) {
        final corePaint = Paint()
          ..color = Colors.white.withAlpha(240)
          ..strokeWidth = math.max(0.8, gauge * 0.6)
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, corePaint);
      }
    } else {
      // Cuerda metálica normal (Níquel / Bronce pulido)
      final normalPaint = Paint()
        ..color = Colors.white.withAlpha(85)
        ..strokeWidth = gauge
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, normalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticGuitarHeadstockPainter oldDelegate) {
    return oldDelegate.guitarType != guitarType ||
        oldDelegate.activeStringIndex != activeStringIndex ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isSounding != isSounding;
  }
}

class _StringDef {
  final int index;
  final double postX;
  final double postY;
  final double nutX;
  final double gauge;

  const _StringDef({
    required this.index,
    required this.postX,
    required this.postY,
    required this.nutX,
    required this.gauge,
  });
}

class _PairDef {
  final _StringDef string1;
  final _StringDef string2;

  const _PairDef({
    required this.string1,
    required this.string2,
  });
}
