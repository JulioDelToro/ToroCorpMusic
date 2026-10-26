import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/song_script.dart';
import 'lyric_token_widget.dart';

/// Barra de teleprompter anclada debajo de la cámara para mantener contacto visual natural.
/// Muestra las líneas de letras y acordes inferiores con auto-scroll, efecto karaoke
/// e indicador de estado vocal en tiempo real (cantando vs esperando en requinto/pausa).
class TeleprompterBarWidget extends StatefulWidget {
  final SongScript song;
  final int activeLineIndex;
  final int activeWordIndex;
  final bool isMirrorMode;
  final double fontSize;
  final Color highlightColor;
  final bool isSinging;
  final bool isWaitingForVoice;
  final VoidCallback? onNextTap;
  final VoidCallback? onPrevTap;
  final VoidCallback? onResetTap;
  final void Function(int lineIndex, int wordIndex)? onWordTap;

  const TeleprompterBarWidget({
    super.key,
    required this.song,
    this.activeLineIndex = 0,
    this.activeWordIndex = 0,
    this.isMirrorMode = false,
    this.fontSize = 26.0,
    this.highlightColor = const Color(0xFFFFD60A),
    this.isSinging = false,
    this.isWaitingForVoice = true,
    this.onNextTap,
    this.onPrevTap,
    this.onResetTap,
    this.onWordTap,
  });

  @override
  State<TeleprompterBarWidget> createState() => _TeleprompterBarWidgetState();
}

class _TeleprompterBarWidgetState extends State<TeleprompterBarWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant TeleprompterBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeLineIndex != widget.activeLineIndex) {
      _scrollToActiveLine();
    }
  }

  void _scrollToActiveLine() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 90.0;
    final targetOffset = widget.activeLineIndex * itemHeight;
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.song.lines;

    Widget content = Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
      ),
      child: lines.isEmpty
          ? const Center(
              child: Text(
                'Sin guion cargado. Agrega una letra o PDF.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                // 1. Barra superior de estado vocal en vivo (VAD) y reinicio
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicador de Voz en tiempo real
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.isSinging
                              ? widget.highlightColor.withAlpha(45)
                              : Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.isSinging
                                ? widget.highlightColor
                                : AppColors.borderDark,
                            width: widget.isSinging ? 1.5 : 1,
                          ),
                          boxShadow: widget.isSinging
                              ? [
                                  BoxShadow(
                                    color: widget.highlightColor.withAlpha(120),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isSinging ? Icons.mic : Icons.pause_circle_outline,
                              size: 13,
                              color: widget.isSinging
                                  ? widget.highlightColor
                                  : AppColors.chordAmber,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.isSinging
                                  ? 'CANTANDO • SIGUIENDO VOZ'
                                  : 'ESPERANDO VOZ (REQUINTO / PAUSA)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: widget.isSinging
                                    ? widget.highlightColor
                                    : AppColors.chordAmber,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Botón discreto de reinicio al principio
                      if (widget.onResetTap != null)
                        GestureDetector(
                          onTap: widget.onResetTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.first_page, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Reiniciar',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Líneas de Letras y Acordes con desplazamiento suave
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: lines.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, lineIdx) {
                      final line = lines[lineIdx];
                      final isCurrentLine = lineIdx == widget.activeLineIndex;
                      final isPastLine = lineIdx < widget.activeLineIndex;

                      return Opacity(
                        opacity: isCurrentLine ? 1.0 : (isPastLine ? 0.35 : 0.65),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(line.tokens.length, (wordIdx) {
                              final token = line.tokens[wordIdx];
                              final isActiveWord = isCurrentLine && wordIdx == widget.activeWordIndex;
                              final isPastWord = isPastLine || (isCurrentLine && wordIdx < widget.activeWordIndex);

                              return GestureDetector(
                                onTap: () {
                                  widget.onWordTap?.call(lineIdx, wordIdx);
                                },
                                child: LyricTokenWidget(
                                  token: token,
                                  isActive: isActiveWord,
                                  isPast: isPastWord,
                                  fontSize: widget.fontSize,
                                  highlightColor: widget.highlightColor,
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );

    // Soporte para modo espejo (Mirror Mode) si se usa con cristal de teleprompter físico
    if (widget.isMirrorMode) {
      content = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.14159), // Inversión horizontal
        child: content,
      );
    }

    return content;
  }
}
