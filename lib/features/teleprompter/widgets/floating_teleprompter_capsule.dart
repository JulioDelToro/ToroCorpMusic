import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/lyric_token.dart';
import '../../scripts/models/song_script.dart';

/// Cápsula flotante estilo "Dynamic Island" anclada inmediatamente bajo la cámara frontal.
///
/// Arquitectura de 2 Líneas según especificación:
/// - Línea 1 (Línea Actual que se va leyendo):
///   * Las palabras que ya leí se ponen en color (highlightColor).
///   * La palabra activa resalta en color con resplandor.
///   * Las palabras por leer están en blanco.
/// - Línea 2 (Línea Siguiente que sigue para leer):
///   * Muestra el siguiente verso en color blanco suave (Colors.white60) para anticipar lectura.
/// - Sin desbordes ni saltos de posición durante la lectura.
class FloatingTeleprompterCapsule extends StatefulWidget {
  final LyricLine? currentLine;
  final LyricLine? nextLine;
  final List<LyricToken>? tokens; // Compatibilidad y fallback
  final int currentWordIndex;
  final bool isSinging;
  final bool isWaitingForVoice;
  final bool isRecording;
  final int recordingSeconds;
  final Color highlightColor;
  final VoidCallback? onMenuTap;
  final VoidCallback? onPlaceholderTap;
  final Animation<double>? menuAnimationProgress;
  final ValueChanged<int>? onWordTap;
  final VoidCallback? onNextLineTap;
  final VoidCallback? onResetTap;
  final double width;
  final double height;

  const FloatingTeleprompterCapsule({
    super.key,
    this.currentLine,
    this.nextLine,
    this.tokens,
    required this.currentWordIndex,
    this.isSinging = false,
    this.isWaitingForVoice = true,
    this.isRecording = false,
    this.recordingSeconds = 0,
    this.highlightColor = const Color(0xFF64D2FF), // Cian eléctrico default
    this.onMenuTap,
    this.onPlaceholderTap,
    this.menuAnimationProgress,
    this.onWordTap,
    this.onNextLineTap,
    this.onResetTap,
    this.width = 355.0,
    this.height = 108.0,
  });

  @override
  State<FloatingTeleprompterCapsule> createState() =>
      _FloatingTeleprompterCapsuleState();
}

class _FloatingTeleprompterCapsuleState
    extends State<FloatingTeleprompterCapsule> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  LyricLine? _getEffectiveCurrentLine() {
    if (widget.currentLine != null) return widget.currentLine;
    if (widget.tokens != null && widget.tokens!.isNotEmpty) {
      return LyricLine(tokens: widget.tokens!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth = math.min(widget.width, screenWidth - 16);
    final currentLine = _getEffectiveCurrentLine();

    return Container(
      width: effectiveWidth,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(238), // Negro puro OLED
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withAlpha(35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 1. Indicador de Micrófono "Voz" (Estático) y REC ────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Píldora de "Voz" con ancho fijo para evitar movimiento de texto
              Container(
                width: 58,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.isSinging
                      ? widget.highlightColor.withAlpha(45)
                      : Colors.white.withAlpha(14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isSinging
                        ? widget.highlightColor
                        : Colors.white.withAlpha(35),
                    width: widget.isSinging ? 1.5 : 0.8,
                  ),
                  boxShadow: widget.isSinging
                      ? [
                          BoxShadow(
                            color: widget.highlightColor.withAlpha(140),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isSinging ? Icons.mic : Icons.mic_none,
                      color: widget.isSinging
                          ? widget.highlightColor
                          : Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Voz',
                      style: TextStyle(
                        color: widget.isSinging
                            ? widget.highlightColor
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Indicador de Grabación / Temporizador
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7.5,
                    height: 7.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isRecording
                          ? AppColors.recordRed
                          : Colors.white38,
                      boxShadow: widget.isRecording
                          ? [
                              BoxShadow(
                                color: AppColors.recordRed.withAlpha(180),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isRecording
                        ? _formatTimer(widget.recordingSeconds)
                        : 'REC',
                    style: TextStyle(
                      color: widget.isRecording
                          ? AppColors.recordRed
                          : Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 10),
          const VerticalDivider(
            color: Colors.white24,
            width: 1,
            indent: 6,
            endIndent: 6,
          ),
          const SizedBox(width: 10),

          // ── 2. Área Central de Karaoke (Exactamente 2 Líneas) ──────────────
          Expanded(
            child: currentLine == null || currentLine.tokens.isEmpty
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onPlaceholderTap ?? widget.onMenuTap,
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const Text(
                        'Toca aquí para escribir o pegar la letra de tu canción...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : currentLine.isInstrumental
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onNextLineTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.chordAmber.withAlpha(28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.chordAmber.withAlpha(140), width: 1.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note, color: AppColors.chordAmber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentLine.instrumentalLabel ?? '🎸 REQUINTO EN CURSO',
                                      style: const TextStyle(
                                        color: AppColors.chordAmber,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const Text(
                                      'Toca aquí para iniciar el siguiente verso',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.skip_next, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── FILA 1: Línea que voy leyendo ──
                            // Las palabras que ya leí se ponen en color
                            _buildLineRow(
                              line: currentLine,
                              activeWordIndex: widget.currentWordIndex,
                              isCurrentLine: true,
                              onWordTap: widget.onWordTap,
                            ),

                            const SizedBox(height: 5),

                            // ── FILA 2: Línea siguiente que sigue para leer ──
                            _buildLineRow(
                              line: widget.nextLine,
                              activeWordIndex: -1,
                              isCurrentLine: false,
                              onWordTap: (_) => widget.onNextLineTap?.call(),
                            ),
                          ],
                        ),
                      ),
          ),

          // ── 3. Botón de Menú Hamburguesa (☰ <-> ✕) Integrado en la Cápsula ──
          if (widget.onMenuTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onMenuTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(45),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: widget.menuAnimationProgress != null
                      ? AnimatedIcon(
                          icon: AnimatedIcons.menu_close,
                          progress: widget.menuAnimationProgress!,
                          color: AppColors.textWhite,
                          size: 20,
                        )
                      : const Icon(
                          Icons.menu,
                          color: AppColors.textWhite,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineRow({
    required LyricLine? line,
    required int activeWordIndex,
    required bool isCurrentLine,
    ValueChanged<int>? onWordTap,
  }) {
    if (line == null || line.tokens.isEmpty) {
      if (!isCurrentLine) {
        return const Padding(
          padding: EdgeInsets.only(top: 2, left: 4),
          child: Text(
            '• Fin de la canción •',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (!isCurrentLine && line.isInstrumental) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '[ ${line.instrumentalLabel ?? '🎸 REQUINTO / SOLO'} ]',
          style: const TextStyle(
            color: AppColors.chordAmber,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4.5,
      runSpacing: 2.0,
      children: List.generate(line.tokens.length, (idx) {
        final token = line.tokens[idx];
        final isRead = isCurrentLine && idx < activeWordIndex;
        final isCurrent = isCurrentLine && idx == activeWordIndex;

        final Color wordColor;
        final FontWeight fontWeight;
        final double fontSize;
        List<Shadow>? shadows;

        if (isCurrentLine) {
          if (isRead) {
            // "las que se ponen en color que ya las leí"
            wordColor = widget.highlightColor;
            fontWeight = FontWeight.w600;
            fontSize = 14.0;
          } else if (isCurrent) {
            // Palabra activa cantando en este instante
            wordColor = widget.highlightColor;
            fontWeight = FontWeight.bold;
            fontSize = 15.0;
            shadows = [
              BoxShadow(
                color: widget.highlightColor.withAlpha(180),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ];
          } else {
            // Palabra que falta por leer de esta línea
            wordColor = Colors.white;
            fontWeight = FontWeight.w600;
            fontSize = 14.0;
          }
        } else {
          // "la línea siguiente que sigue para leer"
          wordColor = Colors.white60;
          fontWeight = FontWeight.w500;
          fontSize = 12.5;
        }

        final wordStyle = TextStyle(
          color: wordColor,
          fontWeight: fontWeight,
          fontSize: fontSize,
          height: 1.15,
          shadows: shadows,
        );

        final chord = token.chordUnderneath;

        Widget tokenWidget;
        if (chord != null && chord.isNotEmpty) {
          final Color chordColor = isCurrentLine
              ? (isRead || isCurrent ? widget.highlightColor : AppColors.chordAmber)
              : AppColors.chordAmber.withAlpha(140);

          tokenWidget = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chord,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isCurrentLine ? 9.5 : 8.5,
                  fontWeight: FontWeight.bold,
                  color: chordColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(token.word, style: wordStyle),
            ],
          );
        } else {
          tokenWidget = Text(token.word, style: wordStyle);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onWordTap != null ? () => onWordTap(idx) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
            child: tokenWidget,
          ),
        );
      }),
    );
  }
}
