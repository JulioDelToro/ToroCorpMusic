import 'lyric_token.dart';

/// Representa una línea de texto con sus tokens y acordes correspondientes.
class LyricLine {
  final List<LyricToken> tokens;
  final bool isInstrumental;
  final String? instrumentalLabel;

  const LyricLine({
    required this.tokens,
    this.isInstrumental = false,
    this.instrumentalLabel,
  });

  String get fullText => tokens.map((t) => t.word).join(' ');

  @override
  String toString() => 'LyricLine(tokens: $tokens, isInstrumental: $isInstrumental)';
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
