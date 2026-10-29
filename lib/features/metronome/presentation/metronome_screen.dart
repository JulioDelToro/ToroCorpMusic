import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/metronome_controller.dart';

/// Interactive Metronome Screen for ToroCorp Music.
///
/// Features:
/// - Large BPM readout with +/- 1 BPM micro-adjusters.
/// - Continuous tempo Slider (40 - 240 BPM).
/// - Standard Time Signature chips (2/4, 3/4, 4/4, 6/8).
/// - Visual animated pendulum swinging in sync with tempo.
/// - Visual beat pulse LED row with golden amber accent on beat 1.
/// - Interactive Tap Tempo button with 2.5s window reset.
/// - Large Iniciar / Detener (Play / Stop) toggle button.
class MetronomeScreen extends StatefulWidget {
  final MetronomeController? controller;

  const MetronomeScreen({
    super.key,
    this.controller,
  });

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with SingleTickerProviderStateMixin {
  late final MetronomeController _controller;
  late final bool _ownsController;
  late final AnimationController _pendulumController;
  late final Animation<double> _pendulumAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = MetronomeController();
      _ownsController = true;
    }

    _pendulumController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (60000 / _controller.bpm).round()),
    );

    _pendulumAnimation = CurvedAnimation(
      parent: _pendulumController,
      curve: Curves.easeInOutSine,
    );

    _controller.addListener(_handleControllerStateChanged);

    if (_controller.isPlaying) {
      _startPendulum();
    }
  }

  void _handleControllerStateChanged() {
    if (!mounted) return;

    // Update pendulum swing period when BPM changes
    final targetDuration = Duration(milliseconds: (60000 / _controller.bpm).round());
    if (_pendulumController.duration != targetDuration) {
      _pendulumController.duration = targetDuration;
    }

    if (_controller.isPlaying) {
      _startPendulum();
    } else {
      if (_pendulumController.isAnimating) {
        _stopPendulum();
      }
    }

    setState(() {});
  }

  void _startPendulum() {
    _pendulumController.repeat(reverse: true);
  }

  void _stopPendulum() {
    _pendulumController.animateTo(
      0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerStateChanged);
    _pendulumController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBeat = _controller.currentBeat;
    final totalBeats = _controller.timeSignature.beatsPerBar;

    return Scaffold(
      backgroundColor: AppColors.pureBlackOled,
      appBar: AppBar(
        backgroundColor: AppColors.pureBlackOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textWhite),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metrónomo',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Precisión de Estudio • Cero Latencia',
              style: TextStyle(
                color: AppColors.chordAmber,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Mechanical Visual Pendulum
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedBuilder(
                    animation: _pendulumAnimation,
                    builder: (context, child) {
                      // Map 0.0..1.0 to angle -24 deg .. +24 deg
                      final angle = (_pendulumAnimation.value - 0.5) * 2 * (24.0 * math.pi / 180.0);
                      return CustomPaint(
                        painter: _MetronomePendulumPainter(
                          angleRad: angle,
                          bpm: _controller.bpm,
                          isActive: _controller.isPlaying,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Beat Pulse LED Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalBeats, (index) {
                  final beatIndex = index + 1;
                  final isCurrent = _controller.isPlaying && currentBeat == beatIndex;
                  final isDownbeat = beatIndex == 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      width: isCurrent ? (isDownbeat ? 28 : 22) : 18,
                      height: isCurrent ? (isDownbeat ? 28 : 22) : 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? (isDownbeat ? AppColors.chordAmber : AppColors.tunerInTuneGreen)
                            : AppColors.cardDark,
                        border: Border.all(
                          color: isCurrent
                              ? (isDownbeat ? const Color(0xFFFFD700) : const Color(0xFF69F0AE))
                              : AppColors.borderDark,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: (isDownbeat ? AppColors.chordAmber : AppColors.tunerInTuneGreen)
                                      .withValues(alpha: 0.6),
                                  blurRadius: isDownbeat ? 14 : 8,
                                  spreadRadius: isDownbeat ? 3 : 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$beatIndex',
                          style: TextStyle(
                            fontSize: isCurrent ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.black : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // 3. Large BPM Readout with +/- 1 BPM Adjustment Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrement Button (-1)
                  Material(
                    color: AppColors.surfaceDark,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.borderDark),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.textWhite, size: 28),
                      tooltip: '-1 BPM',
                      onPressed: _controller.decrementBpm,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Center BPM text & Italian tempo name
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        children: [
                          Text(
                            '${_controller.bpm}',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textWhite,
                              letterSpacing: -1.0,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _controller.tempoMarking.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.chordAmber,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Increment Button (+1)
                  Material(
                    color: AppColors.surfaceDark,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.borderDark),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.textWhite, size: 28),
                      tooltip: '+1 BPM',
                      onPressed: _controller.incrementBpm,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. Continuous Tempo Slider (40 - 240 BPM)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.chordAmber,
                  inactiveTrackColor: AppColors.cardDark,
                  thumbColor: const Color(0xFFFFD700),
                  overlayColor: AppColors.chordAmber.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: _controller.bpm.toDouble(),
                  min: 40.0,
                  max: 240.0,
                  divisions: 200,
                  onChanged: (val) => _controller.setBpm(val.round()),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Time Signature Selector Chips
              const Text(
                'COMPÁS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: MetronomeTimeSignature.values.map((sig) {
                  final isSelected = _controller.timeSignature == sig;
                  return ChoiceChip(
                    label: Text(
                      sig.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : AppColors.textWhite,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.chordAmber,
                    backgroundColor: AppColors.cardDark,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFFFD700) : AppColors.borderDark,
                    ),
                    onSelected: (selected) {
                      if (selected) _controller.setTimeSignature(sig);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 6. Tap Tempo Button
              SizedBox(
                width: 220,
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.touch_app, color: AppColors.chordAmber),
                  label: const Text(
                    'TAP TEMPO',
                    style: TextStyle(
                      color: AppColors.chordAmber,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceDark,
                    side: const BorderSide(color: AppColors.chordAmber, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _controller.tapTempo(),
                ),
              ),

              const SizedBox(height: 24),

              // 7. Play / Stop Toggle Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: Icon(
                    _controller.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                  label: Text(
                    _controller.isPlaying ? 'DETENER METRÓNOMO' : 'INICIAR METRÓNOMO',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _controller.isPlaying
                        ? AppColors.recordRed
                        : AppColors.chordAmber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                  ),
                  onPressed: _controller.togglePlay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the mechanical metronome pendulum arm and sliding weight.
class _MetronomePendulumPainter extends CustomPainter {
  final double angleRad;
  final int bpm;
  final bool isActive;

  _MetronomePendulumPainter({
    required this.angleRad,
    required this.bpm,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pivotX = size.width / 2;
    final pivotY = size.height - 16;
    final armLength = size.height - 36;

    // Draw scale tick arc in background
    final tickPaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCircle(
      center: Offset(pivotX, pivotY),
      radius: armLength,
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2 - 0.45,
      0.9,
      false,
      tickPaint,
    );

    // Save canvas for pendulum rotation around bottom pivot
    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(angleRad);

    // Pendulum rod
    final rodPaint = Paint()
      ..color = isActive ? const Color(0xFFE0E0E0) : AppColors.textSecondary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset.zero,
      Offset(0, -armLength),
      rodPaint,
    );

    // Position of counterweight depends on BPM (lower BPM = higher weight)
    // BPM range 40..240 mapped to weight position along the arm
    final normalizedBpm = (bpm - 40) / (240 - 40); // 0.0 to 1.0
    final weightDistFromPivot = armLength * (0.85 - (normalizedBpm * 0.55));

    // Metallic counterweight (trapezoid or rounded rect)
    final weightPaint = Paint()
      ..color = AppColors.chordAmber
      ..style = PaintingStyle.fill;

    final weightRect = Rect.fromCenter(
      center: Offset(0, -weightDistFromPivot),
      width: 22,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(weightRect, const Radius.circular(4)),
      weightPaint,
    );

    final weightBorderPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(weightRect, const Radius.circular(4)),
      weightBorderPaint,
    );

    canvas.restore();

    // Pivot cap at bottom
    final pivotPaint = Paint()
      ..color = AppColors.cardDark
      ..style = PaintingStyle.fill;
    final pivotBorder = Paint()
      ..color = AppColors.chordAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(pivotX, pivotY), 8, pivotPaint);
    canvas.drawCircle(Offset(pivotX, pivotY), 8, pivotBorder);
  }

  @override
  bool shouldRepaint(covariant _MetronomePendulumPainter oldDelegate) {
    return oldDelegate.angleRad != angleRad ||
        oldDelegate.bpm != bpm ||
        oldDelegate.isActive != isActive;
  }
}
