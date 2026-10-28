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
  final bool isInstrumentalBreak;
  final String? instrumentalLabel;

  const AcousticKaraokeState({
    this.lineIndex = 0,
    this.wordIndex = 0,
    this.isSinging = false,
    this.volumeDb = -60.0,
    this.isWaitingForVoice = true,
    this.vocalEnergy = 0.0,
    this.isInstrumentalBreak = false,
    this.instrumentalLabel,
  });

  AcousticKaraokeState copyWith({
    int? lineIndex,
    int? wordIndex,
    bool? isSinging,
    double? volumeDb,
    bool? isWaitingForVoice,
    double? vocalEnergy,
    bool? isInstrumentalBreak,
    String? instrumentalLabel,
  }) {
    return AcousticKaraokeState(
      lineIndex: lineIndex ?? this.lineIndex,
      wordIndex: wordIndex ?? this.wordIndex,
      isSinging: isSinging ?? this.isSinging,
      volumeDb: volumeDb ?? this.volumeDb,
      isWaitingForVoice: isWaitingForVoice ?? this.isWaitingForVoice,
      vocalEnergy: vocalEnergy ?? this.vocalEnergy,
      isInstrumentalBreak: isInstrumentalBreak ?? this.isInstrumentalBreak,
      instrumentalLabel: instrumentalLabel ?? this.instrumentalLabel,
    );
  }
}

/// Motor acústico de karaoke en tiempo real para ToroCorp Music.
/// 
/// Características:
/// 1. Compatible con AudioSession (evita que el sistema operativo o la cámara silencien el micrófono).
/// 2. Filtro acústico anti-guitarra: discrimina transitorios de púa/cuerda para que el requinto no simule canto.
/// 3. Soporte para secciones instrumentales ([Requinto] / [Solo]): congela el teleprompter y espera al músico.
/// 4. Calibración automática del piso de ruido ambiental (adaptive noise floor).
/// 5. Avance natural por sílabas al cantar sin rezagos.
class AcousticVocalKaraokeService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final StreamController<AcousticKaraokeState> _stateController =
      StreamController<AcousticKaraokeState>.broadcast();

  SongScript song;
  AcousticKaraokeState _state = const AcousticKaraokeState();

  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // ── Parámetros de Detección Vocal (VAD) ──────────────────────────────────
  /// Umbral base optimizado para voz cantada (-32 dB)
  double silenceThresholdDb = -32.0;

  /// Piso de ruido calibrado automáticamente al inicio
  double _ambientFloorDb = -60.0;
  int _calibrationFrames = 0;
  static const int _maxCalibrationFrames = 15;

  /// Filtro anti-guitarra: memoria del último cuadro de amplitud
  double _lastDb = -100.0;
  // ignore: unused_field
  int _consecutivePluckFrames = 0;

  /// Muestras consecutivas para confirmar canto / pausa
  static const int _voiceConfirmFrames = 2; // ~60 ms para confirmar canto real sin falsos positivos
  static const int _silenceConfirmFrames = 6; // ~180 ms para confirmar pausa o requinto de guitarra
  // ────────────────────────────────────────────────────────────────────────

  int _voiceFrames = 0;
  int _silenceFrames = 0;
  bool _confirmedSinging = false;
  bool _isRunning = false;

  AcousticVocalKaraokeService({required this.song}) {
    _stateController.add(_state);
  }

  Stream<AcousticKaraokeState> get stateStream => _stateController.stream;
  AcousticKaraokeState get currentState => _state;
  bool get isRunning => _isRunning;
  bool get isTracking => _isRunning;

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
      _lastDb = -100.0;
      _consecutivePluckFrames = 0;

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

      // 4. Monitorear amplitud cada 30 milisegundos para latencia ultra baja e instantánea
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 30))
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

  /// Procesa niveles de decibeles de audio desde el flujo unificado del micrófono
  void processAudioDb(double db, double maxDb) {
    if (_stateController.isClosed) return;
    _isRunning = true;
    _handleAmplitudeValues(db, maxDb);
  }

  void _handleAmplitude(Amplitude amp) {
    _handleAmplitudeValues(amp.current, amp.max);
  }

  void _handleAmplitudeValues(double db, double maxDb) {
    if (!_isRunning || _stateController.isClosed) return;
    final double deltaDb = _lastDb > -99.0 ? (db - _lastDb) : 0.0;
    _lastDb = db;

    // Calibración adaptativa inicial del piso de ruido de la habitación
    if (_calibrationFrames < _maxCalibrationFrames && db > -100.0) {
      _calibrationFrames++;
      if (db > _ambientFloorDb) {
        _ambientFloorDb = db;
      }
      return;
    }

    // Filtro anti-guitarra: Un requinto / punteo de púa produce un ataque ultra-rápido (>8.5 dB en 30ms)
    // con una cresta elevada (maxDb - db > 6 dB), seguido de caída abrupta.
    // La voz humana cantada, en cambio, tiene un ataque suave y energía sostenida.
    final bool isPluck = deltaDb > 8.5 && (maxDb - db) > 6.0;

    // El umbral efectivo toma en cuenta el ruido de la habitación y el ajuste optimizado
    final double effectiveThreshold = math.max(_ambientFloorDb + 8.0, silenceThresholdDb);
    final bool hasVoice = db > effectiveThreshold && !isPluck;

    if (isPluck) {
      _consecutivePluckFrames++;
      // Ignorar punteos de cuerda / requinto para que no avancen la letra
      _voiceFrames = 0;
      _silenceFrames++;
    } else if (hasVoice) {
      _consecutivePluckFrames = 0;
      _voiceFrames++;
      _silenceFrames = 0;
    } else {
      _consecutivePluckFrames = 0;
      _silenceFrames++;
      _voiceFrames = 0;
    }

    if (!_confirmedSinging && _voiceFrames >= _voiceConfirmFrames) {
      // Transición: silencio -> cantando
      _confirmedSinging = true;
      _emitSinging(db, effectiveThreshold);
    } else if (_confirmedSinging && _silenceFrames >= _silenceConfirmFrames) {
      // Transición: cantando -> pausa o requinto de guitarra
      _confirmedSinging = false;
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
    // Nota: El avance ultra preciso de palabras lo gestiona estrictamente
    // VocalAlignmentMatcher con reconocimiento fonético on-device.
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

        // Si la siguiente línea es una sección instrumental (Requinto / Solo), pausar inmediatamente:
        if (lines[line].isInstrumental) {
          _confirmedSinging = false;
          _state = _state.copyWith(
            lineIndex: line,
            wordIndex: 0,
            isSinging: false,
            isWaitingForVoice: true,
            isInstrumentalBreak: true,
            instrumentalLabel: lines[line].instrumentalLabel ?? '🎸 REQUINTO',
          );
          _stateController.add(_state);
          return;
        }
      } else {
        return;
      }
    }

    _state = _state.copyWith(
      lineIndex: line,
      wordIndex: word,
      isSinging: true,
      isWaitingForVoice: false,
      isInstrumentalBreak: false,
    );
    _stateController.add(_state);
  }

  /// Reanuda el teleprompter después de un requinto o pausa instrumental
  void resumeFromInstrumental() {
    final lines = song.lines;
    if (lines.isEmpty) return;

    int targetLine = _state.lineIndex;
    // Si la línea actual es instrumental, avanzar a la primera línea cantada
    if (_state.isInstrumentalBreak || (targetLine < lines.length && lines[targetLine].isInstrumental)) {
      while (targetLine < lines.length && lines[targetLine].isInstrumental) {
        targetLine++;
      }
    }

    if (targetLine >= lines.length) {
      targetLine = lines.length - 1;
    }

    _state = _state.copyWith(
      lineIndex: targetLine,
      wordIndex: 0,
      isSinging: false,
      isWaitingForVoice: true,
      isInstrumentalBreak: false,
      instrumentalLabel: null,
    );
    _stateController.add(_state);
  }

  /// Sincroniza directamente la palabra cuando el reconocedor fonético confirma una coincidencia
  void syncMatchedWord(int lineIndex, int wordIndex) {
    final lines = song.lines;
    if (lines.isEmpty) return;
    final validLine = lineIndex.clamp(0, lines.length - 1);
    final validWord = wordIndex.clamp(0, lines[validLine].tokens.length - 1);

    final isInstr = lines[validLine].isInstrumental;
    _state = _state.copyWith(
      lineIndex: validLine,
      wordIndex: validWord,
      isSinging: true,
      isWaitingForVoice: false,
      isInstrumentalBreak: isInstr,
      instrumentalLabel: isInstr ? (lines[validLine].instrumentalLabel ?? '🎸 REQUINTO') : null,
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
    final isInstr = lines[validLine].isInstrumental;

    _state = _state.copyWith(
      lineIndex: validLine,
      wordIndex: validWord,
      isSinging: false,
      isWaitingForVoice: true,
      isInstrumentalBreak: isInstr,
      instrumentalLabel: isInstr ? (lines[validLine].instrumentalLabel ?? '🎸 REQUINTO') : null,
    );
    _stateController.add(_state);
  }

  void nextWordManual() {
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
    final isInstr = line < song.lines.length && song.lines[line].isInstrumental;
    _state = _state.copyWith(
      lineIndex: line,
      wordIndex: word,
      isSinging: false,
      isWaitingForVoice: true,
      isInstrumentalBreak: isInstr,
      instrumentalLabel: isInstr ? (song.lines[line].instrumentalLabel ?? '🎸 REQUINTO') : null,
    );
    _stateController.add(_state);
  }

  void reset() {
    _voiceFrames = 0;
    _silenceFrames = 0;
    _confirmedSinging = false;
    _lastDb = -100.0;
    _consecutivePluckFrames = 0;
    _state = const AcousticKaraokeState();
    _stateController.add(_state);
  }

  /// Detiene temporalmente el seguimiento de audio liberando el grabador del micrófono
  Future<void> stopTracking() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _confirmedSinging = false;
  }

  Future<void> dispose() async {
    await stopTracking();
    await _audioRecorder.dispose();
    await _stateController.close();
  }
}
