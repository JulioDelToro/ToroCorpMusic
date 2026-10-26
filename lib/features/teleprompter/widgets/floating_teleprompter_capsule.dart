import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/lyric_token.dart';

/// Cápsula flotante estilo "Dynamic Island" anclada inmediatamente bajo la cámara frontal.
///
/// Perfeccionada según feedback del usuario:
/// 1. Dimensiones ampliadas (108dp de alto) para albergar 3 líneas completas de letra + acordes.
/// 2. Botón "Voz" 100% estático en ancho y texto (nunca cambia de tamaño para evitar saltos en la letra).
/// 3. Botón de menú hamburguesa (☰ <-> ✕) integrado directamente en el extremo derecho de la cápsula.
/// 4. Único indicador de grabación con temporizador debajo de "Voz".
/// 5. Estado inicial limpio con invitación a cargar guion o PDF.
class FloatingTeleprompterCapsule extends StatefulWidget {
  final List<LyricToken> tokens;
  final int currentWordIndex;
  final bool isSinging;
  final bool isWaitingForVoice;
  final bool isRecording;
  final int recordingSeconds;
  final Color highlightColor;
  final VoidCallback? onMenuTap;
  final Animation<double>? menuAnimationProgress;
  final ValueChanged<int>? onWordTap;
  final VoidCallback? onResetTap;
  final double width;
  final double height;

  const FloatingTeleprompterCapsule({
    super.key,
    required this.tokens,
    required this.currentWordIndex,
    this.isSinging = false,
    this.isWaitingForVoice = true,
    this.isRecording = false,
    this.recordingSeconds = 0,
    this.highlightColor = const Color(0xFF64D2FF), // Cian eléctrico Dynamic Island
    this.onMenuTap,
    this.menuAnimationProgress,
    this.onWordTap,
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
  void didUpdateWidget(covariant FloatingTeleprompterCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      _scrollToActiveWord();
    }
  }

  void _scrollToActiveWord() {
    if (!_scrollController.hasClients) return;

    // Con 3 líneas visibles, el auto-scroll se posiciona suavemente
    // estimando ~4 palabras por renglón y 28px de altura por línea (letra + acorde).
    final lineEstimate = (widget.currentWordIndex / 4.0);
    final targetOffset = (lineEstimate * 28.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth = math.min(widget.width, screenWidth - 16);

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

          // ── 2. Área de Lectura Teleprompter (3 líneas + acordes) ─────────
          Expanded(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.85, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: widget.tokens.isEmpty
                    ? GestureDetector(
                        onTap: widget.onMenuTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          color: Colors.transparent,
                          child: const Center(
                            child: Text(
                              'Toca ☰ para escribir, pegar o cargar letra / PDF...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 4.5,
                        runSpacing: 4.0,
                        children: List.generate(widget.tokens.length, (index) {
                          final isSpoken = index < widget.currentWordIndex;
                          final isCurrent = index == widget.currentWordIndex;
                          final token = widget.tokens[index];

                          final Color wordColor = isCurrent
                              ? widget.highlightColor
                              : (isSpoken ? Colors.white38 : Colors.white);

                          final TextStyle wordStyle = TextStyle(
                            color: wordColor,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                            fontSize: isCurrent ? 14.5 : 13.5,
                            height: 1.25,
                            shadows: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          widget.highlightColor.withAlpha(160),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          );

                          return GestureDetector(
                            onTap: widget.onWordTap != null
                                ? () => widget.onWordTap!(index)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                                vertical: 1.0,
                              ),
                              child: token.chordUnderneath != null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          token.chordUnderneath!,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent
                                                ? widget.highlightColor
                                                : AppColors.chordAmber,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(token.word, style: wordStyle),
                                      ],
                                    )
                                  : Text(token.word, style: wordStyle),
                            ),
                          );
                        }),
                      ),
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
}
