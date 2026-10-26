import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/saved_song.dart';

void main() {
  group('SavedSong Model and Serialization Tests', () {
    test('SavedSong serializes to Map and JSON accurately', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final song = SavedSong(
        id: '12345',
        title: 'Mi Canción Original',
        content: 'De música ligera\nNada más queda',
        updatedAt: now,
      );

      final map = song.toMap();
      expect(map['id'], equals('12345'));
      expect(map['title'], equals('Mi Canción Original'));
      expect(map['content'], contains('De música ligera'));

      final jsonStr = song.toJson();
      final recovered = SavedSong.fromJson(jsonStr);
      expect(recovered.id, equals(song.id));
      expect(recovered.title, equals(song.title));
      expect(recovered.content, equals(song.content));
    });

    test('SavedSong.toSongScript parses plain text into lines and lyric tokens', () {
      final song = SavedSong(
        id: '1',
        title: 'Balada',
        content: 'Hola mundo\nEsta es una prueba',
        updatedAt: DateTime.now(),
      );

      final script = song.toSongScript();
      expect(script.title, equals('Balada'));
      expect(script.lines.length, equals(2));
      expect(script.lines[0].tokens.length, equals(2));
      expect(script.lines[0].tokens[0].word, equals('Hola'));
      expect(script.lines[0].tokens[1].word, equals('mundo'));
    });

    test('SavedSong.toSongScript parses ChordPro chords when brackets are present', () {
      final song = SavedSong(
        id: '2',
        title: 'Acordes Pop',
        content: 'De [G]música [D]ligera',
        updatedAt: DateTime.now(),
      );

      final script = song.toSongScript();
      expect(script.title, equals('Acordes Pop'));
      expect(script.lines.isNotEmpty, isTrue);
      final tokens = script.lines[0].tokens;
      expect(tokens[0].word, equals('De'));
      expect(tokens[1].word, equals('música'));
      expect(tokens[1].chordUnderneath, equals('G'));
      expect(tokens[2].word, equals('ligera'));
      expect(tokens[2].chordUnderneath, equals('D'));
    });
  });
}
