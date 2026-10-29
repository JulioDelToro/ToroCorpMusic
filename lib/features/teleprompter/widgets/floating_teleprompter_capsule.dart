import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../scripts/models/lyric_token.dart';
import '../../scripts/models/song_script.dart';

/// Cápsula flotante estilo "Dynamic Island" anclada inmediatamente bajo la cámara frontal.
///
/// Arquitectura de lectura y control interactivo:
/// - Permite hacer scroll vertical ("darle para abajo") para explorar cualquier verso/acorde.
/// - Al tocar cualquier palabra de cualquier línea, actualiza la posición al instante.
/// - Botón "Voz":
///   * Al presionarlo una vez, muestra "Reiniciar".
///   * Al presionarlo de nuevo, reinicia la canción desde el inicio (línea 0, palabra 0).
///   * Si pasan 3.5 segundos sin confirmar, regresa automáticamente a "Voz".
/// - Fila actual con palabras leídas en color, palabra activa en color con resplandor y siguientes en blanco.
class FloatingTeleprompterCapsule extends StatefulWidget {
  final List<LyricLine>? allLines;
  final int currentLineIndex;
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
  final void Function(int lineIndex, int wordIndex)? onLineWordTap;
  final VoidCallback? onNextLineTap;
  final VoidCallback? onResetTap;
  final double width;
  final double height;
  final bool isCameraActive;
  final bool? isExpanded;
  final VoidCallback? onToggleExpand;

  const FloatingTeleprompterCapsule({
    super.key,
    this.allLines,
    this.currentLineIndex = 0,
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
    this.onLineWordTap,
    this.onNextLineTap,
    this.onResetTap,
    this.width = 355.0,
    this.height = 108.0,
    this.isCameraActive = false,
    this.isExpanded,
    this.onToggleExpand,
  });

  @override
  State<FloatingTeleprompterCapsule> createState() =>
      _FloatingTeleprompterCapsuleState();
}

class _FloatingTeleprompterCapsuleState
    extends State<FloatingTeleprompterCapsule> {
  bool _isConfirmingReset = false;
  Timer? _resetConfirmTimer;
  late bool _isExpanded;
  double _fontScale = 1.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? false;
    if (widget.isCameraActive) {
      _isExpanded = false;
    }
  }

  @override
  void didUpdateWidget(FloatingTeleprompterCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != null && widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded!;
    }
    // Auto-colapso fluido cuando la cámara se activa
    if (widget.isCameraActive && (_isExpanded || !oldWidget.isCameraActive)) {
      _isExpanded = false;
    }

    if (_isExpanded && widget.currentLineIndex != oldWidget.currentLineIndex) {
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final targetOffset = (widget.currentLineIndex * 48.0 - 80.0)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleExpanded() {
    if (widget.isCameraActive) return;
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onToggleExpand?.call();
    if (_isExpanded) {
      _scrollToCurrentLine();
    }
  }

  void _decreaseFontSize() {
    setState(() {
      _fontScale = (_fontScale - 0.15).clamp(0.7, 1.8);
    });
  }

  void _increaseFontSize() {
    setState(() {
      _fontScale = (_fontScale + 0.15).clamp(0.7, 1.8);
    });
  }

  @override
  void dispose() {
    _resetConfirmTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleVozTap() {
    if (!_isConfirmingReset) {
      setState(() {
        _isConfirmingReset = true;
      });
      _resetConfirmTimer?.cancel();
      _resetConfirmTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted) {
          setState(() {
            _isConfirmingReset = false;
          });
        }
      });
    } else {
      _resetConfirmTimer?.cancel();
      setState(() {
        _isConfirmingReset = false;
      });
      widget.onResetTap?.call();
    }
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

  List<LyricLine> _getEffectiveLines() {
    if (widget.allLines != null && widget.allLines!.isNotEmpty) {
      return widget.allLines!;
    }
    final list = <LyricLine>[];
    final cur = _getEffectiveCurrentLine();
    if (cur != null) list.add(cur);
    if (widget.nextLine != null) list.add(widget.nextLine!);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final effectiveWidth = _isExpanded
        ? math.max(320.0, screenWidth - 24.0)
        : math.min(widget.width, screenWidth - 16.0);
    final effectiveHeight = _isExpanded
        ? math.min(screenHeight * 0.72, 560.0)
        : widget.height;
    final effectiveRadius = _isExpanded ? 24.0 : 38.0;

    final effectiveLines = _getEffectiveLines();
    final int effectiveLineIndex =
        widget.currentLineIndex.clamp(0, math.max(0, effectiveLines.length - 1));

    final bool isEmpty = effectiveLines.isEmpty ||
        (effectiveLines.length == 1 && effectiveLines.first.tokens.isEmpty);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      width: effectiveWidth,
      height: effectiveHeight,
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 16 : 14,
        vertical: _isExpanded ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(238), // Negro puro OLED
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: _isExpanded
              ? AppColors.chordAmber.withAlpha(90)
              : Colors.white.withAlpha(35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(180),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isExpanded
          ? _buildMusicStandContent(
              effectiveLines: effectiveLines,
              effectiveLineIndex: effectiveLineIndex,
              isEmpty: isEmpty,
            )
          : _buildCompactCapsuleContent(
              effectiveLines: effectiveLines,
              effectiveLineIndex: effectiveLineIndex,
              isEmpty: isEmpty,
            ),
    );
  }

  Widget _buildCompactCapsuleContent({
    required List<LyricLine> effectiveLines,
    required int effectiveLineIndex,
    required bool isEmpty,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. Indicador de Micrófono "Voz" (con Confirmación Reiniciar) y REC ──
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleVozTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isConfirmingReset ? 76 : 58,
                height: 28,
                decoration: BoxDecoration(
                  color: _isConfirmingReset
                      ? AppColors.chordAmber.withAlpha(50)
                      : (widget.isSinging
                          ? widget.highlightColor.withAlpha(45)
                          : Colors.white.withAlpha(14)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isConfirmingReset
                        ? AppColors.chordAmber
                        : (widget.isSinging
                            ? widget.highlightColor
                            : Colors.white.withAlpha(35)),
                    width: (_isConfirmingReset || widget.isSinging) ? 1.5 : 0.8,
                  ),
                  boxShadow: (_isConfirmingReset || widget.isSinging)
                      ? [
                          BoxShadow(
                            color: _isConfirmingReset
                                ? AppColors.chordAmber.withAlpha(160)
                                : widget.highlightColor.withAlpha(140),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConfirmingReset
                              ? Icons.replay_rounded
                              : (widget.isSinging ? Icons.mic : Icons.mic_none),
                          color: _isConfirmingReset
                              ? AppColors.chordAmber
                              : (widget.isSinging
                                  ? widget.highlightColor
                                  : Colors.white70),
                          size: _isConfirmingReset ? 14 : 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isConfirmingReset ? 'Reiniciar' : 'Voz',
                          style: TextStyle(
                            color: _isConfirmingReset
                                ? AppColors.chordAmber
                                : (widget.isSinging
                                    ? widget.highlightColor
                                    : Colors.white70),
                            fontSize: _isConfirmingReset ? 10.5 : 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

        // ── 2. Área Central de Karaoke Estable con 3 Líneas y Acordes ────────
        Expanded(
          child: isEmpty
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
              : ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Línea 1: Línea que se está cantando (permanece en amarillo al terminar)
                        if (effectiveLineIndex < effectiveLines.length)
                          _buildLineItem(
                            line: effectiveLines[effectiveLineIndex],
                            lineIndex: effectiveLineIndex,
                            isCurrentLine: true,
                            isPastLine: false,
                            activeWordIndex: widget.currentWordIndex,
                            onWordTap: (wIdx) => widget.onWordTap?.call(wIdx),
                          ),

                        // Línea 2: Siguiente estrofa para anticipar lectura
                        if (effectiveLineIndex + 1 < effectiveLines.length) ...[
                          const SizedBox(height: 3),
                          _buildLineItem(
                            line: effectiveLines[effectiveLineIndex + 1],
                            lineIndex: effectiveLineIndex + 1,
                            isCurrentLine: false,
                            isPastLine: false,
                            activeWordIndex: -1,
                            onWordTap: (_) => widget.onNextLineTap?.call(),
                          ),
                        ] else if (effectiveLines.length > 1) ...[
                          const SizedBox(height: 2),
                          const Text(
                            '• Fin de la canción •',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        // Línea 3: Tercera estrofa de vista previa (si hay espacio)
                        if (effectiveLineIndex + 2 < effectiveLines.length) ...[
                          const SizedBox(height: 2),
                          _buildLineItem(
                            line: effectiveLines[effectiveLineIndex + 2],
                            lineIndex: effectiveLineIndex + 2,
                            isCurrentLine: false,
                            isPastLine: false,
                            isThirdLine: true,
                            activeWordIndex: -1,
                            onWordTap: null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),

        // Botón de expansión a Modo Atril (solo disponible cuando la cámara está apagada)
        if (!widget.isCameraActive) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.unfold_more,
              color: AppColors.chordAmber,
              size: 20,
            ),
            tooltip: 'Modo Atril (Pantalla Completa)',
            onPressed: _toggleExpanded,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],

        // ── 3. Botón de Menú Hamburguesa (☰ <-> ✕) Integrado en la Cápsula ──
        if (widget.onMenuTap != null) ...[
          const SizedBox(width: 6),
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
    );
  }

  Widget _buildMusicStandContent({
    required List<LyricLine> effectiveLines,
    required int effectiveLineIndex,
    required bool isEmpty,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header Bar del Atril ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left group: Indicador de Voz / Reiniciar y REC
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleVozTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isConfirmingReset ? 76 : 58,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isConfirmingReset
                          ? AppColors.chordAmber.withAlpha(50)
                          : (widget.isSinging
                              ? widget.highlightColor.withAlpha(45)
                              : Colors.white.withAlpha(14)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isConfirmingReset
                            ? AppColors.chordAmber
                            : (widget.isSinging
                                ? widget.highlightColor
                                : Colors.white.withAlpha(35)),
                        width: (_isConfirmingReset || widget.isSinging) ? 1.5 : 0.8,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isConfirmingReset
                                  ? Icons.replay_rounded
                                  : (widget.isSinging ? Icons.mic : Icons.mic_none),
                              color: _isConfirmingReset
                                  ? AppColors.chordAmber
                                  : (widget.isSinging
                                      ? widget.highlightColor
                                      : Colors.white70),
                              size: _isConfirmingReset ? 14 : 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _isConfirmingReset ? 'Reiniciar' : 'Voz',
                              style: TextStyle(
                                color: _isConfirmingReset
                                    ? AppColors.chordAmber
                                    : (widget.isSinging
                                        ? widget.highlightColor
                                        : Colors.white70),
                                fontSize: _isConfirmingReset ? 10.5 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Indicador REC
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isRecording ? AppColors.recordRed : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isRecording ? _formatTimer(widget.recordingSeconds) : 'REC',
                      style: TextStyle(
                        color: widget.isRecording ? AppColors.recordRed : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Right group: Badge Modo Atril, Controles A-/A+, Botón Colapso, Menú
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Modo Atril
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.chordAmber.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.chordAmber.withAlpha(80), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, color: AppColors.chordAmber, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Modo Atril',
                            style: TextStyle(
                              color: AppColors.chordAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Controles de tamaño de letra A- / A+
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Text('A-', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                          tooltip: 'Reducir tamaño',
                          onPressed: _decreaseFontSize,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                        ),
                        Text(
                          '${(_fontScale * 100).round()}%',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: const Text('A+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          tooltip: 'Aumentar tamaño',
                          onPressed: _increaseFontSize,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                        ),
                      ],
                    ),

                    const SizedBox(width: 4),

                    // Botón de Colapso a cápsula
                    IconButton(
                      icon: const Icon(Icons.close_fullscreen, color: Colors.white70, size: 18),
                      tooltip: 'Contraer a cápsula',
                      onPressed: _toggleExpanded,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),

                    // Botón Menú
                    if (widget.onMenuTap != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: widget.onMenuTap,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(20),
                            border: Border.all(color: Colors.white.withAlpha(45), width: 1.0),
                          ),
                          child: Center(
                            child: widget.menuAnimationProgress != null
                                ? AnimatedIcon(
                                    icon: AnimatedIcons.menu_close,
                                    progress: widget.menuAnimationProgress!,
                                    color: AppColors.textWhite,
                                    size: 16,
                                  )
                                : const Icon(Icons.menu, color: AppColors.textWhite, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        const Divider(color: Colors.white24, height: 16, thickness: 0.8),

        // ── Cuerpo de Letras y Acordes con Scroll Vertical y 6-10 Líneas ──
        Expanded(
          child: isEmpty
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPlaceholderTap ?? widget.onMenuTap,
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Toca aquí para escribir o pegar la letra de tu canción...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: effectiveLines.length,
                  itemBuilder: (context, idx) {
                    final line = effectiveLines[idx];
                    final isCurrentLine = idx == effectiveLineIndex;
                    final isPastLine = idx < effectiveLineIndex;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: isCurrentLine
                          ? BoxDecoration(
                              color: widget.highlightColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: widget.highlightColor.withAlpha(120),
                                width: 1.0,
                              ),
                            )
                          : null,
                      child: _buildMusicStandLineItem(
                        line: line,
                        lineIndex: idx,
                        isCurrentLine: isCurrentLine,
                        isPastLine: isPastLine,
                        activeWordIndex: isCurrentLine ? widget.currentWordIndex : -1,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMusicStandLineItem({
    required LyricLine line,
    required int lineIndex,
    required bool isCurrentLine,
    required bool isPastLine,
    required int activeWordIndex,
  }) {
    if (line.isInstrumental) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onLineWordTap?.call(lineIndex, 0);
          if (isCurrentLine) widget.onWordTap?.call(0);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentLine
                ? AppColors.chordAmber.withAlpha(35)
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrentLine
                  ? AppColors.chordAmber.withAlpha(150)
                  : Colors.white24,
              width: isCurrentLine ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color: isCurrentLine ? AppColors.chordAmber : Colors.white60,
                size: (16 * _fontScale).clamp(12.0, 24.0),
              ),
              const SizedBox(width: 6),
              Text(
                line.instrumentalLabel ?? '🎸 REQUINTO / SOLO',
                style: TextStyle(
                  color: isCurrentLine ? AppColors.chordAmber : Colors.white70,
                  fontSize: (13.0 * _fontScale).clamp(10.0, 22.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double baseWordSize = 16.0 * _fontScale;
    final double baseChordSize = 12.0 * _fontScale;

    return Wrap(
      spacing: 6.0 * _fontScale,
      runSpacing: 3.0,
      children: List.generate(line.tokens.length, (idx) {
        final token = line.tokens[idx];
        final isRead = (isCurrentLine && idx < activeWordIndex) || isPastLine;
        final isCurrent = isCurrentLine && idx == activeWordIndex;

        final Color wordColor;
        final FontWeight fontWeight;
        final double fontSize;
        List<Shadow>? shadows;

        if (isCurrent) {
          wordColor = widget.highlightColor;
          fontWeight = FontWeight.bold;
          fontSize = (baseWordSize * 1.1).clamp(12.0, 32.0);
          shadows = [
            BoxShadow(
              color: widget.highlightColor.withAlpha(200),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ];
        } else if (isRead) {
          wordColor = widget.highlightColor;
          fontWeight = FontWeight.w600;
          fontSize = baseWordSize.clamp(11.0, 28.0);
        } else if (isCurrentLine) {
          wordColor = Colors.white;
          fontWeight = FontWeight.w600;
          fontSize = baseWordSize.clamp(11.0, 28.0);
        } else {
          wordColor = Colors.white70;
          fontWeight = FontWeight.w500;
          fontSize = (baseWordSize * 0.95).clamp(10.0, 26.0);
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
          final Color chordColor = (isCurrent || isRead)
              ? widget.highlightColor
              : (isCurrentLine ? AppColors.chordAmber : AppColors.chordAmber.withAlpha(180));

          tokenWidget = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chord,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: baseChordSize.clamp(9.0, 20.0),
                  fontWeight: FontWeight.bold,
                  color: chordColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(token.word, style: wordStyle),
            ],
          );
        } else {
          tokenWidget = Text(token.word, style: wordStyle);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onLineWordTap?.call(lineIndex, idx);
            if (isCurrentLine) {
              widget.onWordTap?.call(idx);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
            child: tokenWidget,
          ),
        );
      }),
    );
  }

  Widget _buildLineItem({
    required LyricLine line,
    required int lineIndex,
    required bool isCurrentLine,
    required bool isPastLine,
    bool isThirdLine = false,
    required int activeWordIndex,
    ValueChanged<int>? onWordTap,
  }) {
    if (line.isInstrumental) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onWordTap?.call(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCurrentLine
                ? AppColors.chordAmber.withAlpha(35)
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrentLine
                  ? AppColors.chordAmber.withAlpha(150)
                  : Colors.white24,
              width: isCurrentLine ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color: isCurrentLine ? AppColors.chordAmber : Colors.white60,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                line.instrumentalLabel ?? '🎸 REQUINTO / SOLO',
                style: TextStyle(
                  color: isCurrentLine ? AppColors.chordAmber : Colors.white70,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              if (isCurrentLine) ...[
                const SizedBox(width: 5),
                const Icon(Icons.touch_app, color: Colors.white60, size: 13),
              ],
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4.5,
      runSpacing: 1.5,
      children: List.generate(line.tokens.length, (idx) {
        final token = line.tokens[idx];
        final isRead = (isCurrentLine && idx < activeWordIndex) || isPastLine;
        final isCurrent = isCurrentLine && idx == activeWordIndex && activeWordIndex < line.tokens.length;

        final Color wordColor;
        final FontWeight fontWeight;
        final double fontSize;
        List<Shadow>? shadows;

        if (isCurrent) {
          wordColor = widget.highlightColor;
          fontWeight = FontWeight.bold;
          fontSize = 14.5;
          shadows = [
            BoxShadow(
              color: widget.highlightColor.withAlpha(190),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ];
        } else if (isRead) {
          wordColor = widget.highlightColor;
          fontWeight = FontWeight.w600;
          fontSize = 13.5;
        } else if (isCurrentLine) {
          wordColor = Colors.white;
          fontWeight = FontWeight.w600;
          fontSize = 13.5;
        } else if (isThirdLine) {
          wordColor = Colors.white38;
          fontWeight = FontWeight.normal;
          fontSize = 10.5;
        } else {
          wordColor = Colors.white60;
          fontWeight = FontWeight.w500;
          fontSize = 12.0;
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
          final Color chordColor = (isCurrent || isRead)
              ? widget.highlightColor
              : (isCurrentLine ? AppColors.chordAmber : AppColors.chordAmber.withAlpha(140));

          tokenWidget = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chord,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isCurrentLine ? 9.5 : (isThirdLine ? 7.5 : 8.5),
                  fontWeight: FontWeight.bold,
                  color: chordColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1.0),
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
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.5),
            child: tokenWidget,
          ),
        );
      }),
    );
  }
}
