import 'dart:async';
import '../../scripts/models/song_script.dart';
import '../models/alignment_state.dart';
import 'audio_bandpass_filter.dart';

/// Motor de alineación fonética en tiempo real entre la voz cantada y la letra de la canción.
/// Sigue estrictamente la voz del cantante:
/// 1. Solo avanza si la palabra cantada/hablada coincide fonéticamente con la letra.
/// 2. Si el músico pausa para un requinto o solo de guitarra, se congela pacientemente y no avanza en falso.
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

  /// Valida si una palabra pronunciada coincide fonéticamente con la palabra esperada en el guion
  static bool verifyWordMatch(String targetWord, String candidateWord, {double minConfidence = 0.65}) {
    final cleanTarget = AudioBandpassFilter.normalizeWord(targetWord);
    final cleanCandidate = AudioBandpassFilter.normalizeWord(candidateWord);
    if (cleanTarget.isEmpty || cleanCandidate.isEmpty) return false;
    return AudioBandpassFilter.similarity(cleanTarget, cleanCandidate) >= minConfidence;
  }

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
  /// Solo avanza si la palabra coincide fonéticamente con la letra actual o inmediata.
  void processSpokenWord(String rawSpokenWord) {
    final cleanSpoken = AudioBandpassFilter.normalizeWord(rawSpokenWord);
    if (cleanSpoken.isEmpty) return;

    final lines = song.lines;
    if (lines.isEmpty) return;

    int currentLine = _currentState.currentLineIndex;
    int currentWord = _currentState.currentWordIndex;

    if (currentLine >= lines.length) return;

    // Si estamos en una sección instrumental (Requinto / Solo), verificar si ya comenzó la siguiente estrofa
    if (lines[currentLine].isInstrumental) {
      int nextVocalLine = currentLine + 1;
      while (nextVocalLine < lines.length && lines[nextVocalLine].isInstrumental) {
        nextVocalLine++;
      }
      if (nextVocalLine < lines.length && lines[nextVocalLine].tokens.isNotEmpty) {
        final targetWord = lines[nextVocalLine].tokens.first.word;
        final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);
        if (sim >= 0.65) {
          _currentState = _currentState.copyWith(
            currentLineIndex: nextVocalLine,
            currentWordIndex: 0,
            confidence: sim,
            lastSpokenWord: rawSpokenWord,
            isSinging: true,
          );
          _stateController.add(_currentState);
          return;
        }
      }
      return; // Permanece en requinto
    }

    // Ventana de búsqueda secuencial controlada: revisa la palabra actual y las siguientes 2 palabras
    int matchedWordIndex = -1;
    int matchedLineIndex = currentLine;
    double bestSimilarity = 0.0;

    final currentTokens = lines[currentLine].tokens;
    for (int offset = 0; offset <= 2; offset++) {
      int checkWord = currentWord + offset;
      if (checkWord < currentTokens.length) {
        final targetWord = currentTokens[checkWord].word;
        final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);
        if (sim >= 0.65 && sim > bestSimilarity) {
          bestSimilarity = sim;
          matchedWordIndex = checkWord;
          matchedLineIndex = currentLine;
        }
      }
    }

    // Si está en la última palabra de la línea, revisar si ya empezó la primera de la siguiente línea cantada
    if (matchedWordIndex == -1 && currentWord >= currentTokens.length - 1) {
      int nextVocalLine = currentLine + 1;
      while (nextVocalLine < lines.length && lines[nextVocalLine].isInstrumental) {
        nextVocalLine++;
      }
      if (nextVocalLine < lines.length && lines[nextVocalLine].tokens.isNotEmpty) {
        final sim = AudioBandpassFilter.similarity(cleanSpoken, lines[nextVocalLine].tokens.first.word);
        if (sim >= 0.65) {
          bestSimilarity = sim;
          matchedWordIndex = 0;
          matchedLineIndex = nextVocalLine;
        }
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

  /// Avance manual de palabra
  void advanceWord() {
    final lines = song.lines;
    if (lines.isEmpty) return;

    int line = _currentState.currentLineIndex;
    int word = _currentState.currentWordIndex + 1;

    if (line >= lines.length) return;

    if (word >= lines[line].tokens.length) {
      if (line + 1 < lines.length) {
        line++;
        word = 0;
      } else {
        return;
      }
    }

    _currentState = _currentState.copyWith(
      currentLineIndex: line,
      currentWordIndex: word,
      isSinging: true,
    );
    _stateController.add(_currentState);
  }

  void jumpTo(int line, int word) {
    final lines = song.lines;
    if (lines.isEmpty) return;

    final validLine = line.clamp(0, lines.length - 1);
    final validWord = word.clamp(0, lines[validLine].tokens.length - 1);

    _currentState = _currentState.copyWith(
      currentLineIndex: validLine,
      currentWordIndex: validWord,
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
