import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../audio/models/alignment_state.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../scripts/models/song_script.dart';

/// Controlador de estado para el teleprompter pegado a la cámara.
class TeleprompterController extends ChangeNotifier {
  SongScript _song;
  final VocalAlignmentMatcher? matcher;
  StreamSubscription<AlignmentState>? _subscription;

  int _activeLineIndex = 0;
  int _activeWordIndex = 0;
  bool _isMirrorMode = false;
  double _fontSize = 26.0;

  TeleprompterController({
    required SongScript initialSong,
    this.matcher,
  }) : _song = initialSong {
    _subscription = matcher?.alignmentStream.listen(_onAlignmentStateChanged);
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
