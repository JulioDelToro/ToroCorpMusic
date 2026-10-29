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

  testWidgets('FloatingTeleprompterCapsule Voz button switches to Reiniciar on tap and resets on second tap', (tester) async {
    bool resetTriggered = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          currentLine: const LyricLine(tokens: [LyricToken(word: 'Hola')]),
          currentWordIndex: 0,
          onResetTap: () => resetTriggered = true,
        ),
      ),
    ));

    // Estado inicial: botón dice 'Voz'
    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Reiniciar'), findsNothing);

    // Primer toque en 'Voz': cambia a 'Reiniciar'
    await tester.tap(find.text('Voz'));
    await tester.pumpAndSettle();

    expect(find.text('Reiniciar'), findsOneWidget);
    expect(find.text('Voz'), findsNothing);
    expect(resetTriggered, isFalse);

    // Segundo toque en 'Reiniciar': ejecuta el reinicio de canción
    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();

    expect(resetTriggered, isTrue);
    expect(find.text('Voz'), findsOneWidget);
  });

  testWidgets('FloatingTeleprompterCapsule displays 3 lines: current line remains fully yellow when finished, line 2 in preview', (tester) async {
    final lines = [
      const LyricLine(tokens: [LyricToken(word: 'Ella'), LyricToken(word: 'durmió')]),
      const LyricLine(tokens: [LyricToken(word: 'Y'), LyricToken(word: 'yo')]),
      const LyricLine(tokens: [LyricToken(word: 'Despiértame')]),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          allLines: lines,
          currentLineIndex: 0,
          currentWordIndex: 2, // Terminada la primera línea (2 de 2 palabras)
          highlightColor: const Color(0xFFFFB800),
        ),
      ),
    ));

    // Ambas palabras de la línea 1 deben estar en pantalla y pintadas en amarillo
    expect(find.text('Ella'), findsOneWidget);
    expect(find.text('durmió'), findsOneWidget);

    final ellaText = tester.widget<Text>(find.text('Ella'));
    expect(ellaText.style?.color, equals(const Color(0xFFFFB800)));

    final durmioText = tester.widget<Text>(find.text('durmió'));
    expect(durmioText.style?.color, equals(const Color(0xFFFFB800)));

    // La siguiente línea (Y yo) debe estar visible debajo para anticipar lectura pero en blanco/preview
    expect(find.text('Y'), findsOneWidget);
    expect(find.text('yo'), findsOneWidget);
    final yText = tester.widget<Text>(find.text('Y'));
    expect(yText.style?.color, equals(Colors.white60));

    // La tercera línea (Despiértame) debe estar visible debajo
    expect(find.text('Despiértame'), findsOneWidget);
  });

  testWidgets('FloatingTeleprompterCapsule expands to Music Stand mode when camera is off with font size controls and chords', (tester) async {
    final lines = [
      const LyricLine(tokens: [LyricToken(word: 'De', chordUnderneath: 'G'), LyricToken(word: 'aquel')]),
      const LyricLine(tokens: [LyricToken(word: 'amor', chordUnderneath: 'Bm'), LyricToken(word: 'de')]),
      const LyricLine(tokens: [LyricToken(word: 'música', chordUnderneath: 'Em'), LyricToken(word: 'ligera')]),
      const LyricLine(tokens: [LyricToken(word: 'Nada', chordUnderneath: 'C'), LyricToken(word: 'nos')]),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingTeleprompterCapsule(
          allLines: lines,
          currentLineIndex: 0,
          currentWordIndex: 0,
          isCameraActive: false,
        ),
      ),
    ));

    // Initially in compact pill mode: height is 108.0
    final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
    final initialSize = tester.getSize(capsuleFinder);
    expect(initialSize.height, equals(108.0));

    // Expand icon button is visible when camera is off
    final expandBtn = find.byIcon(Icons.unfold_more);
    expect(expandBtn, findsOneWidget);

    // Tap to expand into Music Stand mode
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();

    // Height expands significantly (> 200px)
    final expandedSize = tester.getSize(capsuleFinder);
    expect(expandedSize.height, greaterThan(200.0));

    // Mode badge is displayed
    expect(find.text('Modo Atril'), findsOneWidget);

    // Font controls A- and A+ are present
    expect(find.text('A-'), findsOneWidget);
    expect(find.text('A+'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // Tap A+ to increase font size
    await tester.tap(find.text('A+'));
    await tester.pump();
    expect(find.text('115%'), findsOneWidget);

    // Tap A- to decrease font size
    await tester.tap(find.text('A-'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);

    // Chords and lyrics are visible in Music Stand mode
    expect(find.text('G'), findsWidgets);
    expect(find.text('Bm'), findsWidgets);
    expect(find.text('Em'), findsWidgets);
    expect(find.text('C'), findsWidgets);

    // Collapse button is present in Music Stand mode
    final collapseBtn = find.byIcon(Icons.close_fullscreen);
    expect(collapseBtn, findsOneWidget);

    // Tap collapse button to return to compact capsule
    await tester.tap(collapseBtn);
    await tester.pumpAndSettle();

    final collapsedSize = tester.getSize(capsuleFinder);
    expect(collapsedSize.height, equals(108.0));
  });

  testWidgets('FloatingTeleprompterCapsule auto-collapses when isCameraActive changes to true', (tester) async {
    final lines = [
      const LyricLine(tokens: [LyricToken(word: 'Línea', chordUnderneath: 'Am'), LyricToken(word: 'uno')]),
      const LyricLine(tokens: [LyricToken(word: 'Línea', chordUnderneath: 'C'), LyricToken(word: 'dos')]),
    ];

    bool isCamActive = false;

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => isCamActive = true),
                  child: const Text('Toggle Cam'),
                ),
                FloatingTeleprompterCapsule(
                  allLines: lines,
                  currentLineIndex: 0,
                  currentWordIndex: 0,
                  isCameraActive: isCamActive,
                ),
              ],
            ),
          ),
        );
      },
    ));

    // Expand island while camera is off
    final expandBtn = find.byIcon(Icons.unfold_more);
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();

    final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
    expect(tester.getSize(capsuleFinder).height, greaterThan(200.0));

    // Toggle camera ON
    await tester.tap(find.text('Toggle Cam'));
    await tester.pumpAndSettle();

    // Capsule must smoothly auto-collapse back to compact 108.0
    expect(tester.getSize(capsuleFinder).height, equals(108.0));

    // When camera is on, the expand button is no longer available
    expect(find.byIcon(Icons.unfold_more), findsNothing);
  });
}
