import 'lyric_token.dart';

/// Representa una línea de texto con sus tokens y acordes correspondientes.
class LyricLine {
  final List<LyricToken> tokens;

  const LyricLine({required this.tokens});

  String get fullText => tokens.map((t) => t.word).join(' ');

  @override
  String toString() => 'LyricLine(tokens: $tokens)';
}

/// Representa una canción completa estructurada para el teleprompter.
class SongScript {
  final String title;
  final String artist;
  final List<LyricLine> lines;

  const SongScript({
    this.title = 'Sin título',
    this.artist = 'Desconocido',
    required this.lines,
  });

  /// Lista aplanada de todas las palabras cantadas en orden secuencial.
  List<LyricToken> get allTokens => lines.expand((line) => line.tokens).toList();

  @override
  String toString() => 'SongScript(title: $title, lines: ${lines.length})';
}
