import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
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

  testWidgets('FloatingTeleprompterCapsule 2-Line architecture displays current line with read words highlighted and next line below', (tester) async {
    const highlightColor = Color(0xFFFFD60A); // Amarillo Neón
    const line1 = LyricLine(tokens: [
      LyricToken(word: 'De'),
      LyricToken(word: 'aquel'),
      LyricToken(word: 'amor', chordUnderneath: 'Bm'),
      LyricToken(word: 'de'),
      LyricToken(word: 'música'),
      LyricToken(word: 'ligera'),
    ]);

    const line2 = LyricLine(tokens: [
      LyricToken(word: 'Nada'),
      LyricToken(word: 'nos'),
      LyricToken(word: 'libra'),
    ]);

    int tappedWord = -1;
    bool nextLineTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          currentLine: line1,
          nextLine: line2,
          currentWordIndex: 2, // 'amor' activo (índice 2). 'De' y 'aquel' ya leídos.
          isSinging: true,
          highlightColor: highlightColor,
          onWordTap: (idx) => tappedWord = idx,
          onNextLineTap: () => nextLineTapped = true,
        ),
      ),
    ));

    // Validar que ambas líneas se muestran simultáneamente
    expect(find.text('De'), findsOneWidget);
    expect(find.text('aquel'), findsOneWidget);
    expect(find.text('amor'), findsOneWidget);
    expect(find.text('Bm'), findsOneWidget);
    expect(find.text('ligera'), findsOneWidget);
    expect(find.text('Nada'), findsOneWidget);
    expect(find.text('nos'), findsOneWidget);
    expect(find.text('libra'), findsOneWidget);

    // Validar colores de texto:
    // 'De' (índice 0, ya leído): DEBE estar en color highlightColor
    final deWidget = tester.widget<Text>(find.text('De'));
    expect(deWidget.style?.color, equals(highlightColor));

    // 'aquel' (índice 1, ya leído): DEBE estar en color highlightColor
    final aquelWidget = tester.widget<Text>(find.text('aquel'));
    expect(aquelWidget.style?.color, equals(highlightColor));

    // 'amor' (índice 2, cantando en este instante): DEBE estar en color highlightColor con resplandor
    final amorWidget = tester.widget<Text>(find.text('amor'));
    expect(amorWidget.style?.color, equals(highlightColor));
    expect(amorWidget.style?.shadows, isNotNull);

    // 'ligera' (índice 5, por leer de la línea actual): DEBE estar en blanco
    final ligeraWidget = tester.widget<Text>(find.text('ligera'));
    expect(ligeraWidget.style?.color, equals(Colors.white));

    // 'Nada' (línea 2, próxima línea a leer): DEBE estar en blanco atenuado
    final nadaWidget = tester.widget<Text>(find.text('Nada'));
    expect(nadaWidget.style?.color, equals(Colors.white60));

    // Toque en palabra de la línea 1
    await tester.tap(find.text('ligera'));
    await tester.pump();
    expect(tappedWord, equals(5));

    // Toque en la línea 2 para avanzar de línea
    await tester.tap(find.text('Nada'));
    await tester.pump();
    expect(nextLineTapped, isTrue);
  });
}
