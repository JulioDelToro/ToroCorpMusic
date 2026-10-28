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

    // El reconocimiento añade "ligera" (completa el verso 0 dejándolo 100% amarillo en pantalla)
    matcher.processUtterance("De música ligera");
    expect(matcher.currentState.currentLineIndex, equals(0));
    expect(matcher.currentState.currentWordIndex, equals(3)); // 3 de 3 palabras en verso 0

    // El teleprompter conserva el verso 0 en amarillo esperando que el cantante empiece el verso 1
    expect(matcher.currentState.currentLineIndex, equals(0));
    expect(matcher.currentState.currentWordIndex, equals(3));

    // El cantante canta la siguiente estrofa: ahora sí salta al verso 1
    matcher.resetUtterance();
    matcher.processUtterance("Nada nos");
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(2));
  });

  test('VocalAlignmentMatcher jumps ahead to second line if word in first line was missed', () {
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

    // Cantante dijo "De", avanzó al índice 1
    matcher.processSpokenWord("de");
    expect(matcher.currentState.currentLineIndex, equals(0));
    expect(matcher.currentState.currentWordIndex, equals(1));

    // El micrófono no detectó "música ligera", y el usuario ya está cantando en la segunda línea: "nos libra"
    matcher.processSpokenWord("nos");

    // Debe saltar automáticamente a la segunda línea (índice 1) y posicionarse tras la palabra 'nos' (índice 2)
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(2));

    // Canta la última palabra de la segunda línea
    matcher.processSpokenWord("libra");
    expect(matcher.currentState.currentLineIndex, equals(1));
    expect(matcher.currentState.currentWordIndex, equals(3));
  });

  test('VocalAlignmentMatcher matches elongated singing vowels and Spanish phonetic variants', () {
    // Vocales alargadas de canto: "músiiica" -> "música", "noooo" -> "no"
    expect(VocalAlignmentMatcher.verifyWordMatch("música", "múúúúúúúúsica"), isTrue);
    expect(VocalAlignmentMatcher.verifyWordMatch("no", "noooo"), isTrue);

    // Equivalencias fonéticas en español: b/v, seseo z/s/ce/ci, yeísmo ll/y
    expect(VocalAlignmentMatcher.verifyWordMatch("vida", "bida"), isTrue);
    expect(VocalAlignmentMatcher.verifyWordMatch("corazón", "corason"), isTrue);
    expect(VocalAlignmentMatcher.verifyWordMatch("hace", "ase"), isTrue);
    expect(VocalAlignmentMatcher.verifyWordMatch("llora", "yora"), isTrue);

    // Palabras disonantes no relacionadas siguen siendo rechazadas estrictamente
    expect(VocalAlignmentMatcher.verifyWordMatch("música", "carro"), isFalse);
    expect(VocalAlignmentMatcher.verifyWordMatch("ligera", "mesa"), isFalse);
    expect(VocalAlignmentMatcher.verifyWordMatch("de", "zapato"), isFalse);
  });
}
