import '../models/lyric_token.dart';
import '../models/song_script.dart';

/// Parser para el estándar musical ChordPro y detección inteligente de secciones instrumentales (Requinto, Solo).
/// Convierte texto con acordes en corchetes [Acorde] a tokens de teleprompter
/// donde la nota musical se ubica en la parte inferior de la palabra correspondiente.
class ChordProParser {
  final RegExp _chordRegex = RegExp(r'\[(.*?)\]');

  /// Detecta si una línea o etiqueta corresponde a una sección instrumental donde no se canta
  static bool isInstrumentalTag(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[\[\]\(\)\-\:\*]'), '').trim();
    if (clean.isEmpty) return false;
    return clean == 'requinto' ||
        clean.contains('requinto') ||
        clean == 'solo' ||
        clean.startsWith('solo ') ||
        clean.contains('solo de guitarra') ||
        clean == 'interludio' ||
        clean == 'instrumental' ||
        clean == 'intro';
  }

  SongScript parse(String rawText, {String title = 'Sin título', String artist = 'Desconocido'}) {
    final lines = rawText.split('\n');
    final parsedLines = <LyricLine>[];

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      // Directivas ChordPro (ej. {title: ...}, {artist: ...})
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        continue;
      }

      // Detección de línea instrumental (Requinto / Solo)
      if (isInstrumentalTag(trimmed)) {
        final cleanTag = trimmed.replaceAll(RegExp(r'[\[\]\(\)\-\*]'), '').trim().toUpperCase();
        final displayLabel = cleanTag.contains('🎸') ? cleanTag : '🎸 $cleanTag';
        parsedLines.add(LyricLine(
          tokens: [
            LyricToken(word: displayLabel),
          ],
          isInstrumental: true,
          instrumentalLabel: displayLabel,
        ));
        continue;
      }

      final tokens = _parseLine(rawLine);
      if (tokens.isNotEmpty) {
        parsedLines.add(LyricLine(tokens: tokens));
      }
    }

    return SongScript(
      title: title,
      artist: artist,
      lines: parsedLines,
    );
  }

  List<LyricToken> _parseLine(String line) {
    final tokens = <LyricToken>[];

    // Expresión regular que separa por espacios pero respeta acordes
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    for (final wordSegment in words) {
      String cleanWord = wordSegment;
      String? chord;

      final match = _chordRegex.firstMatch(wordSegment);
      if (match != null) {
        chord = match.group(1);
        cleanWord = wordSegment.replaceAll(_chordRegex, '');
      }

      if (cleanWord.isNotEmpty) {
        tokens.add(LyricToken(
          word: cleanWord,
          chordUnderneath: chord,
        ));
      } else if (chord != null) {
        // Acorde solitario (por ejemplo introducción instrumental o cierre)
        tokens.add(LyricToken(
          word: '•',
          chordUnderneath: chord,
        ));
      }
    }

    return tokens;
  }
}
