import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/song_script.dart';
import 'lyric_token_widget.dart';

/// Barra de teleprompter anclada debajo de la cámara para mantener contacto visual natural.
/// Muestra las líneas de letras y acordes inferiores con auto-scroll y efecto karaoke.
class TeleprompterBarWidget extends StatefulWidget {
  final SongScript song;
  final int activeLineIndex;
  final int activeWordIndex;
  final bool isMirrorMode;
  final double fontSize;
  final Color highlightColor;
  final VoidCallback? onNextTap;
  final VoidCallback? onPrevTap;

  const TeleprompterBarWidget({
    super.key,
    required this.song,
    this.activeLineIndex = 0,
    this.activeWordIndex = 0,
    this.isMirrorMode = false,
    this.fontSize = 26.0,
    this.highlightColor = const Color(0xFFFFD60A),
    this.onNextTap,
    this.onPrevTap,
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
      height: 160,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
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
          : ListView.builder(
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

                        return LyricTokenWidget(
                          token: token,
                          isActive: isActiveWord,
                          isPast: isPastWord,
                          fontSize: widget.fontSize,
                          highlightColor: widget.highlightColor,
                        );
                      }),
                    ),
                  ),
                );
              },
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
