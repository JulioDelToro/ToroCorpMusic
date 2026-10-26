import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

/// Motor acústico de karaoke en tiempo real para ToroCorp Music.
/// 
/// Características:
/// 1. Compatible con AudioSession (evita que el sistema operativo o la cámara silencien el micrófono).
/// 2. Captura estable mediante MediaRecorder nativo en caché temporal.
/// 3. Calibración automática del piso de ruido ambiental (adaptive noise floor).
/// 4. Espera paciente en pausas y requintos: si el cantante deja de cantar para tocar la guitarra,
///    el teleprompter se congela inmediatamente en esa palabra exacta y espera pacientemente.
/// 5. Avance natural por sílabas al cantar.
class AcousticVocalKaraokeService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final StreamController<AcousticKaraokeState> _stateController =
      StreamController<AcousticKaraokeState>.broadcast();

  SongScript song;
  AcousticKaraokeState _state = const AcousticKaraokeState();

  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // ── Parámetros de Detección Vocal (VAD) ──────────────────────────────────
  /// Umbral base definido por el usuario (-60 dB = muy sensible, -20 dB = poco sensible)
  double silenceThresholdDb = -40.0;

  /// Piso de ruido calibrado automáticamente al inicio
  double _ambientFloorDb = -60.0;
  int _calibrationFrames = 0;
  static const int _maxCalibrationFrames = 8;

  /// Muestras consecutivas para confirmar canto / pausa
  static const int _voiceConfirmFrames = 2; // ~100 ms
  static const int _silenceConfirmFrames = 3; // ~150 ms

  /// Límites de duración por palabra (ms)
  static const int _minWordHoldMs = 280;
  static const int _maxWordHoldMs = 1800;
  // ────────────────────────────────────────────────────────────────────────

  int _voiceFrames = 0;
  int _silenceFrames = 0;
  bool _confirmedSinging = false;
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

  /// Inicia el seguimiento continuo con sesión de audio configurada
  Future<bool> startTracking() async {
    if (_isRunning) return true;

    try {
      // 1. Configurar AudioSession para grabación compatible con cámara
      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.videoRecording,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        ));
        await session.setActive(true);
      } catch (e) {
        debugPrint('ToroCorp Music: Info AudioSession: $e');
      }

      // 2. Verificar permisos
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        debugPrint('ToroCorp Music: Permiso de micrófono no otorgado');
        return false;
      }

      _isRunning = true;
      _calibrationFrames = 0;
      _ambientFloorDb = -60.0;

      // 3. Crear archivo temporal en caché para MediaRecorder (100% compatible Android/iOS)
      String cachePath = '';
      try {
        final tempDir = await getTemporaryDirectory();
        final cacheFile = File('${tempDir.path}/toro_mic_karaoke.m4a');
        if (await cacheFile.exists()) {
          try {
            await cacheFile.delete();
          } catch (_) {}
        }
        cachePath = cacheFile.path;
      } catch (_) {
        cachePath = '';
      }

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      );

      // Iniciar sesión de grabación
      if (cachePath.isNotEmpty) {
        await _audioRecorder.start(config, path: cachePath);
      } else {
        await _audioRecorder.start(config, path: '');
      }

      // 4. Monitorear amplitud cada 50 milisegundos para latencia ultra baja
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 50))
          .listen(
        _handleAmplitude,
        onError: (err) {
          debugPrint('ToroCorp Music: Error en amplitud: $err');
        },
      );

      debugPrint('ToroCorp Music: Motor acústico iniciado exitosamente');
      return true;
    } catch (e) {
      debugPrint('ToroCorp Music: Error al iniciar motor acústico: $e');
      _isRunning = false;
      return false;
    }
  }

  void _handleAmplitude(Amplitude amp) {
    final double db = amp.current;

    // Calibración adaptativa inicial del piso de ruido de la habitación
    if (_calibrationFrames < _maxCalibrationFrames && db > -100.0) {
      _calibrationFrames++;
      if (db > _ambientFloorDb) {
        _ambientFloorDb = db;
      }
      return;
    }

    // El umbral efectivo toma en cuenta el ruido de la habitación y el ajuste del usuario
    final double effectiveThreshold = math.max(_ambientFloorDb + 5.0, silenceThresholdDb);
    final bool hasVoice = db > effectiveThreshold;

    if (hasVoice) {
      _voiceFrames++;
      _silenceFrames = 0;
    } else {
      _silenceFrames++;
      _voiceFrames = 0;
    }

    if (!_confirmedSinging && _voiceFrames >= _voiceConfirmFrames) {
      // Transición: silencio -> cantando
      _confirmedSinging = true;
      _wordStartTime ??= DateTime.now();
      _emitSinging(db, effectiveThreshold);
    } else if (_confirmedSinging && _silenceFrames >= _silenceConfirmFrames) {
      // Transición: cantando -> pausa o requinto de guitarra
      _confirmedSinging = false;
      _wordStartTime = null;
      _emitWaiting(db);
    } else if (_confirmedSinging) {
      // Continúa cantando: evaluar avance de sílabas
      _tryAdvanceWord(db, effectiveThreshold);
    }
  }

  void _emitSinging(double db, double threshold) {
    _state = _state.copyWith(
      isSinging: true,
      isWaitingForVoice: false,
      volumeDb: db,
      vocalEnergy: _normalizeEnergy(db, threshold),
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

  void _tryAdvanceWord(double db, double threshold) {
    _state = _state.copyWith(
      isSinging: true,
      isWaitingForVoice: false,
      volumeDb: db,
      vocalEnergy: _normalizeEnergy(db, threshold),
    );
    _stateController.add(_state);

    final now = DateTime.now();
    final heldMs = _wordStartTime != null
        ? now.difference(_wordStartTime!).inMilliseconds
        : 0;

    final int targetMs = _wordDurationMs();

    if (heldMs >= targetMs) {
      _advanceWord();
      _wordStartTime = now;
    }
  }

  int _wordDurationMs() {
    final lines = song.lines;
    if (lines.isEmpty) return _minWordHoldMs;
    final lineIdx = _state.lineIndex.clamp(0, lines.length - 1);
    final tokens = lines[lineIdx].tokens;
    if (tokens.isEmpty) return _minWordHoldMs;
    final wordIdx = _state.wordIndex.clamp(0, tokens.length - 1);
    final word = tokens[wordIdx].word.replaceAll(RegExp(r'[^a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]'), '');
    final int syllables = _countSyllables(word);
    return (syllables * 280).clamp(_minWordHoldMs, _maxWordHoldMs);
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
      if (line + 1 < lines.length) {
        line++;
        word = 0;
      } else {
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

  double _normalizeEnergy(double db, double threshold) {
    return ((db - threshold) / (0.0 - threshold)).clamp(0.0, 1.0);
  }

  /// Salto directo a línea y palabra si el usuario toca la pantalla
  void jumpTo(int line, int word) {
    final lines = song.lines;
    if (lines.isEmpty) return;
    final validLine = line.clamp(0, lines.length - 1);
    final validWord = word.clamp(0, lines[validLine].tokens.length - 1);
    _wordStartTime = DateTime.now();
    _state = _state.copyWith(
      lineIndex: validLine,
      wordIndex: validWord,
      isSinging: false,
      isWaitingForVoice: true,
    );
    _stateController.add(_state);
  }

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
    _state = _state.copyWith(
      lineIndex: line,
      wordIndex: word,
      isSinging: false,
      isWaitingForVoice: true,
    );
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
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    await _audioRecorder.dispose();
    await _stateController.close();
  }
}
