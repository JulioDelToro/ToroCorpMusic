import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/tuning_note.dart';
import '../services/pitch_detector.dart';
import '../widgets/guitar_visualizer_widget.dart';

/// Pantalla dedicada de afinador de guitarra para 6 y 12 cuerdas.
/// Permite afinar cuerda por cuerda con retroalimentación visual precisa en tiempo real.
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
  int? _lockedStringIndex; // null = Modo Automático, 1..6 o 1..12 = cuerda fija
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

    // Cada ~2048 muestras (4096 bytes a 22050 Hz = ~92ms), analizamos la frecuencia
    const minBufferSize = 4096;
    if (_pcmBuffer.length >= minBufferSize) {
      final slice = Uint8List.fromList(_pcmBuffer.sublist(0, minBufferSize));
      _pcmBuffer.removeRange(0, minBufferSize ~/ 2); // 50% de solapamiento para respuesta ágil

      final detectedFreq = PitchDetector.detectPitchFromPcm16(
        slice,
        sampleRate: 22050,
      );

      if (detectedFreq > 0) {
        _updateFrequency(detectedFreq);
      } else {
        // Silencio o decaimiento de la cuerda
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
      if (index != null) {
        // Inicializar indicador en la nota seleccionada
        _currentResult = _pitchDetector.analyzeFrequency(
          0,
          guitarType: _selectedGuitarType,
          lockedStringIndex: _lockedStringIndex,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlackOled,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textWhite, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text('Afinador de Guitarra', style: AppTypography.sfProHeadline(fontSize: 17)),
            const Text(
              'ToroCorp Music',
              style: TextStyle(color: AppColors.chordAmber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppColors.tunerInTuneGreen : AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Selector: 6 Cuerdas vs 12 Cuerdas
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeSegment(
                      title: '6 Cuerdas',
                      subtitle: 'Guitarra Estándar',
                      isSelected: _selectedGuitarType == GuitarType.sixString,
                      onTap: () {
                        setState(() {
                          _selectedGuitarType = GuitarType.sixString;
                          _lockedStringIndex = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTypeSegment(
                      title: '12 Cuerdas',
                      subtitle: 'Docerola / Acústica',
                      isSelected: _selectedGuitarType == GuitarType.twelveString,
                      onTap: () {
                        setState(() {
                          _selectedGuitarType = GuitarType.twelveString;
                          _lockedStringIndex = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Medidor Central de Cents y Aguja
            Expanded(
              child: _buildGaugeDisplay(),
            ),

            // Guitarra Visual Interactiva con Pastillas Seleccionables y Cuerdas en Color
            GuitarVisualizerWidget(
              guitarType: _selectedGuitarType,
              lockedStringIndex: _lockedStringIndex,
              detectedStringIndex: _currentResult.targetStringIndex,
              currentResult: _currentResult,
              onSelectString: _selectString,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.chordAmber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.black87 : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeDisplay() {
    final cents = _currentResult.centsOffset;
    final inTune = _currentResult.isInTune;
    final isDetected = _currentResult.detectedFrequency > 0;

    Color stateColor;
    String statusText;

    if (!isDetected) {
      stateColor = AppColors.textSecondary;
      statusText = _lockedStringIndex != null
          ? 'Toca la cuerda $_lockedStringIndexª para afinar'
          : 'Toca una cuerda de la guitarra';
    } else if (inTune) {
      stateColor = AppColors.tunerInTuneGreen;
      statusText = '✓ AFINADA PERFECTA';
    } else if (cents < -3.5) {
      stateColor = const Color(0xFFFF9F0A);
      statusText = '▲ MUY GRAVE (Apretar clavija)';
    } else {
      stateColor = const Color(0xFFFF453A);
      statusText = '▼ MUY AGUDA (Aflojar clavija)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nota Principal en Letra Grande
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              color: stateColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stateColor.withAlpha(120), width: 1.8),
              boxShadow: inTune
                  ? [
                      BoxShadow(
                        color: stateColor.withAlpha(160),
                        blurRadius: 20,
                        spreadRadius: 3,
                      )
                    ]
                  : null,
            ),
            child: Text(
              _currentResult.closestNote,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: inTune ? AppColors.tunerInTuneGreen : AppColors.textWhite,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Frecuencia en Hz y Meta
          Text(
            isDetected
                ? '${_currentResult.detectedFrequency.toStringAsFixed(1)} Hz  •  Meta: ${_currentResult.targetFrequency.toStringAsFixed(1)} Hz'
                : 'Esperando sonido...',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          // Barra / Aguja de Afinación (-50 a +50 cents)
          Column(
            children: [
              // Marcas de regla (-50, -25, 0, +25, +50)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('-50', style: TextStyle(color: Colors.white30, fontSize: 9)),
                    Text('-25', style: TextStyle(color: Colors.white30, fontSize: 9)),
                    Text('0', style: TextStyle(color: AppColors.tunerInTuneGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('+25', style: TextStyle(color: Colors.white30, fontSize: 9)),
                    Text('+50', style: TextStyle(color: Colors.white30, fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Riel y Aguja Dinámica
              SizedBox(
                height: 32,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Mapear cents (-50 a +50) a posición horizontal (0 a width)
                    final double normalized = ((cents.clamp(-50.0, 50.0) + 50.0) / 100.0);
                    final double needleX = (normalized * width).clamp(8.0, width - 8.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Riel de fondo
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        // Zona central afinada (verde)
                        Container(
                          width: 22,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.tunerInTuneGreen.withAlpha(120),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        // Aguja indicadora
                        Positioned(
                          left: needleX - 3,
                          child: Column(
                            children: [
                              Container(
                                width: 6,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: stateColor,
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: stateColor.withAlpha(200),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 3),
              Text(
                isDetected ? '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents' : '0.0 cents',
                style: TextStyle(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Banner de Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: stateColor.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stateColor.withAlpha(100)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: stateColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
