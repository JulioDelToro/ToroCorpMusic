import 'dart:async';
import '../../scripts/models/song_script.dart';
import '../models/alignment_state.dart';
import 'audio_bandpass_filter.dart';

/// Motor de alineación en tiempo real entre la voz cantada y la letra de la canción.
/// Sigue estrictamente la voz del cantante: si el músico pausa para un solo de guitarra
/// o el micrófono capta ruido de cuerdas, el teleprompter no se descontrola y espera pacientemente.
class VocalAlignmentMatcher {
  final SongScript song;
  final StreamController<AlignmentState> _stateController = StreamController<AlignmentState>.broadcast();

  AlignmentState _currentState = const AlignmentState();
  int _lastUtteranceWordCount = 0;

  VocalAlignmentMatcher(this.song) {
    _stateController.add(_currentState);
  }

  Stream<AlignmentState> get alignmentStream => _stateController.stream;
  AlignmentState get currentState => _currentState;

  /// Procesa una frase reconocida continuamente por el micrófono (karaoke tracking)
  void processUtterance(String utterance) {
    final words = utterance.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return;

    if (words.length < _lastUtteranceWordCount) {
      _lastUtteranceWordCount = 0;
    }

    for (int i = _lastUtteranceWordCount; i < words.length; i++) {
      processSpokenWord(words[i]);
    }
    _lastUtteranceWordCount = words.length;
  }

  void resetUtterance() {
    _lastUtteranceWordCount = 0;
  }

  /// Procesa una palabra cantada/hablada capturada por el micrófono.
  void processSpokenWord(String rawSpokenWord) {
    final cleanSpoken = AudioBandpassFilter.normalizeWord(rawSpokenWord);
    if (cleanSpoken.isEmpty) return;

    final lines = song.lines;
    if (lines.isEmpty) return;

    int currentLine = _currentState.currentLineIndex;
    int currentWord = _currentState.currentWordIndex;

    if (currentLine >= lines.length) return;

    final tokens = lines[currentLine].tokens;

    // Ventana de búsqueda: revisa la palabra actual y las siguientes 2 palabras en caso de saltos
    int matchedWordIndex = -1;
    int matchedLineIndex = currentLine;
    double bestSimilarity = 0.0;

    for (int offset = 0; offset <= 2; offset++) {
      int checkWord = currentWord + offset;
      int checkLine = currentLine;

      if (checkWord >= tokens.length) {
        // Mirar en la primera palabra de la siguiente línea
        if (checkLine + 1 < lines.length) {
          checkLine++;
          checkWord = 0;
        } else {
          break;
        }
      }

      final targetWord = lines[checkLine].tokens[checkWord].word;
      final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);

      if (sim >= 0.65 && sim > bestSimilarity) {
        bestSimilarity = sim;
        matchedWordIndex = checkWord;
        matchedLineIndex = checkLine;
      }
    }

    if (matchedWordIndex != -1) {
      _currentState = _currentState.copyWith(
        currentLineIndex: matchedLineIndex,
        currentWordIndex: matchedWordIndex,
        confidence: bestSimilarity,
        lastSpokenWord: rawSpokenWord,
        isSinging: true,
      );
      _stateController.add(_currentState);
    }
  }

  /// Avance manual de palabra (ej. toques en pantalla o pedal Bluetooth)
  void nextWord() {
    final lines = song.lines;
    if (lines.isEmpty) return;

    int nextWord = _currentState.currentWordIndex + 1;
    int nextLine = _currentState.currentLineIndex;

    if (nextWord >= lines[nextLine].tokens.length) {
      if (nextLine + 1 < lines.length) {
        nextLine++;
        nextWord = 0;
      } else {
        return; // Fin de la canción
      }
    }

    _currentState = _currentState.copyWith(
      currentLineIndex: nextLine,
      currentWordIndex: nextWord,
      isSinging: true,
    );
    _stateController.add(_currentState);
  }

  /// Retroceso manual de palabra
  void previousWord() {
    int prevWord = _currentState.currentWordIndex - 1;
    int prevLine = _currentState.currentLineIndex;

    if (prevWord < 0) {
      if (prevLine > 0) {
        prevLine--;
        prevWord = song.lines[prevLine].tokens.length - 1;
      } else {
        prevWord = 0;
      }
    }

    _currentState = _currentState.copyWith(
      currentLineIndex: prevLine,
      currentWordIndex: prevWord,
      isSinging: false,
    );
    _stateController.add(_currentState);
  }

  void reset() {
    _lastUtteranceWordCount = 0;
    _currentState = const AlignmentState();
    _stateController.add(_currentState);
  }

  void dispose() {
    _stateController.close();
  }
}
