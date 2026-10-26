import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/chords/data/guitar_chords_database.dart';

void main() {
  test('GuitarChordsDatabase returns correct fingerings for standard chords', () {
    final db = GuitarChordsDatabase();
    final gChord = db.getChord("G");
    expect(gChord, isNotNull);
    expect(gChord!.frets, equals([3, 2, 0, 0, 0, 3]));

    final cChord = db.getChord("C");
    expect(cChord, isNotNull);
    expect(cChord!.frets, equals([-1, 3, 2, 0, 1, 0]));
  });
}
