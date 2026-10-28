import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../models/tuning_note.dart';
import '../services/pitch_detector.dart';
import '../widgets/guitar_visualizer_widget.dart';

/// Pantalla de afinador de guitarra estilo GuitarTuna (6 y 12 cuerdas / Docerola).
/// 100% código propio vectorial en Flutter, comercialmente vendible.
class GuitarTunerScreen extends StatefulWidget {
  const GuitarTunerScreen({super.key});

  @override
  State<GuitarTunerScreen> createState() => _GuitarTunerScreenState();
}

class _GuitarTunerScreenState extends State<GuitarTunerScreen> {
  final PitchDetector _pitchDetector = PitchDetector();
  AudioRecorder? _audioRecorder;
  AudioRecorder get _recorder => _audioRecorder ??= AudioRecorder();
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  GuitarType _selectedGuitarType = GuitarType.sixString;
  int? _lockedStringIndex; // null = Modo Automático (AUTOM.), 1..6 o 1..12 = cuerda fija
  final List<int> _pcmBuffer = [];

  TuningResult _currentResult = const TuningResult(
    detectedFrequency: 0,
    closestNote: '--',
    targetFrequency: 0,
    centsOffset: 0,
    isInTune: false,
  );

  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _isListening = false;
    _recordStreamSubscription?.cancel();
    _stopAndDisposeRecorder();
    super.dispose();
  }

  Future<void> _stopAndDisposeRecorder() async {
    try {
      await _audioRecorder?.stop();
    } catch (_) {}
    try {
      await _audioRecorder?.dispose();
    } catch (_) {}
    _audioRecorder = null;
  }

  Future<void> _startListening() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        debugPrint('ToroCorp Music Afinador: Permiso de micrófono denegado');
        return;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 22050,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);
      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }

      _recordStreamSubscription = stream.listen(
        _processAudioChunk,
        onError: (err) {
          debugPrint('ToroCorp Music: Error en stream del afinador: $err');
        },
      );
    } catch (e) {
      debugPrint('ToroCorp Music: Error iniciando afinador: $e');
    }
  }

  void _processAudioChunk(Uint8List chunk) {
    if (!mounted || !_isListening) return;

    _pcmBuffer.addAll(chunk);

    const minBufferSize = 4096;
    if (_pcmBuffer.length >= minBufferSize) {
      final slice = Uint8List.fromList(_pcmBuffer.sublist(0, minBufferSize));
      _pcmBuffer.removeRange(0, minBufferSize ~/ 2);

      final detectedFreq = PitchDetector.detectPitchFromPcm16(
        slice,
        sampleRate: 22050,
      );

      if (detectedFreq > 0) {
        _updateFrequency(detectedFreq);
      } else {
        if (_currentResult.detectedFrequency > 0) {
          setState(() {
            _currentResult = _pitchDetector.analyzeFrequency(
              0,
              guitarType: _selectedGuitarType,
              lockedStringIndex: _lockedStringIndex,
            );
          });
        }
      }
    }
  }

  void _updateFrequency(double freq) {
    if (!mounted) return;
    setState(() {
      _currentResult = _pitchDetector.analyzeFrequency(
        freq,
        guitarType: _selectedGuitarType,
        lockedStringIndex: _lockedStringIndex,
      );
    });
  }

  void _selectString(int? index) {
    setState(() {
      _lockedStringIndex = index;
      _currentResult = _pitchDetector.analyzeFrequency(
        0,
        guitarType: _selectedGuitarType,
        lockedStringIndex: _lockedStringIndex,
      );
    });
  }

  void _toggleGuitarType() {
    setState(() {
      if (_selectedGuitarType == GuitarType.sixString) {
        _selectedGuitarType = GuitarType.twelveString;
      } else {
        _selectedGuitarType = GuitarType.sixString;
      }
      _lockedStringIndex = null;
      _currentResult = _pitchDetector.analyzeFrequency(
        0,
        guitarType: _selectedGuitarType,
        lockedStringIndex: null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDetected = _currentResult.detectedFrequency > 0;
    final inTune = _currentResult.isInTune;
    final cents = _currentResult.centsOffset;

    Color stateColor;
    if (!isDetected) {
      stateColor = const Color(0xFF00D084);
    } else if (inTune) {
      stateColor = const Color(0xFF00D084); // Verde GuitarTuna
    } else if (cents < -3.5) {
      stateColor = const Color(0xFFFF9F0A); // Ámbar grave
    } else {
      stateColor = const Color(0xFFFF453A); // Rojo aguda
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121518), // Fondo negro profundo con tono GuitarTuna
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Barra Superior con Título y Micrófono ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: isDetected
                        ? Row(
                            children: [
                              Text(
                                _currentResult.closestNote,
                                style: TextStyle(
                                  color: inTune ? const Color(0xFF00D084) : Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                inTune
                                    ? '✓ AFINADA'
                                    : (cents < -3.5 ? '▲ APRETAR' : '▼ AFLOJAR'),
                                style: TextStyle(
                                  color: stateColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Comienza a afinar',
                                style: TextStyle(
                                  color: Color(0xFF00D084),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'tocando cualquier cuerda',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? const Color(0xFF00D084).withAlpha(40)
                          : Colors.white.withAlpha(15),
                      border: Border.all(
                        color: _isListening
                            ? const Color(0xFF00D084)
                            : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: _isListening ? const Color(0xFF00D084) : Colors.white54,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Fila de Selector de Instrumento y Switch AUTOM. ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleGuitarType,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedGuitarType == GuitarType.sixString
                              ? 'Guitarra 6 cuerdas'
                              : 'Guitarra 12 cuerdas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
                      ],
                    ),
                  ),

                  // Switch AUTOM. (Modo automático)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AUTOM.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          value: _lockedStringIndex == null,
                          activeTrackColor: const Color(0xFF00D084),
                          onChanged: (bool value) {
                            setState(() {
                              _lockedStringIndex = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 3. Rejilla y Medidor de Dial GuitarTuna con ♭ y ♯ ──
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  // Cuadrícula y dial circular central
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TuningGridDialPainter(
                        centsOffset: cents,
                        isDetected: isDetected,
                        isInTune: inTune,
                        stateColor: stateColor,
                      ),
                    ),
                  ),

                  // Pill Banner flotante debajo del dial
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 6,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF212529).withAlpha(220),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDetected ? stateColor.withAlpha(120) : Colors.white.withAlpha(25),
                            width: 1.0,
                          ),
                          boxShadow: isDetected
                              ? [
                                  BoxShadow(
                                    color: stateColor.withAlpha(40),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          !isDetected
                              ? 'Toca cualquier cuerda para comenzar a afinar'
                              : '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents  •  ${_currentResult.detectedFrequency.toStringAsFixed(1)} Hz',
                          style: TextStyle(
                            color: isDetected ? stateColor : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. Guitarra Visual Interactiva (Pala, Clavijas y Cuerdas) ──
            Expanded(
              child: GuitarVisualizerWidget(
                guitarType: _selectedGuitarType,
                lockedStringIndex: _lockedStringIndex,
                detectedStringIndex: _currentResult.targetStringIndex,
                currentResult: _currentResult,
                onSelectString: _selectString,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja la rejilla milimétrica y el dial central con ♭, ♯ y aguja dinámica estilo GuitarTuna.
class _TuningGridDialPainter extends CustomPainter {
  final double centsOffset;
  final bool isDetected;
  final bool isInTune;
  final Color stateColor;

  _TuningGridDialPainter({
    required this.centsOffset,
    required this.isDetected,
    required this.isInTune,
    required this.stateColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final centerY = h * 0.40;

    // ── 1. Cuadrícula de Fondo (Grid Milimétrico) ──
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 0.8;

    const gridSpacing = 22.0;
    // Líneas verticales de cuadrícula
    for (double x = (w / 2) % gridSpacing; x < w; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h - 30), gridPaint);
    }
    // Líneas horizontales de cuadrícula
    for (double y = 0; y < h - 30; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Línea guía vertical central (Cero cents)
    final centerLinePaint = Paint()
      ..color = Colors.white.withAlpha(35)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h - 30), centerLinePaint);

    // ── 2. Letras ♭ (Bemol) y ♯ (Sostenido) a los Costados ──
    final textPainterFlat = TextPainter(
      text: const TextSpan(
        text: '♭',
        style: TextStyle(
          color: Color(0xFF8B949E),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterFlat.paint(canvas, Offset(24, centerY - 14));

    final textPainterSharp = TextPainter(
      text: const TextSpan(
        text: '♯',
        style: TextStyle(
          color: Color(0xFF8B949E),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterSharp.paint(canvas, Offset(w - 38, centerY - 14));

    // ── 3. Dial Circular Central (Objetivo de Afinación) ──
    final ringRadius = 16.0;
    final ringCenter = Offset(w / 2, centerY);

    final ringPaint = Paint()
      ..color = isInTune ? const Color(0xFF00D084) : const Color(0xFF5A626C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    if (isInTune) {
      final glowRing = Paint()
        ..color = const Color(0xFF00D084).withAlpha(140)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(ringCenter, ringRadius, glowRing);
    }

    canvas.drawCircle(ringCenter, ringRadius, ringPaint);

    // Puntero triangular hacia abajo en la base del círculo (v)
    final pointerPath = Path();
    pointerPath.moveTo(w / 2 - 5, centerY + ringRadius - 1);
    pointerPath.lineTo(w / 2 + 5, centerY + ringRadius - 1);
    pointerPath.lineTo(w / 2, centerY + ringRadius + 7);
    pointerPath.close();

    final pointerPaint = Paint()
      ..color = isInTune ? const Color(0xFF00D084) : const Color(0xFF5A626C)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointerPath, pointerPaint);

    // ── 4. Aguja Dinámica Indicadora de Desviación (-50 a +50 cents) ──
    if (isDetected) {
      // Mapear desviación de cents a coordenadas horizontales (entre 48 y w - 48)
      final minX = 52.0;
      final maxX = w - 52.0;
      final double normalized = ((centsOffset.clamp(-50.0, 50.0) + 50.0) / 100.0);
      final double needleX = minX + (normalized * (maxX - minX));

      // Línea vertical brillante de la aguja
      final needleGlow = Paint()
        ..color = stateColor.withAlpha(160)
        ..strokeWidth = 4.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawLine(Offset(needleX, 4), Offset(needleX, h - 36), needleGlow);

      final needleLine = Paint()
        ..color = stateColor
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(needleX, 4), Offset(needleX, h - 36), needleLine);

      // Si está afinada en el centro: destello blanco
      if (isInTune) {
        final coreFlash = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.4;
        canvas.drawLine(Offset(needleX, 8), Offset(needleX, h - 40), coreFlash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TuningGridDialPainter oldDelegate) {
    return oldDelegate.centsOffset != centsOffset ||
        oldDelegate.isDetected != isDetected ||
        oldDelegate.isInTune != isInTune ||
        oldDelegate.stateColor != stateColor;
  }
}
