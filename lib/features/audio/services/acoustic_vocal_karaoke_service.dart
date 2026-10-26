import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../scripts/models/lyric_token.dart';
import '../../scripts/models/song_script.dart';

/// Estado en tiempo real del motor de karaoke acústico.
class AcousticKaraokeState {
  final int lineIndex;
  final int wordIndex;
  final bool isSinging;
  final double volumeDb;
  final bool isWaitingForVoice;
  final double vocalEnergy;

  const AcousticKaraokeState({
    this.lineIndex = 0,
    this.wordIndex = 0,
    this.isSinging = false,
    this.volumeDb = -60.0,
    this.isWaitingForVoice = true,
    this.vocalEnergy = 0.0,
  });

  AcousticKaraokeState copyWith({
    int? lineIndex,
    int? wordIndex,
    bool? isSinging,
    double? volumeDb,
    bool? isWaitingForVoice,
    double? vocalEnergy,
  }) {
    return AcousticKaraokeState(
      lineIndex: lineIndex ?? this.lineIndex,
      wordIndex: wordIndex ?? this.wordIndex,
      isSinging: isSinging ?? this.isSinging,
      volumeDb: volumeDb ?? this.volumeDb,
      isWaitingForVoice: isWaitingForVoice ?? this.isWaitingForVoice,
      vocalEnergy: vocalEnergy ?? this.vocalEnergy,
    );
  }
}

/// Motor de seguimiento vocal en tiempo real para Karaoke y Teleprompter de ToroCorp Music.
/// 
/// Características clave:
/// 1. Cero bips o sonidos de desconexión del sistema: mantiene el canal de audio abierto limpiamente.
/// 2. Detección de actividad vocal (VAD) acústica en tiempo real.
/// 3. Espera paciente: cuando el cantante se detiene o pausa (solo de guitarra, respiración),
///    el teleprompter se congela en la palabra exacta y lo espera.
/// 4. Avance automático: cuando la voz continúa cantando, avanza de palabra e ilumina la letra;
///    al completar el verso, pasa automáticamente a la siguiente línea de la canción.
/// 5. Funciona de manera independiente a la cámara (con cámara activa o desactivada).
class AcousticVocalKaraokeService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final StreamController<AcousticKaraokeState> _stateController =
      StreamController<AcousticKaraokeState>.broadcast();

  SongScript song;
  AcousticKaraokeState _state = const AcousticKaraokeState();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // Parámetros de detección acústica
  double _silenceThresholdDb = -42.0; // dBFS por debajo del cual se considera silencio
  int _consecutiveSingingFrames = 0;
  int _consecutiveSilenceFrames = 0;
  DateTime _lastWordAdvanceTime = DateTime.now();
  bool _isRunning = false;

  AcousticVocalKaraokeService({required this.song}) {
    _stateController.add(_state);
  }

  Stream<AcousticKaraokeState> get stateStream => _stateController.stream;
  AcousticKaraokeState get currentState => _state;
  bool get isRunning => _isRunning;

  void updateSong(SongScript newSong) {
    song = newSong;
    reset();
  }

  void setSilenceThreshold(double thresholdDb) {
    _silenceThresholdDb = thresholdDb;
  }

  /// Inicia la escucha continua de micrófono sin cortes ni sonidos del sistema
  Future<bool> startTracking() async {
    if (_isRunning) return true;

    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        debugPrint('ToroCorp Music: Permiso de micrófono no concedido');
        return false;
      }

      _isRunning = true;
      _lastWordAdvanceTime = DateTime.now();

      // Iniciar captura PCM de audio en tiempo real
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      _audioStreamSubscription = stream.listen(
        _processAudioBuffer,
        onError: (err) {
          debugPrint('ToroCorp Music: Stream audio error: $err');
        },
      );

      // También monitorear amplitud oficial cada 60ms como respaldo
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 60))
          .listen((amp) {
        _processAmplitude(amp.current);
      });

      debugPrint('ToroCorp Music: Motor de Karaoke Acústico iniciado exitosamente');
      return true;
    } catch (e) {
      debugPrint('ToroCorp Music: Error iniciando seguimiento acústico: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Procesa buffer de audio PCM 16-bit para calcular RMS y energía vocal
  void _processAudioBuffer(Uint8List buffer) {
    if (buffer.length < 2) return;

    // Calcular RMS de las muestras PCM 16-bit
    double sumSquares = 0.0;
    int samplesCount = buffer.length ~/ 2;
    int zeroCrossings = 0;
    int prevSample = 0;

    for (int i = 0; i < buffer.length - 1; i += 2) {
      // Little-endian 16-bit signed integer
      int sample = (buffer[i + 1] << 8) | buffer[i];
      if (sample >= 32768) sample -= 65536;

      sumSquares += sample * sample;

      if ((sample > 0 && prevSample <= 0) || (sample < 0 && prevSample >= 0)) {
        zeroCrossings++;
      }
      prevSample = sample;
    }

    final double rms = math.sqrt(sumSquares / samplesCount);
    // Convertir RMS a dBFS aproximado (-100 a 0 dB)
    final double db = rms > 0.0001
        ? 20 * (math.log(rms / 32768.0) / math.ln10)
        : -100.0;

    // Zero-crossing rate: la voz cantada tiene un ZCR moderado en comparación con ruido blanco
    final double zcr = zeroCrossings / samplesCount;
    final bool isVocalSignal = db > _silenceThresholdDb && zcr < 0.45;

    _evaluateVocalActivity(db, isVocalSignal);
  }

  /// Respaldo de amplitud
  void _processAmplitude(double currentDb) {
    if (currentDb > -120.0) {
      final isVocalSignal = currentDb > _silenceThresholdDb;
      _evaluateVocalActivity(currentDb, isVocalSignal);
    }
  }

  /// Evalúa si el usuario está cantando o en silencio, y avanza o espera pacientemente
  void _evaluateVocalActivity(double db, bool isVocal) {
    if (isVocal) {
      _consecutiveSingingFrames++;
      _consecutiveSilenceFrames = 0;
    } else {
      _consecutiveSilenceFrames++;
      _consecutiveSingingFrames = 0;
    }

    // Se considera cantando si hay al menos 2 frames consecutivos con energía vocal
    final bool isCurrentlySinging = _consecutiveSingingFrames >= 2;
    final bool isCurrentlySilent = _consecutiveSilenceFrames >= 3;

    if (isCurrentlySinging) {
      // Cantando: avanzamos el karaoke conforme a la duración y ritmo de la palabra
      _onVoiceDetected(db);
    } else if (isCurrentlySilent) {
      // Silencio o pausa: nos congelamos en la palabra actual y lo esperamos
      _onSilenceDetected(db);
    }
  }

  void _onVoiceDetected(double db) {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastWordAdvanceTime).inMilliseconds;

    final lines = song.lines;
    if (lines.isEmpty) return;

    int currentLine = _state.lineIndex;
    int currentWord = _state.wordIndex;

    if (currentLine >= lines.length) return;

    final currentTokens = lines[currentLine].tokens;
    if (currentTokens.isEmpty) return;

    // Estimar duración natural de la palabra según cantidad de sílabas/caracteres
    final LyricToken activeToken = currentTokens[currentWord.clamp(0, currentTokens.length - 1)];
    final int wordLength = activeToken.word.length;
    // Base de tiempo: palabras cortas (2-3 letras) ~300ms; palabras largas ~650ms
    final int requiredSungDurationMs = (wordLength * 70).clamp(280, 750);

    bool shouldAdvanceWord = false;

    if (elapsedMs >= requiredSungDurationMs) {
      shouldAdvanceWord = true;
      _lastWordAdvanceTime = now;
    }

    if (shouldAdvanceWord) {
      int nextWord = currentWord + 1;
      int nextLine = currentLine;

      if (nextWord >= currentTokens.length) {
        // Fin del verso actual: pasar al siguiente verso de la canción
        if (nextLine + 1 < lines.length) {
          nextLine++;
          nextWord = 0;
        } else {
          // Último verso completado
          nextWord = currentTokens.length - 1;
        }
      }

      _state = _state.copyWith(
        lineIndex: nextLine,
        wordIndex: nextWord,
        isSinging: true,
        volumeDb: db,
        isWaitingForVoice: false,
        vocalEnergy: ((db + 60) / 60).clamp(0.0, 1.0),
      );
    } else {
      // Mantener la palabra actual pero con estado iluminado activo
      _state = _state.copyWith(
        isSinging: true,
        volumeDb: db,
        isWaitingForVoice: false,
        vocalEnergy: ((db + 60) / 60).clamp(0.0, 1.0),
      );
    }

    _stateController.add(_state);
  }

  void _onSilenceDetected(double db) {
    if (!_state.isWaitingForVoice || _state.isSinging) {
      // Entró en pausa o silencio: detener el avance y esperar en esta misma palabra
      _state = _state.copyWith(
        isSinging: false,
        volumeDb: db,
        isWaitingForVoice: true,
        vocalEnergy: 0.0,
      );
      _stateController.add(_state);
    }
  }

  /// Avance manual si el usuario toca la pantalla
  void nextWordManual() {
    final lines = song.lines;
    if (lines.isEmpty) return;

    int nextWord = _state.wordIndex + 1;
    int nextLine = _state.lineIndex;

    if (nextWord >= lines[nextLine].tokens.length) {
      if (nextLine + 1 < lines.length) {
        nextLine++;
        nextWord = 0;
      } else {
        return;
      }
    }

    _lastWordAdvanceTime = DateTime.now();
    _state = _state.copyWith(
      lineIndex: nextLine,
      wordIndex: nextWord,
      isSinging: true,
      isWaitingForVoice: false,
    );
    _stateController.add(_state);
  }

  /// Retroceso manual si el usuario retrocede
  void previousWordManual() {
    int prevWord = _state.wordIndex - 1;
    int prevLine = _state.lineIndex;

    if (prevWord < 0) {
      if (prevLine > 0) {
        prevLine--;
        prevWord = song.lines[prevLine].tokens.length - 1;
      } else {
        prevWord = 0;
      }
    }

    _lastWordAdvanceTime = DateTime.now();
    _state = _state.copyWith(
      lineIndex: prevLine,
      wordIndex: prevWord,
      isSinging: false,
      isWaitingForVoice: true,
    );
    _stateController.add(_state);
  }

  /// Reinicia al principio de la canción
  void reset() {
    _lastWordAdvanceTime = DateTime.now();
    _state = const AcousticKaraokeState();
    _stateController.add(_state);
  }

  /// Detiene el motor y libera recursos
  Future<void> dispose() async {
    _isRunning = false;
    await _audioStreamSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    await _audioRecorder.dispose();
    await _stateController.close();
  }
}
