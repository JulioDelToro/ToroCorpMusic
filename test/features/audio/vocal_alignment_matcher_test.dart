import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/vocal_alignment_matcher.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';

void main() {
  test('VocalAlignmentMatcher advances index on sung word and pauses when silent', () {
    final song = SongScript(lines: [
      const LyricLine(tokens: [
        LyricToken(word: "De"),
        LyricToken(word: "música"),
        LyricToken(word: "ligera")
      ])
    ]);
    final matcher = VocalAlignmentMatcher(song);

    // User sings "De"
    matcher.processSpokenWord("de");
    expect(matcher.currentState.currentWordIndex, equals(0));

    // User sings "música"
    matcher.processSpokenWord("musica");
    expect(matcher.currentState.currentWordIndex, equals(1));

    // Unrelated noise does not advance forward wildly
    matcher.processSpokenWord("zzz_noise");
    expect(matcher.currentState.currentWordIndex, equals(1));
  });
}
