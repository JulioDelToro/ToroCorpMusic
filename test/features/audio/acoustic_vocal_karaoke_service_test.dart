import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/acoustic_vocal_karaoke_service.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';

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

    test('estado inicial: línea 0, palabra 0, esperando voz', () {
      expect(service.currentState.lineIndex, equals(0));
      expect(service.currentState.wordIndex, equals(0));
      expect(service.currentState.isWaitingForVoice, isTrue);
      expect(service.currentState.isSinging, isFalse);
    });

    test('avance manual avanza a la siguiente palabra dentro del mismo verso', () {
      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(1));
      expect(service.currentState.lineIndex, equals(0));

      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(2));
      expect(service.currentState.lineIndex, equals(0));
    });

    test('avance manual al final de verso pasa a la siguiente línea', () {
      service.nextWordManual(); // palabra 1
      service.nextWordManual(); // palabra 2
      service.nextWordManual(); // línea 1, palabra 0
      expect(service.currentState.lineIndex, equals(1));
      expect(service.currentState.wordIndex, equals(0));
    });

    test('retroceso manual retrocede palabra y se queda en 0,0 si ya es la primera', () {
      service.nextWordManual();
      expect(service.currentState.wordIndex, equals(1));

      service.previousWordManual();
      expect(service.currentState.wordIndex, equals(0));

      service.previousWordManual();
      expect(service.currentState.wordIndex, equals(0));
      expect(service.currentState.lineIndex, equals(0));
    });

    test('reset restaura estado inicial', () {
      service.nextWordManual();
      service.nextWordManual();
      service.reset();
      expect(service.currentState.wordIndex, equals(0));
      expect(service.currentState.lineIndex, equals(0));
      expect(service.currentState.isWaitingForVoice, isTrue);
    });

    test('updateSong cambia la canción y reinicia el estado', () {
      service.nextWordManual();
      service.nextWordManual();

      const newSong = SongScript(
        title: 'Nueva Canción',
        lines: [
          LyricLine(tokens: [LyricToken(word: 'Hola')]),
        ],
      );
      service.updateSong(newSong);

      expect(service.currentState.lineIndex, equals(0));
      expect(service.currentState.wordIndex, equals(0));
    });
  });
}
