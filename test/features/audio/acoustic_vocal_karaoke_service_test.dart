import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/acoustic_vocal_karaoke_service.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'create') return null;
        if (methodCall.method == 'hasPermission') return true;
        if (methodCall.method == 'dispose') return null;
        return null;
      },
    );
  });

  group('AcousticVocalKaraokeService', () {
    late SongScript song;
    late AcousticVocalKaraokeService service;

    setUp(() {
      song = const SongScript(
        title: 'Prueba Karaoke',
        lines: [
          LyricLine(tokens: [
            LyricToken(word: 'De'),
            LyricToken(word: 'música'),
            LyricToken(word: 'ligera'),
          ]),
          LyricLine(tokens: [
            LyricToken(word: 'Nada'),
            LyricToken(word: 'más'),
          ]),
        ],
      );
      service = AcousticVocalKaraokeService(song: song);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('initial state has lineIndex 0, wordIndex 0 and isWaitingForVoice true', () {
      expect(service.currentState.lineIndex, equals(0));
      expect(service.currentState.wordIndex, equals(0));
      expect(service.currentState.isWaitingForVoice, isTrue);
    });

    test('manual word advancement advances to next word and stays in line', () {
      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(1));
      expect(service.currentState.lineIndex, equals(0));

      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(2));
      expect(service.currentState.lineIndex, equals(0));
    });

    test('advancing past end of line moves to the next verse', () {
      service.nextWordManual(); // word 1
      service.nextWordManual(); // word 2
      service.nextWordManual(); // line 1, word 0
      expect(service.currentState.lineIndex, equals(1));
      expect(service.currentState.wordIndex, equals(0));
    });

    test('manual previousWord rewinds word index or stays at 0', () {
      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(1));

      service.previousWordManual();
      expect(service.currentState.wordIndex, equals(0));

      service.previousWordManual();
      expect(service.currentState.wordIndex, equals(0));
    });

    test('reset restores initial state', () {
      service.nextWordManual();
      service.nextWordManual();
      service.reset();
      expect(service.currentState.wordIndex, equals(0));
      expect(service.currentState.lineIndex, equals(0));
    });
  });
}
