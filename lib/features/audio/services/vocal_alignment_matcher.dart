import 'dart:async';
import '../../scripts/models/song_script.dart';
import '../models/alignment_state.dart';
import 'audio_bandpass_filter.dart';

/// Motor de alineación fonética en tiempo real entre la voz cantada y la letra de la canción.
/// 
/// Características:
/// 1. Sigue estrictamente la voz del cantante con alta precisión fonética en español.
/// 2. Búsqueda hacia adelante inteligente: si el micrófono pierde una palabra y el usuario ya está
///    cantando en la segunda línea, se adelanta automáticamente a la estrofa y palabra correspondiente.
/// 3. Si el músico pausa para un requinto o solo de guitarra, se congela pacientemente y no avanza en falso.
class VocalAlignmentMatcher {
  SongScript _song;
  final StreamController<AlignmentState> _stateController = StreamController<AlignmentState>.broadcast();

  AlignmentState _currentState = const AlignmentState();
  String _lastProcessedUtterance = '';

  VocalAlignmentMatcher(SongScript song) : _song = song {
    _stateController.add(_currentState);
  }

  SongScript get song => _song;
  Stream<AlignmentState> get alignmentStream => _stateController.stream;
  AlignmentState get currentState => _currentState;

  void updateSong(SongScript newSong) {
    _song = newSong;
    reset();
  }

  /// Valida si una palabra pronunciada coincide fonéticamente con la palabra esperada en el guion
  static bool verifyWordMatch(String targetWord, String candidateWord, {double minConfidence = 0.68}) {
    final cleanTarget = AudioBandpassFilter.normalizeWord(targetWord);
    final cleanCandidate = AudioBandpassFilter.normalizeWord(candidateWord);
    if (cleanTarget.isEmpty || cleanCandidate.isEmpty) return false;
    final sim = AudioBandpassFilter.similarity(cleanTarget, cleanCandidate);
    return _isMatch(cleanCandidate, cleanTarget, sim, threshold: minConfidence);
  }

  static bool _isMatch(String spoken, String target, double sim, {double threshold = 0.68}) {
    final cleanTarget = AudioBandpassFilter.normalizeWord(target);
    final cleanSpoken = AudioBandpassFilter.normalizeWord(spoken);
    if (cleanTarget.isEmpty || cleanSpoken.isEmpty) return false;

    // 1. Coincidencia ortográfica exacta
    if (cleanTarget == cleanSpoken) return true;

    // 2. Coincidencia fonética exacta en español (yeísmo, seseo, b/v, vocales alargadas de canto)
    final pTarget = AudioBandpassFilter.toSpanishPhonetic(cleanTarget);
    final pSpoken = AudioBandpassFilter.toSpanishPhonetic(cleanSpoken);
    if (pTarget.isNotEmpty && pTarget == pSpoken) return true;

    // 3. Palabras muy cortas (1 o 2 letras como "y", "a", "de", "no", "el", "la", "en", "es"):
    // Deben coincidir exactamente (ortográfica o fonéticamente) para evitar falsos positivos
    if (cleanTarget.length <= 2) {
      return false;
    }

    // 4. Palabras de 3 letras ("que", "mas", "por", "tan", "sin", "sol"):
    if (cleanTarget.length == 3) {
      if (sim >= 0.70) return true;
      if (pSpoken.isNotEmpty && pTarget.isNotEmpty && pSpoken == pTarget) return true;
      return false;
    }

    // 5. Palabras estándar (>= 4 letras) - Ultra precisión requerida
    if (sim >= threshold) return true;

    // Prefijo fonético para palabras cantadas con terminación ligada o cortada
    if (cleanTarget.length >= 5 && cleanSpoken.length >= 4) {
      if ((cleanTarget.startsWith(cleanSpoken) || pTarget.startsWith(pSpoken)) && sim >= 0.60) {
        return true;
      }
    }

    return false;
  }

  /// Procesa una frase reconocida continuamente por el streaming de audio
  void processUtterance(String utterance) {
    final cleanUtterance = utterance.trim();
    if (cleanUtterance.isEmpty) return;

    final words = cleanUtterance.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return;

    final prevWords = _lastProcessedUtterance.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Determinar cuántas palabras del inicio ya habían sido procesadas en la emisión previa
    int commonPrefixCount = 0;
    while (commonPrefixCount < prevWords.length &&
           commonPrefixCount < words.length &&
           prevWords[commonPrefixCount].toLowerCase() == words[commonPrefixCount].toLowerCase()) {
      commonPrefixCount++;
    }

    // Procesar únicamente las palabras nuevas o modificadas desde la última emisión
    if (commonPrefixCount < words.length) {
      for (int i = commonPrefixCount; i < words.length; i++) {
        processSpokenWord(words[i]);
      }
    }

    _lastProcessedUtterance = cleanUtterance;
  }

  void resetUtterance() {
    _lastProcessedUtterance = '';
  }

  /// Procesa una palabra cantada/hablada capturada por el micrófono.
  /// Incluye búsqueda hacia adelante inteligente si el cantante ya está en la segunda línea.
  void processSpokenWord(String rawSpokenWord) {
    final cleanSpoken = AudioBandpassFilter.normalizeWord(rawSpokenWord);
    if (cleanSpoken.isEmpty) return;

    final lines = song.lines;
    if (lines.isEmpty) return;

    int currentLine = _currentState.currentLineIndex;
    int currentWord = _currentState.currentWordIndex;

    if (currentLine >= lines.length) return;

    // ── 1. Modo Requinto / Sección Instrumental ──
    if (lines[currentLine].isInstrumental) {
      int nextVocalLine = currentLine + 1;
      while (nextVocalLine < lines.length && lines[nextVocalLine].isInstrumental) {
        nextVocalLine++;
      }
      if (nextVocalLine < lines.length && lines[nextVocalLine].tokens.isNotEmpty) {
        final targetWord = lines[nextVocalLine].tokens.first.word;
        final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);
        if (_isMatch(cleanSpoken, targetWord, sim)) {
          final nextWord = lines[nextVocalLine].tokens.length > 1 ? 1 : 0;
          _currentState = _currentState.copyWith(
            currentLineIndex: nextVocalLine,
            currentWordIndex: nextWord,
            confidence: sim,
            lastSpokenWord: rawSpokenWord,
            isSinging: true,
          );
          _stateController.add(_currentState);
          return;
        }
      }
      return; // Permanece pacientemente en requinto mientras tocan la guitarra
    }

    // ── 2. Búsqueda en la Línea Actual (desde currentWord hasta el final del verso) ──
    int matchedWordIndex = -1;
    int matchedLineIndex = currentLine;
    double bestSimilarity = 0.0;

    final currentTokens = lines[currentLine].tokens;
    for (int checkWord = currentWord; checkWord < currentTokens.length; checkWord++) {
      final targetWord = currentTokens[checkWord].word;
      final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);
      if (_isMatch(cleanSpoken, targetWord, sim) && sim > bestSimilarity) {
        bestSimilarity = sim;
        matchedWordIndex = checkWord;
        matchedLineIndex = currentLine;
      }
    }

    // ── 3. Búsqueda Hacia Adelante (Segunda Línea y siguientes) ──
    // Si no coincidió en la línea actual y el cantante ya está entonando la siguiente estrofa:
    if (matchedWordIndex == -1) {
      for (int lookAhead = 1; lookAhead <= 3; lookAhead++) {
        final targetLineIdx = currentLine + lookAhead;
        if (targetLineIdx >= lines.length) break;

        final targetLine = lines[targetLineIdx];
        if (targetLine.isInstrumental) continue;

        for (int checkWord = 0; checkWord < targetLine.tokens.length; checkWord++) {
          final targetWord = targetLine.tokens[checkWord].word;
          final sim = AudioBandpassFilter.similarity(cleanSpoken, targetWord);
          if (_isMatch(cleanSpoken, targetWord, sim)) {
            bestSimilarity = sim;
            matchedWordIndex = checkWord;
            matchedLineIndex = targetLineIdx;
            break;
          }
        }
        if (matchedWordIndex != -1) break;
      }
    }

    // ── 4. Aplicar Avance Ultra Preciso ──
    if (matchedWordIndex != -1) {
      final targetTokens = lines[matchedLineIndex].tokens;
      int nextWord = matchedWordIndex + 1;
      int nextLine = matchedLineIndex;

      // Si se completó el último término de la línea actual:
      // Conservar la línea actual completamente en amarillo en pantalla
      // NO brincar de línea hasta que el cantante empiece a cantar la siguiente estrofa.
      if (nextWord > targetTokens.length) {
        nextWord = targetTokens.length;
      }

      _currentState = _currentState.copyWith(
        currentLineIndex: nextLine,
        currentWordIndex: nextWord,
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
    _lastProcessedUtterance = '';
    _currentState = const AlignmentState();
    _stateController.add(_currentState);
  }

  void dispose() {
    _stateController.close();
  }
}
