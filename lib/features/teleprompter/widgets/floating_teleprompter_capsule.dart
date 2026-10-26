import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/lyric_token.dart';

/// Cápsula flotante estilo "Dynamic Island" anclada inmediatamente bajo la cámara frontal.
/// 
/// Características clave solicitadas:
/// 1. Ancho restringido con salto de línea automático (`softWrap: true`), nunca en una sola línea.
/// 2. Scroll vertical suave por renglón/palabra manteniendo el verso actual visible sin desborde.
/// 3. Indicador de micrófono "Voz" (con VAD acústico) y temporizador "REC" estilo Dynamic Island.
/// 4. Botón de ajustes rápidos / ecualizador en el extremo derecho como en la interfaz nativa.
/// 5. Soporte para acordes integrados (si la canción los tiene) sin romper el flujo de lectura.
class FloatingTeleprompterCapsule extends StatefulWidget {
  final List<LyricToken> tokens;
  final int currentWordIndex;
  final bool isSinging;
  final bool isWaitingForVoice;
  final bool isRecording;
  final int recordingSeconds;
  final Color highlightColor;
  final VoidCallback? onSettingsTap;
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
    this.highlightColor = const Color(0xFF64D2FF), // Cian elétrico iOS / Dynamic Island
    this.onSettingsTap,
    this.onWordTap,
    this.onResetTap,
    this.width = 330.0,
    this.height = 86.0,
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

    // En promedio entran entre 3.5 y 4.5 palabras por renglón en el ancho de la cápsula.
    // Cada renglón mide aproximadamente 22 a 26 píxeles de alto.
    final lineEstimate = (widget.currentWordIndex / 4.0);
    final targetOffset = (lineEstimate * 24.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
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
    final effectiveWidth = math.min(widget.width, screenWidth - 20);

    return Container(
      width: effectiveWidth,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(235), // Negro puro OLED con opacidad sutil
        borderRadius: BorderRadius.circular(38), // Forma de cápsula / Dynamic Island
        border: Border.all(color: Colors.white.withAlpha(35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 1. Indicador de Micrófono / Voz y REC (Estilo Dynamic Island) ─
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Píldora de Voz con feedback de canto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: widget.isSinging
                      ? widget.highlightColor.withAlpha(40)
                      : Colors.white.withAlpha(16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSinging
                        ? widget.highlightColor
                        : Colors.white.withAlpha(35),
                    width: widget.isSinging ? 1.2 : 0.8,
                  ),
                  boxShadow: widget.isSinging
                      ? [
                          BoxShadow(
                            color: widget.highlightColor.withAlpha(120),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isSinging ? Icons.mic : Icons.mic_none,
                      color: widget.isSinging
                          ? widget.highlightColor
                          : (widget.isWaitingForVoice
                              ? AppColors.chordAmber
                              : Colors.lightBlueAccent),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.isSinging ? 'Canta' : 'Voz',
                      style: TextStyle(
                        color: widget.isSinging
                            ? widget.highlightColor
                            : (widget.isWaitingForVoice
                                ? AppColors.chordAmber
                                : Colors.lightBlueAccent),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),

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
            indent: 4,
            endIndent: 4,
          ),
          const SizedBox(width: 10),

          // ── 2. Área de Lectura Teleprompter con Wrap Vertical y Shader ──
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
                  stops: [0.0, 0.76, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: widget.tokens.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Carga un guion o letra desde el menú...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 4.0,
                        runSpacing: 3.5,
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
                                            fontSize: 9.0,
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent
                                                ? widget.highlightColor
                                                : AppColors.chordAmber,
                                            height: 1.0,
                                          ),
                                        ),
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

          // ── 3. Botón de Ajustes / Sliders estilo nativo (Extremo Derecho) ──
          if (widget.onSettingsTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSettingsTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(40),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 17,
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
