import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../audio/models/alignment_state.dart';
import '../../audio/services/acoustic_vocal_karaoke_service.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../scripts/models/song_script.dart';

/// Controlador de estado para el teleprompter anclado a la cámara.
/// Soporta tanto alineación acústica por VAD en tiempo real como alineación por palabras reconocidas.
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

  void updateSong(SongScript newSong) {
    _song = newSong;
    _activeLineIndex = 0;
    _activeWordIndex = 0;
    notifyListeners();
  }

  void _onAlignmentStateChanged(AlignmentState state) {
    _activeLineIndex = state.currentLineIndex;
    _activeWordIndex = state.currentWordIndex;
    notifyListeners();
  }

  void _onAcousticStateChanged(AcousticKaraokeState state) {
    _activeLineIndex = state.lineIndex;
    _activeWordIndex = state.wordIndex;
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
    _activeLineIndex = lineIndex;
    _activeWordIndex = wordIndex;
    notifyListeners();
  }

  void nextWord() {
    final lines = _song.lines;
    if (lines.isEmpty) return;
    int nextW = _activeWordIndex + 1;
    int nextL = _activeLineIndex;
    if (nextW >= lines[nextL].tokens.length) {
      if (nextL + 1 < lines.length) {
        nextL++;
        nextW = 0;
      }
    }
    _activeLineIndex = nextL;
    _activeWordIndex = nextW;
    notifyListeners();
  }

  @override
  void dispose() {
    _matcherSubscription?.cancel();
    _acousticSubscription?.cancel();
    super.dispose();
  }
}
