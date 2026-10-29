import 'dart:convert';
import 'lyric_token.dart';
import 'song_script.dart';
import '../services/chordpro_parser.dart';

/// Modelo de canción/guion guardado localmente por el usuario.
class SavedSong {
  final String id;
  final String title;
  final String artist;
  final String content;
  final DateTime updatedAt;

  const SavedSong({
    required this.id,
    required this.title,
    this.artist = 'Desconocido',
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'content': content,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedSong.fromMap(Map<String, dynamic> map) {
    return SavedSong(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Sin título',
      artist: map['artist'] as String? ?? 'Desconocido',
      content: map['content'] as String? ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavedSong.fromJson(String source) =>
      SavedSong.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Convierte el texto plano / con corchetes en un SongScript estructurado
  SongScript toSongScript() {
    final cleanTitle = title.trim().isEmpty ? 'Canción' : title.trim();
    if (content.contains('[') && content.contains(']')) {
      final parser = ChordProParser();
      return parser.parse(content, title: cleanTitle, artist: artist);
    }

    // Separación natural de líneas
    final rawLines = content.split('\n');
    final parsedLines = <LyricLine>[];

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (ChordProParser.isInstrumentalTag(trimmed)) {
        final cleanTag = trimmed.replaceAll(RegExp(r'[\[\]\(\)\-\*]'), '').trim().toUpperCase();
        final displayLabel = cleanTag.contains('🎸') ? cleanTag : '🎸 $cleanTag';
        parsedLines.add(LyricLine(
          tokens: [LyricToken(word: displayLabel)],
          isInstrumental: true,
          instrumentalLabel: displayLabel,
        ));
        continue;
      }

      final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      final tokens = words.map((w) => LyricToken(word: w)).toList();
      if (tokens.isNotEmpty) {
        parsedLines.add(LyricLine(tokens: tokens));
      }
    }

    return SongScript(
      title: cleanTitle,
      artist: artist,
      lines: parsedLines,
    );
  }
}
