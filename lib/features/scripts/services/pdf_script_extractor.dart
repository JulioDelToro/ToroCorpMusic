import '../models/lyric_token.dart';
import '../models/song_script.dart';

/// Extractor y analizador de canciones a partir de texto plano o extraído de PDFs.
/// Detecta automáticamente filas de acordes situadas por encima de la letra
/// y las asocia para que queden situadas en la parte inferior de la palabra en el teleprompter.
class PdfScriptExtractor {
  static final RegExp _chordTokenRegex = RegExp(
    r'^[A-G][b#]?(m|maj|min|dim|aug|sus|add|M)?([0-9]{1,2})?(/[A-G][b#]?)?$',
  );

  SongScript extractFromRawText(String rawText, {String title = 'PDF Importado'}) {
    final rawLines = rawText.split('\n');
    final parsedLines = <LyricLine>[];

    int i = 0;
    while (i < rawLines.length) {
      final currentLine = rawLines[i];
      final trimmed = currentLine.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      if (_isChordLine(currentLine)) {
        // La línea actual tiene acordes. Verificamos si la siguiente línea tiene la letra.
        if (i + 1 < rawLines.length && !_isChordLine(rawLines[i + 1]) && rawLines[i + 1].trim().isNotEmpty) {
          final chordLine = currentLine;
          final lyricLine = rawLines[i + 1];

          final tokens = _alignChordsWithLyrics(chordLine, lyricLine);
          parsedLines.add(LyricLine(tokens: tokens));
          i += 2;
          continue;
        } else {
          // Línea de acordes aislada (introducción o puente instrumental)
          final chords = trimmed.split(RegExp(r'\s+')).where((c) => c.isNotEmpty);
          final tokens = chords.map((c) => LyricToken(word: '•', chordUnderneath: c)).toList();
          parsedLines.add(LyricLine(tokens: tokens));
          i++;
          continue;
        }
      } else {
        // Línea solo de letra sin acordes
        final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
        final tokens = words.map((w) => LyricToken(word: w)).toList();
        parsedLines.add(LyricLine(tokens: tokens));
        i++;
      }
    }

    return SongScript(
      title: title,
      lines: parsedLines,
    );
  }

  bool _isChordLine(String line) {
    final tokens = line.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;

    int chordCount = 0;
    for (final token in tokens) {
      final clean = token.replaceAll(RegExp(r'[\[\],()]'), '');
      if (_chordTokenRegex.hasMatch(clean)) {
        chordCount++;
      }
    }

    return (chordCount / tokens.length) >= 0.6;
  }

  List<LyricToken> _alignChordsWithLyrics(String chordLine, String lyricLine) {
    final tokens = <LyricToken>[];

    // Localizar posición de cada acorde en la línea superior
    final chordMatches = RegExp(r'\S+').allMatches(chordLine).toList();
    final chordsWithPositions = <MapEntry<int, String>>[];

    for (final match in chordMatches) {
      final chord = match.group(0)!;
      chordsWithPositions.add(MapEntry(match.start, chord));
    }

    // Localizar cada palabra en la línea de letra
    final wordMatches = RegExp(r'\S+').allMatches(lyricLine).toList();
    final usedChordIndices = <int>{};

    for (int w = 0; w < wordMatches.length; w++) {
      final wordMatch = wordMatches[w];
      final word = wordMatch.group(0)!;
      final wordStart = wordMatch.start;
      final wordEnd = wordMatch.end;

      String? matchedChord;
      for (int c = 0; c < chordsWithPositions.length; c++) {
        if (usedChordIndices.contains(c)) continue;

        final chordPos = chordsWithPositions[c].key;
        final isInRange = chordPos >= wordStart - 2 && chordPos <= wordEnd + 4;
        final isLastWord = (w == wordMatches.length - 1) && (chordPos >= wordStart - 2);

        if (isInRange || isLastWord) {
          matchedChord = chordsWithPositions[c].value;
          usedChordIndices.add(c);
          break;
        }
      }

      tokens.add(LyricToken(
        word: word,
        chordUnderneath: matchedChord,
      ));
    }

    return tokens;
  }
}
