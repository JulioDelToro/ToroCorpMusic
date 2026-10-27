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

    // User sings "De" -> matches and advances cursor to word 1 ('música')
    matcher.processSpokenWord("de");
    expect(matcher.currentState.currentWordIndex, equals(1));

    // User sings "música" -> matches and advances cursor to word 2 ('ligera')
    matcher.processSpokenWord("musica");
    expect(matcher.currentState.currentWordIndex, equals(2));

    // Unrelated noise does not advance forward wildly
    matcher.processSpokenWord("zzz_noise");
    expect(matcher.currentState.currentWordIndex, equals(2));
  });

  test('VocalAlignmentMatcher tracks continuous utterances like karaoke and transitions verses', () {
    final song = SongScript(lines: [
      const LyricLine(tokens: [
        LyricToken(word: "De"),
        LyricToken(word: "música"),
        LyricToken(word: "ligera")
      ]),
      const LyricLine(tokens: [
        LyricToken(word: "Nada"),
        LyricToken(word: "nos"),
        LyricToken(word: "libra")
      ]),
    ]);
    final matcher = VocalAlignmentMatcher(song);

    // Cantante canta la primera frase continua: "De música"
    matcher.processUtterance("De música");
    expect(matcher.currentState.currentLineIndex, equals(0));
    expect(matcher.currentState.currentWordIndex, equals(2));

    // El reconocimiento añade "ligera" (completa verso 0 y avanza a verso 1)
    matcher.processUtterance("De música ligera");
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(0));

    // El cantante hace una pausa / solo de guitarra: el teleprompter se queda esperando pacientemente
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(0));

    // El cantante reanuda y canta la siguiente estrofa
    matcher.resetUtterance();
    matcher.processUtterance("Nada nos");
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(2));
  });
}
