import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../audio/models/alignment_state.dart';
import '../../audio/services/acoustic_vocal_karaoke_service.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../scripts/models/song_script.dart';

/// Controlador de estado para el teleprompter anclado a la cámara.
/// Soporta alineación acústica con rechazo anti-guitarra, pausas de requinto y alineación fonética por palabras.
class TeleprompterController extends ChangeNotifier {
  SongScript _song;
  final VocalAlignmentMatcher? matcher;
  final AcousticVocalKaraokeService? acousticService;

  StreamSubscription<AlignmentState>? _matcherSubscription;
  StreamSubscription<AcousticKaraokeState>? _acousticSubscription;

  int _activeLineIndex = 0;
  int _activeWordIndex = 0;
  bool _isMirrorMode = false;
  double _fontSize = 26.0;
  bool _isSinging = false;
  bool _isWaitingForVoice = true;
  double _volumeDb = -60.0;
  double _vocalEnergy = 0.0;
  bool _isInstrumentalBreak = false;
  String? _instrumentalLabel;

  TeleprompterController({
    required SongScript initialSong,
    this.matcher,
    this.acousticService,
  }) : _song = initialSong {
    _matcherSubscription = matcher?.alignmentStream.listen(_onAlignmentStateChanged);
    _acousticSubscription = acousticService?.stateStream.listen(_onAcousticStateChanged);
  }

  SongScript get song => _song;
  int get activeLineIndex => _activeLineIndex;
  int get activeWordIndex => _activeWordIndex;
  bool get isMirrorMode => _isMirrorMode;
  double get fontSize => _fontSize;
  bool get isSinging => _isSinging;
  bool get isWaitingForVoice => _isWaitingForVoice;
  double get volumeDb => _volumeDb;
  double get vocalEnergy => _vocalEnergy;
  bool get isInstrumentalBreak =>
      _isInstrumentalBreak || (currentLine?.isInstrumental ?? false);
  String? get instrumentalLabel =>
      _instrumentalLabel ?? currentLine?.instrumentalLabel;

  /// Retorna la línea actual que se está leyendo o null si no hay canción
  LyricLine? get currentLine =>
      _song.lines.isNotEmpty && _activeLineIndex < _song.lines.length
          ? _song.lines[_activeLineIndex]
          : null;

  /// Retorna la línea siguiente que sigue para leer o null si es la última
  LyricLine? get nextLine =>
      _song.lines.isNotEmpty && (_activeLineIndex + 1) < _song.lines.length
          ? _song.lines[_activeLineIndex + 1]
          : null;

  /// Retorna el índice global absoluto de la palabra activa en toda la canción
  int get globalActiveWordIndex {
    int count = 0;
    for (int l = 0; l < _activeLineIndex && l < _song.lines.length; l++) {
      count += _song.lines[l].tokens.length;
    }
    return count + _activeWordIndex;
  }

  void updateSong(SongScript newSong) {
    _song = newSong;
    _activeLineIndex = 0;
    _activeWordIndex = 0;
    _isSinging = false;
    _isWaitingForVoice = true;
    _isInstrumentalBreak = false;
    _instrumentalLabel = null;
    notifyListeners();
  }

  void _onAlignmentStateChanged(AlignmentState state) {
    _activeLineIndex = state.currentLineIndex;
    _activeWordIndex = state.currentWordIndex;
    _isSinging = state.isSinging;
    _isInstrumentalBreak = false;
    _instrumentalLabel = null;
    acousticService?.syncMatchedWord(state.currentLineIndex, state.currentWordIndex);
    notifyListeners();
  }

  void _onAcousticStateChanged(AcousticKaraokeState state) {
    _activeLineIndex = state.lineIndex;
    _activeWordIndex = state.wordIndex;
    _isSinging = state.isSinging;
    _isWaitingForVoice = state.isWaitingForVoice;
    _volumeDb = state.volumeDb;
    _vocalEnergy = state.vocalEnergy;
    _isInstrumentalBreak = state.isInstrumentalBreak;
    _instrumentalLabel = state.instrumentalLabel;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(18.0, 38.0);
    notifyListeners();
  }

  void toggleMirrorMode() {
    _isMirrorMode = !_isMirrorMode;
    notifyListeners();
  }

  void jumpTo(int lineIndex, int wordIndex) {
    if (_song.lines.isEmpty) return;
    _activeLineIndex = lineIndex.clamp(0, _song.lines.length - 1);
    final tokens = _song.lines[_activeLineIndex].tokens;
    _activeWordIndex = tokens.isEmpty ? 0 : wordIndex.clamp(0, tokens.length - 1);
    _isInstrumentalBreak = false;
    _instrumentalLabel = null;
    acousticService?.jumpTo(_activeLineIndex, _activeWordIndex);
    matcher?.jumpTo(_activeLineIndex, _activeWordIndex);
    notifyListeners();
  }

  /// Salta a una palabra dentro de la línea actual
  void jumpToWordInCurrentLine(int wordIndex) {
    jumpTo(_activeLineIndex, wordIndex);
  }

  /// Salta a la primera palabra de la línea siguiente o reanuda tras requinto
  void jumpToNextLine() {
    if (_activeLineIndex + 1 < _song.lines.length) {
      jumpTo(_activeLineIndex + 1, 0);
    }
  }

  /// Reanuda el teleprompter inmediatamente si está en un requinto o solo instrumental
  void resumeFromInstrumental() {
    _isInstrumentalBreak = false;
    _instrumentalLabel = null;
    acousticService?.resumeFromInstrumental();
    if (currentLine?.isInstrumental ?? false) {
      jumpToNextLine();
    } else {
      notifyListeners();
    }
  }

  /// Procesa una palabra reconocida para alimentar el reconocedor fonético
  void processSpokenWord(String word) {
    matcher?.processSpokenWord(word);
  }

  /// Procesa una frase reconocida continuamente para alimentar el reconocedor fonético
  void processUtterance(String utterance) {
    matcher?.processUtterance(utterance);
  }

  /// Salta a una palabra usando su índice global plano en toda la canción
  void jumpToGlobalWord(int globalIndex) {
    int remaining = globalIndex;
    for (int l = 0; l < _song.lines.length; l++) {
      final len = _song.lines[l].tokens.length;
      if (remaining < len) {
        jumpTo(l, remaining);
        return;
      }
      remaining -= len;
    }
    if (_song.lines.isNotEmpty) {
      jumpTo(_song.lines.length - 1, _song.lines.last.tokens.length - 1);
    }
  }

  void nextWord() {
    acousticService?.nextWordManual();
  }

  void previousWord() {
    acousticService?.previousWordManual();
  }

  void reset() {
    _activeLineIndex = 0;
    _activeWordIndex = 0;
    _isSinging = false;
    _isWaitingForVoice = true;
    _isInstrumentalBreak = false;
    _instrumentalLabel = null;
    acousticService?.reset();
    matcher?.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _matcherSubscription?.cancel();
    _acousticSubscription?.cancel();
    super.dispose();
  }
}
