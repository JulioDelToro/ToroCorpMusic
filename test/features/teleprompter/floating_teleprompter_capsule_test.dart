import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';

void main() {
  testWidgets('FloatingTeleprompterCapsule renders Dynamic Island pill with Voz, REC, tokens and settings button', (tester) async {
    final tokens = [
      const LyricToken(word: 'Estoy'),
      const LyricToken(word: 'grabando', chordUnderneath: 'G'),
      const LyricToken(word: 'este'),
      const LyricToken(word: 'video'),
    ];

    int tappedIndex = -1;
    bool settingsTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          tokens: tokens,
          currentWordIndex: 1, // 'grabando' activo con acorde G
          isSinging: true,
          isRecording: true,
          recordingSeconds: 2,
          onWordTap: (idx) => tappedIndex = idx,
          onSettingsTap: () => settingsTapped = true,
        ),
      ),
    ));

    // Validar indicadores de la izquierda
    expect(find.text('Canta'), findsOneWidget);
    expect(find.text('00:02'), findsOneWidget);

    // Validar texto del teleprompter
    expect(find.text('Estoy'), findsOneWidget);
    expect(find.text('grabando'), findsOneWidget);
    expect(find.text('G'), findsOneWidget); // Acorde superior
    expect(find.text('video'), findsOneWidget);

    // Validar botón derecho de sliders / ecualizador
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Probar toque en palabra
    await tester.tap(find.text('video'));
    await tester.pump();
    expect(tappedIndex, equals(3));

    // Probar toque en botón de ajustes
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    expect(settingsTapped, isTrue);
  });
}
