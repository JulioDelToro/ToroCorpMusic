import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/acoustic_vocal_karaoke_service.dart';
import 'package:toro_music_teleprompter/features/audio/services/vocal_alignment_matcher.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'create') return null;
        if (methodCall.method == 'hasPermission') return true;
        if (methodCall.method == 'dispose') return null;
        if (methodCall.method == 'stop') return null;
        if (methodCall.method == 'start') return null;
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('Requinto and Instrumental Pause Detection', () {
    test('ChordProParser detects [Requinto] and [Solo] as instrumental lines', () {
      const raw = '''
[Bm] De música [G] ligera
[Requinto]
[Bm] Nada más queda
''';
      final parser = ChordProParser();
      final song = parser.parse(raw);

      expect(song.lines.length, equals(3));
      expect(song.lines[0].isInstrumental, isFalse);
      expect(song.lines[1].isInstrumental, isTrue);
      expect(song.lines[1].instrumentalLabel, contains('REQUINTO'));
      expect(song.lines[2].isInstrumental, isFalse);
    });

    test('AcousticVocalKaraokeService locks on instrumental requinto line', () async {
      final song = SongScript(
        lines: [
          const LyricLine(tokens: [
            LyricToken(word: 'De'),
            LyricToken(word: 'música'),
          ]),
          const LyricLine(
            tokens: [LyricToken(word: '🎸 REQUINTO')],
            isInstrumental: true,
            instrumentalLabel: '🎸 REQUINTO',
          ),
          const LyricLine(tokens: [
            LyricToken(word: 'Nada'),
          ]),
        ],
      );

      final service = AcousticVocalKaraokeService(song: song);
      expect(service.currentState.isInstrumentalBreak, isFalse);

      // Advance through verse 1
      service.nextWordManual(); // word 1 'música'
      expect(service.currentState.wordIndex, equals(1));

      // Advance at end of verse 1: transitions into Requinto and locks
      service.nextWordManual();
      expect(service.currentState.lineIndex, equals(1));
      expect(service.currentState.isInstrumentalBreak, isTrue);
      expect(service.currentState.instrumentalLabel, contains('REQUINTO'));

      // Resuming from instrumental advances to next sung verse
      service.resumeFromInstrumental();
      expect(service.currentState.lineIndex, equals(2));
      expect(service.currentState.isInstrumentalBreak, isFalse);
      expect(service.currentState.wordIndex, equals(0));

      await service.dispose();
    });
  });

  group('Word Matching and Phonetic Verification', () {
    test('VocalAlignmentMatcher.verifyWordMatch accepts matching phonetic words', () {
      expect(VocalAlignmentMatcher.verifyWordMatch('música', 'musica'), isTrue);
      expect(VocalAlignmentMatcher.verifyWordMatch('ligera', 'ligera'), isTrue);
      expect(VocalAlignmentMatcher.verifyWordMatch('canción', 'cancion'), isTrue);
    });

    test('VocalAlignmentMatcher.verifyWordMatch strictly rejects non-matching words', () {
      // User says "mesa" or "hola" instead of "música"
      expect(VocalAlignmentMatcher.verifyWordMatch('música', 'mesa'), isFalse);
      expect(VocalAlignmentMatcher.verifyWordMatch('ligera', 'guitarra'), isFalse);
      expect(VocalAlignmentMatcher.verifyWordMatch('de', 'nada'), isFalse);
    });

    test('VocalAlignmentMatcher rejects non-matching spoken words and freezes position', () {
      final song = SongScript(lines: [
        const LyricLine(tokens: [
          LyricToken(word: 'De'),
          LyricToken(word: 'música'),
          LyricToken(word: 'ligera'),
        ])
      ]);
      final matcher = VocalAlignmentMatcher(song);

      // Sings first word: "de" -> matches and advances active pointer to next word (1: 'música')
      matcher.processSpokenWord('de');
      expect(matcher.currentState.currentWordIndex, equals(1));

      // User says random unrelated word: "carro" / "mesa"
      matcher.processSpokenWord('carro');
      expect(matcher.currentState.currentWordIndex, equals(1)); // Does NOT advance!

      matcher.processSpokenWord('mesa');
      expect(matcher.currentState.currentWordIndex, equals(1)); // Still does NOT advance!

      // User sings actual lyric: "música" -> matches and advances to next word (2: 'ligera')
      matcher.processSpokenWord('musica');
      expect(matcher.currentState.currentWordIndex, equals(2)); // Advances!
    });
  });
}
