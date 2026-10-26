import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';

void main() {
  test('ChordproParser binds chords directly beneath their corresponding word', () {
    const rawChordPro = "De [G]música [D]ligera...";
    final parser = ChordProParser();
    final song = parser.parse(rawChordPro);
    
    expect(song.lines.first.tokens.length, equals(3));
    expect(song.lines.first.tokens[0].word, equals("De"));
    expect(song.lines.first.tokens[0].chordUnderneath, isNull);
    expect(song.lines.first.tokens[1].word, equals("música"));
    expect(song.lines.first.tokens[1].chordUnderneath, equals("G"));
    expect(song.lines.first.tokens[2].word, equals("ligera..."));
    expect(song.lines.first.tokens[2].chordUnderneath, equals("D"));
  });
}
