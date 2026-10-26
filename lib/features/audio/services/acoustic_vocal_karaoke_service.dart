import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

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

/// Motor de karaoke acústico en tiempo real para ToroCorp Music.
///
/// ## Comportamiento clave:
/// - **Ilumina la palabra actual** siempre que haya energía vocal por encima del umbral.
/// - **Avanza a la siguiente palabra** después de que el usuario ha cantado la actual durante
///   suficiente tiempo (estimado por longitud de sílabas). Avance suave, no brusco.
/// - **Se congela** exactamente en la palabra que se cantaba cuando el usuario para
///   (respiro, solo de guitarra, pausa). No salta, no retrocede, simplemente espera.
/// - **Reanuda** desde esa misma palabra en cuanto detecta voz de nuevo.
/// - **Cero bips ni sonidos de sistema**: el canal de audio nunca se cierra ni reconecta.
/// - Funciona sin importar si la cámara está activa o no.
class AcousticVocalKaraokeService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final StreamController<AcousticKaraokeState> _stateController =
      StreamController<AcousticKaraokeState>.broadcast();

  SongScript song;
  AcousticKaraokeState _state = const AcousticKaraokeState();

  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // ── Parámetros de VAD (ajustables) ───────────────────────────────────────
  /// dBFS por encima del cual se considera que hay voz activa.
  /// -40 dB suele funcionar bien en habitaciones normales.
  double silenceThresholdDb = -40.0;

  /// Número de muestras consecutivas con voz antes de confirmar "está cantando".
  static const int _voiceConfirmFrames = 2;

  /// Número de muestras consecutivas sin voz antes de congelar el karaoke.
  static const int _silenceConfirmFrames = 5;

  /// Tiempo mínimo que hay que cantar una palabra antes de avanzar (ms).
  static const int _minWordHoldMs = 350;

  /// Tiempo máximo por palabra — si lleva más de esto cantando, avanza sí o sí.
  static const int _maxWordHoldMs = 1800;
  // ─────────────────────────────────────────────────────────────────────────

  int _voiceFrames = 0;
  int _silenceFrames = 0;
  bool _confirmedSinging = false;

  /// Momento en que empezamos a cantar la palabra actual.
  DateTime? _wordStartTime;

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

  // ── Arranque ─────────────────────────────────────────────────────────────

  Future<bool> startTracking() async {
    if (_isRunning) return true;
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        debugPrint('ToroCorp Music: permiso de micrófono no concedido.');
        return false;
      }

      _isRunning = true;

      // Iniciar grabación de stream para habilitar el canal de audio.
      // Usamos el grabador solo para mantener el micro abierto y leer amplitud.
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );
      // startStream mantiene el canal de audio abierto sin guardar archivo.
      final stream = await _audioRecorder.startStream(config);
      // Descartamos el stream de bytes; usamos onAmplitudeChanged.
      stream.listen((_) {}, onError: (_) {});

      // Leer amplitud cada 80 ms — frecuencia suficiente para karaoke fluido.
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen(_handleAmplitude);

      debugPrint('ToroCorp Music: motor de karaoke acústico activo.');
      return true;
    } catch (e) {
      debugPrint('ToroCorp Music: error al iniciar karaoke acústico: $e');
      _isRunning = false;
      return false;
    }
  }

  // ── Procesado de amplitud ─────────────────────────────────────────────────

  void _handleAmplitude(Amplitude amp) {
    final double db = amp.current;
    final bool hasVoice = db > silenceThresholdDb;

    if (hasVoice) {
      _voiceFrames++;
      _silenceFrames = 0;
    } else {
      _silenceFrames++;
      _voiceFrames = 0;
    }

    if (!_confirmedSinging && _voiceFrames >= _voiceConfirmFrames) {
      // Transición: silencio → cantando
      _confirmedSinging = true;
      _wordStartTime ??= DateTime.now();
      _emitSinging(db);
    } else if (_confirmedSinging && _silenceFrames >= _silenceConfirmFrames) {
      // Transición: cantando → silencio / pausa
      _confirmedSinging = false;
      _wordStartTime = null;
      _emitWaiting(db);
    } else if (_confirmedSinging) {
      // Sigue cantando: evaluar si ya es hora de avanzar la palabra.
      _tryAdvanceWord(db);
    }
  }

  void _emitSinging(double db) {
    _state = _state.copyWith(
      isSinging: true,
      isWaitingForVoice: false,
      volumeDb: db,
      vocalEnergy: _normalizeEnergy(db),
    );
    _stateController.add(_state);
  }

  void _emitWaiting(double db) {
    _state = _state.copyWith(
      isSinging: false,
      isWaitingForVoice: true,
      volumeDb: db,
      vocalEnergy: 0.0,
    );
    _stateController.add(_state);
  }

  void _tryAdvanceWord(double db) {
    // Actualizar estado visual (sigue iluminado)
    _state = _state.copyWith(
      isSinging: true,
      isWaitingForVoice: false,
      volumeDb: db,
      vocalEnergy: _normalizeEnergy(db),
    );
    _stateController.add(_state);

    // Calcular cuánto tiempo llevamos cantando la palabra actual.
    final now = DateTime.now();
    final heldMs = _wordStartTime != null
        ? now.difference(_wordStartTime!).inMilliseconds
        : 0;

    // Estimar duración esperada de la palabra según su longitud.
    final int targetMs = _wordDurationMs();

    if (heldMs >= targetMs) {
      _advanceWord();
      _wordStartTime = now; // Reiniciar temporizador para la siguiente palabra
    }
  }

  /// Estima la duración (ms) que se debería cantar la palabra actual.
  int _wordDurationMs() {
    final lines = song.lines;
    if (lines.isEmpty) return _minWordHoldMs;
    final lineIdx = _state.lineIndex.clamp(0, lines.length - 1);
    final tokens = lines[lineIdx].tokens;
    if (tokens.isEmpty) return _minWordHoldMs;
    final wordIdx = _state.wordIndex.clamp(0, tokens.length - 1);
    final word = tokens[wordIdx].word.replaceAll(RegExp(r'[^a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]'), '');
    // Aproximación de sílabas: ~1 sílaba cada 2 caracteres vocálicos.
    final int syllables = _countSyllables(word);
    // Cada sílaba cantada dura aprox 250-400 ms.
    return (syllables * 300).clamp(_minWordHoldMs, _maxWordHoldMs);
  }

  int _countSyllables(String word) {
    if (word.isEmpty) return 1;
    final vowels = RegExp(r'[aeiouáéíóúüAEIOUÁÉÍÓÚÜ]');
    final count = vowels.allMatches(word).length;
    return count < 1 ? 1 : count;
  }

  void _advanceWord() {
    final lines = song.lines;
    if (lines.isEmpty) return;

    int line = _state.lineIndex;
    int word = _state.wordIndex + 1;

    if (line >= lines.length) return;

    if (word >= lines[line].tokens.length) {
      // Fin de verso: pasar al siguiente.
      if (line + 1 < lines.length) {
        line++;
        word = 0;
      } else {
        // Última palabra: quedarse aquí.
        return;
      }
    }

    _state = _state.copyWith(
      lineIndex: line,
      wordIndex: word,
      isSinging: true,
      isWaitingForVoice: false,
    );
    _stateController.add(_state);
  }

  double _normalizeEnergy(double db) {
    return ((db - silenceThresholdDb) / (0.0 - silenceThresholdDb)).clamp(0.0, 1.0);
  }

  // ── Control manual (toque en pantalla) ───────────────────────────────────

  void nextWordManual() {
    _wordStartTime = DateTime.now();
    _advanceWord();
  }

  void previousWordManual() {
    int line = _state.lineIndex;
    int word = _state.wordIndex - 1;
    if (word < 0) {
      if (line > 0) {
        line--;
        word = song.lines[line].tokens.length - 1;
      } else {
        word = 0;
      }
    }
    _wordStartTime = DateTime.now();
    _state = _state.copyWith(lineIndex: line, wordIndex: word, isSinging: false, isWaitingForVoice: true);
    _stateController.add(_state);
  }

  void reset() {
    _voiceFrames = 0;
    _silenceFrames = 0;
    _confirmedSinging = false;
    _wordStartTime = null;
    _state = const AcousticKaraokeState();
    _stateController.add(_state);
  }

  Future<void> dispose() async {
    _isRunning = false;
    await _amplitudeSubscription?.cancel();
    await _audioRecorder.dispose();
    await _stateController.close();
  }
}
