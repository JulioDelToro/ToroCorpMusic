import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';

void main() {
  testWidgets('FloatingTeleprompterCapsule renders Dynamic Island pill with static Voz, REC, tokens and menu button', (tester) async {
    final tokens = [
      const LyricToken(word: 'Estoy'),
      const LyricToken(word: 'grabando', chordUnderneath: 'G'),
      const LyricToken(word: 'este'),
      const LyricToken(word: 'video'),
    ];

    int tappedIndex = -1;
    bool menuTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          tokens: tokens,
          currentWordIndex: 1, // 'grabando' activo con acorde G
          isSinging: true,
          isRecording: true,
          recordingSeconds: 2,
          onWordTap: (idx) => tappedIndex = idx,
          onMenuTap: () => menuTapped = true,
        ),
      ),
    ));

    // Validar indicador estático 'Voz' (nunca cambia de texto)
    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('00:02'), findsOneWidget);

    // Validar texto del teleprompter
    expect(find.text('Estoy'), findsOneWidget);
    expect(find.text('grabando'), findsOneWidget);
    expect(find.text('G'), findsOneWidget); // Acorde superior
    expect(find.text('video'), findsOneWidget);

    // Validar botón de menú en el extremo derecho de la cápsula
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // Probar toque en palabra
    await tester.tap(find.text('video'));
    await tester.pump();
    expect(tappedIndex, equals(3));

    // Probar toque en botón de menú
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(menuTapped, isTrue);
  });
}
